# BE-AutoVRS - Kiến Trúc Hệ Thống Backend

## 📋 Tổng Quan

**BE-AutoVRS** là hệ thống backend Python cho AutoVRS (Automatic Visual Recognition System) - hệ thống kiểm tra lỗi PCB tự động sử dụng AI và machine vision.

### Công nghệ chính:
- **Framework**: FastAPI (REST API)
- **AI Engine**: ONNX Runtime (YOLOv11 OBB Detection)
- **Camera**: SICK IC4 (Industrial Camera)
- **PLC**: Omron FinsNet Protocol
- **Segmentation**: SAM/SAM2 (Segment Anything Model)

---

## 🏗️ Kiến Trúc Tổng Thể

```
┌──────────────────────────────────────────────────────────────┐
│                     Flutter App (Frontend)                    │
│                          (Port: 8080)                         │
└─────┬────────────┬────────────┬────────────┬─────────────────┘
      │            │            │            │
      ▼            ▼            ▼            ▼
┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐
│ AI API  │  │ PLC      │  │ SICK     │  │ WebSocket    │
│ :8082   │  │ Gateway  │  │ Camera   │  │ Coordinator  │
│         │  │ :8083    │  │ Stream   │  │ :8081        │
└─────────┘  └──────────┘  └──────────┘  └──────────────┘
     │            │            │
     ▼            ▼            ▼
┌─────────┐  ┌──────────┐  ┌──────────┐
│ ONNX    │  │ Omron    │  │ SICK IC4 │
│ Models  │  │ PLC      │  │ Camera   │
│ (12 AI) │  │ FinsNet  │  │ Hardware │
└─────────┘  └──────────┘  └──────────┘
```

---

## 🔧 Các Module Chính

### 1. **AI Detection API** (`ai_detection_api.py`)
**Port: 8082**

#### Chức năng:
- Nhận ảnh PCB (base64)
- Chạy AI pipeline phát hiện lỗi
- Trả về kết quả phân loại lỗi + phán định OK/NG

#### API Endpoints:
- `POST /api/ai-detection` - Phát hiện lỗi từ ảnh
- `GET /api/health` - Kiểm tra health status

#### AI Pipeline Flow:
```
Input Image (BGR)
    ↓
[1] ONNX MultiClass Detector (YOLOv11 OBB)
    ├─ Có detection → Step 3
    └─ Không có → Step 2
    ↓
[2] ONNX SingleClass Ensemble (11 models parallel)
    ├─ BamDinhKhongTot
    ├─ DiVat
    ├─ DiVatDuongMach
    ├─ KhuyetMach
    ├─ NganMach
    ├─ ThieuDong
    ├─ ThieuDongDuongMach
    ├─ ThuaDong
    ├─ ThuaDongDuongMach
    ├─ VetLom
    └─ Xuoc
    ↓
[3] SAM Trace Segmentation (cho các lỗi cần đo)
    ├─ KhuyetMach: đo trace width
    ├─ ThuaDong: đo copper width
    └─ ThieuDong: đo copper width
    ↓
[4] Verdict Engine (Quality Standards)
    ├─ Check defect count (>= 3 → NG)
    ├─ Check always-NG classes
    ├─ Check size/ratio criteria
    └─ Output: OK/NG + reasoning
    ↓
Output: InspectionResult[] with verdicts
```

#### Các Class Chính:
- **`AdvancedAIService`**: Wrapper service cho AI pipeline
- **`InspectionPipeline`**: Main pipeline coordinator
- **`ONNXMultiClassDetector`**: YOLO multiclass detection
- **`ONNXSingleClassEnsemble`**: Ensemble của 11 single-class models
- **`SAMTraceSegmenter`**: Segmentation và đo bề rộng trace
- **`VerdictEngine`**: Logic phán định OK/NG

---

### 2. **PLC Gateway API** (`plc_gateway_api.py`)
**Port: 8083**

#### Chức năng:
Tích hợp Flutter ↔ PLC ↔ Camera ↔ AI cho chức năng Manual VRS

