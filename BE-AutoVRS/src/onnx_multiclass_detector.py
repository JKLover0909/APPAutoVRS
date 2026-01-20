# src/onnx_multiclass_detector.py
"""
ONNX-based MultiClass OBB Detector (replaces Ultralytics YOLO)
Performs inference using ONNX Runtime for better CPU performance.
"""

import cv2
import numpy as np
import onnxruntime as ort
from typing import List, Optional, Dict

from utils.detection import Detection


class ONNXMultiClassDetector:
    """
    Multi-class OBB detector using ONNX Runtime.
    Replaces Ultralytics YOLO with pure ONNX inference.
    """
    
    def __init__(
        self, 
        model_path: str,
        conf_threshold: float = 0.25,
        providers: Optional[List[str]] = None,
        imgsz: int = 640,
        class_names: Optional[List[str]] = None,
        class_id_map: Optional[Dict[int, str]] = None
    ):
        """
        Initialize ONNX detector.
        
        Args:
            model_path: Path to ONNX model file (.onnx)
            conf_threshold: Confidence threshold for detections
            providers: ONNX Runtime providers (e.g., ['CUDAExecutionProvider', 'CPUExecutionProvider'])
            imgsz: Input image size (default 640 for YOLO models)
            class_names: List of class names (for sequential 0-N class IDs)
            class_id_map: Dictionary mapping class_id to class_name (for non-sequential IDs)
        """
        self.model_path = model_path
        self.conf_threshold = conf_threshold
        self.imgsz = imgsz
        self.class_names = class_names or []
        self.class_id_map = class_id_map or {}
        
        # Default to CPU if no providers specified
        if providers is None:
            providers = ['CPUExecutionProvider']
        
        print(f"🔄 Loading ONNX MultiClass model: {model_path}")
        print(f"   Providers: {providers}")
        print(f"   Class names provided: {len(self.class_names)} classes")
        if self.class_names:
            print(f"   Classes: {self.class_names}")
        
        # Create ONNX Runtime session
        self.session = ort.InferenceSession(model_path, providers=providers)
        
        # Get model input/output info
        self.input_name = self.session.get_inputs()[0].name
        self.output_names = [output.name for output in self.session.get_outputs()]
        
        print(f"✅ ONNX MultiClass model loaded")
        print(f"   Input: {self.input_name}")
        print(f"   Outputs: {self.output_names}")
    
    def preprocess(self, image_bgr: np.ndarray) -> np.ndarray:
        """
        Preprocess image for ONNX model inference.
        
        Args:
            image_bgr: Input image in BGR format (H, W, 3)
        
        Returns:
            Preprocessed tensor (1, 3, imgsz, imgsz) in RGB format
        """
        # Store original shape for later use
        self.orig_h, self.orig_w = image_bgr.shape[:2]
        
        # Convert BGR to RGB
        image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
        
        # Resize with letterbox (maintain aspect ratio)
        image_resized = self._letterbox(image_rgb, (self.imgsz, self.imgsz))
        
        # Normalize to [0, 1] and transpose to CHW format
        image_normalized = image_resized.astype(np.float32) / 255.0
        image_chw = np.transpose(image_normalized, (2, 0, 1))  # HWC -> CHW
        
        # Add batch dimension
        image_batch = np.expand_dims(image_chw, axis=0)  # (1, 3, H, W)
        
        return image_batch
    
    def _letterbox(
        self, 
        image: np.ndarray, 
        new_shape: tuple = (640, 640), 
        color: tuple = (114, 114, 114)
    ) -> np.ndarray:
        """
        Resize image with letterbox (maintain aspect ratio, pad with gray).
        
        Args:
            image: Input image (H, W, 3)
            new_shape: Target size (height, width)
            color: Padding color (RGB)
        
        Returns:
            Resized and padded image
        """
        shape = image.shape[:2]  # current shape [height, width]
        
        # Scale ratio (new / old)
        r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])
        
        # Compute padding
        new_unpad = int(round(shape[1] * r)), int(round(shape[0] * r))
        dw, dh = new_shape[1] - new_unpad[0], new_shape[0] - new_unpad[1]  # wh padding
        dw /= 2  # divide padding into 2 sides
        dh /= 2
        
        if shape[::-1] != new_unpad:  # resize
            image = cv2.resize(image, new_unpad, interpolation=cv2.INTER_LINEAR)
        
        top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
        left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
        image = cv2.copyMakeBorder(image, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color)
        
        # Store padding info for later coordinate conversion
        self.pad_w = left
        self.pad_h = top
        self.scale = r
        
        return image
    
    def postprocess(self, outputs: List[np.ndarray]) -> List[Detection]:
        """
        Convert ONNX model outputs to Detection objects.
        
        Args:
            outputs: List of ONNX output tensors
        
        Returns:
            List of Detection objects with OBB polygons
        """
        detections = []
        
        # YOLOv11 OBB output format: (1, 16, 8400) for multiclass
        # 16 features:
        #   [0-3]: center bbox (cx, cy, w, h)
        #   [4-11]: OBB 8 coords (x1,y1,x2,y2,x3,y3,x4,y4)
        #   [12]: objectness/confidence
        #   [13]: class_id (direct integer, not probabilities!)
        #   [14-15]: angle or reserved
        
        # Get first output
        if len(outputs) == 0:
            return detections
        
        output = outputs[0]  # Shape: (1, 16, 8400)
        
        # CRITICAL: Transpose from (1, features, 8400) to (8400, features)
        if len(output.shape) == 3:
            output = output[0].T  # (16, 8400) -> (8400, 16)
        elif len(output.shape) == 2:
            output = output.T  # (16, 8400) -> (8400, 16)
        
        num_detections, num_features = output.shape
        print(f"✅ Multiclass output shape after transpose: ({num_detections}, {num_features})")
        
        # Parse each detection
        for idx, det in enumerate(output):
            # DEBUG: Print first detection to verify format
            if idx == 0:
                print(f"🔍 First detection features ({num_features}):")
                print(f"   [0-3] Center bbox: {det[0:4]}")
                print(f"   [4-11] OBB coords: {det[4:12]}")
                print(f"   [12] Confidence: {det[12]}")
                print(f"   [13] Class ID: {det[13]}")
                if num_features > 14:
                    print(f"   [14-15] Extra: {det[14:16]}")
            
            # Extract confidence (index 12)
            confidence = float(det[12])
            
            # Filter by confidence threshold
            if confidence < self.conf_threshold:
                continue
            
            # Extract OBB corner points (indices 4-11)
            points_flat = det[4:12]
            
            # Extract class_id (index 13) - it's a direct integer, not probabilities!
            class_id = int(det[13])
            
            # Convert coordinates back to original image space
            points = self._scale_coords(points_flat)
            
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
            
            # Calculate OBB width/length (simple approximation)
            width = float(np.linalg.norm(poly_np[1] - poly_np[0]))
            length = float(np.linalg.norm(poly_np[2] - poly_np[1]))
            if width > length:
                width, length = length, width  # width is shorter side
            
            # Map class_id to class_name
            # Priority: 1) explicit class_id_map, 2) sequential class_names array, 3) fallback
            if class_id in self.class_id_map:
                class_name = self.class_id_map[class_id]
            elif self.class_names and 0 <= class_id < len(self.class_names):
                class_name = self.class_names[class_id]
            else:
                # Log unknown class_id for debugging
                print(f"⚠️  Unknown class_id: {class_id}")
                print(f"   class_id_map: {self.class_id_map}")
                print(f"   class_names: {self.class_names}")
                class_name = f"class_{class_id}"  # Fallback
            
            # Create Detection object
            detection = Detection(
                class_name=class_name,
                cls_id=class_id,
                conf=confidence,
                poly=poly_np,
                bbox=bbox_list,
                width=width,
                length=length
            )
            
            detections.append(detection)
        
        return detections
    
    def _scale_coords(self, points_flat: np.ndarray) -> List[List[float]]:
        """
        Scale coordinates from model space back to original image space.
        
        Args:
            points_flat: Flat array of 8 values [x1,y1,x2,y2,x3,y3,x4,y4]
        
        Returns:
            List of 4 points [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
        """
        points = []
        for i in range(0, 8, 2):
            x = points_flat[i]
            y = points_flat[i + 1]
            
            # Remove padding
            x = (x - self.pad_w) / self.scale
            y = (y - self.pad_h) / self.scale
            
            # Clip to original image bounds
            x = np.clip(x, 0, self.orig_w)
            y = np.clip(y, 0, self.orig_h)
            
            points.append([float(x), float(y)])
        
        return points
    
    def predict(self, image_bgr: np.ndarray) -> List[Detection]:
        """
        Run inference on image and return detections.
        
        Args:
            image_bgr: Input image in BGR format (OpenCV format)
        
        Returns:
            List of Detection objects
        """
        # Preprocess image
        input_tensor = self.preprocess(image_bgr)
        
        # Run inference
        outputs = self.session.run(self.output_names, {self.input_name: input_tensor})
        
        # Postprocess outputs
        detections = self.postprocess(outputs)
        
        return detections
    
    def __repr__(self):
        return f"ONNXMultiClassDetector(model={self.model_path}, conf={self.conf_threshold})"
