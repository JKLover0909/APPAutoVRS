# segment/sam_segmenter.py
import os
import numpy as np
import torch
import cv2
from ultralytics import SAM

class SAMSegmenter:
    """
    Giao diện gọn cho SAM:
    - load_model()
    - segment_from_bbox(image_bgr, bbox) -> mask (H,W) uint8 {0,1}
    - segment_from_polygon(image_bgr, polygon, use_bbox_hint=True) -> mask (H,W) uint8 {0,1}
      *ĐẢM BẢO mask chỉ nằm trong polygon*
    """
    def __init__(self, model_path=None):
        self.model_path = model_path
        self.model = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

    def load_model(self):
        try:
            if self.model_path is None:
                self.model_path = os.path.join(os.getcwd(), "models", "sam2.1_s.pt")
            if not os.path.exists(self.model_path):
                print(f"⚠️ SAM model not found: {self.model_path}, using dummy.")
                self.model = "dummy"
                return True

            
            self.model = SAM(self.model_path)
            return True
        except Exception as e:
            print(f"⚠️ SAM load error: {e}, using dummy.")
            self.model = "dummy"
            return True

    def _safe_bbox(self, image_bgr, bbox):
        h, w = image_bgr.shape[:2]
        x1,y1,x2,y2 = bbox
        x1 = max(0, min(int(x1), w-1))
        y1 = max(0, min(int(y1), h-1))
        x2 = max(x1+1, min(int(x2), w))
        y2 = max(y1+1, min(int(y2), h))
        return [x1,y1,x2,y2]

    def segment_from_bbox(self, image_bgr, bbox):
        """Bản cũ (giữ nguyên): mask trong bbox."""
        x1,y1,x2,y2 = self._safe_bbox(image_bgr, bbox)

        if self.model == "dummy":
            mask = np.zeros(image_bgr.shape[:2], dtype=np.uint8)
            cx, cy = (x1+x2)//2, (y1+y2)//2
            rx, ry = max(1,(x2-x1)//2), max(1,(y2-y1)//2)
            yy, xx = np.ogrid[:mask.shape[0], :mask.shape[1]]
            ellipse = ((xx-cx)/rx)**2 + ((yy-cy)/ry)**2 <= 1
            mask[ellipse] = 1
            return mask

        try:
            res = self.model.predict(image_bgr, bboxes=[[x1,y1,x2,y2]])
            if res and len(res)>0 and getattr(res[0], "masks", None) is not None:
                mk = res[0].masks[0].data
                mk = mk.cpu().numpy().squeeze().astype(np.uint8)
                mk[mk>0] = 1
                return mk
        except Exception as e:
            print(f"⚠️ SAM inference error (bbox): {e}")

        mask = np.zeros(image_bgr.shape[:2], dtype=np.uint8)
        mask[y1:y2, x1:x2] = 1
        return mask

    def segment_from_polygon(self, image_bgr, polygon, use_bbox_hint=True):
        """
        polygon: ndarray/list shape (4,2) hoặc (N,2), toạ độ ảnh (int/float)
        Trả về mask nhị phân (H,W) ∈ {0,1} và được giới hạn trong cả polygon & bbox.
        Yêu cầu mới:
        - ROI = bounding box của polygon (không phải toàn ảnh)
        - Positive point = tâm bbox
        - SAM được prompt bằng bboxes + points(labels=1)
        """
        h, w = image_bgr.shape[:2]

        # -------- 1) Polygon & bbox ----------
        pts = np.asarray(polygon, dtype=np.float32).reshape(-1, 2)
        # polygon mask (dùng để kẹp kết quả cuối, vẫn “segment trong polygon”)
        poly_mask = np.zeros((h, w), dtype=np.uint8)
        cv2.fillPoly(poly_mask, [pts.astype(np.int32).reshape(-1, 1, 2)], 1)

        # bbox từ polygon
        x1, y1 = float(pts[:, 0].min()), float(pts[:, 1].min())
        x2, y2 = float(pts[:, 0].max()), float(pts[:, 1].max())
        x1, y1, x2, y2 = self._safe_bbox(image_bgr, [x1, y1, x2, y2])

        # bbox mask (ROI): chỉ cho phép trong bbox
        bbox_mask = np.zeros((h, w), dtype=np.uint8)
        bbox_mask[y1:y2, x1:x2] = 1

        # Positive point = tâm bbox
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2

        # -------- 2) Dummy path (không có SAM) ----------
        if self.model == "dummy":
            # Vẽ 1 ellipse trong bbox, rồi kẹp theo bbox & polygon
            mask = np.zeros((h, w), dtype=np.uint8)
            rx, ry = max(1, (x2 - x1) // 2), max(1, (y2 - y1) // 2)
            yy, xx = np.ogrid[:h, :w]
            ellipse = ((xx - cx) / max(1, rx)) ** 2 + ((yy - cy) / max(1, ry)) ** 2 <= 1
            mask[ellipse] = 1
            # clip theo ROI & polygon
            return (mask & bbox_mask & poly_mask).astype(np.uint8)

        # -------- 3) Gọi SAM với bboxes + positive point ----------
        sam_mask = None
        try:
            # Ultralytics SAM: truyền đồng thời bbox và points/labels
            # (API hiện tại hỗ trợ points = [[cx,cy]] và labels = [1] cho positive)
            res = self.model.predict(
                image_bgr,
                bboxes=[[x1, y1, x2, y2]] if use_bbox_hint else None,
                points=[[[float(cx), float(cy)]]],
                labels=[[1]],
            )

            # Nếu SAM trả nhiều mask, chọn mask có overlap lớn nhất với ROI (bbox ∩ polygon)
            roi_for_select = (bbox_mask & poly_mask).astype(np.uint8)
            if res and len(res) > 0 and getattr(res[0], "masks", None) is not None and len(res[0].masks) > 0:
                best_mk, best_overlap = None, -1
                for mk in res[0].masks.data:
                    mk = mk.detach().cpu().numpy().squeeze().astype(np.uint8)
                    mk[mk > 0] = 1
                    # Ưu tiên mask nằm trong ROI
                    overlap = int((mk & roi_for_select).sum())
                    if overlap > best_overlap:
                        best_overlap = overlap
                        best_mk = mk
                sam_mask = best_mk
        except Exception as e:
            print(f"⚠️ SAM inference error (polygon+bbox+point): {e}")

        # -------- 4) Clip kết quả trong ROI (bbox) & polygon ----------
        if sam_mask is None:
            # fallback: chỉ ROI (bbox ∩ polygon)
            return (bbox_mask & poly_mask).astype(np.uint8)

        clipped = (sam_mask & bbox_mask & poly_mask).astype(np.uint8)
        return clipped
    