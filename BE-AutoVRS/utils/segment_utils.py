#utils/segment_utils.py
"""
segment_utils.py

Các hàm tiện ích cho:
- Xử lý OBB (tính trục u/v, bề rộng trace)
- Sinh điểm positive/negative cho SAM
- Đo bề rộng mask tại 1 điểm
- Helper đọc kết quả YOLO OBB
- Hàm vẽ debug
"""

from pathlib import Path
from typing import List, Optional, Tuple

import cv2
import numpy as np


# -------------------- IO helpers -------------------- #
def list_images(folder: str) -> List[str]:
    """Liệt kê toàn bộ ảnh trong folder (đệ quy)."""
    exts = (".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff")
    paths = [p for p in Path(folder).rglob("*") if p.suffix.lower() in exts]
    return sorted(str(p) for p in paths)


# -------------------- YOLO OBB helpers -------------------- #
def polys_from_obb(result) -> Optional[np.ndarray]:
    """
    Lấy polygon (4 điểm) từ YOLO OBB result.
    Trả về: (N, 4, 2) float32 hoặc None nếu không có OBB.
    """
    obb = getattr(result, "obb", None)
    if obb is not None and hasattr(obb, "xyxyxyxy") and obb.xyxyxyxy is not None:
        arr = obb.xyxyxyxy.detach().cpu().numpy()
        return arr.reshape(-1, 4, 2).astype(np.float32)
    return None


# -------------------- Geometry helpers -------------------- #
def _safe_unit(v: np.ndarray) -> np.ndarray:
    n = float(np.linalg.norm(v))
    return v / (n + 1e-6)


def obb_axes_and_width(poly_xy: np.ndarray) -> Tuple[np.ndarray, np.ndarray, float, np.ndarray]:
    """
    Từ polygon OBB (4x2) → trục u (song song trace), v (vuông góc trace), bề rộng theo v, tâm C.
    """
    P = np.asarray(poly_xy, dtype=np.float32)
    C = P.mean(0)

    edges = np.roll(P, -1, axis=0) - P
    i = int(np.argmax(np.linalg.norm(edges, axis=1)))

    u = _safe_unit(edges[i])                             # trục dài (theo trace)
    v = _safe_unit(np.array([-u[1], u[0]], np.float32))  # trục bề rộng (vuông góc trace)

    proj_v = (P - C) @ v
    width = float(proj_v.max() - proj_v.min())

    return u, v, width, C


def two_positive_points_outward_45(
    poly_xy: np.ndarray,
    img_hw: Optional[Tuple[int, int]] = None,
    frac_v: float = 1.0,
    frac_uv: float = 0.5,
    margin_px: int = 2,
) -> np.ndarray:
    """
    Sinh 2 điểm dương:
    - Chọn 2 đỉnh phía GAP (theo chiếu v nhỏ nhất).
    - Đẩy ra ngoài OBB theo hướng 45° (kết hợp v và ±u).
    """
    P = np.asarray(poly_xy, dtype=np.float32)
    C = P.mean(0)
    u, v, width, _ = obb_axes_and_width(P)

    if width < 1e-3:
        return P[:2].copy()

    proj_v = (P - C) @ v
    lower_idx = np.argsort(proj_v)[:2]  # hai điểm phía GAP

    step_v = (width * 0.6 * frac_v)
    step_u = step_v * frac_uv

    poly_i32 = P.astype(np.int32)
    pts = []
    H, W = img_hw if img_hw is not None else (None, None)

    for idx in lower_idx:
        sgn_u = np.sign((P[idx] - C) @ u) or 1.0
        cand = P[idx] + step_v * v + sgn_u * step_u * u

        # Nếu vẫn còn nằm trong OBB → lật u
        if cv2.pointPolygonTest(poly_i32, (float(cand[0]), float(cand[1])), False) >= 0:
            cand = P[idx] + step_v * v - sgn_u * step_u * u

        # Nếu vẫn trong OBB → đẩy thêm theo v
        if cv2.pointPolygonTest(poly_i32, (float(cand[0]), float(cand[1])), False) >= 0:
            cand = cand + (margin_px + 1.0) * v

        # Clamp vào ảnh
        if img_hw is not None:
            cand[0] = np.clip(cand[0], 0, W - 1)
            cand[1] = np.clip(cand[1], 0, H - 1)

        pts.append(cand)

    return np.stack(pts, 0).astype(np.float32)
