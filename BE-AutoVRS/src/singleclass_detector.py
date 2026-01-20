import os
from concurrent.futures import ThreadPoolExecutor, as_completed
import numpy as np
import torch
import torchvision
from typing import List, Tuple
from ultralytics import YOLO
from utils.detection import Detection
from utils.geometry import obb_xyxyxyxy_to_polygon, polygon_to_bbox, obb_size


class SingleClassEnsemble:
    """
    Ensemble of single-class OBB detectors.
    Runs multiple models in parallel and applies NMS on results.
    Returns list of Detection objects.
    """

    def __init__(
        self, 
        engine_paths: List[str], 
        engine_names: List[str], 
        conf: float = 0.1, 
        imgsz: int = 640,
        device: int = 0, 
        iou_nms: float = 0.4,  # Changed default from 0.8 to 0.4 (more reasonable)
        num_threads: int = 4
    ):
        assert len(engine_paths) == len(engine_names), "engine_paths and engine_names must have same length"
        
        self.conf = conf
        self.imgsz = imgsz
        self.device = device
        self.iou_nms = iou_nms
        self.num_threads = max(1, num_threads)
        
        # Load models
        self.models = self._load_models(engine_paths, engine_names)

    def _load_models(self, paths: List[str], names: List[str]) -> List[Tuple[str, YOLO]]:
        """Load all valid models."""
        models = []
        for path, name in zip(paths, names):
            if not os.path.exists(path):
                print(f"⚠️ Model not found: {name} at {path}")
                continue
            try:
                models.append((name, YOLO(path)))
            except Exception as e:
                print(f"⚠️ Failed to load {name}: {e}")
                continue
        
        print(f"✓ Loaded {len(models)}/{len(paths)} single-class models")
        return models

    def predict(self, image_bgr: np.ndarray) -> List[Detection]:
        """Run ensemble inference with NMS."""
        if not self.models:
            return []

        # Parallel inference
        all_detections = []
        with ThreadPoolExecutor(max_workers=self.num_threads) as executor:
            futures = [executor.submit(self._infer_one_model, m, image_bgr) for m in self.models]
            for future in as_completed(futures):
                all_detections.extend(future.result() or [])

        if not all_detections:
            return []

        # Apply NMS
        return self._apply_nms(all_detections)

    def _infer_one_model(self, model_tuple: Tuple[str, YOLO], image_bgr: np.ndarray) -> List[Detection]:
        """Run inference on single model."""
        class_name, model = model_tuple
        
        results = model.predict(
            source=image_bgr, 
            conf=self.conf, 
            imgsz=self.imgsz,
            device=self.device, 
            verbose=False
        )
        
        if not results:
            return []

        return self._parse_result(results[0], class_name)

    def _parse_result(self, result, class_name: str) -> List[Detection]:
        """Parse single model result into Detection objects."""
        detections = []

        # Try OBB first
        obb = getattr(result, "obb", None)
        if obb and getattr(obb, "xyxyxyxy", None) is not None and len(obb.xyxyxyxy) > 0:
            polys = obb.xyxyxyxy.detach().cpu().numpy() if hasattr(obb.xyxyxyxy, "detach") else obb.xyxyxyxy
            confs = obb.conf.detach().cpu().numpy() if hasattr(obb.conf, "detach") else obb.conf
            
            for poly8, cf in zip(polys, confs):
                poly = obb_xyxyxyxy_to_polygon(poly8)
                bbox = polygon_to_bbox(poly)
                width, length = obb_size(poly)
                
                detections.append(Detection(
                    class_name=class_name,
                    cls_id=0,
                    conf=float(cf),
                    poly=poly,
                    bbox=bbox,
                    width=width,
                    length=length
                ))
            return detections

        # Fallback to axis-aligned boxes
        boxes = getattr(result, "boxes", None)
        if boxes and getattr(boxes, "xyxy", None) is not None and len(boxes.xyxy) > 0:
            xyxy = boxes.xyxy.detach().cpu().numpy() if hasattr(boxes.xyxy, "detach") else boxes.xyxy
            confs = boxes.conf.detach().cpu().numpy() if hasattr(boxes.conf, "detach") else boxes.conf
            
            for (x1, y1, x2, y2), cf in zip(xyxy, confs):
                poly = np.array([[x1, y1], [x2, y1], [x2, y2], [x1, y2]], dtype=np.float32)
                width, length = obb_size(poly)
                
                detections.append(Detection(
                    class_name=class_name,
                    cls_id=0,
                    conf=float(cf),
                    poly=poly,
                    bbox=[float(x1), float(y1), float(x2), float(y2)],
                    width=width,
                    length=length
                ))
        
        return detections

    def _apply_nms(self, detections: List[Detection]) -> List[Detection]:
        """Apply Non-Maximum Suppression on detections."""
        if not detections:
            return []
        
        try:
            boxes_tensor = torch.tensor([d.bbox for d in detections], dtype=torch.float32)
            confs_tensor = torch.tensor([d.conf for d in detections], dtype=torch.float32)
            keep_indices = torchvision.ops.nms(boxes_tensor, confs_tensor, self.iou_nms).tolist()
            return [detections[i] for i in keep_indices]
        except Exception as e:
            print(f"⚠️ NMS failed: {e}, returning all detections")
            return detections
