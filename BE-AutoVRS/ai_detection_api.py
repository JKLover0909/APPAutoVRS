# -*- coding: utf-8 -*-
# AutoVRS AI Detection API
# Backend Python với FastAPI và Advanced Inspection Pipeline (AOI Inspection Core)

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import cv2
import numpy as np
import base64
from datetime import datetime
import logging
import os
import traceback
import sys

# Add current directory to path to find local modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Import AI Core
try:
    import config_ai
    from src.inspection_pipeline import InspectionPipeline, PipelineConfig
    from utils.detection import InspectionResult
except ImportError as e:
    print(f"CRITICAL ERROR: Failed to import AI Core modules: {e}")
    # Fallback/Exit logic handled in startup
    raise e

# ===============================
# Logging
# ===============================
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("AutoVRS_AI_Advanced")

# ===============================
# FastAPI app
# ===============================
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models for request/response
class DetectionRequest(BaseModel):
    image_base64: str
    confidence_threshold: float = 0.25
    iou_threshold: float = 0.45

class DetectionResult(BaseModel):
    success: bool
    message: str
    detections: List[Dict[str, Any]] = []
    processed_image_base64: str = ""
    statistics: Dict[str, Any] = {}
    timestamp: str

# ===============================
# AI Service Wrapper
# ===============================
class AdvancedAIService:
    def __init__(self):
        self.pipeline: Optional[InspectionPipeline] = None
        self.config = None
        self.class_names_vi = {
            "BamDinhKhongTot": "Bám Dính Không Tốt",
            "ChamKim": "Châm Kim",
            "DiVat": "Dị vật",
            "DiVatDuongMach": "Dị vật đường mạch",
            "KhuyetMach": "Khuyết mạch",
            "NganMach": "Ngắn Mạch",
            "ThieuDong": "Thiếu Đồng",
            "ThieuDongDuongMach": "Thiếu Đồng Đường Mạch",
            "ThuaDong": "Thừa Đồng",
            "ThuaDongDuongMach": "Thừa Đồng Đường Mạch",
            "VetLom": "Vết Lõm",
            "Xuoc": "Xước",
            "Other": "Khác"
        }
        self.initialize_pipeline()

    def initialize_pipeline(self):
        """Initialize the ONNX Inspection Pipeline with config."""
        try:
            logger.info("🚀 Initializing ONNX AOI Inspection Pipeline...")
            
            # Create config from config_ai.py
            self.config = PipelineConfig(
                multiclass_model_path=config_ai.MULTICLASS_MODEL,
                single_engine_paths=config_ai.SINGLE_ENGINE_PATHS,
                single_engine_names=config_ai.SINGLE_ENGINE_NAMES,
                # multiclass_class_map not needed - uses sequential class_names
                imgsz=config_ai.IMGSZ,
                conf_multiclass=config_ai.CONF_MULTICLASS,
                conf_single=config_ai.CONF_SINGLE,
                iou_nms_single=config_ai.IOU_NMS_SINGLE,
                single_threads=config_ai.SINGLE_THREADS,
                sam_model_path=config_ai.SAM_MODEL_PATH,
                pixel_size_um=config_ai.PIXEL_SIZE_UM
            )
            
            # Add ONNX providers to config
            self.config.onnx_providers = config_ai.ONNX_PROVIDERS
            
            self.pipeline = InspectionPipeline(self.config)
            logger.info("✅ ONNX Pipeline initialized successfully")
            logger.info(f"🖥️  Using: {config_ai.ONNX_PROVIDERS}")
            
        except Exception as e:
            logger.exception(f"❌ Failed to initialize ONNX pipeline: {e}")
            self.pipeline = None

    def preprocess_image(self, image_base64: str) -> np.ndarray:
        """Decode base64 image -> BGR numpy"""
        try:
            image_data = base64.b64decode(image_base64)
            nparr = np.frombuffer(image_data, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if image is None:
                raise ValueError("Decoded image is None")
            return image
        except Exception as e:
            raise ValueError(f"Failed to decode base64 image: {e}")

    def save_image(self, image: np.ndarray, folder: str, prefix: str):
        """Save image to folder with timestamp"""
        os.makedirs(folder, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        filename = f"{prefix}_{timestamp}.jpg"
        path = os.path.join(folder, filename)
        cv2.imwrite(path, image)
        return path, filename

    def encode_image_to_base64(self, image: np.ndarray) -> str:
        _, buffer = cv2.imencode(".jpg", image)
        return base64.b64encode(buffer.tobytes()).decode("utf-8")
    
    def format_results(self, inspection_results: List[InspectionResult], image: np.ndarray):
        """
        Format Pipeline results to match legacy API response format.
        Also draws results on the image.
        """
        detections_out = []
        stats = {
            "total_defects": len(inspection_results),
            "defect_types": {},
            "verdict_counts": {"OK": 0, "NG": 0},
            "system_verdict": "OK",
            "primary_defect": None  # Defect with highest confidence if NG
        }
        
        # Determine system verdict (NG if any defect is NG)
        ng_defects = [r for r in inspection_results if r.verdict == "NG"]
        if ng_defects:
            stats["system_verdict"] = "NG"
            # Find defect with highest confidence among NG defects
            primary = max(ng_defects, key=lambda r: r.detection.conf)
            vn_name = self.class_names_vi.get(primary.detection.class_name, primary.detection.class_name)
            stats["primary_defect"] = {
                "class_name": primary.detection.class_name,
                "class_name_vi": vn_name,
                "confidence": primary.detection.conf,
                "reason_code": primary.reason_code,
                "reason_text": primary.reason_text
            }
            
        annotated_image = image.copy()
        
        for idx, res in enumerate(inspection_results):
            det = res.detection
            
            # 1. Update Stats
            vn_name = self.class_names_vi.get(det.class_name, det.class_name)
            stats["defect_types"][vn_name] = stats["defect_types"].get(vn_name, 0) + 1
            stats["verdict_counts"][res.verdict] = stats["verdict_counts"].get(res.verdict, 0) + 1
            
            # 2. Format DTO (Data Transfer Object)
            # Map back to what Frontend expects: class_id, class_name, conf, polygon
            d_dict = {
                "class_id": det.cls_id,  # Use cls_id from Detection dataclass
                "class_name": det.class_name,
                "class_name_vi": vn_name,
                "confidence": det.conf,
                "polygon": det.poly.tolist(), # List of [x, y]
                # New fields from advanced logic
                "verdict": res.verdict,
                "reason_code": res.reason_code,
                "reason_text": res.reason_text,
                "measurements": res.measurements
            }
            detections_out.append(d_dict)
            
            # 3. Draw on image
            color = (0, 0, 255) if res.verdict == "NG" else (0, 255, 0) # Red for NG, Green for OK
            
            # Draw bbox/poly
            pts = det.poly.reshape((-1, 1, 2)).astype(np.int32)
            cv2.polylines(annotated_image, [pts], True, color, 2)
            
            # Draw Label
            label = f"{idx+1}.{vn_name} [{res.verdict}]"
            x, y = pts[0][0]
            cv2.putText(annotated_image, label, (x, y - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        return detections_out, annotated_image, stats

# ===============================
# Initialize Service
# ===============================
ai_service = AdvancedAIService()

# ===============================
# Endpoints
# ===============================
@app.on_event("startup")
async def startup_event():
    logger.info("🚀 AutoVRS Advanced AI API started")
    if ai_service.pipeline is None:
        logger.warning("⚠️ Pipeline did not initialize correctly. Check logs/paths.")

@app.get("/")
async def root():
    return {
        "message": "AutoVRS Advanced AI Detection API",
        "version": "2.0.0",
        "model_loaded": ai_service.pipeline is not None,
        "mode": "Advanced Inspection Pipeline"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": ai_service.pipeline is not None,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/api/ai-detection", response_model=DetectionResult)
async def ai_detection(request: DetectionRequest):
    try:
        if ai_service.pipeline is None:
             raise HTTPException(status_code=503, detail="AI Model not initialized")
             
        # 1. Preprocess
        image = ai_service.preprocess_image(request.image_base64)

        # 2. Save Input
        input_folder = r"BE-AutoVRS\Image_input"
        input_path, input_filename = ai_service.save_image(image, input_folder, "ai_input")

        # 3. Run Pipeline Inference
        # Pipeline takes generic BGR image
        # Note: pipeline.inspect() returns List[InspectionResult]
        inspection_results = ai_service.pipeline.inspect(image, use_sam=True)
        
        # 3.5. Filter to show only highest confidence defect
        if inspection_results:
            # Sort by confidence (highest first)
            inspection_results_sorted = sorted(
                inspection_results, 
                key=lambda r: r.detection.conf, 
                reverse=True
            )
            # Keep only top 1 (highest confidence)
            inspection_results = [inspection_results_sorted[0]]
            logger.info(f"📊 Filtered to top 1 defect: {inspection_results[0].detection.class_name} "
                       f"(conf={inspection_results[0].detection.conf:.3f})")

        # 4. Format Results & Draw
        detections, annotated_image, stats = ai_service.format_results(inspection_results, image)

        # 5. Save Output
        output_folder = r"BE-AutoVRS\Image_output"
        output_path, output_filename = ai_service.save_image(annotated_image, output_folder, "ai_processed")

        # 6. Encode Response
        result_image_base64 = ai_service.encode_image_to_base64(annotated_image)
        
        # Create summary message
        sys_verdict = stats.get("system_verdict", "OK")
        defect_count = stats.get("total_defects", 0)
        
        # Include primary defect name in message if NG
        if sys_verdict == "NG" and stats.get("primary_defect"):
            primary = stats["primary_defect"]
            defect_name = primary["class_name_vi"]
            confidence = primary["confidence"]
            msg = f"Inspection: {sys_verdict} - {defect_name} (Conf: {confidence:.2%}). Total: {defect_count} defects."
        else:
            msg = f"Inspection Completed: {sys_verdict}. Found {defect_count} items."

        return DetectionResult(
            success=True,
            message=msg,
            detections=detections,
            processed_image_base64=result_image_base64,
            statistics=stats,
            timestamp=datetime.now().isoformat()
        )

    except Exception as e:
        logger.exception(f"❌ Detection failed: {e}")
        logger.debug(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    # Use config_ai or hardcoded port if needed
    uvicorn.run(app, host="0.0.0.0", port=8082, log_level="info")
