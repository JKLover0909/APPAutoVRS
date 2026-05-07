# BE-AutoVRS - Backend System

## 🎯 Quick Start

### Installation
```bash
cd BE-AutoVRS
conda create -n autovrs python=3.10
conda activate autovrs
pip install -r requirements_ai.txt
```

### Start Services

#### AI Detection API (Port 8082)
```bash
python run_ai_api.py
```

#### PLC Gateway API (Port 8083)
```bash
python run_plc_gateway.py
```

#### SICK Camera Stream (Port 8999)
```bash
python run_sick_camera.py
```

## 📚 Documentation

- **[ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md)** - Chi tiết kiến trúc hệ thống
- **[ONNX_MIGRATION_SUMMARY.md](ONNX_MIGRATION_SUMMARY.md)** - ONNX migration guide
- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Hướng dẫn testing
- **[PLC_GATEWAY_README.md](PLC_GATEWAY_README.md)** - PLC integration
- **[SICK_CAMERA_README.md](SICK_CAMERA_README.md)** - Camera streaming

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│         Flutter App (Frontend)              │
└──────┬──────────┬──────────┬────────────────┘
       │          │          │
       ▼          ▼          ▼
   ┌───────┐ ┌────────┐ ┌─────────┐
   │ AI    │ │ PLC    │ │ Camera  │
   │ :8082 │ │ :8083  │ │ :8999   │
   └───────┘ └────────┘ └─────────┘
```

## 🤖 AI Pipeline

```
Input Image
    ↓
MultiClass YOLO (ONNX)
    ↓ (fallback)
SingleClass Ensemble (11 models)
    ↓
SAM Segmentation (if needed)
    ↓
Verdict Engine (OK/NG)
    ↓
Output Results
```

## 📦 Models

### Multiclass Model
- **Path**: `models/multiclass_model/weights/best.onnx`
- **Classes**: 11 defect types

### Singleclass Models (11 models)
- BamDinhKhongTot
- DiVat
- DiVatDuongMach
- KhuyetMach
- NganMach
- ThieuDong
- ThieuDongDuongMach
- ThuaDong
- ThuaDongDuongMach
- VetLom
- Xuoc

## 📁 Structure

```
BE-AutoVRS/
├── config_ai.py              # Configuration
├── ai_detection_api.py       # AI API (:8082)
├── plc_gateway_api.py        # PLC Gateway (:8083)
├── sick_camera_stream.py     # Camera Stream (:8999)
├── src/                      # Core logic
│   ├── inspection_pipeline.py
│   ├── onnx_multiclass_detector.py
│   ├── onnx_singleclass_detector.py
│   ├── segment_trace.py
│   ├── verdict_engine.py
│   └── standards.py
├── utils/                    # Utilities
│   ├── detection.py
│   ├── geometry.py
│   └── visualization.py
└── models/                   # AI models (.onnx)
```

## 🔧 API Endpoints

### AI Detection API (8082)
- `POST /api/ai-detection` - Detect defects
- `GET /api/health` - Health check

### PLC Gateway (8083)
- `POST /api/inspect-defect` - Inspect at coordinates
- `POST /api/plc/move` - Move PLC
- `POST /api/camera/capture` - Capture image

### Camera Stream (8999)
- WebSocket: Binary JPEG frames

## 🧪 Testing

```bash
# Test AI detection
curl -X POST http://localhost:8082/api/ai-detection \
  -H "Content-Type: application/json" \
  -d '{"image_base64": "..."}'

# Health check
curl http://localhost:8082/api/health
```

## 📊 Quality Standards

| Defect Class | Always NG? | Needs SAM? | Criteria |
|--------------|------------|------------|----------|
| BamDinhKhongTot | ✅ Yes | No | Always fail |
| DiVat | No | No | Length < 1.3mm |
| DiVatDuongMach | ✅ Yes | No | Always fail |
| KhuyetMach | No | ✅ Yes | Width ≤ 1/3 trace |
| NganMach | ✅ Yes | No | Always fail |
| ThieuDong | No | ✅ Yes | Complex |
| ThuaDong | No | ✅ Yes | Length < 1.3mm |
| VetLom | ✅ Yes | No | Always fail |
| Xuoc | ✅ Yes | No | Always fail |

## 🚀 Performance

- **ONNX Runtime**: 2-3x faster than PyTorch
- **MultiClass**: ~50ms per image (CPU)
- **Ensemble**: ~200ms with 11 models (parallel)
- **SAM**: ~1-2s per segmentation

## 📖 Learn More

See [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md) for detailed documentation.
