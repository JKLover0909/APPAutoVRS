# Testing Guide: ONNX Runtime Migration

## Prerequisites
Đảm bảo đã install dependencies:
```bash
cd BE-AutoVRS
pip install -r requirements_ai.txt
```

## Quick Test

### 1. Kiểm tra ONNX Runtime providers
```bash
python -c "import onnxruntime as ort; print('ONNX Providers:', ort.get_available_providers())"
```

Expected output:
- **GPU**: `['CUDAExecutionProvider', 'CPUExecutionProvider']`
- **CPU only**: `['CPUExecutionProvider']`

### 2. Verify model files
```bash
# Windows PowerShell
Get-ChildItem -Path "models" -Recurse -Filter "*.onnx" | Select-Object Name, Length, DirectoryName

# Hoặc Python
python -c "import os; [print(f) for f in os.walk('models') for f in f[2] if f.endswith('.onnx')]"
```

Expected: 12 `.onnx` files (1 multiclass + 11 single-class)

### 3. Test ONNX detector standalone
```python
# test_onnx_detector.py
import cv2
import sys
sys.path.append('.')

from src.onnx_multiclass_detector import ONNXMultiClassDetector

# Load detector
detector = ONNXMultiClassDetector(
    model_path='models/multiclass_model/weights/best.onnx',
    conf_threshold=0.10,
    providers=['CPUExecutionProvider']
)

# Test với sample image
image = cv2.imread('Image_input/test.jpg')  # Dùng image có sẵn
if image is None:
    print("❌ Test image not found")
    exit(1)

print(f"Image shape: {image.shape}")

# Run inference
detections = detector.predict(image)
print(f"✅ Found {len(detections)} detections")

for i, det in enumerate(detections):
    print(f"  [{i+1}] Class: {det.class_name}, Conf: {det.conf:.2f}, BBox: {det.bbox}")
```

Run test:
```bash
python test_onnx_detector.py
```

### 4. Start API server
```bash
python run_ai_api.py
```

Expected startup logs:
```
🚀 Initializing ONNX AOI Inspection Pipeline...
✅ ONNX Runtime: Using CPU  (or GPU if CUDA available)
   Available providers: ['CPUExecutionProvider']
🔄 Loading ONNX MultiClass model: models/multiclass_model/weights/best.onnx
   Providers: ['CPUExecutionProvider']
✅ ONNX MultiClass model loaded
🔄 Loading 11 ONNX SingleClass models...
   [1/11] Loaded: BamDinhKhongTot
   [2/11] Loaded: ThieuDongDuongMach
   ...
✅ All 11 ONNX SingleClass models loaded
✓ ONNX Pipeline ready
✅ ONNX Pipeline initialized successfully
🖥️  Using: ['CPUExecutionProvider']
INFO:     Started server process
INFO:     Uvicorn running on http://0.0.0.0:8082
```

### 5. Test API endpoint
#### Using Python:
```python
import requests
import base64

# Read test image
with open('Image_input/test.jpg', 'rb') as f:
    image_b64 = base64.b64encode(f.read()).decode('utf-8')

# Send request
response = requests.post(
    'http://localhost:8082/api/ai-detection',
    json={
        'image_base64': image_b64,
        'confidence_threshold': 0.25
    }
)

result = response.json()
print(f"Success: {result['success']}")
print(f"Message: {result['message']}")
print(f"Detections: {len(result['detections'])}")
```

#### Using cURL:
```bash
# Encode image to base64
$imageBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("Image_input\test.jpg"))

# Send request
curl -X POST http://localhost:8082/api/ai-detection `
  -H "Content-Type: application/json" `
  -d "{\"image_base64\":\"$imageBase64\",\"confidence_threshold\":0.25}"
```

### 6. Test from Flutter app
Đảm bảo Flutter app đang gọi đúng endpoint:
- Endpoint: `POST http://localhost:8082/api/ai-detection`
- Request format:
  ```json
  {
    "image_base64": "...",
    "confidence_threshold": 0.25
  }
  ```

## Performance Benchmark

### Test inference speed:
```python
import time
import cv2
from src.onnx_multiclass_detector import ONNXMultiClassDetector

detector = ONNXMultiClassDetector(
    model_path='models/multiclass_model/weights/best.onnx',
    conf_threshold=0.10,
    providers=['CPUExecutionProvider']
)

image = cv2.imread('Image_input/test.jpg')

# Warmup
for _ in range(3):
    detector.predict(image)

# Benchmark
num_runs = 10
start = time.time()
for _ in range(num_runs):
    detections = detector.predict(image)
end = time.time()

avg_time = (end - start) / num_runs
fps = num_runs / (end - start)

print(f"Average inference time: {avg_time*1000:.2f} ms")
print(f"FPS: {fps:.2f}")
```

Expected results:
- **CPU**: ~100-200ms per image (5-10 FPS)
- **GPU**: ~20-50ms per image (20-50 FPS)
- **PyTorch (baseline)**: 2-3x slower than ONNX on CPU

## Troubleshooting

### Problem 1: "onnxruntime not installed"
```bash
pip install onnxruntime  # CPU version
# OR
pip install onnxruntime-gpu  # GPU version
```

### Problem 2: No detections found
**Possible causes:**
1. ONNX output format mismatch → Debug output shape
2. Confidence threshold too high → Lower to 0.05
3. Preprocessing wrong → Check image normalization

**Debug:**
```python
# In onnx_multiclass_detector.py, add to postprocess():
print(f"DEBUG: Output shape: {outputs[0].shape}")
print(f"DEBUG: First detection: {outputs[0][0][:10]}")
```

### Problem 3: Wrong coordinates
**Possible causes:**
1. Letterbox padding not scaled correctly
2. Coordinate conversion wrong

**Debug:**
```python
# Check preprocessing output
input_tensor = detector.preprocess(image)
print(f"Input shape: {input_tensor.shape}")  # Should be (1, 3, 640, 640)
print(f"Original: {detector.orig_h}x{detector.orig_w}")
print(f"Padding: pad_w={detector.pad_w}, pad_h={detector.pad_h}")
```

### Problem 4: NMS not working (too many overlaps)
**Adjust IOU threshold:**
```python
# In config_ai.py
IOU_NMS_SINGLE = 0.3  # Lower = more aggressive NMS
```

### Problem 5: CUDA not detected
**Install CUDA-enabled ONNX Runtime:**
```bash
pip uninstall onnxruntime
pip install onnxruntime-gpu
```

Verify CUDA:
```python
import onnxruntime as ort
print(ort.get_available_providers())
# Should include 'CUDAExecutionProvider'
```

## Next Steps
1. ✅ Test with real PCB images
2. ✅ Compare accuracy with PyTorch version
3. ✅ Benchmark performance (CPU vs GPU)
4. ✅ Update documentation
5. ✅ Deploy to production

## Rollback
If ONNX version doesn't work:
1. Revert changes to these files:
   - `config_ai.py` (change .onnx back to .pt)
   - `inspection_pipeline.py` (import old detectors)
   - `ai_detection_api.py` (pass device instead of providers)

2. Old detector files are still available:
   - `src/multiclass_detector.py`
   - `src/singleclass_detector.py`
