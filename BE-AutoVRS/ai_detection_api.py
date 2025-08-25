# -*- coding: utf-8 -*-
# AutoVRS AI Detection API
# Backend Python với FastAPI và Ultralytics YOLO

from fastapi import FastAPI, HTTPException # type: ignore
from fastapi.middleware.cors import CORSMiddleware # type: ignore
from pydantic import BaseModel # type: ignore
from typing import List, Dict, Any
import cv2 # type: ignore
import numpy as np # type: ignore
import base64
from datetime import datetime
import logging
import os
import traceback
from ultralytics import YOLO # type: ignore

# ===============================
# Logging
# ===============================
logging.basicConfig(level=logging.DEBUG, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("AutoVRS_AI")

# ===============================
# FastAPI app
# ===============================
# ===============================
# FastAPI app
# ===============================
# create FastAPI app and CORS
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
# ===== Single OBB inference helper (uses task='obb') =====
class SingleOBBInference:
    def __init__(self, model_path: str):
        """Load a YOLO model with OBB outputs (task='obb')."""
        self.model_path = model_path
        # instantiate Ultralytics model with obb task to get .obb in results
        self.model = YOLO(model_path, task='obb')
        # Normalize names into a safe dict-like mapping
        names = getattr(self.model, 'names', None)
        if names is None:
            self.names = {}
        elif isinstance(names, dict):
            self.names = names
        elif isinstance(names, (list, tuple)):
            self.names = {i: n for i, n in enumerate(names)}
        else:
            self.names = {}
        logger.info(f"Loaded OBB model: {model_path}")

    def infer_image(self, image_path: str):
        """Run model on image_path and return detections + annotated image.
        Returns dict: {'num_objects', 'detections', 'annotated_image'}
        """
        results = self.model(image_path)[0]
        obb = getattr(results, 'obb', None)
        names = getattr(results, 'names', self.names)
        image = cv2.imread(image_path)

        if obb is None or len(getattr(obb, 'cls', [])) == 0:
            logger.warning("No objects detected (OBB).")
            return {'num_objects': 0, 'detections': [], 'annotated_image': image}

        # Safely obtain polygon coords (avoid using `or` on tensor-like objects)
        polygons = getattr(obb, 'xyxyxyxy', None)
        if polygons is None:
            polygons = getattr(obb, 'xyxy', None)
        conf = getattr(obb, 'conf', None)
        cls = getattr(obb, 'cls', None)

        # Convert PyTorch tensors to numpy arrays if necessary
        try:
            import importlib
            _torch = importlib.import_module('torch')
            if polygons is not None and isinstance(polygons, _torch.Tensor):
                polygons = polygons.cpu().numpy()
            if conf is not None and isinstance(conf, _torch.Tensor):
                conf = conf.cpu().numpy()
            if cls is not None and isinstance(cls, _torch.Tensor):
                cls = cls.cpu().numpy()
        except Exception:
            # torch may not be installed or conversion may fail; continue gracefully
            pass

        detections = []
        if cls is None or len(cls) == 0:
            logger.warning("OBB results contain no classes")
            return {'num_objects': 0, 'detections': [], 'annotated_image': image}

        for i in range(len(cls)):
            cls_id = int(cls[i])
            # safe name lookup
            if isinstance(names, dict):
                class_name = names.get(cls_id, str(cls_id))
            else:
                try:
                    class_name = names[cls_id] if cls_id < len(names) else str(cls_id)
                except Exception:
                    class_name = str(cls_id)

            conf_val = float(conf[i]) if (conf is not None and len(conf) > i) else 0.0
            poly = None
            if polygons is not None:
                try:
                    poly = polygons[i]
                except Exception:
                    poly = None

            detections.append({
                'class_id': cls_id,
                'class_name': class_name,
                'conf': conf_val,
                'polygon': poly.tolist() if (poly is not None and hasattr(poly, 'tolist')) else (list(poly) if poly is not None else [])
            })

        # draw OBB
        annotated = self.draw_obb(image.copy(), polygons, conf, cls, names)

        return {'num_objects': len(cls), 'detections': detections, 'annotated_image': annotated}

    @staticmethod
    def draw_obb(img, polygons, conf, cls, names):
        for i in range(len(cls)):
            try:
                pts = np.array(polygons[i]).reshape((4,2)).astype(np.int32)
                pts = pts.reshape((-1, 1, 2))
                cv2.polylines(img, [pts], isClosed=True, color=(0,255,0), thickness=2)
                x_text, y_text = pts[0][0]
                cls_id = int(cls[i])
                label = names.get(cls_id, str(cls_id)) if isinstance(names, dict) else (names[cls_id] if cls_id < len(names) else str(cls_id))
                cv2.putText(img, f"{label}:{conf[i]:.2f}", (int(x_text), int(y_text)), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0,0,255), 2)
            except Exception:
                continue
        return img


