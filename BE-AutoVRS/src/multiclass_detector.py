from ultralytics import YOLO
import numpy as np
from typing import List
from utils.detection import Detection
from utils.geometry import obb_xyxyxyxy_to_polygon, polygon_to_bbox, obb_size


class MultiClassOBBDetector:
    """Multi-class OBB detector using YOLO. Returns list of Detection objects."""
    
    def __init__(self, model_path: str, conf: float = 0.1, imgsz: int = 640, device: int = 0):
        self.model = YOLO(model_path)
        self.conf = conf
        self.imgsz = imgsz
        self.device = device
        self.names = dict(enumerate(self.model.names)) if not isinstance(self.model.names, dict) else self.model.names

    def predict(self, image_bgr: np.ndarray) -> List[Detection]:
        """Run inference and return list of Detection objects."""
        results = self.model.predict(
            source=image_bgr, 
            conf=self.conf, 
            imgsz=self.imgsz,
            device=self.device, 
            verbose=False
        )
        
        if not results:
            return []

        return self._parse_results(results[0])

    def _parse_results(self, result) -> List[Detection]:
        """Parse YOLO result into Detection objects."""
        detections = []
        
        # Try OBB first
        obb = getattr(result, "obb", None)
        if obb and getattr(obb, "xyxyxyxy", None) is not None and len(obb.xyxyxyxy) > 0:
            detections = self._parse_obb(obb)
        # Fallback to axis-aligned boxes
        elif hasattr(result, "boxes") and result.boxes is not None and len(result.boxes) > 0:
            detections = self._parse_boxes(result.boxes)
            
        return detections

    def _parse_obb(self, obb) -> List[Detection]:
        """Parse OBB detections."""
        detections = []
        polys = obb.xyxyxyxy.detach().cpu().numpy() if hasattr(obb.xyxyxyxy, "detach") else obb.xyxyxyxy
        cls_ids = obb.cls.detach().cpu().numpy() if hasattr(obb.cls, "detach") else obb.cls
        confs = obb.conf.detach().cpu().numpy() if hasattr(obb.conf, "detach") else obb.conf

        for poly8, cid, cf in zip(polys, cls_ids, confs):
            poly = obb_xyxyxyxy_to_polygon(poly8)
            bbox = polygon_to_bbox(poly)
            width, length = obb_size(poly)
            
            detections.append(Detection(
                class_name=self.names.get(int(cid), str(int(cid))),
                cls_id=int(cid),
                conf=float(cf),
                poly=poly,
                bbox=bbox,
                width=width,
                length=length
            ))
        
        return detections

    def _parse_boxes(self, boxes) -> List[Detection]:
        """Parse axis-aligned bounding boxes as fallback."""
        detections = []
        xyxy = boxes.xyxy.detach().cpu().numpy() if hasattr(boxes.xyxy, "detach") else boxes.xyxy
        cls_ids = boxes.cls.detach().cpu().numpy() if hasattr(boxes.cls, "detach") else boxes.cls
        confs = boxes.conf.detach().cpu().numpy() if hasattr(boxes.conf, "detach") else boxes.conf

        for (x1, y1, x2, y2), cid, cf in zip(xyxy, cls_ids, confs):
            poly = np.array([[x1, y1], [x2, y1], [x2, y2], [x1, y2]], dtype=np.float32)
            width, length = obb_size(poly)
            
            detections.append(Detection(
                class_name=self.names.get(int(cid), str(int(cid))),
                cls_id=int(cid),
                conf=float(cf),
                poly=poly,
                bbox=[float(x1), float(y1), float(x2), float(y2)],
                width=width,
                length=length
            ))
        
        return detections
