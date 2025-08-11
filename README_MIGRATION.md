# AutoVRS Architecture Migration

## 🔄 **Thay đổi kiến trúc từ Python-centered sang Flutter-centered**

### **Trước khi migrate:**
```
Python Backend (Full Stack)
├── Camera Service (OpenCV)
├── AI Detection (ONNX)  
├── WebSocket Streaming
├── HTTP API Endpoints
├── File Management
└── Image Processing

Flutter Frontend (UI Only)
├── WebSocket Client
├── Image Display
└── UI Controls
```

### **Sau khi migrate:**
```
Python Backend (AI Only)
├── AI Detection Service (ONNX)
└── WebSocket Communication

Flutter Frontend (Full Stack)
├── Camera Service (camera package)
├── Image Capture & Processing
├── WebSocket Client
├── Local Storage
├── UI Controls
└── Business Logic
```

---

## 🗂️ **File Changes**

### **Backend Changes:**
- **NEW**: `main_minimal.py` - Minimal FastAPI with AI only
- **NEW**: `requirements_minimal.txt` - Reduced dependencies
- **NEW**: `start_minimal_backend.bat` - Startup script
- **REMOVED**: Camera service logic
- **REMOVED**: HTTP API endpoints
- **REMOVED**: File management
- **KEPT**: `DefectDetectionService` for AI detection

### **Frontend Changes:**
- **NEW**: `FlutterCameraService` - Full camera management
- **NEW**: `CameraScreen` - Camera UI with real-time preview
- **UPDATED**: `pubspec.yaml` - Added camera dependencies
- **UPDATED**: Routes - Added camera screen
- **UPDATED**: Main app - Added camera service provider

---

## 🚀 **Cách chạy hệ thống mới**

### **1. Khởi động Backend (AI Only):**
```bash
cd BE-AutoVRS
start_minimal_backend.bat
```

### **2. Khởi động Flutter Frontend:**
```bash
cd FE-AutoVRS
flutter pub get
flutter run
```

### **3. Sử dụng:**
- Mở Flutter app
- Navigate to `/camera` route
- Camera sẽ tự động khởi tạo
- Chụp ảnh và AI sẽ phân tích qua WebSocket

---

## 📡 **WebSocket Protocol Mới**

### **Flutter → Python (AI Analysis Request):**
```json
{
  "type": "analyze_image",
  "request_id": "flutter_timestamp", 
  "image_data": "base64_encoded_image"
}
```

### **Python → Flutter (AI Analysis Response):**
```json
{
  "type": "analysis_result",
  "request_id": "flutter_timestamp",
  "success": true,
  "detection_results": {
    "num_defects": 2,
    "detections": [
      {
        "bbox": [x1, y1, x2, y2],
        "class_name": "short_circuit", 
        "confidence": 0.95,
        "color": [255, 0, 0]
      }
    ],
    "confidence_threshold": 0.5
  },
  "analysis": {
    "image_size": [height, width, channels],
    "num_defects": 2,
    "confidence_threshold": 0.5
  }
}
```

---

## 🔧 **Lợi ích của kiến trúc mới**

### **✅ Ưu điểm:**
- **Performance**: Flutter xử lý camera natively, giảm latency
- **Deployment**: Backend nhẹ hơn, chỉ cần GPU cho AI
- **Scalability**: Multiple Flutter clients có thể dùng 1 AI backend
- **Platform Support**: Flutter hỗ trợ mobile/desktop tốt hơn
- **Offline Mode**: Camera hoạt động độc lập, không cần backend

### **⚠️ Cân nhắc:**
- **Flutter Complexity**: Logic phức tạp hơn ở frontend
- **Platform Differences**: Camera API khác nhau giữa platform
- **AI Performance**: Cần network connection để phân tích
- **State Management**: Phải đồng bộ state giữa camera và AI

---

## 🛠️ **Future Improvements**

### **Có thể thêm:**
1. **Local AI**: Chạy ONNX trực tiếp trong Flutter (via tflite/onnx)
2. **Offline Storage**: Cache kết quả phân tích
3. **Multi-camera**: Hỗ trợ nhiều camera đồng thời
4. **Real-time Detection**: Stream + AI real-time
5. **Cloud Sync**: Đồng bộ dữ liệu lên cloud

### **Để rollback về kiến trúc cũ:**
- Sử dụng `main.py` thay vì `main_minimal.py`
- Bỏ camera logic trong Flutter
- Quay lại WebSocket streaming từ Python