#### Workflow:
```
1. Flutter gửi tọa độ defect (X, Y)
2. Gateway gửi tọa độ đến PLC Omron (FinsNet)
   - X → D2810
   - Y → D2910
   - Trigger → D3000
3. Đợi PLC di chuyển camera (2 giây)
4. Capture ảnh từ SICK camera (snap_single)
5. Gửi ảnh đến AI API (POST :8082/api/ai-detection)
6. Trả kết quả về Flutter
```

#### API Endpoints:
- `POST /api/inspect-defect` - Kiểm tra lỗi tại tọa độ
- `POST /api/plc/move` - Di chuyển PLC đến tọa độ
- `POST /api/camera/capture` - Capture ảnh từ camera
- `GET /api/health` - Health check

#### Dependencies:
- **pythonnet**: Load C# DLL cho PLC Omron
- **imagingcontrol4**: SICK camera SDK
- **ClassLibrary.dll**: C# library cho FinsNet protocol

---

### 3. **SICK Camera Stream** (`sick_camera_stream.py`)
**Port: 8999** (WebSocket)

#### Chức năng:
Stream video real-time từ SICK camera đến Flutter App

#### Protocol:
- **WebSocket Binary**: Gửi JPEG frames trực tiếp (không base64)
- **Target FPS**: 30 FPS
- **Resolution**: 1920x1080
- **JPEG Quality**: 60

#### Flow:
```
SICK IC4 Camera
    ↓ (Capture BGR8 frames)
IC4 FrameListener
    ↓ (Queue + callback)
cv2.imencode → JPEG
    ↓ (Binary)
WebSocket Broadcast
    ↓
Flutter App (WebSocketChannel)
    ↓
Image.memory(bytes)
```

#### Class Chính:
- **`SICKCameraStreamServer`**: WebSocket server
- **`FrameListener`**: IC4 callback handler
- Mock mode nếu không có IC4 SDK

---

### 4. **WebSocket Coordinator** (`server/ws_coord_server.py`)
**Port: 8081**

#### Chức năng:
Gửi tọa độ clicked từ Flutter → backend để highlight/draw

---

## 📁 Cấu Trúc Source Code

```
BE-AutoVRS/
├── config_ai.py                    # Config: models, paths, thresholds
├── ai_detection_api.py             # Main AI Detection API (port 8082)
├── plc_gateway_api.py              # PLC + Camera + AI Gateway (port 8083)
├── sick_camera_stream.py           # SICK Camera WebSocket Stream (port 8999)
├── run_ai_api.py                   # Entry point cho AI API
├── run_plc_gateway.py              # Entry point cho PLC Gateway
├── run_sick_camera.py              # Entry point cho Camera Stream
├── python_cli.py                   # CLI test tool cho PLC
│
├── src/                            # Core AI Logic
│   ├── inspection_pipeline.py      # Main AOI inspection pipeline
│   ├── onnx_multiclass_detector.py # YOLO multiclass (ONNX)
│   ├── onnx_singleclass_detector.py# YOLO singleclass ensemble (ONNX)
│   ├── segment_trace.py            # SAM trace segmentation
│   ├── verdict_engine.py           # OK/NG decision logic
│   ├── standards.py                # Quality standards/criteria
│   ├── map_aoi_data.py             # AOI data mapping utility
│   └── train_yolov12.py            # Training script
│
├── utils/                          # Helper utilities
│   ├── detection.py                # Detection & Result classes
│   ├── geometry.py                 # Geometric calculations
│   ├── segment_utils.py            # SAM utility functions
│   ├── visualization.py            # Drawing utilities
│   └── yolo_export_engine.py       # ONNX export tool
│
├── models/                         # AI Models (ONNX)
│   ├── multiclass_model/
│   │   └── weights/best.onnx       # 1 multiclass model (11 classes)
│   └── singleclass_model/          # 11 single-class models
│       ├── BamDinhKhongTot/weights/best.onnx
│       ├── DiVat/weights/best.onnx
│       ├── DiVatDuongMach/weights/best.onnx
│       ├── KhuyetMach/weights/best.onnx
│       ├── NganMach/weights/best.onnx
│       ├── ThieuDong/weights/best.onnx
│       ├── ThieuDongDuongMach/weights/best.onnx
│       ├── ThuaDong/weights/best.onnx
│       ├── ThuaDongDuongMach/weights/best.onnx
│       ├── VetLom/weights/best.onnx
│       └── Xuoc/weights/best.onnx
│
├── server/                         # Additional servers
│   └── ws_coord_server.py          # WebSocket coordinator (port 8081)
│
├── Image_input/                    # Input images for testing
├── Image_output/                   # Output images with detections
├── recorded_videos/                # Recorded videos from camera
└── runs/                           # Training runs / predictions

```