# ===============================
# AI Detection Service (uses SingleOBBInference)
# ===============================
class AIDetectionService:
    def __init__(self, model_path: str):
        self.model_path = model_path
        self.model = None
        self.inferer = None
        self.class_names_vi = {
            0: 'Bám Dính Không Tốt',
            1: 'Châm Kim',
            2: 'Dị vật',
            3: 'Khuyết mạch',
            4: 'Ngắn Mạch',
            5: 'Thiếu Đồng',
            6: 'Thừa Đồng',
            7: 'Xước',
            8: 'Orther'
        }
        self.load_model()

    def load_model(self):
        """Load model and wrap with OBB inferer."""
        try:
            logger.info(f"🚀 Loading model (OBB) from {self.model_path}")
            self.inferer = SingleOBBInference(self.model_path)
            self.model = self.inferer.model
            logger.info("✅ Model (OBB) loaded successfully")
        except Exception as e:
            logger.exception(f"❌ Failed to load model: {e}")
            logger.debug(traceback.format_exc())
            self.model = None
            self.inferer = None

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
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{prefix}_{timestamp}.jpg"
        path = os.path.join(folder, filename)
        cv2.imwrite(path, image)
        return path, filename

    def encode_image_to_base64(self, image: np.ndarray) -> str:
        _, buffer = cv2.imencode(".jpg", image)
        return base64.b64encode(buffer.tobytes()).decode("utf-8")

    def run_inference(self, image_path: str, confidence_threshold: float, iou_threshold: float):
        """Run OBB inference via SingleOBBInference."""
        if self.inferer is None:
            raise RuntimeError("Model not loaded")

        try:
            result = self.inferer.infer_image(image_path)
        except Exception as e:
            logger.exception(f"Inference error for image {image_path}: {e}")
            logger.debug(traceback.format_exc())
            raise

        detections = result.get('detections', [])
        annotated_image = result.get('annotated_image', None)

        # Stats
        stats = {
            "total_defects": len(detections),
            "defect_types": {},
            "max_confidence": max([d['conf'] for d in detections]) if detections else 0.0,
            "avg_confidence": (sum([d['conf'] for d in detections]) / len(detections)) if detections else 0.0
        }
        for d in detections:
            t = d.get('class_name')
            t_vi = self.class_names_vi.get(d.get('class_id'), t)
            # ensure detection contains class_name_vi and confidence keys for client
            d['class_name_vi'] = t_vi
            d['confidence'] = d.get('conf', 0.0)
            stats['defect_types'][t_vi] = stats['defect_types'].get(t_vi, 0) + 1

        return detections, annotated_image, stats

# Initialize AI service
MODEL_PATH = r"C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS\models\multi.onnx"
ai_service = AIDetectionService(MODEL_PATH)

# ===============================
# FastAPI endpoints
# ===============================
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
    try:
        # ===============================
        # 1. Preprocess
        # ===============================
        image = ai_service.preprocess_image(request.image_base64)

        # ===============================
        # 2. Save input image
        # ===============================
        input_folder = r"C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS\Image_input"
        input_image_path, input_filename = ai_service.save_image(image, input_folder, "ai_input")

        # ===============================
        # 3. Run inference
        # ===============================
        detections, annotated_image, stats = ai_service.run_inference(
            input_image_path, request.confidence_threshold, request.iou_threshold
        )

        # ===============================
        # 4. Save annotated image
        # ===============================
        output_folder = r"C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS\Image_output"
        output_image_path, processed_filename = ai_service.save_image(annotated_image, output_folder, "ai_processed")

        # Encode to base64
        result_image_base64 = ai_service.encode_image_to_base64(annotated_image)

        return DetectionResult(
            success=True,
            message=f"Detection completed successfully. Found {len(detections)} defects. Images saved: {input_filename} → {processed_filename}",
            detections=detections,
            processed_image_base64=result_image_base64,
            statistics=stats,
            timestamp=datetime.now().isoformat()
        )

    except Exception as e:
        # log full traceback to server log (use logger.exception to include stacktrace)
        logger.exception(f"❌ Detection failed: {e}")
        logger.debug(traceback.format_exc()) # type: ignore
        # keep HTTP 500 response but avoid exposing stacktrace in response
        raise HTTPException(status_code=500, detail="Detection failed (check server logs for details)")
# ...existing code...

# ===============================
# Run server
# ===============================
if __name__ == "__main__":
    import uvicorn # type: ignore
    uvicorn.run(app, host="0.0.0.0", port=8082, log_level="info")
