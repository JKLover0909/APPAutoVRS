# 📋 Phân Tích Kiến Trúc AutoVRS - Flutter App & Python Backend

## 📑 Mục Lục
1. [Tổng Quan](#tổng-quan)
2. [Kiến Trúc Flutter App](#kiến-trúc-flutter-app)
3. [Backend Services](#backend-services)
4. [API Communication Flow](#api-communication-flow)
5. [Data Models & Database](#data-models--database)
6. [Key Services & Providers](#key-services--providers)

---

## 🎯 Tổng Quan

### AutoVRS System
- **AutoVRS** = Automatic Visual Recognition System (Hệ thống kiểm tra tự động dựa trên hình ảnh)
- **Mục đích**: Kiểm tra PCB tự động, phát hiện lỗi bằng AI
- **Backend**: Python-based (AI Detection, WebSocket, REST API)
- **Frontend**: Flutter cross-platform (Windows, iOS, Android, Linux, macOS)

### Tech Stack
- Check out C++
#### Frontend (Flutter)
```
✅ State Management: Provider (MVVM-style)
✅ Navigation: GoRouter
✅ UI Framework: Material Design 3
✅ Realtime Communication: WebSocket + HTTP
✅ Local Storage: SQLite + Hive
✅ Camera: camera plugin + image_picker
✅ Visualization: fl_chart (charts)
```

#### Backend (Python)
```
✅ Web Framework: Flask/FastAPI (8686 port - QCamber)
✅ WebSocket Server: (Port 12345 - AutoVRS)
✅ Video Streaming: (Port 8081 - VideoFrame Service)
✅ AI Detection: (Port 8082 - AI Detection API)
✅ AI Model: YOLOv11 (.onnx, .pt)
```

---

## 🏗️ Kiến Trúc Flutter App

### 📁 Folder Structure
```
App/
├── lib/
│   ├── main.dart                          # App Entry Point
│   ├── core/
│   │   ├── app_theme.dart                # Light/Dark Theme
│   │   ├── routes.dart                   # GoRouter Navigation
│   │   └── routes_new.dart               # Alternative routes
│   ├── models/                            # Data models
│   ├── providers/                         # State Management (Provider)
│   │   ├── api_service.dart              # Base URL config
│   │   ├── auth_provider.dart            # Authentication
│   │   ├── navigation_provider.dart      # Navigation state
│   │   ├── vrs_provider.dart             # VRS system state
│   │   └── statistics_provider.dart      # Statistics
│   ├── services/                          # Business Logic
│   │   ├── autovrs_websocket_service.dart   # WebSocket to AutoVRS (12345)
│   │   ├── ai_detection_service.dart       # HTTP to AI API (8082)
│   │   ├── video_frame_service.dart        # WebSocket Video Stream (8081)
│   │   ├── local_database_service.dart     # SQLite Database
│   │   ├── flutter_camera_service.dart     # Camera control
│   │   └── logging.dart                    # Logging utility
│   ├── screens/                           # UI Screens
│   │   ├── main_layout.dart              # Main Layout
│   │   ├── home_screen.dart              # Home Screen
│   │   ├── camera_screen.dart            # Camera View
│   │   ├── vrs/
│   │   │   ├── vrs_main_screen.dart      # Main VRS
│   │   │   ├── manual_vrs_screen.dart    # Manual inspection
│   │   │   ├── light_adjust_screen.dart  # Light settings
│   │   │   └── ...
│   │   ├── model_management/             # Model management screens
│   │   ├── statistics/                   # Statistics screens
│   │   ├── alignment/                    # Board alignment screens
│   │   └── ...
│   └── widgets/                           # Reusable widgets
├── pubspec.yaml                           # Dependencies
├── android/                               # Android build files
├── ios/                                   # iOS build files
├── windows/                               # Windows build files
├── linux/                                 # Linux build files
├── macos/                                 # macOS build files
└── web/                                   # Web build files
```

### 📱 App Entry Point

```dart
// main.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Platform-specific initialization
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize Hive (local storage)
  await Hive.initFlutter();
  
  // Initialize Database
  final dbService = LocalDatabaseService();
  await dbService.database;
  
  runApp(const AutoVRSApp());
}

class AutoVRSApp extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // State Management Providers
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VRSProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        
        // Services Providers
        ChangeNotifierProvider(create: (_) => FlutterCameraService()),
        ChangeNotifierProvider(
          create: (_) {
            final svc = AutoVRSWebSocketService();
            svc.connect(); // Auto-connect on app start
            return svc;
          },
        ),
        ChangeNotifierProvider(create: (_) => AIDetectionService()),
      ],
      child: MaterialApp.router(
        title: 'AutoVRS - Hệ thống kiểm tra tự động',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        routerConfig: AppRoutes.router,
        locale: const Locale('vi', 'VN'),
      ),
    );
  }
}
```

---

## 🌐 Backend Services

### 1. **QCamber REST API** (Port 8686)
- **Loại**: REST API
- **Mục đích**: Kiểm soát khi quay PCB, chụp ảnh
- **Endpoints**:
  - `POST /api/capture` - Chụp ảnh PCB tại vị trí cụ thể
  - `GET /api/status` - Kiểm tra trạng thái server

### 2. **AutoVRS WebSocket Server** (Port 12345)
- **Loại**: WebSocket Real-time
- **Mục đích**: Gửi frame video live, nhận detection results
- **Message Types**:
  - `connection` - Thông tin camera (serial, sensor)
  - `video_frame` - JPEG frame data
  - `capture_response` - Response capture request
  - `ai_detection` - AI detection results
  - `camera_status` - Camera status

### 3. **Video Frame Streaming** (Port 8081)
- **Loại**: WebSocket
- **Mục đích**: Stream video từ camera
- **Data**: Base64-encoded JPEG frames

### 4. **AI Detection API** (Port 8082)
- **Loại**: REST API + HTTP POST
- **Mục đình**: YOLOv11-based defect detection
- **Endpoint**: `POST /api/ai-detection`
- **Request Body**:
  ```json
  {
    "image_base64": "...",
    "confidence_threshold": 0.25,
    "iou_threshold": 0.1
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "detections": [
      {
        "bbox": [x1, y1, x2, y2],
        "confidence": 0.95,
        "class_id": 0,
        "class_name": "solder_joint",
        "class_name_vi": "chỗ hàn",
        "coordinates": {"x": 100, "y": 200}
      }
    ],
    "statistics": {...},
    "processed_image_base64": "..."
  }
  ```

---

## 🔄 API Communication Flow

### Flow 1: Chụp Ảnh PCB từ QCamber

```
[Flutter App]
    ↓
    │ HTTP POST /api/capture
    │ {jobName, layerName, x, y, zoom}
    ↓
[QCamber Server (Port 8686)]
    ↓
    │ Kiểm soát khi quay PCB
    │ Chụp ảnh tại vị trí (x, y) với zoom level
    ↓
[Returns PNG Image]
    ↓
[Flutter App]
    ├─→ Lưu vào thư mục
    └─→ Hiển thị trên UI
```

**Python Notebook (TestRestAPI.ipynb) Flow**:

```python
# 1. Initialize QCamber API Client
api = QCamberAPI("http://localhost:8686")

# 2. Check server status
status = api.check_status()  # GET /api/status

# 3. Capture PCB with image
metadata, image = api.capture_pcb_with_image(
    job_name="tgz2",
    layer_name="l2",
    x=1.5, y=2.0,
    zoom=128.0,
    timeout=30
)

# 4. Handle Response
if image:
    # image is PIL.Image object
    image.save("output.png")
    display_image(image)
else:
    print(f"Error: {metadata.get('error')}")
```

### Flow 2: Realtime Video Streaming

```
[AutoVRS WebSocket Server (Port 12345)]
    ↓
    │ WebSocket stream (frame every ~33ms @ 30fps)
    │ Binary: JPEG frame data (typically 50-150KB)
    ↓
[Flutter App - AutoVRSWebSocketService]
    ├─→ Receive binary frame
    ├─→ Store in _currentFrame
    └─→ Update UI with ValueNotifier
         └→ Display on VideoStreamWidget
```

### Flow 3: AI Detection Pipeline

```
[Flutter App - Live Frame]
    ↓
    │ Extract current frame
    │ Convert to base64
    ↓
[Python AI Detection Service (Port 8082)]
    │ Receive: {image_base64, confidence_threshold, iou_threshold}
    ↓
    │ YOLOv11 inference
    │ Postprocessing (NMS, confidence filtering)
    ↓
[Returns JSON]
    ├─→ detections[] with bounding boxes
    ├─→ statistics (total count, OK/NG rate)
    └─→ processed_image_base64 (with boxes drawn)
    ↓
[Flutter App - AIDetectionService]
    ├─→ Parse response to AIDetectionResult
    ├─→ Store defections
    └─→ Save processed image locally
         └→ "C:/...Desktop/APPAutoVRS/BE-AutoVRS/images_ai"
```

---

## 💾 Data Models & Database

### SQLite Schema (Local Database)

```sql
-- Models (AI Models cho inspection)
CREATE TABLE tbModel (
    id_model INTEGER PRIMARY KEY,
    name TEXT,
    line_size REAL,
    space_size REAL,
    url_gerber TEXT
);

-- Lots (Batch/Lô hàng)
CREATE TABLE tbLot (
    id_lot INTEGER PRIMARY KEY,
    NG_rate REAL,
    fakeDef REAL,
    board_quantity INTEGER,
    tbModelid_model INTEGER,
    FOREIGN KEY (tbModelid_model) REFERENCES tbModel(id_model)
);

-- Boards (PCB)
CREATE TABLE tbBoard (
    id_board INTEGER PRIMARY KEY,
    defect_quantity INTEGER,
    erro_quantity INTEGER,
    tbLotid_lot INTEGER,
    FOREIGN KEY (tbLotid_lot) REFERENCES tbLot(id_lot)
);

-- Defects (Lỗi được phát hiện)
CREATE TABLE tbDefect (
    id_defect INTEGER PRIMARY KEY,
    type TEXT,                    -- Loại lỗi (short, open, etc)
    judgement TEXT,               -- Đánh giá (OK, NG)
    height REAL,
    width REAL,
    time TEXT,
    coordinates TEXT,             -- JSON: {"x": 100, "y": 200}
    url_image INTEGER,            -- Đường dẫn ảnh
    tbBoardid_board INTEGER,
    FOREIGN KEY (tbBoardid_board) REFERENCES tbBoard(id_board)
);

-- Configuration
CREATE TABLE tbConfig (
    config_key TEXT PRIMARY KEY,
    config_value TEXT
);
```

### Key Configuration Keys
```
- system_status: "OK", "NG", "Error"
- system_mode: "auto", "manual"
- current_model: id_model
- magnification: 140.0 (zoom level)
- light_level: 50.0 (camera light)
```

---

## 🔧 Key Services & Providers

### 1. **VRSProvider** (State Management)

```dart
class VRSProvider extends ChangeNotifier {
  // System Status
  String _systemStatus = 'Loading...';
  bool _isAutoMode = true;
  
  // Current Context
  String _currentModel = '';
  String _currentLot = '';
  String _currentBoard = '';
  
  // Statistics
  int _totalCount = 0;
  int _okCount = 0;
  int _ngCount = 0;
  double get ngRate => (_ngCount / _totalCount) * 100;
  
  // Camera Settings
  double _magnification = 140.0;
  double _lightLevel = 50.0;
  
  // Alignment
  List<Map<String, dynamic>> _alignmentPoints = [];
  int _currentAlignmentStep = 1;
  
  // Methods
  setCurrentModel(String modelId)
  toggleMode()  // Auto ↔ Manual
  setMagnification(double value)
  setLightLevel(double value)
  incrementCount(bool isOK)
}
```

### 2. **AutoVRSWebSocketService** (Real-time Video)

```dart
class AutoVRSWebSocketService extends ChangeNotifier {
  // Connection
  Future<bool> connect({String serverUrl, String clientId})
  Future<void> disconnect()
  
  // Current Frame
  Uint8List? get currentFrame
  ValueNotifier<Uint8List?> get currentFrameNotifier  // for optimized UI updates
  
  // Detection Results
  Map<String, dynamic>? get lastDetectionResults
  List<Map<String, dynamic>>? get detections
  
  // Captured Image
  void setCapturedImage(Uint8List image)
  void setViewingCapturedImage(bool viewing)
  
  // Methods
  void requestCapture({required int timestamp})
  void returnToLiveCamera()
}
```

### 3. **AIDetectionService** (AI Detection API)

```dart
class AIDetectionService extends ChangeNotifier {
  Future<AIDetectionResult?> detectDefects({
    required Uint8List imageData,
    double confidenceThreshold = 0.25,
    double iouThreshold = 0.1,
  })
  
  // Results
  AIDetectionResult? get lastResult
  bool get isLoading
  String? get lastError
}

class AIDetectionResult {
  final bool success;
  final List<DefectDetection> detections;
  final Uint8List? processedImage;
  final Map<String, dynamic> statistics;
}

class DefectDetection {
  final List<int> bbox;          // [x1, y1, x2, y2]
  final double confidence;       // 0.0 - 1.0
  final int classId;
  final String className;        // English
  final String classNameVi;      // Vietnamese
  final Map<String, int> coordinates;  // Center point
}
```

### 4. **LocalDatabaseService** (SQLite)

```dart
class LocalDatabaseService {
  // Model operations
  Future<List<Map>> getAllModels()
  Future<Map?> getModelById(int id)
  Future<int> insertModel(Map model)
  Future<int> deleteModel(int id)
  
  // Lot operations
  Future<List<Map>> getLotsByModel(int modelId)
  Future<Map?> getFirstLotByModelId(String modelId)
  
  // Board operations
  Future<List<Map>> getAllBoards()
  Future<List<Map>> getFirstBoardByLotId(String lotId)
  
  // Defect operations
  Future<List<Map>> getDefectsByBoard(int boardId)
  Future<int> insertDefect(Map defect)
  
  // Config operations
  Future<String?> getConfigValue(String key)
  Future<void> updateConfig(String key, String value)
}
```

### 5. **VideoFrameService** (Video Streaming)

```dart
class VideoFrameService extends ChangeNotifier {
  Future<bool> connect({String? customUrl})
  void disconnect()
  
  Uint8List? get currentFrame
  bool get isConnected
  int get frameId
  int get videoWidth
  int get videoHeight
  double get videoFps
  int get framesReceived
}
```

---

## 🎬 Manual VRS Screen Flow

### Manual Inspection Screen (`manual_vrs_screen.dart`)

**Mục đích**: Kiểm tra thủ công từng khiếm khuyết

```
[ManualVRSScreen - State]
├─ _defects: List<Map> (loaded from database)
├─ _currentDefectIndex: int
├─ _isAnalyzing: bool
├─ _hasAnalysisResult: bool
├─ _analysisResult: AIDetectionResult?
└─ _selectedVideoSource: int (0=AutoVRS, 1=VideoStream)

[Main UI Layout]
├─ Live Camera Stream (from AutoVRSWebSocketService)
│  └─ Display _currentFrame from WebSocket
├─ Defects List Panel
│  ├─ Current Defect Details
│  ├─ Navigate Prev/Next
│  └─ Show Coordinates, Type, etc.
├─ Action Buttons
│  ├─ "Chụp lại" (Capture & Analyze)
│  ├─ "Phóng to" (Zoom)
│  ├─ "OK/NG" (Judgement)
│  └─ "Lưu" (Save)
└─ AI Detection Panel
   ├─ Detection Results (bboxes, confidence)
   ├─ Classification
   └─ Processed Image (with boxes)

[Capture & Analysis Flow]
1. User clicks "Chụp lại"
2. Get current frame from AutoVRSWebSocketService
3. Send to AI Detection API (port 8082)
4. Receive AIDetectionResult
5. Display processed image with boxes
6. User confirms OK/NG
7. Save to database (tbDefect)
8. Move to next defect
```

---

## 🔌 Communication Ports Summary

| Port | Service | Type | Purpose |
|------|---------|------|---------|
| 8000 | Backend API | REST | Legacy/General API |
| 8081 | Video Frame | WebSocket | Video streaming |
| 8082 | AI Detection | HTTP REST | YOLOv11 detection |
| 8686 | QCamber | REST API | PCB imaging/control |
| 12345 | AutoVRS | WebSocket | Real-time video + detection |

---

## 📊 Authentication

### AuthProvider
```dart
// Passwords:
// - Worker: "worker" password
// - Admin: "admin" password

authenticateWorker(String password)  // "worker" or "admin"
authenticateAdmin(String password)   // only "admin"
```

---

## 📂 File Storage

### Local Paths
- **Database**: `C:\Users\{user}\Documents\AutoVRS\autovrs.db`
- **Processed Images**: `C:/Users/sonng/Desktop/APPAutoVRS/BE-AutoVRS/images_ai/`
- **Hive Storage**: `{app_directory}/hive_data/`

---

## 🎨 Navigation Routes

```dart
GoRoute(path: '/', name: 'home')              // Home
GoRoute(path: '/select-model')                // Select Model
GoRoute(path: '/vrs-main')                    // VRS Main
GoRoute(path: '/manual-vrs')                  // Manual Inspection
GoRoute(path: '/light-adjust')                // Light Settings
GoRoute(path: '/board-align/:step')           // Board Alignment
GoRoute(path: '/statistics')                  // Statistics
GoRoute(path: '/camera')                      // Camera
```

---

## 🚀 Key Dependencies

**pubspec.yaml**:
```yaml
# State Management
provider: ^6.1.2

# Navigation
go_router: ^14.6.1

# WebSocket
web_socket_channel: ^2.4.0

# HTTP
http: ^1.2.2

# Camera
camera: ^0.10.6
image_picker: ^1.1.2

# Database
sqflite: ^2.3.3
hive_flutter: ^1.1.0

# UI
fl_chart: ^0.69.2
flutter_feather_icons: ^2.0.0+1

# Storage
shared_preferences: ^2.3.2
```

---

## 📝 TestRestAPI.ipynb Analysis

### QCamberAPI Client (Python)

```python
class QCamberAPI:
    def __init__(self, base_url="http://localhost:8686"):
        self.base_url = base_url
        self.session = requests.Session()
    
    def check_status(self):
        """GET /api/status"""
        
    def capture_pcb(self, job_name, layer_name, x=0, y=0, zoom=1.0):
        """POST /api/capture - Just request, no image returned"""
        
    def capture_pcb_with_image(self, job_name, layer_name, x=0, y=0, zoom=1.0, timeout=30):
        """
        POST /api/capture - Returns image
        
        Returns: (metadata: dict, image: PIL.Image | None)
        """
        
    def is_server_running(self):
        """Check if server on port 8686 is accessible"""

# Usage
api = QCamberAPI()

# Test server
status = api.check_status()

# Capture specific layer with coordinates
metadata, image = api.capture_pcb_with_image(
    job_name="tgz2",
    layer_name="l2",
    x=1.5, y=2.0,
    zoom=128.0
)

if image:
    print(f"✅ Image: {image.size}")
    plt.imshow(image)
    plt.show()
else:
    print(f"❌ Error: {metadata.get('error')}")
```

### Diagnostic Features

```python
def diagnose_connection():
    """Chẩn đoán vấn đề kết nối"""
    # 1. Check if port 8686 is open
    # 2. Check HTTP response
    # 3. Check JSON parsing
    # 4. Suggest solutions
```

---

## 🎯 Summary

### Frontend (Flutter)
- ✅ **Multi-platform**: Windows, iOS, Android, Linux, macOS
- ✅ **Real-time**: WebSocket for live video streaming
- ✅ **AI Integration**: Sends frames to Python AI backend
- ✅ **Local Storage**: SQLite database for models, lots, boards, defects
- ✅ **State Management**: Provider for reactive UI
- ✅ **Manual Inspection**: Screen for reviewing defects one-by-one

### Backend (Python)
- ✅ **QCamber API**: Control PCB imaging hardware
- ✅ **AutoVRS WebSocket**: Real-time video streaming
- ✅ **AI Detection**: YOLOv11-based defect detection
- ✅ **REST APIs**: Standard HTTP endpoints

### Integration
- ✅ **Jupyter Notebook (TestRestAPI.ipynb)**: Testing QCamber REST API
- ✅ **QCamberAPI Client**: Python helper class for API interactions
- ✅ **Error Handling**: Comprehensive diagnostics and troubleshooting

---

**Last Updated**: October 20, 2025
**Documented By**: GitHub Copilot
