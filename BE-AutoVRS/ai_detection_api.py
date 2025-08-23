# -*- coding: utf-8 -*-
# AI Detection API cho AutoVRS
# Backend Python với FastAPI và Ultralytics YOLO

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import cv2
import numpy as np
import base64
from datetime import datetime
import logging
from typing import List, Dict, Any
import json
import os
from ultralytics import YOLO

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
    confidence_threshold: float = 0.25
    iou_threshold: float = 0.45

class DetectionResult(BaseModel):
    success: bool
    message: str
    detections: List[Dict[str, Any]]
    processed_image_base64: str
    statistics: Dict[str, Any]
    timestamp: str

class AIDetectionService:
    def __init__(self, model_path: str = r"C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS\models\best.onnx"):
        """Initialize Ultralytics YOLO model"""
        self.model_path = model_path
        self.model = None
        self.load_model()
        
        # Class names tiếng Việt
        self.class_names_vi = {
            0: 'Khuyết mạch',
            1: 'Hở mạch', 
            2: 'Thiếu linh kiện',
            3: 'Đường dẫn bị hỏng',
            4: 'Sai linh kiện',
            5: 'Lỗi hàn',
            6: 'Vết nứt',
            7: 'Vết xước',
        }

    def load_model(self):
        """Load Ultralytics YOLO model"""
        logger.info(f"🚀 Loading Ultralytics YOLO model from: {self.model_path}")
        
        try:
            # Load model ONNX với Ultralytics
            self.model = YOLO(self.model_path)
            logger.info(f"✅ Model loaded successfully")
            logger.info(f"✅ Model type: {type(self.model)}")
            
            # Test model với dummy prediction
            logger.info("🧪 Testing model...")
            
        except Exception as e:
            logger.error(f"❌ Failed to load model: {e}")
            self.model = None

    def detect_defects_from_file(self, image_path: str, confidence_threshold=0.1, iou_threshold=0.45):
        """Chạy AI detection với file path - Logic giống CodeAI.ipynb"""
        if self.model is None:
            logger.error("❌ Model not loaded")
            return [], None, {"error": "Model not loaded"}
            
        logger.info(f"🔍 Starting Ultralytics YOLO detection from file")
        logger.info(f"🔍 Image path: {image_path}")
        logger.info(f"🔍 Confidence threshold: {confidence_threshold}")
        logger.info(f"🔍 IoU threshold: {iou_threshold}")
        
        try:
            # Thực hiện nhận diện với mô hình ONNX - Logic giống CodeAI.ipynb
            print("🔍 Đang thực hiện nhận diện với mô hình ONNX...")
            results = self.model(image_path, conf=confidence_threshold, iou=iou_threshold)
            print("✅ Nhận diện hoàn tất!")
            
            # Vẽ kết quả lên ảnh
            annotated_image_bgr = results[0].plot()
            
            # Hiển thị thông tin chi tiết về các đối tượng được phát hiện
            print("\n📊 Chi tiết các đối tượng được phát hiện:")
            print("="*50)
            
            # Lấy thông tin boxes từ kết quả
            boxes = results[0].boxes
            
            # Tạo detection results
            detections = []
            
            if len(boxes) == 0:
                print("Không phát hiện đối tượng nào!")
                logger.warning("❌ No objects detected!")
            else:
                for i, box in enumerate(boxes):
                    class_id = int(box.cls[0])
                    class_name = self.model.names[class_id]  # Lấy tên class từ model
                    confidence = float(box.conf[0])
                    # Lấy tọa độ dạng [x1, y1, x2, y2]
                    coords = [round(x) for x in box.xyxy[0].tolist()]
                    
                    print(f"📌 Đối tượng {i+1}:")
                    print(f"   - Class: {class_name} (ID: {class_id})")
                    print(f"   - Độ tin cậy (Confidence): {confidence:.3f}")
                    print(f"   - Tọa độ [x1, y1, x2, y2]: {coords}")
                    print("-"*50)
                    
                    # Thêm vào detection results
                    detections.append({
                        'bbox': coords,
                        'confidence': confidence,
                        'class_id': class_id,
                        'class_name': class_name,
                        'class_name_vi': self.class_names_vi.get(class_id, class_name)
                    })
            
            # Thống kê
            stats = {
                'total_defects': len(detections),
                'defect_types': {},
                'max_confidence': max([d['confidence'] for d in detections]) if detections else 0.0,
                'avg_confidence': sum([d['confidence'] for d in detections]) / len(detections) if detections else 0.0
            }
            
            # Đếm số lượng từng loại defect
            for d in detections:
                defect_type = d['class_name_vi']
                stats['defect_types'][defect_type] = stats['defect_types'].get(defect_type, 0) + 1
            
            # So sánh số lượng phát hiện từ mô hình ONNX
            print(f"\n📈 Tổng số đối tượng phát hiện được: {len(boxes)}")
            logger.info(f"✅ Detection completed: {len(detections)} defects found")
            
            return detections, annotated_image_bgr, stats
            
        except Exception as e:
            logger.error(f"❌ Detection error: {e}")
            import traceback
            logger.error(f"❌ Traceback: {traceback.format_exc()}")
            return [], None, {"error": str(e)}

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
        "model_loaded": ai_service.model is not None,
        "endpoints": ["/api/ai-detection", "/health"]
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": ai_service.model is not None,
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
        
        # Tạo folder Image_input nếu chưa tồn tại
        input_folder = r"C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS\Image_input"
        os.makedirs(input_folder, exist_ok=True)
        
        # Tạo folder Image_output nếu chưa tồn tại
        output_folder = r"C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS\Image_output"
        os.makedirs(output_folder, exist_ok=True)
        
        # Tạo tên file với timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        input_filename = f"ai_input_{timestamp}.jpg"
        processed_filename = f"ai_processed_{timestamp}.jpg"
        
        # Bước 1: Lưu ảnh gốc từ base64 vào Image_input folder
        input_image_path = os.path.join(input_folder, input_filename)
        cv2.imwrite(input_image_path, image)
        logger.info(f"💾 Saved input image to: {input_image_path}")
        print(f"✅ Đã lưu ảnh input tại: {input_image_path}")
        
        # Bước 2: Chạy AI detection với file path (giống CodeAI.ipynb)
        detections, result_image, stats = ai_service.detect_defects_from_file(
            input_image_path, 
            request.confidence_threshold, 
            request.iou_threshold
        )
        
        # Bước 3: Lưu ảnh đã xử lý vào Image_output folder
        if result_image is not None:
            output_save_path = os.path.join(output_folder, processed_filename)
            cv2.imwrite(output_save_path, result_image)
            logger.info(f"💾 Saved processed image to: {output_save_path}")
            print(f"✅ Đã lưu ảnh kết quả tại: {output_save_path}")
            
            # Encode result image
            _, buffer = cv2.imencode('.jpg', result_image)
            result_image_base64 = base64.b64encode(buffer.tobytes()).decode('utf-8')
        else:
            # Nếu không có result_image, dùng ảnh gốc
            _, buffer = cv2.imencode('.jpg', image)
            result_image_base64 = base64.b64encode(buffer.tobytes()).decode('utf-8')
        
        logger.info(f"✅ Detection completed: {len(detections)} defects found")
        
        return DetectionResult(
            success=True,
            message=f"Detection completed successfully. Found {len(detections)} defects. Images saved: {input_filename} → {processed_filename}",
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
    uvicorn.run(app, host="0.0.0.0", port=8082, log_level="info")