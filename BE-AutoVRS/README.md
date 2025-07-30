# AutoVRS Backend

🚀 Backend service cho hệ thống Automatic Visual Reference System (AutoVRS)

## 🌟 Tính năng

- **📹 Camera Stream**: Streaming video real-time từ camera của máy chủ
- **🔌 WebSocket**: Kết nối real-time với Flutter frontend
- **📸 Image Capture**: Chụp ảnh từ camera với API
- **⚡ FastAPI**: High-performance REST API
- **🎯 Square Format**: Tự động chuyển đổi hình ảnh về dạng vuông
- **🔧 Configurable**: Dễ dàng cấu hình camera và các tham số

## 🛠️ Cài đặt

### 1. Clone và setup
```bash
cd BE-AutoVRS
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/Mac
source venv/bin/activate

pip install -r requirements.txt
```

### 2. Cấu hình
Chỉnh sửa file `.env`:
```env
# Camera Configuration
CAMERA_INDEX=0
CAMERA_WIDTH=640
CAMERA_HEIGHT=480
CAMERA_FPS=30

# Server Configuration
HOST=0.0.0.0
PORT=8000
```

### 3. Chạy server
```bash
# Cách 1: Sử dụng script runner
python run.py

# Cách 2: Chạy trực tiếp
python main.py

# Cách 3: Sử dụng uvicorn
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## 📡 API Endpoints

### REST API
- `GET /` - Health check cơ bản
- `GET /health` - Health check chi tiết
- `GET /camera/info` - Thông tin camera
- `POST /camera/capture` - Chụp ảnh
- `GET /ws/status` - Trạng thái WebSocket

### WebSocket
- `ws://localhost:8000/ws/{client_id}` - Kết nối WebSocket

## 💬 WebSocket Messages

### Từ Client → Server
```json
{
  "type": "capture_image",
  "request_id": "unique_id",
  "filename": "optional_filename.jpg"
}

{
  "type": "get_status"
}

{
  "type": "ping",
  "timestamp": 1234567890
}
```

### Từ Server → Client
```json
{
  "type": "video_frame",
  "data": "base64_image_data",
  "timestamp": 1234567890,
  "frame_info": {
    "frame_count": 1234,
    "resolution": {"width": 640, "height": 640}
  }
}

{
  "type": "capture_response",
  "success": true,
  "message": "Image saved",
  "filepath": "/path/to/image.jpg"
}
```

## 🎯 Tích hợp với Flutter

### 1. Thêm WebSocket dependency
```yaml
dependencies:
  web_socket_channel: ^2.4.0
```

### 2. Kết nối WebSocket
```dart
import 'package:web_socket_channel/web_socket_channel.dart';

final channel = WebSocketChannel.connect(
  Uri.parse('ws://localhost:8000/ws/flutter_client'),
);

// Lắng nghe messages
channel.stream.listen((message) {
  final data = jsonDecode(message);
  if (data['type'] == 'video_frame') {
    // Hiển thị frame
    final imageBytes = base64Decode(data['data']);
    // Update UI với imageBytes
  }
});

// Gửi capture request
channel.sink.add(jsonEncode({
  'type': 'capture_image',
  'request_id': 'capture_001',
  'filename': 'board_001.jpg'
}));
```

### 3. Hiển thị Live Image
```dart
Container(
  width: 400,
  height: 400, // Square container
  decoration: BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.circular(8),
  ),
  child: _imageBytes != null
    ? Image.memory(_imageBytes!, fit: BoxFit.cover)
    : Center(child: Text('No Camera Feed')),
)
```

## 📁 Cấu trúc Project

```
BE-AutoVRS/
├── main.py                 # FastAPI application chính
├── run.py                  # Script khởi chạy
├── requirements.txt        # Python dependencies
├── .env                    # Configuration file
├── config/
│   ├── __init__.py
│   └── settings.py        # Application settings
├── src/
│   └── services/
│       ├── __init__.py
│       ├── camera_service.py    # Camera management
│       └── websocket_service.py # WebSocket management
└── captures/              # Thư mục lưu ảnh chụp
```

## 🔧 Configuration Options

| Tham số | Mô tả | Giá trị mặc định |
|---------|-------|------------------|
| CAMERA_INDEX | Index của camera | 0 |
| CAMERA_WIDTH | Độ rộng frame | 640 |
| CAMERA_HEIGHT | Độ cao frame | 480 |
| CAMERA_FPS | Frame per second | 30 |
| HOST | Server host | 0.0.0.0 |
| PORT | Server port | 8000 |

## 🐛 Troubleshooting

### Camera không được tìm thấy
```bash
# Kiểm tra camera có sẵn
python -c "import cv2; print([i for i in range(5) if cv2.VideoCapture(i).isOpened()])"
```

### Port đã được sử dụng
```bash
# Windows
netstat -ano | findstr :8000

# Linux/Mac  
lsof -i :8000
```

### WebSocket connection failed
- Kiểm tra firewall settings
- Đảm bảo server đang chạy
- Kiểm tra URL WebSocket đúng format

## 📊 Performance Tips

1. **Giảm FPS WebSocket**: Mặc định 10 FPS, có thể tăng/giảm tùy network
2. **Điều chỉnh JPEG quality**: Thay đổi quality parameter trong `frame_to_base64`
3. **Optimize camera resolution**: Sử dụng resolution phù hợp với hardware

## 🚀 Production Deployment

### 1. Sử dụng Gunicorn
```bash
pip install gunicorn
gunicorn main:app -w 1 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

### 2. Docker deployment
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## 📝 License

MIT License - xem file LICENSE để biết thêm chi tiết.

---

🎯 **Happy Coding!** Nếu có vấn đề gì, hãy tạo issue hoặc liên hệ team phát triển.
