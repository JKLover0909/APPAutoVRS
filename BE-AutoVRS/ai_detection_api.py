# -*- coding: utf-8 -*-
# AI Detection API cho AutoVRS
# Backend Python với FastAPI và ONNX Runtime

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import cv2
import numpy as np
import onnxruntime as ort
import base64
from datetime import datetime
import logging
from typing import List, Dict, Any
import json
import os

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="AutoVRS AI Detection API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class DetectionRequest(BaseModel):
    image_base64: str
    confidence_threshold: float = 0.5
    iou_threshold: float = 0.4

class DetectionResult(BaseModel):
    success: bool
    message: str
    detections: List[Dict[str, Any]]
    processed_image_base64: str
    statistics: Dict[str, Any]
    timestamp: str

class AIDetectionService:
    def __init__(self, model_path: str = "yolov11n.onnx"):
        self.model_path = model_path
        self.session = None
        self.input_name = None
        self.output_names = None
        self.class_names = {
            0: 'short_circuit',      # Đoản mạch
            1: 'open_circuit',       # Hở mạch  
            2: 'missing_component',  # Thiếu linh kiện
            3: 'damaged_track',      # Đường dẫn bị hỏng
            4: 'wrong_component',    # Sai linh kiện
            5: 'solder_defect',      # Lỗi hàn
            6: 'crack',              # Vết nứt
            7: 'scratch',            # Vết xước
        }
        
        # Bản dịch tiếng Việt
        self.class_names_vi = {
            0: 'Đoản mạch',
            1: 'Hở mạch',
            2: 'Thiếu linh kiện',
            3: 'Đường dẫn bị hỏng',
            4: 'Sai linh kiện',
            5: 'Lỗi hàn',
            6: 'Vết nứt',
            7: 'Vết xước',
        }
        
        self.load_model()
    
    def load_model(self):
        """Load ONNX model"""
        logger.info(f"🚀 Loading model from: {self.model_path}")
        logger.info(f"🚀 Model file exists: {os.path.exists(self.model_path)}")
        
        if os.path.exists(self.model_path):
            file_size = os.path.getsize(self.model_path)
            logger.info(f"🚀 Model file size: {file_size} bytes")
        
        try:
            logger.info("🚀 Creating ONNX inference session...")
            self.session = ort.InferenceSession(self.model_path)
            self.input_name = self.session.get_inputs()[0].name
            self.output_names = [output.name for output in self.session.get_outputs()]
            
            logger.info(f"✅ Model loaded successfully: {self.model_path}")
            logger.info(f"✅ Input name: {self.input_name}")
            logger.info(f"✅ Output names: {self.output_names}")
            logger.info(f"✅ Input shape: {self.session.get_inputs()[0].shape}")
            
            # Test if model is working
            dummy_input = np.random.random((1, 3, 640, 640)).astype(np.float32)
            logger.info("🧪 Testing model with dummy input...")
            test_outputs = self.session.run(self.output_names, {self.input_name: dummy_input})
            logger.info(f"🧪 Test successful - got {len(test_outputs)} outputs")
            
        except Exception as e:
            logger.error(f"❌ Failed to load model: {e}")
            logger.error(f"❌ Error type: {type(e)}")
            import traceback
            logger.error(f"❌ Traceback: {traceback.format_exc()}")
            self.session = None
    
    def preprocess_image(self, image: np.ndarray, input_size: tuple = (640, 640)):
        """Tiền xử lý ảnh cho ONNX model"""
        # Resize ảnh
        resized = cv2.resize(image, input_size)
        
        # Chuyển BGR sang RGB
        rgb_image = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
        
        # Normalize [0, 255] -> [0, 1]
        normalized = rgb_image.astype(np.float32) / 255.0
        
        # Chuyển từ HWC sang CHW
        transposed = np.transpose(normalized, (2, 0, 1))
        
        # Thêm batch dimension
        batched = np.expand_dims(transposed, axis=0)
        
        return batched
    
    def postprocess_outputs(self, outputs, confidence_threshold=0.5, iou_threshold=0.4):
        """Xử lý output từ ONNX model YOLOv11"""
        detections = []
        
        logger.info(f"🔍 Processing {len(outputs)} outputs")
        for i, output in enumerate(outputs):
            logger.info(f"🔍 Output {i} shape: {output.shape if hasattr(output, 'shape') else 'No shape attr'}")
        
        # YOLOv11 có format khác với YOLOv5/v8
        # Thử xử lý output chính (thường là output cuối cùng hoặc có shape lớn nhất)
        try:
            # Tìm output có shape phù hợp với detections
            main_output = None
            for output in outputs:
                if hasattr(output, 'shape') and len(output.shape) >= 2:
                    logger.info(f"🔍 Candidate output shape: {output.shape}")
                    # YOLOv11 thường có format [batch, num_classes + 4, num_anchors]
                    # hoặc [batch, num_anchors, num_classes + 4]
                    if output.shape[-1] > 80 or output.shape[1] > 80:  # Có thể chứa classes
                        main_output = output
                        break
            
            if main_output is None:
                # Fallback: sử dụng output đầu tiên
                main_output = outputs[0]
                logger.warning(f"🔍 Using fallback output with shape: {main_output.shape}")
            
            logger.info(f"🔍 Selected output shape: {main_output.shape}")
            
            # Xử lý output
            if len(main_output.shape) == 3:  # [batch, features, anchors]
                predictions = main_output[0]  # Remove batch dimension
                logger.info(f"🔍 Predictions shape after removing batch: {predictions.shape}")
                
                # Transpose nếu cần: [features, anchors] -> [anchors, features]
                if predictions.shape[0] > predictions.shape[1]:
                    predictions = predictions.T
                    logger.info(f"🔍 Transposed predictions shape: {predictions.shape}")
                
                # Bây giờ predictions có shape [num_anchors, num_features]
                num_anchors, num_features = predictions.shape
                logger.info(f"🔍 Processing {num_anchors} anchors with {num_features} features each")
                
                for i in range(num_anchors):
                    detection = predictions[i]
                    
                    if num_features >= 6:  # Ít nhất cần 4 bbox + 1 conf + 1 class
                        # Format: [x_center, y_center, width, height, confidence, class_scores...]
                        x_center, y_center, width, height = detection[:4]
                        confidence = detection[4]
                        
                        logger.debug(f"🔍 Detection {i}: bbox=({x_center:.2f}, {y_center:.2f}, {width:.2f}, {height:.2f}), conf={confidence:.3f}")
                        
                        if confidence >= confidence_threshold:
                            if num_features > 5:
                                class_scores = detection[5:]
                                class_id = np.argmax(class_scores)
                                class_confidence = class_scores[class_id]
                            else:
                                # Nếu không có class scores, dùng confidence chung
                                class_id = 0
                                class_confidence = confidence
                            
                            if class_confidence >= confidence_threshold:
                                # Convert to corner coordinates (scale by 640 if normalized)
                                scale = 640  # Assuming input was 640x640
                                x1 = int((x_center - width / 2) * scale)
                                y1 = int((y_center - height / 2) * scale)
                                x2 = int((x_center + width / 2) * scale)
                                y2 = int((y_center + height / 2) * scale)
                                
                                # Convert class_id to int
                                class_id_int = int(class_id)
                                
                                logger.info(f"✅ Valid detection {i}: class={class_id_int}, conf={confidence:.3f}, bbox=({x1},{y1},{x2},{y2})")
                                
                                detections.append({
                                    'bbox': [x1, y1, x2, y2],
                                    'confidence': float(confidence),
                                    'class_id': class_id_int,
                                    'class_name': self.class_names.get(class_id_int, 'unknown'),
                                    'class_name_vi': self.class_names_vi.get(class_id_int, 'Không xác định'),
                                    'coordinates': {
                                        'x': x1,
                                        'y': y1,
                                        'width': int(abs(x2 - x1)),
                                        'height': int(abs(y2 - y1))
                                    }
                                })
            
            logger.info(f"🔍 Found {len(detections)} raw detections before NMS")
            
            # Apply NMS (Non-Maximum Suppression) if needed
            if len(detections) > 0:
                detections = self.apply_nms(detections, iou_threshold)
                logger.info(f"🔍 {len(detections)} detections after NMS")
            
        except Exception as e:
            logger.error(f"❌ Error in postprocessing: {e}")
            import traceback
            logger.error(f"❌ Traceback: {traceback.format_exc()}")
            
        return detections
    
    def apply_nms(self, detections, iou_threshold=0.4):
        """Apply Non-Maximum Suppression"""
        if len(detections) == 0:
            return detections
        
        # Sort by confidence
        detections = sorted(detections, key=lambda x: x['confidence'], reverse=True)
        
        # Apply simple NMS (có thể cải thiện bằng cv2.dnn.NMSBoxes)
        filtered_detections = []
        for detection in detections:
            should_keep = True
            for kept_detection in filtered_detections:
                if self.calculate_iou(detection['bbox'], kept_detection['bbox']) > iou_threshold:
                    should_keep = False
                    break
            if should_keep:
                filtered_detections.append(detection)
        
        return filtered_detections
    
    def calculate_iou(self, box1, box2):
        """Calculate Intersection over Union"""
        x1_1, y1_1, x2_1, y2_1 = box1
        x1_2, y1_2, x2_2, y2_2 = box2
        
        # Calculate intersection
        x1_i = max(x1_1, x1_2)
        y1_i = max(y1_1, y1_2)
        x2_i = min(x2_1, x2_2)
        y2_i = min(y2_1, y2_2)
        
        if x2_i <= x1_i or y2_i <= y1_i:
            return 0.0
        
        intersection = (x2_i - x1_i) * (y2_i - y1_i)
        
        # Calculate union
        area1 = (x2_1 - x1_1) * (y2_1 - y1_1)
        area2 = (x2_2 - x1_2) * (y2_2 - y1_2)
        union = area1 + area2 - intersection
        
        return intersection / union if union > 0 else 0.0
    
    def draw_detections(self, image: np.ndarray, detections: List[Dict]):
        """Vẽ bounding boxes lên ảnh"""
        result_image = image.copy()
        
        for detection in detections:
            bbox = detection['bbox']
            confidence = detection['confidence']
            class_name_vi = detection['class_name_vi']
            
            x1, y1, x2, y2 = bbox
            
            # Vẽ bounding box
            cv2.rectangle(result_image, (x1, y1), (x2, y2), (0, 255, 0), 2)
            
            # Vẽ label
            label = f"{class_name_vi}: {confidence:.2f}"
            label_size = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 2)[0]
            
            # Background cho text
            cv2.rectangle(result_image, (x1, y1 - label_size[1] - 10), 
                         (x1 + label_size[0], y1), (0, 255, 0), -1)
            
            # Text
            cv2.putText(result_image, label, (x1, y1 - 5), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 2)
        
        return result_image
    
    def detect_defects(self, image: np.ndarray, confidence_threshold=0.5, iou_threshold=0.4):
        """Chạy AI detection trên ảnh"""
        logger.info(f"🔍 Starting detection - model loaded: {self.session is not None}")
        logger.info(f"🔍 Image shape: {image.shape}")
        logger.info(f"🔍 Confidence threshold: {confidence_threshold}")
        logger.info(f"🔍 IoU threshold: {iou_threshold}")
        
        if self.session is None:
            logger.warning("⚠️ Model not loaded - returning empty results")
            return [], image, {"error": "Model not loaded"}

        try:
            # Preprocess
            logger.info("🔍 Preprocessing image...")
            input_tensor = self.preprocess_image(image)
            logger.info(f"🔍 Input tensor shape: {input_tensor.shape}")
            
            # Run inference
            logger.info("🔍 Running inference...")
            outputs = self.session.run(self.output_names, {self.input_name: input_tensor})
            logger.info(f"🔍 Inference complete - outputs count: {len(outputs)}")
            for i, output in enumerate(outputs):
                try:
                    logger.info(f"🔍 Output {i} shape: {output.shape}") # type: ignore
                except:
                    logger.info(f"🔍 Output {i} type: {type(output)}")
            
            # Postprocess
            logger.info("🔍 Postprocessing outputs...")
            detections = self.postprocess_outputs(outputs, confidence_threshold, iou_threshold)
            logger.info(f"🔍 Raw detections found: {len(detections)}")
            
            # Draw results
            result_image = self.draw_detections(image, detections)
            logger.info(f"🔍 Final detections after NMS: {len(detections)}")
            
            # Statistics
            stats = {
                "total_defects": len(detections),
                "defect_types": {},
                "max_confidence": max([d['confidence'] for d in detections]) if detections else 0.0,
                "avg_confidence": sum([d['confidence'] for d in detections]) / len(detections) if detections else 0.0
            }
            
            # Count by type
            for detection in detections:
                class_name = detection['class_name_vi']
                stats["defect_types"][class_name] = stats["defect_types"].get(class_name, 0) + 1
            
            return detections, result_image, stats
            
        except Exception as e:
            logger.error(f"Detection error: {e}")
            return [], image, {"error": str(e)}