---

## 🤖 AI Pipeline Chi Tiết

### **InspectionPipeline** (Core AOI Logic)

#### Step 1: Detection
```python
# Thử MultiClass trước
detections = multiclass_detector.predict(image_bgr)

# Fallback sang SingleClass ensemble nếu không có
if not detections:
    detections = single_ensemble.predict(image_bgr)
```

#### Step 2: SAM Segmentation (cho các lỗi cần đo)
```python
for detection in detections:
    if detection.class_name in ["KhuyetMach", "ThuaDong", "ThieuDong"]:
        # Segment TRACE (không phải defect)
        segmentation = sam_segmenter.segment(
            image=image_bgr,
            detection=detection
        )
        # Đo bề rộng trace vuông góc với defect
        trace_width_mm = segmentation.width_mm
```

#### Step 3: Verdict Engine
```python
for detection in detections:
    verdict = verdict_engine.evaluate_single_defect(
        detection=detection,
        segmentation=segmentation
    )
    # Output: OK/NG với reasoning
```

### **Defect Classes** (11 loại lỗi)

| Class ID | Class Name              | Tiếng Việt                  | Always NG? | Needs SAM? |
|----------|-------------------------|-----------------------------|------------|------------|
| 0        | BamDinhKhongTot         | Bám dính không tốt          | ✅ Yes      | No         |
| 1        | DiVat                   | Dị vật                      | No         | No         |
| 2        | DiVatDuongMach          | Dị vật đường mạch           | ✅ Yes      | No         |
| 3        | KhuyetMach              | Khuyết mạch                 | No         | ✅ Yes      |
| 4        | NganMach                | Ngắn mạch                   | ✅ Yes      | No         |
| 5        | ThieuDong               | Thiếu đồng                  | No         | ✅ Yes      |
| 6        | ThieuDongDuongMach      | Thiếu đồng đường mạch       | No         | No         |
| 7        | ThuaDong                | Thừa đồng                   | No         | ✅ Yes      |
| 8        | ThuaDongDuongMach       | Thừa đồng đường mạch        | No         | No         |
| 9        | VetLom                  | Vết lõm                     | ✅ Yes      | No         |
| 10       | Xuoc                    | Xước                        | ✅ Yes      | No         |

---

## 📐 Quality Standards (Tiêu Chuẩn Phán Định)

### Rule 1: Always NG (Luôn lỗi)
```
- BamDinhKhongTot
- NganMach
- VetLom
- Xuoc
- DiVatDuongMach
→ Verdict: NG (không cần đo)
```

### Rule 2: Multi-Defect Rule
```
If total_defects >= 3:
    → Verdict: NG
```

### Rule 3: KhuyetMach (Khuyết mạch)
```
1. Segment TRACE bằng SAM
2. Đo trace_width
3. If defect_width <= 1/3 * trace_width:
    → OK
   Else:
    → NG
```

### Rule 4: ThuaDong (Thừa đồng)
```
If defect_length > 1.3mm:
    → NG
Else:
    → OK
```

### Rule 5: ThuaDongDuongMach
```
If defect_length > 1.3mm:
    → NG
Else:
    1. Segment LINE bằng SAM
    2. If defect_width > 30% * line_width:
        → NG
       Else:
        → OK
```

### Rule 6: ThieuDong (Thiếu đồng)
```
If defect_length > 1.3mm:
    → NG
Else:
    1. Segment COPPER bằng SAM
    2. If defect_length < 1/3 * copper_width:
        → OK
       Else:
        → NG
```

### Rule 7: DiVat (Dị vật)
```
If defect_length < 1.3mm:
    → OK (requires_recheck: true)
Else:
    → NG
```

---

## 🔄 ONNX Runtime Migration

