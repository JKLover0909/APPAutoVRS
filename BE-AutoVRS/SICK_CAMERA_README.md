# 🚀 SICK Camera Stream - Quick Start Guide

## Overview
Module mới để stream video từ SICK camera qua WebSocket port 8999.

```
SICK Camera (IC4) → Python (port 8999) → Flutter App
          ↓                                    ↓
    Binary JPEG frames                   Display live
```

---

## 📁 Files Created/Modified

### Python Backend
- ✅ `BE-AutoVRS/sick_camera_stream.py` - Main server code
- ✅ `BE-AutoVRS/run_sick_camera.py` - Entry point

### Flutter Frontend  
- ✅ `App/lib/services/flutter_camera_service.dart` - Modified to receive binary

---

## 🚀 How to Run

### 1. Start Python Server

```bash
cd BE-AutoVRS
python run_sick_camera.py
```

**Output**:
```
🚀 Starting SICK Camera Stream Server...
📋 Port: 8999
============================================================
🚀 SICK Camera WebSocket Server
============================================================
📡 Server: ws://0.0.0.0:8999
📷 Camera: SICK IC4  (or MOCK if IC4 not available)
📐 Resolution: 640x480
🎥 Target FPS: 20
📦 JPEG Quality: 70
============================================================
✅ Server ready, waiting for clients...
```

### 2. Run Flutter App

```bash
cd App
flutter run -d windows
```

### 3. Navigate to Camera Screen

Trong Flutter app, mở Camera Screen để xem live stream.

---

## ⚙️ Configuration

### Python Side (`sick_camera_stream.py`)

```python
# Adjust these values:
self.width = 640          # Resolution width
self.height = 480         # Resolution height  
self.jpeg_quality = 70    # JPEG quality (60-90)
self.target_fps = 20      # Target frames per second
```

### Flutter Side

FlutterCameraService automatically connects to `ws://localhost:8999`.

---

## 🔍 Troubleshooting

### Camera Not Found
```
⚠️  WARNING: imagingcontrol4 not installed. Will use mock camera.
```
**Solution**: 
- Install IC4: `pip install imagingcontrol4`
- Or use MOCK mode for testing

### Connection Refused
```
❌ Failed to connect to backend: Connection refused
```
**Solution**: Make sure Python server is running

### Slow Performance
**Optimize**:
```python
self.width = 320          # Lower resolution
self.height = 240
self.jpeg_quality = 60    # Lower quality
self.target_fps = 15      # Lower FPS
```

---

## 📊 Protocol Details

### Binary Protocol (No Base64!)

**Python sends**:
```python
# Pure binary JPEG bytes
jpeg_bytes = cv2.imencode('.jpg', frame)[1].tobytes()
await websocket.send(jpeg_bytes)
```

**Flutter receives**:
```dart
channel.stream.listen((message) {
  if (message is List<int>) {
    imageData = Uint8List.fromList(message);
    // Display: Image.memory(imageData)
  }
});
```

### Bandwidth Calculation

```
Resolution: 640x480
JPEG Quality: 70
Estimated size: ~15KB per frame
FPS: 20
Bandwidth: 15KB × 20 = 300KB/s = 2.4 Mbps
```

---

## 🎯 Integration Points

Module này thay thế:
- ❌ Port 12345 (C++ module)
- ✅ Port 8999 (Python SICK camera)

**Screens sử dụng**:
- `manual_vrs_screen.dart` - Dùng `AutoVRSWebSocketService`
- `vrs_main_screen.dart` - Dùng `AutoVRSWebSocketService`
- `camera_screen.dart` - Dùng `FlutterCameraService`

---

## 📝 Next Steps

1. Test với SICK camera thật
2. Adjust resolution/quality dựa trên network
3. Integrate với AI detection (port 8082)
4. Replace C++ module stream (port 12345) nếu cần

---

## 💡 Tips

**Mock Mode**: Tự động enable nếu không có IC4 hoặc camera
**Fallback**: Server vẫn chạy với test pattern
**Binary Protocol**: Nhỏ hơn 33% so với base64
**WebSocket**: Bidirectional, low latency