# Initialize AI service
ai_service = AIDetectionService()

@app.on_event("startup")
async def startup_event():
    logger.info("🚀 AutoVRS AI Detection API started")

@app.get("/")
async def root():
    return {
        "message": "AutoVRS AI Detection API",
        "version": "1.0.0",
        "model_loaded": ai_service.session is not None,
        "endpoints": ["/api/ai-detection", "/health"]
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": ai_service.session is not None,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/api/ai-detection", response_model=DetectionResult)
async def ai_detection(request: DetectionRequest):
    """API endpoint cho AI detection"""
    try:
        # Decode base64 image
        image_data = base64.b64decode(request.image_base64)
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Invalid image data")
        
        # Tạo folder images_ai nếu chưa tồn tại
        save_folder = os.path.join(os.path.dirname(__file__), "images_ai")
        os.makedirs(save_folder, exist_ok=True)
        
        # Tạo tên file với timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        input_filename = f"ai_input_{timestamp}.jpg"
        processed_filename = f"ai_processed_{timestamp}.jpg"
        
        # Lưu ảnh gốc
        input_save_path = os.path.join(save_folder, input_filename)
        cv2.imwrite(input_save_path, image)
        logger.info(f"💾 Saved input image: {input_save_path}")
        
        # Run AI detection
        detections, result_image, stats = ai_service.detect_defects(
            image, 
            request.confidence_threshold, 
            request.iou_threshold
        )
        
        # Lưu ảnh đã xử lý (có bounding boxes)
        processed_save_path = os.path.join(save_folder, processed_filename)
        cv2.imwrite(processed_save_path, result_image)
        logger.info(f"💾 Saved processed image: {processed_save_path}")
        
        # Encode result image
        _, buffer = cv2.imencode('.jpg', result_image)
        result_image_base64 = base64.b64encode(buffer.tobytes()).decode('utf-8')
        
        logger.info(f"✅ Detection completed: {len(detections)} defects found")
        
        return DetectionResult(
            success=True,
            message=f"Detection completed successfully. Found {len(detections)} defects. Images saved: {input_filename}, {processed_filename}",
            detections=detections,
            processed_image_base64=result_image_base64,
            statistics=stats,
            timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"❌ Detection error: {e}")
        raise HTTPException(status_code=500, detail=f"Detection failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn # type: ignore
    uvicorn.run(app, host="0.0.0.0", port=8082, log_level="info")
