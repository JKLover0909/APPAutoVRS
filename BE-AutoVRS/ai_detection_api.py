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

    def detect_defects(self, image: np.ndarray, confidence_threshold=0.25, iou_threshold=0.45):
        """Chạy AI detection với Ultralytics YOLO"""
        if self.model is None:
            logger.error("❌ Model not loaded")
            return [], image, {"error": "Model not loaded"}
            
        logger.info(f"🔍 Starting Ultralytics YOLO detection")
        logger.info(f"🔍 Image shape: {image.shape}")
        logger.info(f"🔍 Image dtype: {image.dtype}")
        logger.info(f"🔍 Image min/max: {image.min()}/{image.max()}")
        logger.info(f"🔍 Confidence threshold: {confidence_threshold}")
        logger.info(f"🔍 IoU threshold: {iou_threshold}")
        
        try:
            # DEBUG: Lưu ảnh tạm để so sánh với code riêng
            temp_path = r"C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS\temp_debug_api.jpg"
            cv2.imwrite(temp_path, image)
            logger.info(f"🧪 Saved temp image for debug: {temp_path}")
            
            # Method 1: Thử với file path (giống code riêng)
            print("🔍 Method 1: Đang thực hiện nhận diện với file path...")
            results_path = self.model(temp_path, conf=confidence_threshold, iou=iou_threshold)
            print(f"✅ Method 1 hoàn tất! Boxes found: {len(results_path[0].boxes) if results_path[0].boxes is not None else 0}")
            
            # Method 2: Thử với numpy array trực tiếp
            print("🔍 Method 2: Đang thực hiện nhận diện với numpy array...")
            results_array = self.model(image, conf=confidence_threshold, iou=iou_threshold)
            print(f"✅ Method 2 hoàn tất! Boxes found: {len(results_array[0].boxes) if results_array[0].boxes is not None else 0}")
            
            # Method 3: Thử với BGR -> RGB conversion
            print("🔍 Method 3: Đang thực hiện nhận diện với RGB conversion...")
            image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            results_rgb = self.model(image_rgb, conf=confidence_threshold, iou=iou_threshold)
            print(f"✅ Method 3 hoàn tất! Boxes found: {len(results_rgb[0].boxes) if results_rgb[0].boxes is not None else 0}")
            
            # Chọn kết quả tốt nhất
            results = results_path  # Bắt đầu với file path vì nó hoạt động trong code riêng
            method_used = "file_path"
            
            if results_array[0].boxes is not None and len(results_array[0].boxes) > 0:
                results = results_array
                method_used = "numpy_array"
            elif results_rgb[0].boxes is not None and len(results_rgb[0].boxes) > 0:
                results = results_rgb
                method_used = "rgb_conversion"
                
            print(f"🎯 Using method: {method_used}")
            
            # Vẽ kết quả lên ảnh
            annotated_image_bgr = results[0].plot()
            
            # Lấy thông tin boxes từ kết quả
            boxes = results[0].boxes
            
            # Debug: In ra số lượng boxes chi tiết
            logger.info(f"🧪 Final boxes: {boxes}")
            logger.info(f"🧪 Number of boxes detected: {len(boxes) if boxes is not None else 0}")
            logger.info(f"🧪 Method used: {method_used}")
            
            # Tạo detection results
            detections = []
            
            if boxes is None or len(boxes) == 0:
                print("❌ Không phát hiện đối tượng nào!")
                logger.warning("❌ No objects detected - this might be the issue!")
            else:
                print("\n📊 Chi tiết các đối tượng được phát hiện:")
                print("="*50)
                
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
                'avg_confidence': sum([d['confidence'] for d in detections]) / len(detections) if detections else 0.0,
                'method_used': method_used  # Thêm thông tin method đã dùng
            }
            
            # Đếm số lượng từng loại defect
            for d in detections:
                defect_type = d['class_name_vi']
                stats['defect_types'][defect_type] = stats['defect_types'].get(defect_type, 0) + 1
            
            print(f"\n📈 Tổng số đối tượng phát hiện được: {len(boxes) if boxes else 0}")
            logger.info(f"✅ Detection completed: {len(detections)} defects found using {method_used}")
            
            # Cleanup temp file
            if os.path.exists(temp_path):
                os.remove(temp_path)
            
            return detections, annotated_image_bgr, stats
            
        except Exception as e:
            logger.error(f"❌ Detection error: {e}")
            import traceback
            logger.error(f"❌ Traceback: {traceback.format_exc()}")
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
        
        # Tạo folder Image_output nếu chưa tồn tại
        output_folder = r"C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS\Image_output"
        os.makedirs(output_folder, exist_ok=True)
        
        # Tạo tên file với timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        processed_filename = f"ai_processed_{timestamp}.jpg"
        
        # Run AI detection
        detections, result_image, stats = ai_service.detect_defects(
            image, 
            request.confidence_threshold, 
            request.iou_threshold
        )
        
        # Chỉ lưu ảnh đã xử lý vào Image_output folder
        output_save_path = os.path.join(output_folder, processed_filename)
        cv2.imwrite(output_save_path, result_image)
        logger.info(f"💾 Saved processed image to: {output_save_path}")
        print(f"✅ Đã lưu ảnh kết quả tại: {output_save_path}")
        
        # Encode result image
        _, buffer = cv2.imencode('.jpg', result_image)
        result_image_base64 = base64.b64encode(buffer.tobytes()).decode('utf-8')
        
        logger.info(f"✅ Detection completed: {len(detections)} defects found")
        
        return DetectionResult(
            success=True,
            message=f"Detection completed successfully. Found {len(detections)} defects. Image saved: {processed_filename}",
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