# AutoVRS - Hệ thống kiểm tra tự động

AutoVRS là một ứng dụng Flutter được thiết kế để quản lý và vận hành hệ thống kiểm tra tự động (Automatic Visual Recognition System) trong sản xuất linh kiện điện tử.

## Tính năng chính

### 🏠 Dashboard
- Hiển thị trạng thái hệ thống tổng quan
- Thông tin chế độ hoạt động (Auto/Manual)
- Model hiện tại đang sử dụng
- Hoạt động gần đây của hệ thống

### 🔧 Quản lý Model
- Cài đặt và chọn model sản phẩm
- Thêm model mới vào hệ thống
- Cấu hình thông số kiểm tra

### 👁️ Hệ thống VRS
- **Auto VRS**: Giám sát kiểm tra tự động
- **Manual VRS**: Kiểm tra thủ công
- Điều chỉnh ánh sáng camera
- Hệ thống định vị board 4 bước

### 📊 Thống kê & Báo cáo
- Biểu đồ phân tích loại lỗi
- Tỷ lệ phán định NG
- Lựa chọn lô hàng để phân tích
- Chi tiết các loại defect

## Kiến trúc ứng dụng

### State Management
- **Provider**: Quản lý state cho navigation, authentication, VRS, và statistics
- **Hive**: Local storage cho cấu hình và dữ liệu

### Navigation
- **GoRouter**: Declarative routing với deep linking support
- **Sidebar Navigation**: Menu điều hướng với phân quyền truy cập

### Authentication
- **Worker**: Quyền vận hành cơ bản (mật khẩu: `worker`)
- **Admin**: Quyền quản trị đầy đủ (mật khẩu: `admin`)

### UI/UX
- **Material Design 3**: Giao diện hiện đại và nhất quán
- **Vietnamese Localization**: Hỗ trợ tiếng Việt đầy đủ
- **Responsive Design**: Tương thích nhiều kích thước màn hình
# Cấu trúc thư mục nguồn dự án AutoVRS

Dự án này là một ứng dụng Flutter (hiện hỗ trợ mạnh cho Desktop: Windows) với cấu trúc phân lớp dịch vụ và giao diện. 

Dưới đây là một mô tả tổng quan về các thành phần cốt lõi bên trong `lib/`:

```


c:\Code\APPAutoVRS\App\
├── lib/
│   ├── core/
│   │   ├── app_theme.dart        : Thiết lập chủ đề (Theme) Sáng/Tối.
│   │   └── routes.dart           : Định nghĩa các đường dẫn định tuyến bằng `go_router`.
│   │
│   ├── providers/                : Chứa các lớp State Management (Provider).
│   │   ├── auth_provider.dart    : Trạng thái xác thực.
│   │   ├── navigation_provider.dart : Quản lý trạng thái điều hướng (Sidebar).
│   │   ├── statistics_provider.dart: Trạng thái cho Thống kê (NGRate, Báo cáo lỗi).
│   │   └── vrs_provider.dart     : Xử lý trạng thái chính của quy trình VRS.
│   │
│   ├── screens/                  : Các màn hình giao diện (UI).
│   │   ├── alignment/            : (Board Align Screen) Căn lấp hình ảnh thực tế với Gerber.
│   │   ├── model_management/     : Thêm / Chọn Model bo mạch mẫu (Add/Select Model).
│   │   ├── statistics/           : Bảng điều khiển và Thống kê (NGRate, SelectLot, Thống kê Lỗi).
│   │   ├── vrs/                  : Cốt lõi của phần mềm - Màn hình Verify & Review System.
│   │   │   ├── light_adjust_screen.dart : Chỉnh sáng.
│   │   │   ├── manual_vrs_screen.dart   : Xác nhận thủ công các khu vực lỗi.
│   │   │   └── vrs_main_screen.dart     : Màn hình kiểm tra tổng quát (Auto-run Camera).
│   │   ├── camera_screen.dart    : Hiển thị dòng stream thuần từ camera.
│   │   ├── home_screen.dart      : Màn hình chính sau khi khởi tạo.
│   │   └── main_layout.dart      : Bộ khung UI dùng chung với Sidebar.
│   │
│   ├── services/                 : Chứa logic cốt lõi. Giao tiếp thiết bị và hệ thống bên ngoài.
│   │   ├── ai_detection_service.dart     : Gọi API nhận diện AI (thường chạy port 8082).
│   │   ├── autovrs_websocket_service.dart: Bắt luồng khung hình từ WebSocket SICK Camera (port 8999).
│   │   ├── local_database_service.dart   : Quản lý SQLite CSDL Hệ thống (Model, Lot, Board, Defect).
│   │   ├── qcamber_gerber_service.dart   : Mở, hiển thị và phân tích file Gerber.
│   │   └── video_frame_service.dart      : Lưu lại khung hình có sự cố, xử lý binary mảng Video.
│   │
│   ├── widgets/                  : Các thành phần UI có thể tái sử dụng.
│   │   ├── defect_list_widget.dart       : Thanh bên danh sách lô/board.
│   │   ├── detection_overlay_widget.dart : Vẽ hộp Bounding Box lên trên hình.
│   │   ├── gerber_image_widget.dart      : Kết xuất hình báo Gerber.
│   │   └── sidebar_navigation.dart       : Cấu tạo Nav Menu chính.
│   │
│   └── main.dart                 : Điểm vào (Entry point) của ứng dụng Flutter.
├── pubspec.yaml                  : Các dependency cài đặt (GoRouter, Provider, Hive, Sqflite_ffi,...).
└── README.md
```

