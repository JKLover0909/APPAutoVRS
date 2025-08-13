# 🤖 AutoVRS AI Detection Integration

## 📋 Tổng quan
Tích hợp AI Detection với backend Python và Flutter app để phân tích lỗi trên PCB với model ONNX.
autovrs_websocket_service
https://5d0fc6ea5f81.ngrok-free.app

## 🔧 Cài đặt

### 1. Chuẩn bị model
- Đặt file `best.onnx` trong thư mục gốc `APPAutoVRS/`
- Model sẽ được tự động copy vào `BE-AutoVRS/`

### 2. Chạy Backend AI
```bash
# Tự động setup và chạy
./start_ai_backend.bat

# Hoặc manual:
cd BE-AutoVRS
pip install -r requirements_ai.txt
python run_ai_api.py
```

### 3. Chạy Flutter App
```bash
cd App
flutter run -d windows
```

## 🎯 Cách sử dụng

### Trong giao diện VRS Thủ Công:

1. **Chọn nguồn video**: AutoVRS hoặc Video Stream
2. **Nhấn "AI Phân tích"**: Chạy AI detection trên frame hiện tại
3. **Xem kết quả**: Panel hiển thị loại lỗi AI dự đoán
4. **Lưu kết quả**: Lưu vào database hoặc xuất báo cáo

## 📊 Kết quả AI Detection

### Loại lỗi được phát hiện:
- ✅ **Đoản mạch** - Short circuit
- ✅ **Hở mạch** - Open circuit  
- ✅ **Thiếu linh kiện** - Missing component
- ✅ **Đường dẫn bị hỏng** - Damaged track
- ✅ **Sai linh kiện** - Wrong component
- ✅ **Lỗi hàn** - Solder defect
- ✅ **Vết nứt** - Crack
- ✅ **Vết xước** - Scratch

### Thông tin hiển thị:
- **Tổng số lỗi** phát hiện
- **Độ tin cậy** trung bình
- **Chi tiết từng lỗi** với tọa độ và confidence
- **Thống kê theo loại** lỗi

## 🔗 API Endpoints

### Backend AI API (Port 8082):
- `GET /` - Thông tin API
- `GET /health` - Health check
- `POST /api/ai-detection` - AI detection endpoint

### Request format:
```json
{
  "image_base64": "base64_encoded_image",
  "confidence_threshold": 0.5,
  "iou_threshold": 0.4
}
```

### Response format:
```json
{
  "success": true,
  "message": "Detection completed successfully",
  "detections": [...],
  "processed_image_base64": "...",
  "statistics": {...},
  "timestamp": "2025-08-12T..."
}
```

## 🛠️ Architecture

```
Flutter App (Port: Flutter)
    ↓ HTTP POST
Backend AI API (Port: 8082)
    ↓ Load & Inference  
ONNX Model (best.onnx)
    ↓ Detection Results
Flutter UI Display
```

## 🎨 UI Components

### Đã thêm:
- ✅ **AIDetectionService** - Service kết nối API
- ✅ **AI Analysis Button** - Nút chạy phân tích
- ✅ **AI Results Panel** - Panel hiển thị kết quả
- ✅ **Statistics Cards** - Cards thống kê
- ✅ **Defect List** - Danh sách lỗi phát hiện
- ✅ **Action Buttons** - Lưu DB, xuất báo cáo

### Tính năng:
- 🔄 **Loading state** khi đang phân tích
- 📊 **Real-time statistics** 
- 💾 **Database integration** để lưu kết quả
- 📄 **Report export** (JSON format)
- 🎯 **Confidence scoring** cho từng detection

## 🚀 Deployment

### Development:
1. Chạy AI backend: `python run_ai_api.py`
2. Chạy Flutter app: `flutter run -d windows`

### Production:
- AI Backend có thể deploy lên server riêng
- Cập nhật `_baseUrl` trong `AIDetectionService`
- Sử dụng Docker cho backend nếu cần

## 🐛 Troubleshooting

### Lỗi thường gặp:

1. **Model không load được**:
   - Kiểm tra file `best.onnx` có tồn tại
   - Kiểm tra ONNX Runtime version compatibility

2. **API connection failed**:
   - Kiểm tra backend có đang chạy (port 8082)
   - Kiểm tra firewall/network settings

3. **No frame to analyze**:
   - Kiểm tra video source đang hoạt động
   - Đảm bảo có frame hiện tại từ camera/stream

## 📝 Future Enhancements

- [ ] Batch processing nhiều ảnh
- [ ] Real-time detection trên video stream
- [ ] Custom confidence thresholds per defect type
- [ ] Model versioning và A/B testing
- [ ] Export báo cáo PDF với charts
- [ ] Integration với các model khác

---
🎉 **AI Detection đã sẵn sàng sử dụng!**
