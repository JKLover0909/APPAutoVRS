"""
Defect Detection Service for PCB defect detection using ONNX model
"""
import cv2
import numpy as np
import onnxruntime as ort
import os
import base64
from typing import List, Dict, Any, Tuple
from loguru import logger

class DefectDetectionService:
    """
    Service for detecting defects on PCB using YOLOv8 ONNX model
    """
    
    def __init__(self, model_path: str):
        """
        Initialize Defect Detection Service with YOLOv8 model path
        
        Args:
            model_path: Path to the ONNX model file
        """
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"❌ Model not found: {model_path}")
        
        self.model_path = model_path
        self.session = ort.InferenceSession(model_path)
        self.input_name = self.session.get_inputs()[0].name
        self.output_name = self.session.get_outputs()[0].name
        self.input_shape = self.session.get_inputs()[0].shape
        
        # PCB Defect class names (customize based on your model)
        self.defect_class_names = {
            0: 'short_circuit',      # Đoản mạch
            1: 'open_circuit',       # Hở mạch  
            2: 'missing_component',  # Thiếu linh kiện
            3: 'damaged_track',      # Đường dẫn bị hỏng
            4: 'wrong_component',    # Sai linh kiện
            5: 'solder_defect',      # Lỗi hàn
            6: 'crack',              # Vết nứt
            7: 'scratch',            # Vết xước
        }
        
        # Colors for different defect types
        self.defect_colors = {
            0: (0, 0, 255),     # Red - Đoản mạch
            1: (255, 0, 0),     # Blue - Hở mạch
            2: (0, 255, 255),   # Yellow - Thiếu linh kiện
            3: (255, 0, 255),   # Magenta - Đường dẫn bị hỏng
            4: (128, 0, 128),   # Purple - Sai linh kiện
            5: (0, 165, 255),   # Orange - Lỗi hàn
            6: (0, 255, 0),     # Green - Vết nứt
            7: (255, 255, 0),   # Cyan - Vết xước
        }
        
        logger.info(f"✅ DefectDetectionService initialized with model: {model_path}")
    
    def preprocess_image(self, image_path: str, input_size: Tuple[int, int] = (640, 640)) -> Tuple[np.ndarray, np.ndarray, Tuple[int, int]]:
        """
        Preprocess image for YOLOv8 inference
        
        Args:
            image_path: Path to input image
            input_size: Model input size (width, height)
            
        Returns:
            Tuple of (input_tensor, original_image_rgb, original_size)
        """
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Cannot read image: {image_path}")
        
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        original_height, original_width = image_rgb.shape[:2]
        
        # Resize to input size
        resized_image = cv2.resize(image_rgb, input_size)
        
        # Normalize to [0, 1]
        normalized = resized_image.astype(np.float32) / 255.0
        
        # Convert HWC to CHW
        transposed = np.transpose(normalized, (2, 0, 1))
        
        # Add batch dimension
        input_tensor = np.expand_dims(transposed, axis=0)
        
        return input_tensor, image_rgb, (original_width, original_height)
    
    def postprocess_detections(self, outputs: List[np.ndarray], original_size: Tuple[int, int], 
                             input_size: Tuple[int, int] = (640, 640), 
                             conf_threshold: float = 0.5) -> List[Dict[str, Any]]:
        """
        Process YOLOv8 outputs and extract defect detections
        
        Args:
            outputs: Model outputs
            original_size: Original image size (width, height)
            input_size: Model input size (width, height)
            conf_threshold: Confidence threshold for detections
            
        Returns:
            List of detection dictionaries
        """
        original_width, original_height = original_size
        input_width, input_height = input_size
        
        # YOLOv8 output shape: [1, 84, 8400] or similar
        predictions = outputs[0]
        
        # Transpose to [1, 8400, 84]
        predictions = np.transpose(predictions, (0, 2, 1))
        
        detections = []
        scale_x = original_width / input_width
        scale_y = original_height / input_height
        
        for detection in predictions[0]:
            # Get bbox coordinates (center_x, center_y, width, height)
            center_x, center_y, width, height = detection[:4]
            
            # Get class confidences
            class_scores = detection[4:]
            class_id = np.argmax(class_scores)
            confidence = class_scores[class_id]
            
            # Filter by confidence threshold
            if confidence >= conf_threshold and class_id < len(self.defect_class_names):
                # Convert to original scale
                x1 = int((center_x - width / 2) * scale_x)
                y1 = int((center_y - height / 2) * scale_y)
                x2 = int((center_x + width / 2) * scale_x)
                y2 = int((center_y + height / 2) * scale_y)
                
                # Ensure bbox is within image boundaries
                x1 = max(0, min(x1, original_width))
                y1 = max(0, min(y1, original_height))
                x2 = max(0, min(x2, original_width))
                y2 = max(0, min(y2, original_height))
                
                defect_name = self.defect_class_names.get(class_id, f'defect_{class_id}')
                
                detections.append({
                    'bbox': [x1, y1, x2, y2],
                    'confidence': float(confidence),
                    'class_id': int(class_id),
                    'class_name': defect_name,
                    'color': self.defect_colors.get(class_id, (255, 255, 255))
                })
        
        # Apply Non-Maximum Suppression
        if len(detections) > 0:
            boxes = np.array([det['bbox'] for det in detections])
            scores = np.array([det['confidence'] for det in detections])
            
            # OpenCV NMS
            indices = cv2.dnn.NMSBoxes(boxes.tolist(), scores.tolist(), conf_threshold, 0.4)
            
            if len(indices) > 0:
                if isinstance(indices, np.ndarray):
                    indices = indices.flatten()
                return [detections[i] for i in indices]
        
        return []
    
    def draw_defect_detections(self, image: np.ndarray, detections: List[Dict[str, Any]]) -> np.ndarray:
        """
        Draw bounding boxes for defect detections
        
        Args:
            image: Original image in RGB format
            detections: List of detection dictionaries
            
        Returns:
            Image with drawn bounding boxes
        """
        image_copy = image.copy()
        
        for i, detection in enumerate(detections):
            bbox = detection['bbox']
            confidence = detection['confidence']
            class_name = detection['class_name']
            color = detection['color']
            
            x1, y1, x2, y2 = bbox
            
            # Draw bounding box
            cv2.rectangle(image_copy, (x1, y1), (x2, y2), color, 2)
            
            # Prepare label
            label = f"{class_name}: {confidence:.2f}"
            
            # Draw label background
            label_size = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)[0]
            cv2.rectangle(image_copy, (x1, y1 - label_size[1] - 10), 
                         (x1 + label_size[0], y1), color, -1)
            
            # Draw label text
            cv2.putText(image_copy, label, (x1, y1 - 5), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
            
            # Add defect size info
            defect_width = x2 - x1
            defect_height = y2 - y1
            size_info = f"Size: {defect_width}x{defect_height}"
            cv2.putText(image_copy, size_info, (x1, y2 + 20), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.4, color, 1)
        
        return image_copy
    
    def detect_defects_from_file(self, image_path: str, conf_threshold: float = 0.5) -> Tuple[np.ndarray, List[Dict[str, Any]]]:
        """
        Detect defects in image file and draw bounding boxes
        
        Args:
            image_path: Path to input image
            conf_threshold: Confidence threshold for detections
            
        Returns:
            Tuple of (result_image, detections)
        """
        try:
            # Preprocess image
            input_tensor, original_image, original_size = self.preprocess_image(image_path)
            
            # Run inference
            outputs = self.session.run([self.output_name], {self.input_name: input_tensor})
            
            # Post-process detections
            detections = self.postprocess_detections(outputs, original_size, conf_threshold=conf_threshold)
            
            # Draw detections
            result_image = self.draw_defect_detections(original_image, detections)
            
            logger.info(f"🔍 Detected {len(detections)} defects in {image_path}")
            for detection in detections:
                logger.info(f"  🚨 {detection['class_name']}: {detection['confidence']:.3f}")
            
            return result_image, detections
            
        except Exception as e:
            logger.error(f"❌ Error in defect detection: {e}")
            raise
    
    def detect_defects_from_frame(self, frame: np.ndarray, conf_threshold: float = 0.5) -> Tuple[np.ndarray, List[Dict[str, Any]]]:
        """
        Detect defects in numpy frame and draw bounding boxes
        
        Args:
            frame: Input frame in BGR format
            conf_threshold: Confidence threshold for detections
            
        Returns:
            Tuple of (result_image, detections)
        """
        try:
            # Convert BGR to RGB
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            original_height, original_width = frame_rgb.shape[:2]
            
            # Resize to input size
            resized_image = cv2.resize(frame_rgb, (640, 640))
            
            # Normalize and prepare input tensor
            normalized = resized_image.astype(np.float32) / 255.0
            transposed = np.transpose(normalized, (2, 0, 1))
            input_tensor = np.expand_dims(transposed, axis=0)
            
            # Run inference
            outputs = self.session.run([self.output_name], {self.input_name: input_tensor})
            
            # Post-process detections
            detections = self.postprocess_detections(outputs, (original_width, original_height), conf_threshold=conf_threshold)
            
            # Draw detections
            result_image = self.draw_defect_detections(frame_rgb, detections)
            
            return result_image, detections
            
        except Exception as e:
            logger.error(f"❌ Error in frame defect detection: {e}")
            raise
    
    def frame_to_base64(self, frame: np.ndarray, quality: int = 80) -> str:
        """
        Convert frame to base64 string for WebSocket transmission
        
        Args:
            frame: Input frame in RGB format
            quality: JPEG quality (1-100)
            
        Returns:
            Base64 encoded string
        """
        try:
            # Convert RGB to BGR for OpenCV
            frame_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
            
            # Encode as JPEG
            encode_param = [cv2.IMWRITE_JPEG_QUALITY, quality]
            _, buffer = cv2.imencode('.jpg', frame_bgr, encode_param)
            
            # Convert to base64
            base64_string = base64.b64encode(buffer).decode('utf-8')
            return base64_string
            
        except Exception as e:
            logger.error(f"❌ Error converting frame to base64: {e}")
            raise