def two_positive_points_angle(
    poly_xy: np.ndarray,
    angle_deg: float = 30.0,
    img_hw: Optional[Tuple[int, int]] = None,
) -> np.ndarray:
    """
    Sinh 2 positive points bằng giao của:
    - Trục đối xứng ngang OBB (qua tâm, song song cạnh dài)
    - Hai đường đi qua 2 đỉnh phía GAP, tạo góc angle_deg với cạnh ngắn.

    poly_xy : (4, 2) toạ độ 4 đỉnh OBB (theo YOLO OBB)
    angle_deg : góc với cạnh ngắn (trục v), ví dụ 30°
    img_hw : (H, W) nếu muốn clamp điểm vào trong ảnh
    """
    P = np.asarray(poly_xy, dtype=np.float32)

    # Lấy trục u (dài), v (ngắn), bề rộng theo v, tâm C
    u, v, width, C = obb_axes_and_width(P)
    if width < 1e-3:
        # OBB suy biến → fallback: lấy 2 đỉnh đầu
        return P[:2].copy()

    # Đưa các đỉnh về hệ toạ độ local (u, v)
    d = P - C
    x = d @ u  # toạ độ theo trục dài
    y = d @ v  # toạ độ theo trục ngắn

    # Lấy 2 đỉnh ở phía "GAP": 2 giá trị y nhỏ nhất (cùng 1 cạnh dài)
    idxs = np.argsort(y)[:2]

    angle = np.deg2rad(angle_deg)
    tan_a = float(np.tan(angle))

    x_min, x_max = float(x.min()), float(x.max())
    pos_local = []

    for idx in idxs:
        x0, y0 = float(x[idx]), float(y[idx])

        # Hai khả năng cho hướng (±): đều tạo góc angle_deg với trục v
        # Ta chọn hướng sao cho:
        #   1) Ưu tiên giao điểm nằm trong đoạn [x_min, x_max]
        #   2) Gần tâm (x=0) hơn
        candidates = []
        for s in (+1.0, -1.0):
            # Đường: (x, y) = (x0, y0) + t * (s*sin(a), cos(a))
            # Giao với y = 0  →  t = -y0 / cos(a)
            #                 →  x_int = x0 - y0 * s * tan(a)
            x_int = x0 - y0 * s * tan_a
            inside = (x_min <= x_int <= x_max)
            dist_center = abs(x_int)
            # not inside để khi sort, inside (False) ưu tiên hơn outside (True)
            candidates.append((not inside, dist_center, x_int))

        _, _, x_best = min(candidates, key=lambda t: (t[0], t[1]))
        pos_local.append(np.array([x_best, 0.0], dtype=np.float32))  # y=0 trên trục đối xứng

    # Đưa về toạ độ ảnh
    pts = []
    H, W = img_hw if img_hw is not None else (None, None)
    for xl, yl in pos_local:
        p = C + xl * u + yl * v
        if img_hw is not None:
            p[0] = np.clip(p[0], 0, W - 1)
            p[1] = np.clip(p[1], 0, H - 1)
        pts.append(p)

    return np.stack(pts, axis=0).astype(np.float32)


def select_best_positive_point(
    mask01: np.ndarray,
    pos_pts: np.ndarray,
    radius: int = 10,
) -> Tuple[int, float]:
    """
    Chọn điểm positive có nhiều pixel mask nhất trong vùng lân cận.
    
    Returns:
        (best_idx, overlap_ratio) - index của điểm tốt nhất và tỉ lệ overlap
    """
    H, W = mask01.shape
    best_idx = 0
    max_overlap = 0.0
    
    for i, pt in enumerate(pos_pts):
        x, y = int(round(pt[0])), int(round(pt[1]))
        if not (0 <= x < W and 0 <= y < H):
            continue
            
        # Tạo vùng kiểm tra
        y1, y2 = max(0, y - radius), min(H, y + radius + 1)
        x1, x2 = max(0, x - radius), min(W, x + radius + 1)
        
        roi = mask01[y1:y2, x1:x2]
        overlap = float(roi.sum()) / (roi.size + 1e-6)
        
        if overlap > max_overlap:
            max_overlap = overlap
            best_idx = i
    
    return best_idx, max_overlap


