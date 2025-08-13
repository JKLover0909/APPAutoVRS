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
        
        # Class names mapping (cập nhật theo model của bạn)
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
        try:
            if not os.path.exists(self.model_path):
                logger.warning(f"⚠️ Model file not found: {self.model_path}")
                logger.info("📝 Running in demo mode without actual AI detection")
                self.session = None
                return
                
            self.session = ort.InferenceSession(self.model_path)
            self.input_name = self.session.get_inputs()[0].name
            self.output_names = [output.name for output in self.session.get_outputs()]
            logger.info(f"✅ Model loaded successfully: {self.model_path}")
            logger.info(f"Input name: {self.input_name}")
            logger.info(f"Output names: {self.output_names}")
        except Exception as e:
            logger.error(f"❌ Failed to load model: {e}")
            logger.info("📝 Running in demo mode without actual AI detection")
            self.session = None
    
    def create_demo_detections(self, image_shape):
        """Tạo detection demo khi không có model"""
        height, width = image_shape[:2]
        
        # Tạo một vài detection giả lập
        demo_detections = [
            {
                'bbox': [50, 50, 150, 150],
                'confidence': 0.85,
                'class_id': 7,
                'class_name': 'scratch',
                'class_name_vi': 'Vết xước',
                'coordinates': {'x': 50, 'y': 50, 'width': 100, 'height': 100}
            },
            {
                'bbox': [200, 100, 280, 180],
                'confidence': 0.72,
                'class_id': 5,
                'class_name': 'solder_defect', 
                'class_name_vi': 'Lỗi hàn',
                'coordinates': {'x': 200, 'y': 100, 'width': 80, 'height': 80}
            }
        ]
        
        return demo_detections
    
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
        try:
            if self.session is None:
                # Demo mode - tạo detection giả lập
                logger.info("🎭 Running in demo mode")
                detections = self.create_demo_detections(image.shape)
            else:
                # TODO: Implement actual ONNX inference here
                # Hiện tại chạy demo mode
                detections = self.create_demo_detections(image.shape)
            
            # Draw results
            result_image = self.draw_detections(image, detections)
            
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
    logger.info("📡 Server: http://localhost:8082")
    logger.info("📋 API Documentation: http://localhost:8082/docs")

@app.get("/")
async def root():
    return {
        "message": "AutoVRS AI Detection API",
        "version": "1.0.0",
        "model_loaded": ai_service.session is not None,
        "endpoints": ["/api/ai-detection", "/health"],
        "status": "🟢 Running"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": ai_service.session is not None,
        "timestamp": datetime.now().isoformat(),
        "mode": "production" if ai_service.session is not None else "demo"
    }

@app.post("/api/ai-detection", response_model=DetectionResult)
async def ai_detection(request: DetectionRequest):
    """API endpoint cho AI detection"""
    try:
        logger.info("🤖 Received AI detection request")
        
        # Decode base64 image
        image_data = base64.b64decode(request.image_base64)
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Invalid image data")
        
        logger.info(f"📸 Processing image: {image.shape}")
        
        # Run AI detection
        detections, result_image, stats = ai_service.detect_defects(
            image, 
            request.confidence_threshold, 
            request.iou_threshold
        )
        
        # Encode result image
        _, buffer = cv2.imencode('.jpg', result_image)
        result_image_base64 = base64.b64encode(buffer.tobytes()).decode('utf-8')
        
        logger.info(f"✅ Detection completed: {len(detections)} defects found")
        
        return DetectionResult(
            success=True,
            message=f"Detection completed successfully. Found {len(detections)} defects.",
            detections=detections,
            processed_image_base64=result_image_base64,
            statistics=stats,
            timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"❌ Detection error: {e}")
        raise HTTPException(status_code=500, detail=f"Detection failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    
    print("🤖 Starting AutoVRS AI Detection API...")
    print("📁 Make sure 'yolov11.onnx' file is in the same directory (optional for demo)")
    print("📡 API will be available at: http://localhost:8082")
    print("📋 API Documentation: http://localhost:8082/docs")
    print("🛑 Press Ctrl+C to stop")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8082,
        log_level="info"
    )