### Tại sao chuyển sang ONNX?
- **CPU Performance**: 2-3x nhanh hơn PyTorch
- **Memory**: Giảm memory usage
- **Deployment**: Không cần PyTorch runtime
- **Model Size**: Nhỏ hơn ~10-15%

### Models:
```
models/
├── multiclass_model/weights/best.onnx      # 1 model, 11 classes
└── singleclass_model/*/weights/best.onnx   # 11 models, 1 class each
```

### ONNX Providers:
```python
# Auto-detect GPU/CPU
if 'CUDAExecutionProvider' in ort.get_available_providers():
    ONNX_PROVIDERS = ['CUDAExecutionProvider', 'CPUExecutionProvider']
else:
    ONNX_PROVIDERS = ['CPUExecutionProvider']
```

---

## 🚀 Cách Chạy Hệ Thống

### 1. Install Dependencies
```bash
cd BE-AutoVRS
conda create -n autovrs python=3.10
conda activate autovrs
pip install -r requirements_ai.txt
```

### 2. Start AI Detection API
```bash
python run_ai_api.py
# Port: 8082
# Endpoint: http://localhost:8082/api/ai-detection
```

### 3. Start PLC Gateway API (Optional)
```bash
python run_plc_gateway.py
# Port: 8083
# Requires: ClassLibrary.dll (PLC), SICK IC4 SDK
```

### 4. Start SICK Camera Stream (Optional)
```bash
python run_sick_camera.py
# Port: 8999 (WebSocket)
# Requires: imagingcontrol4 SDK
```

### 5. Test API
```bash
# Test AI Detection
curl -X POST http://localhost:8082/api/ai-detection \
  -H "Content-Type: application/json" \
  -d '{"image_base64": "...", "confidence_threshold": 0.25}'

# Health check
curl http://localhost:8082/api/health
```

---

## 📊 Data Classes

### **Detection** (utils/detection.py)
```python
@dataclass
class Detection:
    class_name: str          # "KhuyetMach", "ThuaDong", etc.
    cls_id: int              # 0-10
    conf: float              # Confidence 0-1
    poly: np.ndarray         # (4,2) OBB polygon
    bbox: List[float]        # [x1, y1, x2, y2]
    width: float             # OBB width (shorter side)
    length: float            # OBB length (longer side)
```

### **SegmentationResult**
```python
@dataclass
class SegmentationResult:
    mask: np.ndarray         # (H,W) binary mask
    width_px: float          # Width in pixels
    width_um: float          # Width in micrometers
    width_mm: float          # Width in millimeters
    p_left: np.ndarray       # Left endpoint
    p_right: np.ndarray      # Right endpoint
```

### **InspectionResult**
```python
@dataclass
class InspectionResult:
    detection: Detection
    segmentation: Optional[SegmentationResult]
    verdict: str             # "OK" or "NG"
    reason: VerdictReason
    requires_recheck: bool   # For DiVat
```

---

## 🔧 Configuration (config_ai.py)

```python
# Model paths
MULTICLASS_MODEL = 'models/multiclass_model/weights/best.onnx'
SINGLE_ENGINE_PATHS = [
    'models/singleclass_model/BamDinhKhongTot/weights/best.onnx',
    # ... 10 more models
]

# ONNX Runtime
ONNX_PROVIDERS = ['CUDAExecutionProvider', 'CPUExecutionProvider']

# Inference params
IMGSZ = 640
CONF_MULTICLASS = 0.10
CONF_SINGLE = 0.10
IOU_NMS_SINGLE = 0.4
SINGLE_THREADS = 4

# SAM (optional)
SAM_MODEL_PATH = None  # or 'models/sam2_s.pt'

# Standards
PIXEL_SIZE_UM = 10.0  # µm/pixel
```

---

## 🧪 Testing

### Test ONNX Detector
```python
from src.onnx_multiclass_detector import ONNXMultiClassDetector
import cv2

detector = ONNXMultiClassDetector(
    model_path='models/multiclass_model/weights/best.onnx',
    conf_threshold=0.10
)

image = cv2.imread('Image_input/test.jpg')
detections = detector.predict(image)

for det in detections:
    print(f"{det.class_name}: {det.conf:.2f}")
```