## Các Dòng Chảy Chức Năng Chính

* **Giao tiếp phần cứng (Camera SICK)**: Được đẩy qua WebSocket trong `autovrs_websocket_service.dart`. Các Byte ảnh JPEG từ Socket sau đó được vẽ trên App và chụp lưu lại cục bộ.
* **Xử lý AI Detection**: Thay vì tính toán ML bên trong Flutter, hệ thống gọi HTTP Post Base64 ảnh lên AI Backend qua `ai_detection_service.dart`.
* **Database (DB)**: Mọi log kiểm tra phân cấp Model -> Lot -> Board -> Defect được lưu vào `autovrs.db` cục bộ trong Documents của User. Logic nằm tại `local_database_service.dart`. 

## Cài đặt và chạy

### Yêu cầu hệ thống
- Flutter SDK 3.32.7+
- Dart 3.8.1+
- Windows 10+ (cho desktop app)

### Cài đặt dependencies
```bash
flutter pub get
```

### Chạy ứng dụng
```bash
# Desktop (Windows)
flutter run -d windows

# Web
flutter run -d chrome

# Mobile (nếu có thiết bị/emulator)
flutter run
```

### Build production
```bash
# Windows desktop
flutter build windows

# Web
flutter build web

# Android APK
flutter build apk
```

## Sử dụng

### Đăng nhập
1. Mở ứng dụng
2. Click vào icon user ở góc phải top bar
3. Chọn "Đăng nhập Worker" hoặc "Đăng nhập Admin"
4. Nhập mật khẩu tương ứng

### Điều hướng
- Sử dụng sidebar menu để di chuyển giữa các chức năng
- Nút "Quay lại" trong top bar để trở về màn hình trước
- Các chức năng có biểu tượng khóa yêu cầu đăng nhập

### Tính năng đặc biệt
- **Real-time clock**: Hiển thị thời gian hiện tại
- **Password protection**: Bảo mật theo từng cấp độ user
- **Visual feedback**: Icons và màu sắc trực quan cho trạng thái
- **Responsive layout**: Tự động điều chỉnh theo kích thước màn hình

## Phát triển

### Thêm màn hình mới
1. Tạo file trong thư mục `screens/`
2. Thêm route trong `core/routes.dart`
3. Cập nhật navigation menu trong `widgets/sidebar_navigation.dart`

### Thêm provider mới
1. Tạo class extends `ChangeNotifier` trong `providers/`
2. Đăng ký trong `main.dart` với `MultiProvider`

### Customization
- Theme colors: `core/app_theme.dart`
- Localization: `l10n/` directory
- Icons: `flutter_feather_icons` package

## Roadmap

- [ ] Hoàn thiện các màn hình VRS
- [ ] Tích hợp camera feed thực tế  
- [ ] Kết nối database backend
- [ ] Export báo cáo PDF/Excel
- [ ] Multi-language support
- [ ] Dark theme support
- [ ] Notification system

## Support

Dự án được phát triển bởi **Meiko Automation** - 2025

Để báo cáo lỗi hoặc yêu cầu tính năng mới, vui lòng tạo issue trong repository này.
