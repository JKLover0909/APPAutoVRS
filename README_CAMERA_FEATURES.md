# Hướng dẫn sử dụng tính năng Camera mới trong AutoVRS

## Tổng quan
Hệ thống AutoVRS đã được cập nhật với tính năng camera real-time và chụp ảnh. Bây giờ bạn có thể:

1. **Xem Live Camera**: Xem trực tiếp hình ảnh từ camera của máy tính
2. **Chụp lại**: Chụp ảnh hiện tại và xem ngay lập tức
3. **Thoát ảnh**: Quay lại chế độ live camera từ ảnh vừa chụp

## Cách sử dụng

### Khởi động Backend
1. Mở terminal/command prompt
2. Chuyển đến thư mục BE-AutoVRS:
   ```bash
   cd "C:\Users\sonng\OneDrive\Desktop\APPAutoVRS\BE-AutoVRS"
   ```
3. Kích hoạt virtual environment:
   ```bash
   .venv\Scripts\activate
   ```
4. Chạy backend:
   ```bash
   python main.py
   ```

### Khởi động Frontend
1. Mở terminal mới
2. Chuyển đến thư mục FE-AutoVRS:
   ```bash
   cd "C:\Users\sonng\OneDrive\Desktop\APPAutoVRS\FE-AutoVRS"
   ```
3. Chạy Flutter app:
   ```bash
   flutter run -d windows
   ```

### Sử dụng tính năng Camera

#### Trong Manual VRS Screen:
1. **Xem Live Camera**: 
   - Vào "VRS thủ công"
   - Ở phần "Ảnh Live từ VRS", bạn sẽ thấy live feed từ camera
   
2. **Chụp ảnh**:
   - Nhấn nút "Chụp lại" (có icon camera)
   - Ảnh vừa chụp sẽ thay thế live camera
   - Tiêu đề sẽ đổi thành "Ảnh Đã Chụp" (màu xanh)
   
3. **Quay lại Live Camera**:
   - Nhấn nút "X" ở góc trên bên phải của ảnh
   - Sẽ quay lại chế độ live camera
   - Tiêu đề sẽ đổi lại thành "Ảnh Live từ VRS"

#### Trong Giám sát AutoVRS:
- Tương tự như Manual VRS Screen
- Có thể chụp ảnh và xem trong chế độ giám sát

## Tính năng kỹ thuật

### Backend Features:
- **FastAPI WebSocket Server**: Port 8000
- **Real-time Camera Streaming**: OpenCV với định dạng vuông 640x640
- **Image Capture**: Lưu ảnh và trả về base64 ngay lập tức
- **Error Handling**: Xử lý lỗi camera và connection

### Frontend Features:
- **Real-time Display**: Hiển thị video trực tiếp từ backend
- **Responsive Design**: Tự động điều chỉnh kích thước hình vuông
- **State Management**: Provider pattern cho WebSocket service
- **Visual Indicators**: 
  - Trạng thái kết nối (Connected/Disconnected)
  - Chế độ hiển thị (Live/Captured)
  - Frame counter

## Troubleshooting

### Backend không khởi động được:
1. Kiểm tra Python version (cần Python 3.7+)
2. Kiểm tra NumPy version (phải < 2.0 để tương thích OpenCV)
3. Kiểm tra camera permission

### Frontend không kết nối được:
1. Đảm bảo backend đang chạy trên port 8000
2. Kiểm tra firewall settings
3. Xem console để debug WebSocket connection

### Camera không hoạt động:
1. Kiểm tra camera có đang được sử dụng bởi app khác không
2. Thử thay đổi CAMERA_INDEX trong .env file (0, 1, 2...)
3. Kiểm tra camera permissions trong Windows

## Cấu hình

### Backend (.env file):
```env
CAMERA_INDEX=0          # Camera to use (0=default, 1=external)
CAMERA_WIDTH=640        # Camera resolution width
CAMERA_HEIGHT=480       # Camera resolution height
CAMERA_FPS=30          # Frames per second
HOST=0.0.0.0           # Server host
PORT=8000              # Server port
```

### Các ports sử dụng:
- **Backend API**: 8000
- **WebSocket**: 8000/ws/
- **Flutter Dev**: 57xxx (random port)

## Notes
- Ảnh được lưu trong thư mục `BE-AutoVRS/captures/`
- Định dạng ảnh: JPG với timestamp
- Kích thước hiển thị: Vuông (responsive)
- WebSocket reconnection: Tự động retry khi mất kết nối
