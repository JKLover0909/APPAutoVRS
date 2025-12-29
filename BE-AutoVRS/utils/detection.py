from dataclasses import dataclass, field
import numpy as np
from typing import List, Optional

@dataclass
class Detection:
    """Unified detection result for OBB/bbox detectors."""
    class_name: str
    cls_id: int
    conf: float
    poly: np.ndarray  # (4,2) or (N,2) float - polygon coordinates
    bbox: List[float] # [x1, y1, x2, y2] float - axis-aligned bounding box
    width: float      # OBB width (shorter side)
    length: float     # OBB length (longer side)

    def area(self) -> float:
        """Area of axis-aligned bbox."""
        x1, y1, x2, y2 = self.bbox
        return (x2 - x1) * (y2 - y1)

    def center(self) -> np.ndarray:
        """Center of bbox."""
        x1, y1, x2, y2 = self.bbox
        return np.array([(x1+x2)/2, (y1+y2)/2], dtype=np.float32)
    
    def to_dict(self) -> dict:
        """Convert to dictionary format with proper type conversion."""
        return {
            "class_name": self.class_name,
            "conf": float(self.conf),
            "bbox": [float(x) for x in self.bbox],
            "poly": self.poly.tolist() if isinstance(self.poly, np.ndarray) else self.poly,
            "width": float(self.width),
            "length": float(self.length)
        }


@dataclass
class SegmentationResult:
    """Unified segmentation result from SAM or other segmenters."""
    mask: np.ndarray              # (H,W) uint8 {0,1} - binary mask
    width_px: float               # Measured width in pixels
    width_um: Optional[float] = None   # Width in micrometers (if pixel_size known)
    width_mm: Optional[float] = None   # Width in millimeters
    pos_points: Optional[np.ndarray] = None  # Positive prompt points used
    best_pos_idx: Optional[int] = None       # Index of best positive point
    overlap: Optional[float] = None          # Overlap ratio with mask
    p_left: Optional[np.ndarray] = None      # Left endpoint of width measurement
    p_right: Optional[np.ndarray] = None     # Right endpoint of width measurement
    p_start: Optional[np.ndarray] = None     # Start point of measurement
    
    def to_dict(self) -> dict:
        """Convert to dictionary format with proper type conversion."""
        result = {
            "width_px": float(self.width_px),
            "width_um": float(self.width_um) if self.width_um is not None else None,
            "width_mm": float(self.width_mm) if self.width_mm is not None else None,
        }
        
        if self.overlap is not None:
            result["overlap"] = float(self.overlap)
        
        if self.mask is not None:
            result["mask_shape"] = list(self.mask.shape)
        
        if self.p_left is not None:
            result["p_left"] = [float(x) for x in self.p_left]
        
        if self.p_right is not None:
            result["p_right"] = [float(x) for x in self.p_right]
        
        if self.p_start is not None:
            result["p_start"] = [float(x) for x in self.p_start]
        
        if self.best_pos_idx is not None:
            result["best_pos_idx"] = int(self.best_pos_idx)
        
        if self.pos_points is not None:
            result["pos_points"] = [[float(x) for x in pt] for pt in self.pos_points]
        
        return result


@dataclass  
class InspectionResult:
    """Complete inspection result: detection + optional segmentation + verdict."""
    detection: Detection
    segmentation: Optional[SegmentationResult] = None
    verdict: str = "NG"  # "OK" or "NG"
    reason_code: str = ""  # Reason code for verdict
    reason_text: str = ""  # Human-readable reason
    measurements: dict = None  # Additional measurements
    requires_recheck: bool = False  # Needs manual re-check
    
    def __post_init__(self):
        if self.measurements is None:
            self.measurements = {}
    
    def to_dict(self) -> dict:
        """Convert to dictionary format with proper type conversion."""
        result = {
            "verdict": self.verdict,
            "reason_code": self.reason_code,
            "reason_text": self.reason_text,
            "requires_recheck": bool(self.requires_recheck),
            "detection": self.detection.to_dict(),
        }
        
        if self.segmentation:
            result["segmentation"] = self.segmentation.to_dict()
        
        if self.measurements:
            # Convert all numpy types in measurements
            result["measurements"] = {
                k: float(v) if hasattr(v, 'item') else (v.item() if hasattr(v, 'item') else v)
                for k, v in self.measurements.items()
            }
        
        return result