# -------------------- Prior mask (đồng thô) -------------------- #
def copper_prior(image_bgr: np.ndarray) -> np.ndarray:
    """
    Tạo mask "đồng thô" từ kênh a của màu LAB + Otsu.
    Dùng làm prior khi chọn mask SAM phù hợp.
    """
    lab = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2LAB)
    a = lab[:, :, 1]
    thr, _ = cv2.threshold(a, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return (a > thr).astype(np.uint8)

def heal_mask_with_defects(
    mask01: np.ndarray,
    defect_polys: Optional[np.ndarray] = None,
) -> np.ndarray:
    """
    Trả về mask đã được 'vá' các vùng lỗi:
    - mask01: 0/1
    - defect_polys: (M, 4, 2) hoặc (4, 2) là các OBB vùng khuyết.
    Bên trong các polygon này sẽ được set = 1 (coi như đồng).
    """
    mask = (mask01 > 0).astype(np.uint8)

    if defect_polys is None:
        return mask

    polys = np.asarray(defect_polys, dtype=np.float32)
    if polys.ndim == 2:
        polys = polys[None, ...]  # (4,2) -> (1,4,2)

    mask_filled = mask.copy()
    for poly in polys:
        cv2.fillConvexPoly(mask_filled, poly.astype(np.int32), 1)

    return mask_filled



# -------------------- Đo bề rộng trace trên mask -------------------- #
def width_at_point(
    mask01: np.ndarray,
    point_xy: np.ndarray,
    step: float = 0.5,
    max_len: float = 512.0,
    smooth_window: int = 5,
    n_dirs: int = 72,
    defect_polys: Optional[np.ndarray] = None,
) -> Tuple[float, Optional[np.ndarray], Optional[np.ndarray], Optional[np.ndarray]]:
    """
    Đo bề rộng trace tại point_xy, bỏ qua vùng lỗi (defect_polys).
    """
    if mask01.ndim != 2:
        raise ValueError("mask01 phải là ảnh 2D")
    print('============================================================')
    print(f"mask01 shape: {mask01}")

    # 1) Vá mask để lấp vùng lỗi
    mask = heal_mask_with_defects(mask01, defect_polys)
    mask = (mask > 0).astype(np.uint8) * 255

    # 2) Làm mịn mask
    if smooth_window is not None and smooth_window >= 3:
        if smooth_window % 2 == 0:
            smooth_window += 1
        mask = cv2.GaussianBlur(mask, (smooth_window, smooth_window), 0)
        _, mask = cv2.threshold(mask, 127, 255, cv2.THRESH_BINARY)
    mask = (mask > 0).astype(np.uint8)

    H, W = mask.shape
    p0 = np.array(point_xy, dtype=np.float32)
    x0, y0 = int(round(p0[0])), int(round(p0[1]))
    if not (0 <= x0 < W and 0 <= y0 < H):
        return 0.0, None, None, None
    if mask[y0, x0] == 0:
        return 0.0, None, None, None

    def walk(direction: np.ndarray) -> np.ndarray:
        t = 0.0
        p = p0.copy()
        last_inside = p0.copy()
        while t < max_len:
            p = p0 + t * direction
            x, y = int(round(p[0])), int(round(p[1]))
            if x < 0 or x >= W or y < 0 or y >= H or mask[y, x] == 0:
                if t > 0:
                    p = p0 + max(0.0, t - step) * direction
                break
            last_inside = p.copy()
            t += step
        return last_inside

    best_width = 0.0
    best_left = None
    best_right = None

    angles = np.linspace(0.0, np.pi, num=n_dirs, endpoint=False).astype(np.float32)
    for theta in angles:
        d = np.array([np.cos(theta), np.sin(theta)], dtype=np.float32)
        p_plus = walk(+d)
        p_minus = walk(-d)
        if np.allclose(p_plus, p0) or np.allclose(p_minus, p0):
            continue
        width = float(np.linalg.norm(p_plus - p_minus))
        if best_width == 0.0 or width < best_width:
            best_width = width
            best_left = p_minus
            best_right = p_plus

    if best_left is None or best_right is None:
        return 0.0, None, None, None

    return best_width, best_left.astype(np.float32), best_right.astype(np.float32), p0.astype(np.float32)




# -------------------- Vẽ debug -------------------- #
def draw_poly_pts(
    img: np.ndarray,
    poly: np.ndarray,
    pos_pts: np.ndarray,
    mask01: Optional[np.ndarray] = None,
    color_mask: Tuple[int, int, int] = (180, 80, 200),
) -> np.ndarray:
    """Vẽ polygon, các điểm prompt và (tuỳ chọn) overlay mask."""
    vis = img.copy()

    # polygon gốc (cyan)
    cv2.polylines(vis, [poly.astype(np.int32)], True, (255, 255, 0), 2, cv2.LINE_AA)
    for p in poly:
        cv2.circle(vis, tuple(np.int32(p)), 3, (255, 255, 0), -1, cv2.LINE_AA)

    # điểm dương (xanh lá)
    for p in pos_pts:
        cv2.circle(vis, tuple(np.int32(p)), 6, (40, 220, 70), -1, cv2.LINE_AA)

    # overlay mask
    if mask01 is not None:
        col = np.zeros_like(vis)
        col[mask01 > 0] = color_mask
        vis = cv2.addWeighted(vis, 1.0, col, 0.45, 0)

    return vis


def draw_width_line(
    img: np.ndarray,
    p_left: Optional[np.ndarray],
    p_right: Optional[np.ndarray],
    color: Tuple[int, int, int] = (50, 230, 50),
    thickness: int = 2,
) -> np.ndarray:
    """Vẽ đoạn đo bề rộng trên ảnh."""
    vis = img.copy()
    if p_left is not None and p_right is not None:
        cv2.line(vis, tuple(np.int32(p_left)), tuple(np.int32(p_right)),
                 color, thickness, cv2.LINE_AA)
        cv2.circle(vis, tuple(np.int32(p_left)), 4, color, -1, cv2.LINE_AA)
        cv2.circle(vis, tuple(np.int32(p_right)), 4, color, -1, cv2.LINE_AA)
    return vis
