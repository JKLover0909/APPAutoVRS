"""
Visualization utilities for AOI inspection results.
"""

import cv2
import numpy as np
from typing import List
from utils.detection import Detection, InspectionResult


def draw_detections(
    image_bgr: np.ndarray,
    detections: List[Detection],
    show_label: bool = True,
    color: tuple = (0, 0, 255),
    text_scale: float = 0.7,
    text_thick: int = 2,
    poly_thick: int = 2,
    alpha_bg: float = 0.6,
    offset: int = 8
) -> np.ndarray:
    """
    Draw detection polygons and labels on image.
    
    Args:
        image_bgr: Input image
        detections: List of Detection objects
        show_label: Whether to show class labels
        color: BGR color for drawing
        text_scale: Text size
        text_thick: Text thickness
        poly_thick: Polygon line thickness
        alpha_bg: Background alpha for labels
        offset: Offset for label positioning
        
    Returns:
        Annotated image
    """
    img = image_bgr.copy()
    h, w = img.shape[:2]

    for det in detections:
        poly = np.asarray(det.poly, dtype=int).reshape(-1, 2)

        # Draw polygon
        cv2.polylines(img, [poly.reshape(-1, 1, 2)], True, color, poly_thick, lineType=cv2.LINE_AA)

        if not show_label:
            continue

        # Prepare label text
        label = f'{det.class_name} {float(det.conf):.2f}'
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, text_scale, text_thick)

        # Find anchor point (highest vertex)
        anchor = poly[np.argmin(poly[:, 1])]
        ax, ay = int(anchor[0]), int(anchor[1])

        # Position label above anchor (or below if out of bounds)
        x1 = ax
        y1 = ay - th - 10 - offset
        x2 = x1 + tw + 8
        y2 = y1 + th + 6

        # Handle boundary cases
        if y1 < 0:
            y1 = ay + offset
            y2 = y1 + th + 6
        if x2 > w:
            x1 = max(0, w - (tw + 8))
            x2 = x1 + tw + 8
        if x1 < 0:
            x1 = 0
            x2 = tw + 8

        # Draw semi-transparent background
        roi = img[max(0, y1):min(h, y2), max(0, x1):min(w, x2)]
        if roi.size > 0:
            overlay = roi.copy()
            cv2.rectangle(overlay, (0, 0), (overlay.shape[1] - 1, overlay.shape[0] - 1), color, -1)
            cv2.addWeighted(overlay, alpha_bg, roi, 1 - alpha_bg, 0, dst=roi)

        # Draw text
        tx = x1 + 4
        ty = y2 - 4
        cv2.putText(img, label, (tx, ty), cv2.FONT_HERSHEY_SIMPLEX, 
                   text_scale, (255, 255, 255), text_thick, cv2.LINE_AA)

        # Draw leader line from label to anchor
        cx = np.clip(ax, x1, x2)
        if ay <= y1:
            p_label = (int(np.clip(ax, x1 + 3, x2 - 3)), y2)
        elif ay >= y2:
            p_label = (int(np.clip(ax, x1 + 3, x2 - 3)), y1)
        else:
            p_label = (x1 if ax < x1 else x2, int(np.clip(ay, y1 + 3, y2 - 3)))

        cv2.line(img, p_label, (ax, ay), color, 2, lineType=cv2.LINE_AA)

    return img


def overlay_sam_masks(
    image_rgb: np.ndarray,
    results: List[InspectionResult],
    alpha: float = 0.65,
    edge_thick: int = 3,
    class_colors: dict = None
) -> np.ndarray:
    """
    Overlay SAM segmentation masks on image.
    
    Args:
        image_rgb: Input image in RGB format
        results: List of InspectionResult objects with segmentation
        alpha: Transparency of mask overlay
        edge_thick: Thickness of mask contour
        class_colors: Dict mapping class names to BGR colors
        
    Returns:
        Image with overlaid masks
    """
    if class_colors is None:
        class_colors = {
            "ChamKim": (0, 255, 255),
            "DiVat": (255, 0, 180),
            "KhuyetMach": (255, 140, 0),
            "ThieuDong": (0, 255, 0),
            "ThuaDong": (0, 180, 255),
            "Xuoc": (255, 0, 0),
        }
    
    default_color = (255, 0, 180)
    edge_color_out = (255, 255, 255)
    edge_color_in = (0, 0, 0)
    
    img = image_rgb.copy()
    
    for result in results:
        if result.segmentation is None or result.segmentation.mask is None:
            continue
            
        mask = result.segmentation.mask
        mask_bin = (mask > 0).astype(np.uint8)
        
        # Get color for this class
        color = class_colors.get(result.detection.class_name, default_color)
        
        # Create colored overlay
        color_layer = np.zeros_like(img, dtype=np.uint8)
        color_layer[:] = color
        mask3 = np.repeat(mask_bin[..., None], 3, axis=2)
        
        # Blend with original
        img = (img * (1 - alpha * mask3) + color_layer * (alpha * mask3)).astype(np.uint8)
        
        # Draw contours
        cnt_mask = (mask_bin * 255).astype(np.uint8)
        contours, _ = cv2.findContours(cnt_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            cv2.drawContours(img, contours, -1, edge_color_out, edge_thick + 2, lineType=cv2.LINE_AA)
            cv2.drawContours(img, contours, -1, edge_color_in, edge_thick, lineType=cv2.LINE_AA)
    
    return img
