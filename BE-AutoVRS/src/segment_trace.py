"""
SAM-based trace/defect segmenter with width measurement.

Uses SAM/SAM2 to:
- Generate masks from OBB-based point prompts
- Measure width at selected positive points
"""

import os
from typing import Optional
from ultralytics import SAM
import cv2
import numpy as np
import torch

from utils.detection import SegmentationResult
from utils.segment_utils import (
    two_positive_points_outward_45,
    width_at_point,
    copper_prior,
    select_best_positive_point,
)


class SAMTraceSegmenter:
    """
    Segment đường mạch / vùng lỗi dựa vào OBB + SAM/SAM2, sau đó đo bề rộng.

    Workflow:
      1) Từ OBB → sinh 2 điểm dương (pos) phía phần cần segment + 2 điểm âm (neg).
      2) Gọi SAM/SAM2 để lấy mask.
      3) Đo bề rộng mask tại 1 trong 2 điểm dương theo phương vuông góc trace (v_dir).
    """

    def __init__(
        self,
        weights: str,
        pixel_size_um: Optional[float] = None,
        use_prior: bool = True,
    ) -> None:
        """
        weights       : đường dẫn trọng số SAM2/SAM.
        pixel_size_um : kích thước pixel (µm/pixel). Nếu None → chỉ báo px.
        use_prior     : dùng mask "đồng thô" (LAB a + Otsu) khi chọn mask tốt nhất.
        """
        self.pixel_size_um = pixel_size_um
        self.use_prior = use_prior
        self.model = None
        self.backend = "dummy"  # "sam2", "sam" hoặc "dummy"
        self._load_model(weights)

    def _load_model(self, weights: str) -> None:
        """Load SAM2 hoặc SAM từ ultralytics. Fallback sang dummy nếu lỗi."""
        try:
              # type: ignore

            if not os.path.exists(weights):
                raise FileNotFoundError(weights)

            self.model = SAM(weights)
            self.backend = "sam"
        except Exception as e:
            print(f"[WARN] Không load được SAM/SAM2: {e}. Dùng backend dummy.")
            self.model = None
            self.backend = "dummy"

    @torch.inference_mode()
    def _predict_mask(
        self,
        image_bgr: np.ndarray,
        pts_xy: np.ndarray,
        labels: np.ndarray,
    ) -> np.ndarray:
        """
        Gọi SAM/SAM2 với point prompts, sau đó chọn mask "đẹp" nhất:
        - phải cover toàn bộ điểm dương (cho phép lệch 1px).
        - ưu thế mask có tâm gần trung bình các pos-point, diện tích hợp lý,
          và IoU tốt với prior (nếu bật).
        """
        H, W = image_bgr.shape[:2]

        if self.backend == "dummy" or self.model is None:
            return np.zeros((H, W), dtype=np.uint8)

        pts_xy = pts_xy.astype(np.float32)
        labels = labels.astype(np.int32).tolist()

        # API SAM2/SAM hơi khác nhau → thử lần 1, lỗi thì đổi tham số
        kwargs = dict(points=[pts_xy.tolist()], labels=[labels])
        try:
            results = self.model.predict(image_bgr, **kwargs, verbose=False)
        except TypeError:
            kwargs.pop("labels", None)
            kwargs["point_labels"] = [labels]
            results = self.model.predict(image_bgr, **kwargs, verbose=False)

        r0 = results[0]
        data = getattr(getattr(r0, "masks", None), "data", None)
        print(f"Mask data: {data}")
        if data is None or len(data) == 0:
            return np.zeros((H, W), dtype=np.uint8)

        masks = data.detach().cpu().numpy()  # (K, H, W)

        pos = pts_xy[np.array(labels) == 1]
        center = pos.mean(0)
        prior = copper_prior(image_bgr) if self.use_prior else None

        best_score = -1e9
        best_mask = None

        for m in masks:
            m_bin = m > 0.5

            # (1) Tất cả pos-point phải nằm trong/giáp mask (nới 1px)
            ok = True
            for p in pos.astype(int):
                y, x = int(p[1]), int(p[0])
                if not (0 <= x < W and 0 <= y < H):
                    ok = False
                    break
                y0, y1 = max(0, y - 1), min(H - 1, y + 1)
                x0, x1 = max(0, x - 1), min(W - 1, x + 1)
                if m_bin[y0:y1 + 1, x0:x1 + 1].max() == 0:
                    ok = False
                    break
            if not ok:
                continue

            # (2) Tính score: khoảng cách tâm nhỏ, diện tích vừa phải, IoU tốt với prior
            ys, xs = np.where(m_bin)
            if len(xs) == 0:
                continue

            cen = np.array([xs.mean(), ys.mean()], dtype=np.float32)
            dist = float(np.linalg.norm(cen - center))

            score = -dist + 0.001 * float(m_bin.sum())
            if prior is not None:
                inter = (m_bin & (prior > 0)).sum()
                uni = m_bin.sum() + (prior > 0).sum() - inter + 1e-6
                score += 0.002 * float(inter / uni)

            if score > best_score:
                best_score = score
                best_mask = m_bin

        if best_mask is None:
            return np.zeros((H, W), dtype=np.uint8)
        return best_mask.astype(np.uint8)

    def segment_and_measure_from_obb(
    self,
    image_bgr: np.ndarray,
    obb_poly_xy: np.ndarray,
    frac_v: float = 1.0,
    frac_uv: float = 1.0,
    margin_px: int = 2,
    step: float = 0.5,
    max_len: int = 512,
    selection_radius: int = 10,
) -> SegmentationResult:
        H, W = image_bgr.shape[:2]
        poly = np.asarray(obb_poly_xy, dtype=np.float32)

        # 1) Generate positive points (outward from OBB at 45°)
        pos_points = two_positive_points_outward_45(
            poly,
            img_hw=(H, W),
            frac_v=frac_v,
            frac_uv=frac_uv,
            margin_px=margin_px,
        )

        points = np.vstack([pos_points])  # (2,2)
        labels = np.array([1, 1], dtype=np.int32)

        # 2) SAM segmentation
        mask01 = self._predict_mask(image_bgr, points, labels)

        # 3) Select best positive point (highest overlap with mask)
        best_idx, overlap = select_best_positive_point(
            mask01,
            pos_points,
            radius=selection_radius,
        )
        p_measure = pos_points[best_idx]

        # 4) Measure width (bỏ qua vùng lỗi nếu có defect_obb_polys)
        width_px, p_left, p_right, p_start = width_at_point(
            mask01,
            p_measure,
            step=step,
            max_len=max_len,
            defect_polys=poly,
        )

        width_um = None
        width_mm = None
        if self.pixel_size_um is not None:
            width_um = width_px * float(self.pixel_size_um)
            width_mm = width_um / 1000.0

        return SegmentationResult(
            mask=mask01,
            width_px=float(width_px),
            width_um=width_um,
            width_mm=width_mm,
            pos_points=pos_points,
            best_pos_idx=int(best_idx),
            overlap=float(overlap),
            p_left=p_left,
            p_right=p_right,
            p_start=p_start,
        )

