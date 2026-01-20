# src/onnx_singleclass_detector.py
"""
ONNX-based SingleClass Ensemble OBB Detector (replaces Ultralytics YOLO)
Runs multiple single-class ONNX models in parallel and merges results with NMS.
"""

import cv2
import numpy as np
import onnxruntime as ort
from typing import List, Optional, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed

from utils.detection import Detection


class ONNXSingleClassEnsemble:
    """
    Ensemble of single-class OBB detectors using ONNX Runtime.
    Runs all models in parallel and applies NMS to merge results.
    """
    
    def __init__(
        self,
        model_paths: List[str],
        class_names: List[str],
        conf_threshold: float = 0.25,
        iou_threshold: float = 0.4,
        providers: Optional[List[str]] = None,
        num_threads: int = 4,
        imgsz: int = 640
    ):
        """
        Initialize ensemble of ONNX single-class detectors.
        
        Args:
            model_paths: List of paths to ONNX model files
            class_names: List of class names corresponding to each model
            conf_threshold: Confidence threshold for detections
            iou_threshold: IOU threshold for NMS
            providers: ONNX Runtime providers
            num_threads: Number of parallel threads for inference
            imgsz: Input image size
        """
        assert len(model_paths) == len(class_names), \
            f"Number of models ({len(model_paths)}) must match number of class names ({len(class_names)})"
        
        self.model_paths = model_paths
        self.class_names = class_names
        self.conf_threshold = conf_threshold
        self.iou_threshold = iou_threshold
        self.num_threads = num_threads
        self.imgsz = imgsz
        
        if providers is None:
            providers = ['CPUExecutionProvider']
        self.providers = providers
        
        print(f"🔄 Loading {len(model_paths)} ONNX SingleClass models...")
        print(f"   Providers: {providers}")
        print(f"   Parallel threads: {num_threads}")
        
        # Load all ONNX sessions
        self.sessions = []
        for i, (path, name) in enumerate(zip(model_paths, class_names)):
            session = ort.InferenceSession(path, providers=providers)
            self.sessions.append((name, session))
            print(f"   [{i+1}/{len(model_paths)}] Loaded: {name}")
        
        print(f"✅ All {len(self.sessions)} ONNX SingleClass models loaded")
    
    def preprocess(self, image_bgr: np.ndarray) -> Tuple[np.ndarray, dict]:
        """
        Preprocess image for ONNX inference.
        
        Args:
            image_bgr: Input image in BGR format
        
        Returns:
            Tuple of (preprocessed tensor, metadata dict)
        """
        orig_h, orig_w = image_bgr.shape[:2]
        
        # Convert BGR to RGB
        image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
        
        # Resize with letterbox
        image_resized, pad_info = self._letterbox(image_rgb, (self.imgsz, self.imgsz))
        
        # Normalize and transpose
        image_normalized = image_resized.astype(np.float32) / 255.0
        image_chw = np.transpose(image_normalized, (2, 0, 1))
        image_batch = np.expand_dims(image_chw, axis=0)
        
        # Store metadata for coordinate conversion
        metadata = {
            'orig_h': orig_h,
            'orig_w': orig_w,
            'pad_w': pad_info['pad_w'],
            'pad_h': pad_info['pad_h'],
            'scale': pad_info['scale']
        }
        
        return image_batch, metadata
    
    def _letterbox(
        self,
        image: np.ndarray,
        new_shape: tuple = (640, 640),
        color: tuple = (114, 114, 114)
    ) -> Tuple[np.ndarray, dict]:
        """
        Resize image with letterbox padding.
        
        Returns:
            Tuple of (padded image, padding info dict)
        """
        shape = image.shape[:2]
        r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])
        
        new_unpad = int(round(shape[1] * r)), int(round(shape[0] * r))
        dw, dh = new_shape[1] - new_unpad[0], new_shape[0] - new_unpad[1]
        dw /= 2
        dh /= 2
        
        if shape[::-1] != new_unpad:
            image = cv2.resize(image, new_unpad, interpolation=cv2.INTER_LINEAR)
        
        top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
        left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
        image = cv2.copyMakeBorder(image, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color)
        
        pad_info = {'pad_w': left, 'pad_h': top, 'scale': r}
        return image, pad_info
    
    def _run_single_model(
        self,
        class_name: str,
        session: ort.InferenceSession,
        input_tensor: np.ndarray,
        metadata: dict
    ) -> List[Detection]:
        """
        Run inference on a single ONNX model.
        
        Args:
            class_name: Name of the class this model detects
            session: ONNX Runtime session
            input_tensor: Preprocessed input tensor
            metadata: Metadata for coordinate conversion
        
        Returns:
            List of Detection objects
        """
        detections = []
        
        try:
            # Get input/output names
            input_name = session.get_inputs()[0].name
            output_names = [output.name for output in session.get_outputs()]
            
            # Run inference
            outputs = session.run(output_names, {input_name: input_tensor})
            
            # Parse outputs - YOLOv11 OBB Singleclass format: (1, 6, 8400)
            # 6 features: [cx, cy, w, h, conf, class_prob]
            # Note: Simplified format without explicit OBB coords
            if len(outputs) > 0:
                output = outputs[0]  # Shape: (1, 6, 8400)
                
                # CRITICAL: Transpose from (1, features, 8400) to (8400, features)
                if len(output.shape) == 3:
                    output = output[0].T  # (6, 8400) -> (8400, 6)
                elif len(output.shape) == 2:
                    output = output.T
                
                for det in output:
                    if len(det) >= 5:
                        # Format: [cx, cy, w, h, conf, ...]
                        cx, cy, w, h = det[0:4]
                        confidence = float(det[4])
                        
                        if confidence < self.conf_threshold:
                            continue
                        
                        # Convert center bbox to corner points (OBB approximation)
                        x1, y1 = cx - w/2, cy - h/2
                        x2, y2 = cx + w/2, cy - h/2
                        x3, y3 = cx + w/2, cy + h/2
                        x4, y4 = cx - w/2, cy + h/2
                        points_flat = np.array([x1, y1, x2, y2, x3, y3, x4, y4])
                        
                        # Scale coordinates back to original image
                        points = self._scale_coords(points_flat, metadata)
                        
                        # Convert polygon to numpy array
                        poly_np = np.array(points, dtype=np.float32)
                        
                        # Calculate axis-aligned bounding box
                        x_coords = poly_np[:, 0]
                        y_coords = poly_np[:, 1]
                        bbox_list = [
                            float(x_coords.min()),
                            float(y_coords.min()),
                            float(x_coords.max()),
                            float(y_coords.max())
                        ]
                        
                        # Calculate OBB width/length
                        width = float(np.linalg.norm(poly_np[1] - poly_np[0]))
                        length = float(np.linalg.norm(poly_np[2] - poly_np[1]))
                        if width > length:
                            width, length = length, width
                        
                        detection = Detection(
                            class_name=class_name,
                            cls_id=0,  # Single-class model
                            conf=confidence,
                            poly=poly_np,
                            bbox=bbox_list,
                            width=width,
                            length=length
                        )
                        detections.append(detection)
        
        except Exception as e:
            print(f"⚠️  Error running model {class_name}: {e}")
        
        return detections
    
    def _scale_coords(self, points_flat: np.ndarray, metadata: dict) -> List[List[float]]:
        """
        Scale coordinates from model space to original image space.
        """
        points = []
        for i in range(0, 8, 2):
            x = points_flat[i]
            y = points_flat[i + 1]
            
            x = (x - metadata['pad_w']) / metadata['scale']
            y = (y - metadata['pad_h']) / metadata['scale']
            
            x = np.clip(x, 0, metadata['orig_w'])
            y = np.clip(y, 0, metadata['orig_h'])
            
            points.append([float(x), float(y)])
        
        return points
    
    def _apply_nms(self, all_detections: List[Detection]) -> List[Detection]:
        """
        Apply Non-Maximum Suppression to remove overlapping detections.
        
        Args:
            all_detections: List of all detections from all models
        
        Returns:
            Filtered list of detections after NMS
        """
        if len(all_detections) == 0:
            return []
        
        # Convert OBB polygons to bounding boxes for NMS
        boxes = []
        confidences = []
        indices_map = []
        
        for idx, det in enumerate(all_detections):
            # Convert polygon to axis-aligned bounding box
            points = np.array(det.poly)  # Use poly attribute
            x_coords = points[:, 0]
            y_coords = points[:, 1]
            
            x_min, x_max = x_coords.min(), x_coords.max()
            y_min, y_max = y_coords.min(), y_coords.max()
            
            boxes.append([x_min, y_min, x_max, y_max])
            confidences.append(det.conf)  # Use conf attribute
            indices_map.append(idx)
        
        boxes = np.array(boxes, dtype=np.float32)
        confidences = np.array(confidences, dtype=np.float32)
        
        # Apply OpenCV NMS
        keep_indices = cv2.dnn.NMSBoxes(
            bboxes=boxes.tolist(),
            scores=confidences.tolist(),
            score_threshold=self.conf_threshold,
            nms_threshold=self.iou_threshold
        )
        
        # Extract kept detections
        kept_detections = []
        if len(keep_indices) > 0:
            if isinstance(keep_indices, tuple):
                keep_indices = keep_indices[0]
            
            for idx in keep_indices.flatten():
                original_idx = indices_map[idx]
                kept_detections.append(all_detections[original_idx])
        
        return kept_detections
    
    def predict(self, image_bgr: np.ndarray) -> List[Detection]:
        """
        Run inference on all models in parallel and merge results.
        
        Args:
            image_bgr: Input image in BGR format
        
        Returns:
            List of Detection objects after NMS
        """
        # Preprocess once (shared by all models)
        input_tensor, metadata = self.preprocess(image_bgr)
        
        # Run all models in parallel
        all_detections = []
        
        with ThreadPoolExecutor(max_workers=self.num_threads) as executor:
            futures = []
            for class_name, session in self.sessions:
                future = executor.submit(
                    self._run_single_model,
                    class_name,
                    session,
                    input_tensor,
                    metadata
                )
                futures.append(future)
            
            # Collect results
            for future in as_completed(futures):
                detections = future.result()
                all_detections.extend(detections)
        
        # Apply NMS to remove overlapping detections
        final_detections = self._apply_nms(all_detections)
        
        return final_detections
    
    def __repr__(self):
        return f"ONNXSingleClassEnsemble(models={len(self.sessions)}, conf={self.conf_threshold}, iou={self.iou_threshold})"
