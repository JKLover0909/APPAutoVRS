import numpy as np

def obb_xyxyxyxy_to_polygon(xyxyxyxy_row, dtype=np.float32):
    """
    Chuyển OBB 8 điểm sang polygon (4,2) float.
    """
    return np.asarray(xyxyxyxy_row, dtype=dtype).reshape(-1, 2)

def polygon_to_bbox(points, dtype=np.float32):
    """
    Tính bounding box axis-aligned từ polygon.
    """
    pts = np.asarray(points, dtype=dtype)
    xs, ys = pts[:, 0], pts[:, 1]
    return [xs.min(), ys.min(), xs.max(), ys.max()]

def obb_size(poly):
    """
    Tính kích thước OBB: chiều rộng và chiều dài dựa trên polygon 4 điểm.
    width = cạnh nhỏ hơn, length = cạnh lớn hơn
    """
    poly = np.asarray(poly, dtype=np.float32)
    d0 = np.linalg.norm(poly[0] - poly[1])
    d1 = np.linalg.norm(poly[1] - poly[2])
    length = max(d0, d1)
    width  = min(d0, d1)
    return width, length
