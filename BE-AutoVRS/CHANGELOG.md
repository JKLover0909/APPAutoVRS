# Changelog - BE-AutoVRS

All notable changes to the BE-AutoVRS backend system.

---

## [2.0.0] - 2024 Q4 - ONNX Runtime Migration

### 🚀 Major Changes
- **Migrated from PyTorch to ONNX Runtime** for inference
- **2-3x faster CPU performance**
- **Reduced memory footprint**
- **Lighter deployment** (no PyTorch dependency for inference)

### ✨ Added
- `src/onnx_multiclass_detector.py` - ONNX multiclass detector
- `src/onnx_singleclass_detector.py` - ONNX singleclass ensemble
- ONNX Runtime provider auto-detection (CUDA/CPU)
- 12 ONNX models (1 multiclass + 11 singleclass)

### 🔄 Changed
- `config_ai.py` - Updated to use `.onnx` models instead of `.pt`
- `inspection_pipeline.py` - Integrated ONNX detectors
- `ai_detection_api.py` - Updated to use ONNX providers

### 📚 Documentation
- `ONNX_MIGRATION_SUMMARY.md` - Migration guide
- `TESTING_GUIDE.md` - Updated testing instructions

### 🐛 Fixed
- Memory leaks in PyTorch inference
- Slow CPU performance issues

---

## [1.5.0] - 2024 Q3 - SICK Camera Integration

### ✨ Added
- `sick_camera_stream.py` - WebSocket camera streaming (port 8999)
- `run_sick_camera.py` - Entry point for camera stream
- Real-time 30 FPS streaming to Flutter
- Binary JPEG frame protocol (no base64)

### 🔄 Changed
- Improved camera capture performance
- Reduced latency to ~33ms per frame

### 📚 Documentation
- `SICK_CAMERA_README.md` - Camera setup guide

---

## [1.4.0] - 2024 Q2 - PLC Gateway Integration

### ✨ Added
- `plc_gateway_api.py` - PLC + Camera + AI gateway (port 8083)
- `run_plc_gateway.py` - Entry point
- Omron PLC FinsNet protocol integration
- Automated defect inspection workflow
- Python.NET integration for C# DLL

### 🔄 Changed
- Improved PLC communication reliability
- Added timeout handling for PLC operations

### 📚 Documentation
- `PLC_GATEWAY_README.md` - Integration guide
- `python_cli.py` - CLI testing tool

---

## [1.3.0] - 2024 Q1 - SAM Segmentation

### ✨ Added
- `src/segment_trace.py` - SAM trace segmentation
- `src/sam_segmenter.py` - SAM model wrapper
- Trace width measurement for KhuyetMach, ThuaDong, ThieuDong
- `utils/segment_utils.py` - SAM helper functions

### 🔄 Changed
- Enhanced verdict engine with SAM-based measurements
- Improved accuracy for width-dependent defects

---

## [1.2.0] - 2023 Q4 - Verdict Engine

### ✨ Added
- `src/verdict_engine.py` - OK/NG decision logic
- `src/standards.py` - Quality standards and criteria
- 11 defect classes with custom rules
- Multi-defect rule (>= 3 → NG)

### 🔄 Changed
- Unified verdict system across all defect types
- Added detailed reasoning for each verdict

---

## [1.1.0] - 2023 Q3 - SingleClass Ensemble

### ✨ Added
- `src/singleclass_detector.py` - Ensemble of 11 models
- Parallel inference with ThreadPoolExecutor
- NMS merging for ensemble results
- Fallback mechanism from MultiClass

### 🔄 Changed
- Improved detection recall with ensemble approach
- Better handling of rare defect types

---

## [1.0.0] - 2023 Q2 - Initial Release

### ✨ Added
- `ai_detection_api.py` - Main AI detection API (port 8082)
- `src/inspection_pipeline.py` - Core AOI pipeline
- `src/multiclass_detector.py` - YOLOv8 OBB detection
- `config_ai.py` - Configuration management
- `utils/detection.py` - Core data classes
- `utils/visualization.py` - Drawing utilities
- FastAPI REST endpoints
- Health check endpoints

### 📚 Documentation
- Initial README
- API documentation

---

## Version History Summary

| Version | Date | Key Feature |
|---------|------|-------------|
| 2.0.0 | 2024 Q4 | ONNX Runtime Migration |
| 1.5.0 | 2024 Q3 | SICK Camera Stream |
| 1.4.0 | 2024 Q2 | PLC Gateway |
| 1.3.0 | 2024 Q1 | SAM Segmentation |
| 1.2.0 | 2023 Q4 | Verdict Engine |
| 1.1.0 | 2023 Q3 | SingleClass Ensemble |
| 1.0.0 | 2023 Q2 | Initial Release |

---

## Migration Guides

### From 1.x to 2.0 (ONNX Migration)

#### Required Changes:
1. **Models**: Export all `.pt` models to `.onnx` format
   ```bash
   python utils/yolo_export_engine.py --format onnx
   ```

2. **Dependencies**: Install ONNX Runtime
   ```bash
   pip install onnxruntime>=1.16.3
   # or for GPU
   pip install onnxruntime-gpu>=1.16.3
   ```

3. **Config**: Update `config_ai.py`
   ```python
   # Old
   MULTICLASS_MODEL = 'models/multiclass_model/weights/best.pt'
   DEVICE = 'cuda'
   
   # New
   MULTICLASS_MODEL = 'models/multiclass_model/weights/best.onnx'
   ONNX_PROVIDERS = ['CUDAExecutionProvider', 'CPUExecutionProvider']
   ```

4. **Code**: No changes needed in main API - pipeline handles ONNX transparently

#### Breaking Changes:
- Model format changed from `.pt` to `.onnx`
- `DEVICE` config replaced with `ONNX_PROVIDERS`
- Old PyTorch models not compatible (need re-export)

#### Benefits:
- 2-3x faster inference on CPU
- Lower memory usage
- Smaller Docker images
- No PyTorch runtime dependency

---

## Roadmap

### [2.1.0] - Planned
- [ ] Model versioning system
- [ ] Hot-reload for models
- [ ] A/B testing framework
- [ ] Performance metrics dashboard

### [2.2.0] - Planned
- [ ] Batch processing API
- [ ] Async inference queue
- [ ] Multi-GPU support
- [ ] Model quantization (INT8)

### [3.0.0] - Future
- [ ] Multi-camera support
- [ ] Active learning pipeline
- [ ] Real-time monitoring dashboard
- [ ] Model auto-retraining
- [ ] Distributed inference

---

## Known Issues

### Current
- SAM segmentation can be slow (~1-2s per defect)
- PLC connection may timeout on slow networks
- Camera stream requires IC4 SDK (Windows only)

### Fixed
- ✅ Memory leak in PyTorch inference (v2.0.0)
- ✅ Slow CPU performance (v2.0.0)
- ✅ Base64 overhead in camera stream (v1.5.0)

---

## Contributors

- AutoVRS Development Team
- AI/ML Engineers
- Backend Engineers
- QA Team

---

## Support

For issues or questions:
- Check documentation in `/BE-AutoVRS/*.md` files
- Review test notebooks in `/BE-AutoVRS/*.ipynb`
- Contact development team

---

## License

Proprietary - Internal use only
