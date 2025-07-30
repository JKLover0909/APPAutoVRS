"""
Camera Service for AutoVRS
Handles camera operations, image capture, and streaming
"""

import cv2
import numpy as np
import asyncio
import base64
import json
import time
import os
from typing import Optional, Tuple, Dict, Any, List
from threading import Thread, Lock
from loguru import logger
from config.settings import settings
from services.defect_detection_service import DefectDetectionService


class CameraService:
    """Service for managing camera operations"""
    
    def __init__(self):
        self.camera = None
        self.is_running = False
        self.current_frame = None
        self.frame_lock = Lock()
        self.capture_thread = None
        self.frame_count = 0
        self.last_capture_time = 0
        
        # Initialize defect detection service
        try:
            # Use the available model path
            model_path = "src/models/yolov8n.onnx"
            logger.info(f"Checking for model at: {model_path}")
            logger.info(f"File exists: {os.path.exists(model_path)}")
            
            if os.path.exists(model_path):
                self.defect_detector = DefectDetectionService(model_path)
                logger.info(f"✅ Defect detection initialized with model: {model_path}")
            else:
                logger.warning(f"❌ Defect detection model not found at {model_path}")
                self.defect_detector = None
        except Exception as e:
            logger.error(f"❌ Failed to initialize defect detector: {e}")
            self.defect_detector = None
            
        self.detection_enabled = True  # Flag to enable/disable detection
        logger.info(f"Detection enabled: {self.detection_enabled}, Detector available: {self.defect_detector is not None}")
        
    async def initialize(self) -> bool:
        """Initialize camera"""
        try:
            self.camera = cv2.VideoCapture(settings.camera_index)
            
            if not self.camera.isOpened():
                logger.error(f"Cannot open camera at index {settings.camera_index}")
                return False
            
            # Set camera properties
            self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, settings.camera_width)
            self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, settings.camera_height)
            self.camera.set(cv2.CAP_PROP_FPS, settings.camera_fps)
            
            # Test reading a frame
            ret, frame = self.camera.read()
            if not ret:
                logger.error("Cannot read frame from camera")
                return False
            
            logger.info(f"Camera initialized successfully: {frame.shape}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize camera: {e}")
            return False
    
    def start_capture(self):
        """Start camera capture in background thread"""
        if self.is_running:
            return
        
        self.is_running = True
        self.capture_thread = Thread(target=self._capture_loop, daemon=True)
        self.capture_thread.start()
        logger.info("Camera capture started")
    
    def stop_capture(self):
        """Stop camera capture"""
        self.is_running = False
        if self.capture_thread:
            self.capture_thread.join(timeout=2.0)
        logger.info("Camera capture stopped")
    
    def _capture_loop(self):
        """Main capture loop running in background thread"""
        while self.is_running and self.camera and self.camera.isOpened():
            try:
                ret, frame = self.camera.read()
                if ret:
                    # Flip frame horizontally for mirror effect
                    frame = cv2.flip(frame, 1)
                    
                    # Add timestamp and frame counter
                    self.frame_count += 1
                    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                    
                    # Add overlay information
                    cv2.putText(frame, f"Frame: {self.frame_count}", (10, 30), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    cv2.putText(frame, timestamp, (10, 60), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
                    cv2.putText(frame, "LIVE VRS", (10, 90), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                    
                    # Thread-safe frame update
                    with self.frame_lock:
                        self.current_frame = frame.copy()
                        self.last_capture_time = time.time()
                
                # Control frame rate
                time.sleep(1.0 / settings.camera_fps)
                
            except Exception as e:
                logger.error(f"Error in capture loop: {e}")
                time.sleep(0.1)
    
    def get_current_frame(self) -> Optional[np.ndarray]:
        """Get current frame (thread-safe)"""
        with self.frame_lock:
            return self.current_frame.copy() if self.current_frame is not None else None
    
    def capture_image(self, filename: Optional[str] = None, apply_detection: bool = True) -> Dict[str, Any]:
        """
        Capture a single image with optional defect detection
        Returns: {
            "success": bool,
            "message": str,
            "filepath": Optional[str],
            "base64_image": Optional[str],
            "detection_results": Optional[Dict]
        }
        """
        try:
            frame = self.get_current_frame()
            if frame is None:
                return {
                    "success": False,
                    "message": "No frame available",
                    "filepath": None,
                    "base64_image": None,
                    "detection_results": None
                }
            
            if filename is None:
                timestamp = time.strftime("%Y%m%d_%H%M%S")
                filename = f"capture_{timestamp}.jpg"
            
            filepath = f"{settings.get_full_captures_dir()}/{filename}"
            
            # Ensure captures directory exists
            os.makedirs(settings.get_full_captures_dir(), exist_ok=True)
            
            # Resize to square format for consistency
            square_frame = self.resize_to_square(frame)
            
            # Apply defect detection if enabled and detector is available
            detection_results = None
            processed_frame = square_frame.copy()
            
            if apply_detection and self.detection_enabled and self.defect_detector is not None:
                try:
                    annotated_frame, detections = self.defect_detector.detect_defects_from_frame(square_frame)
                    processed_frame = annotated_frame
                    detection_results = {
                        "detections": detections,
                        "num_defects": len(detections),
                        "annotated_image": annotated_frame
                    }
                    logger.info(f"Defect detection completed: {len(detections)} defects found")
                except Exception as e:
                    logger.warning(f"Defect detection failed: {e}")
                    detection_results = {"error": str(e)}
            elif apply_detection and self.detection_enabled:
                # Fallback: Tạo bounding box giả để test UI
                logger.info("Creating test bounding box (no model available)")
                test_frame = square_frame.copy()
                h, w = test_frame.shape[:2]
                
                # Vẽ một bounding box test ở giữa ảnh
                cv2.rectangle(test_frame, 
                            (w//4, h//4), (3*w//4, 3*h//4), 
                            (0, 255, 0), 2)
                cv2.putText(test_frame, "TEST DETECTION", 
                          (w//4, h//4-10), cv2.FONT_HERSHEY_SIMPLEX, 
                          0.7, (0, 255, 0), 2)
                
                processed_frame = test_frame
                logger.info(f"TEST: Drew bounding box on image {w}x{h}")
                logger.info(f"TEST: Box coordinates: ({w//4}, {h//4}) to ({3*w//4}, {3*h//4})")
                
                detection_results = {
                    "detections": [{
                        "class_name": "test_defect",
                        "confidence": 0.9,
                        "bbox": [w//4, h//4, 3*w//4, 3*h//4]
                    }],
                    "num_defects": 1,
                    "annotated_image": test_frame
                }
            
            # Save the processed image (with detections if any)
            success = cv2.imwrite(filepath, processed_frame)
            
            if success:
                # Convert to base64 for immediate display
                base64_image = self.frame_to_base64(processed_frame)
                logger.info(f"Image captured: {filepath}")
                logger.info(f"Detection applied: {apply_detection and self.detection_enabled and self.defect_detector is not None}")
                logger.info(f"Base64 image length: {len(base64_image) if base64_image else 0}")
                logger.info(f"Processed frame shape: {processed_frame.shape}")
                if detection_results:
                    logger.info(f"Detection results: {detection_results.get('num_defects', 0)} defects found")
                
                return {
                    "success": True,
                    "message": f"Image saved as {filename}",
                    "filepath": filepath,
                    "base64_image": base64_image,
                    "detection_results": detection_results
                }
            else:
                return {
                    "success": False,
                    "message": "Failed to save image",
                    "filepath": None,
                    "base64_image": None,
                    "detection_results": None
                }
                
        except Exception as e:
            logger.error(f"Error capturing image: {e}")
            return {
                "success": False,
                "message": f"Capture error: {str(e)}",
                "filepath": None,
                "base64_image": None,
                "detection_results": None
            }
    
    def frame_to_base64(self, frame: np.ndarray, quality: int = 80) -> str:
        """Convert frame to base64 string for WebSocket transmission"""
        try:
            # Encode frame as JPEG
            encode_param = [cv2.IMWRITE_JPEG_QUALITY, quality]
            _, buffer = cv2.imencode('.jpg', frame, encode_param)
            
            # Convert to base64
            frame_base64 = base64.b64encode(buffer).decode('utf-8')
            return frame_base64
            
        except Exception as e:
            logger.error(f"Error converting frame to base64: {e}")
            return ""
    
    def get_frame_info(self) -> Dict[str, Any]:
        """Get information about current frame"""
        frame = self.get_current_frame()
        if frame is None:
            return {"status": "no_frame"}
        
        return {
            "status": "active",
            "frame_count": self.frame_count,
            "resolution": {
                "width": frame.shape[1],
                "height": frame.shape[0]
            },
            "last_update": self.last_capture_time,
            "is_square": frame.shape[0] == frame.shape[1]
        }
    
    def resize_to_square(self, frame: np.ndarray, size: int = 640) -> np.ndarray:
        """Resize frame to square maintaining aspect ratio"""
        h, w = frame.shape[:2]
        
        # Calculate square crop
        if w > h:
            # Wide image - crop width
            start_x = (w - h) // 2
            cropped = frame[:, start_x:start_x + h]
        else:
            # Tall image - crop height
            start_y = (h - w) // 2
            cropped = frame[start_y:start_y + w, :]
        
        # Resize to target size
        return cv2.resize(cropped, (size, size))
    
    def set_detection_enabled(self, enabled: bool):
        """Enable or disable defect detection"""
        self.detection_enabled = enabled
        logger.info(f"Defect detection {'enabled' if enabled else 'disabled'}")
    
    def is_detection_available(self) -> bool:
        """Check if defect detection is available"""
        return self.defect_detector is not None
    
    def get_detection_status(self) -> Dict[str, Any]:
        """Get status of defect detection service"""
        return {
            "available": self.is_detection_available(),
            "enabled": self.detection_enabled,
            "model_loaded": self.defect_detector is not None and hasattr(self.defect_detector, 'session')
        }
    
    def capture_with_detection_analysis(self, filename: Optional[str] = None) -> Dict[str, Any]:
        """
        Capture image and provide detailed detection analysis
        Returns both raw and processed images with full detection data
        """
        logger.info("Starting capture_with_detection_analysis")
        result = self.capture_image(filename, apply_detection=True)
        logger.info(f"Capture result success: {result['success']}")
        
        if result["success"] and result["detection_results"]:
            detection_data = result["detection_results"]
            logger.info(f"Processing detection data: {detection_data}")
            
            # Add analysis summary
            if "detections" in detection_data:
                defects_by_type = {}
                for detection in detection_data["detections"]:
                    defect_type = detection.get("class_name", "unknown")
                    defects_by_type[defect_type] = defects_by_type.get(defect_type, 0) + 1
                
                result["analysis"] = {
                    "total_defects": len(detection_data["detections"]),
                    "defects_by_type": defects_by_type,
                    "has_critical_defects": any(
                        d.get("confidence", 0) > 0.8 for d in detection_data["detections"]
                    )
                }
                logger.info(f"Analysis added: {result['analysis']}")
        else:
            logger.warning("No detection results or capture failed")
        
        return result
    
    async def cleanup(self):
        """Cleanup camera resources"""
        self.stop_capture()
        
        if self.camera:
            self.camera.release()
            self.camera = None
        
        logger.info("Camera cleanup completed")


# Global camera service instance
camera_service = CameraService()
