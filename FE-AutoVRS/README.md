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

## Cấu trúc dự án

```
lib/
├── core/
│   ├── app_theme.dart      # Theme và màu sắc
│   └── routes.dart         # Cấu hình routing
├── models/                 # Data models
├── providers/              # State management
│   ├── auth_provider.dart
│   ├── navigation_provider.dart
│   ├── vrs_provider.dart
│   └── statistics_provider.dart
├── screens/                # Màn hình ứng dụng
│   ├── home_screen.dart
│   ├── main_layout.dart
│   ├── alignment/
│   ├── model_management/
│   ├── statistics/
│   └── vrs/
├── widgets/                # Reusable widgets
│   ├── sidebar_navigation.dart
│   └── password_dialog.dart
└── main.dart              # Entry point
```

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