### Test Full Pipeline
```python
from src.inspection_pipeline import InspectionPipeline, PipelineConfig
import config_ai

config = PipelineConfig(
    multiclass_model_path=config_ai.MULTICLASS_MODEL,
    single_engine_paths=config_ai.SINGLE_ENGINE_PATHS,
    single_engine_names=config_ai.SINGLE_ENGINE_NAMES,
    onnx_providers=config_ai.ONNX_PROVIDERS
)

pipeline = InspectionPipeline(config)
results = pipeline.inspect(image_bgr)

for result in results:
    print(f"{result.detection.class_name}: {result.verdict}")
    print(f"  Reason: {result.reason.reason_text}")
```

---

## 📝 API Documentation

### AI Detection API (Port 8082)

#### POST /api/ai-detection
```json
Request:
{
  "image_base64": "iVBORw0KGgoAAAANS...",
  "confidence_threshold": 0.25,
  "iou_threshold": 0.45
}

Response:
{
  "success": true,
  "message": "Detection completed",
  "detections": [
    {
      "class_name": "KhuyetMach",
      "conf": 0.89,
      "bbox": [100, 200, 150, 250],
      "width": 45.2,
      "length": 78.5,
      "verdict": "OK",
      "reason": "Defect width 15px <= 1/3 trace width 60px"
    }
  ],
  "processed_image_base64": "...",
  "statistics": {
    "total_detections": 1,
    "ok_count": 1,
    "ng_count": 0
  },
  "timestamp": "2026-05-07T10:30:00"
}
```

### PLC Gateway API (Port 8083)

#### POST /api/inspect-defect
```json
Request:
{
  "defect_x": 1234.5,
  "defect_y": 678.9,
  "board_id": "PCB-2024-001",
  "plc_ip": "192.168.3.1",
  "plc_port": 9600
}

Response:
{
  "success": true,
  "message": "Inspection completed",
  "defect_position": {"x": 1234.5, "y": 678.9},
  "plc_response": "OK",
  "capture_time": 2.1,
  "ai_results": { /* AI detection results */ },
  "timestamp": "2026-05-07T10:30:00"
}
```

---

## 🛠️ Dependencies

### Python Packages (requirements_ai.txt)
```
fastapi==0.104.1
uvicorn==0.24.0
opencv-python>=4.8.0
onnxruntime>=1.16.3          # ONNX Runtime (CPU)
# onnxruntime-gpu>=1.16.3    # For GPU support
numpy>=1.24.3
pydantic>=2.5.0
ultralytics>=8.3.0           # For SAM, training
scipy>=1.15.3
pandas>=2.2.3
pillow>=10.0.0
httpx>=0.25.0
websockets>=12.0
pythonnet>=3.0.0             # For PLC C# DLL
```

### External Dependencies
- **SICK IC4 SDK**: `imagingcontrol4` (camera stream)
- **ClassLibrary.dll**: C# library cho Omron PLC (FinsNet)
- **CUDA** (optional): Nếu dùng GPU inference

---

## 🎯 Key Features

### ✅ Implemented
- ONNX Runtime inference (CPU/GPU)
- Multi-class + Single-class ensemble detection
- SAM-based trace segmentation
- Quality standards verdict engine
- PLC integration (Omron FinsNet)
- SICK camera WebSocket stream
- REST API với FastAPI
- Health monitoring

### 🚧 Future Enhancements
- Model versioning & hot-reload
- Batch processing API
- Real-time monitoring dashboard
- Data augmentation pipeline
- Active learning feedback loop
- Multi-camera support

---

## 📖 References

### Documentation Files
- `ONNX_MIGRATION_SUMMARY.md` - ONNX migration guide
- `TESTING_GUIDE.md` - Testing instructions
- `PLC_GATEWAY_README.md` - PLC integration guide
- `SICK_CAMERA_README.md` - Camera streaming guide

### Training Notebooks
- `test_onnx_model.ipynb` - ONNX model testing
- `TestAIInfer.ipynb` - AI inference tests
- `TestRestAPI.ipynb` - API testing
- `TestWS.ipynb` - WebSocket testing

---

## 👥 Authors & Contributors

- **AutoVRS Team** - Industrial PCB inspection system
- **Date**: 2024-2026
- **Version**: 2.0 (ONNX Migration)

---

## 📄 License

Proprietary - Internal use only
