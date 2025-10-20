# 🚀 Quick Reference - AutoVRS System

## 📌 Key Ports

| Port | Service | Use Case |
|------|---------|----------|
| **8686** | QCamber REST | PCB imaging, capture specific layers |
| **8081** | Video Frame Stream | Video streaming (WebSocket) |
| **8082** | AI Detection | YOLOv11 defect detection (REST POST) |
| **12345** | AutoVRS WebSocket | Real-time video + detection results |
| **8000** | Backend API (legacy) | General API endpoints |

---

## 💻 Main Components

### Frontend (Flutter)

**Language**: Dart  
**Framework**: Flutter 3.8.1+  
**State Management**: Provider  
**Real-time**: WebSocket + HTTP

**Key Files**:
- `lib/main.dart` - App entry point
- `lib/providers/vrs_provider.dart` - System state
- `lib/services/autovrs_websocket_service.dart` - WebSocket
- `lib/services/ai_detection_service.dart` - AI API calls
- `lib/screens/vrs/manual_vrs_screen.dart` - Main inspection screen

### Backend (Python)

**AI Model**: YOLOv11  
**REST Framework**: Flask/FastAPI  
**WebSocket**: asyncio-based  
**Database**: SQLite (local) + MySQL/PostgreSQL (remote possible)

**Key Endpoints**:
```
POST   /api/capture              → QCamber (8686)
POST   /api/ai-detection         → AI Service (8082)
GET    /api/status               → QCamber (8686)
WS     /ws/{clientId}            → AutoVRS (12345)
```

---

## 🔌 Service Communication Matrix

```
┌──────────────┬────────────────────┬────────────┬──────────────┐
│ From         │ To                 │ Protocol   │ Port         │
├──────────────┼────────────────────┼────────────┼──────────────┤
│ Flutter      │ QCamber            │ HTTP POST  │ 8686         │
│ Flutter      │ AutoVRS            │ WebSocket  │ 12345        │
│ Flutter      │ AI Detection       │ HTTP POST  │ 8082         │
│ Jupyter NB   │ QCamber            │ HTTP POST  │ 8686         │
│ AutoVRS      │ Flutter            │ WebSocket  │ 12345        │
│ AI Service   │ Flutter            │ HTTP POST  │ 8082         │
└──────────────┴────────────────────┴────────────┴──────────────┘
```

---

## 📊 Providers (State Management)

### VRSProvider
```dart
// System state
String systemStatus
bool isAutoMode
String currentModel
String currentModelName

// Counters
int totalCount, okCount, ngCount
double ngRate

// Settings
double magnification (zoom)
double lightLevel

// Alignment
List<Map> alignmentPoints
int currentAlignmentStep

// Methods
setCurrentModel(id)
toggleMode()
setMagnification(value)
incrementCount(isOK)
```

### AutoVRSWebSocketService
```dart
// Connection
Future<bool> connect(serverUrl, clientId)
Future<void> disconnect()

// Data
Uint8List? currentFrame
Uint8List? capturedImage
bool isViewingCapturedImage

// Detection
Map<String, dynamic>? lastDetectionResults
List<DefectDetection>? detections

// Methods
void requestCapture(timestamp)
void returnToLiveCamera()
```

### AIDetectionService
```dart
// Methods
Future<AIDetectionResult?> detectDefects(
  imageData,
  confidenceThreshold = 0.25,
  iouThreshold = 0.1
)

// Results
AIDetectionResult? lastResult
bool isLoading
String? lastError
```

---

## 📱 Screen Navigation

```
GoRouter(
  '/'                     → HomeScreen
  '/select-model'         → SelectModelScreen
  '/add-model'            → AddModelScreen
  '/vrs-main'             → VRSMainScreen
  '/manual-vrs'           → ManualVRSScreen ⭐ (Main inspection)
  '/light-adjust'         → LightAdjustScreen
  '/board-align/:step'    → BoardAlignScreen
  '/statistics'           → StatisticsScreen
  '/ng-rate'              → NGRateScreen
  '/camera'               → CameraScreen
)
```

---

## 🗄️ Database Tables

### tbModel (AI Models)
```sql
id_model, name, line_size, space_size, url_gerber
```

### tbLot (Batches)
```sql
id_lot, NG_rate, fakeDef, board_quantity, tbModelid_model
```

### tbBoard (PCBs)
```sql
id_board, defect_quantity, erro_quantity, tbLotid_lot
```

### tbDefect (Detected Defects)
```sql
id_defect, type, judgement, height, width, time, 
coordinates, url_image, tbBoardid_board
```

### tbConfig (Settings)
```sql
config_key, config_value
```

---

## 🔐 Authentication

```dart
// Passwords
"worker"  → Worker access
"admin"   → Admin access (includes worker)

AuthProvider methods:
- authenticateWorker(password)
- authenticateAdmin(password)
- logout()
- canAccessFeature(requiredRole)
```

---

## 📦 Testing & Notebooks

### TestRestAPI.ipynb (Python Jupyter Notebook)

**Purpose**: Test QCamber REST API (Port 8686)

**Main Class**: `QCamberAPI`

**Key Methods**:
```python
api = QCamberAPI("http://localhost:8686")

# Check if server is running
api.is_server_running()

# Get server status
api.check_status()

# Capture PCB with image
metadata, image = api.capture_pcb_with_image(
    job_name="tgz2",
    layer_name="l2",
    x=1.5, y=2.0,
    zoom=128.0
)

# Diagnose connection
diagnose_connection()
```

---

## 🎯 Typical Workflow

### 1️⃣ App Startup
```
main() 
  → Initialize database
  → Setup Hive storage
  → Create MultiProvider
  → Auto-connect to WebSocket
  → Show MainLayout/HomeScreen
```

### 2️⃣ Select Model
```
HomeScreen
  → Select model from list
  → VRSProvider.setCurrentModel(modelId)
  → Load associated lots
  → Navigate to VRSMainScreen
```

### 3️⃣ Manual Inspection (Main Flow)
```
ManualVRSScreen
  → Connect to WebSocket (12345)
  → Receive live frames
  → Display current frame
  → Show defect list from database
  → User clicks "Chụp lại"
    ├─ Extract current frame
    ├─ Send to AI Detection (8082)
    ├─ Receive results with bbox
    └─ Display processed image
  → User confirms OK/NG
  → Save to database
  → Move to next defect
```

### 4️⃣ Capture from QCamber (Python Notebook)
```
Jupyter TestRestAPI.ipynb
  → api.is_server_running()  # Check 8686
  → api.check_status()
  → api.capture_pcb_with_image(...)
    ├─ POST to /api/capture
    ├─ Receive PNG image
    └─ Display with matplotlib
```

---

## 🔄 Key Data Flows

### Flow 1: Live Video
```
AutoVRS (12345) 
  → Binary JPEG frames (every ~33ms)
  → WebSocketService._currentFrame
  → ValueNotifier UI update
  → Display on screen
```

### Flow 2: Capture & Detection
```
User action
  → Get frame from WebSocket
  → Convert to Base64
  → POST to AI Detection (8082)
  → Receive AIDetectionResult
  → Draw boxes on image
  → Display + await user judgment
  → Save to database
```

### Flow 3: PCB Imaging
```
Jupyter notebook
  → HTTP POST to QCamber (8686)
  → QCamber controls hardware
  → Capture image at coordinates
  → Return PNG image
  → Save/display locally
```

---

## 📁 File Structure

```
App/
├── lib/
│   ├── main.dart                           # Entry point
│   ├── core/
│   │   ├── app_theme.dart                 # UI theme
│   │   └── routes.dart                    # Navigation
│   ├── providers/
│   │   ├── vrs_provider.dart              # ⭐ Main state
│   │   ├── auth_provider.dart
│   │   └── ...
│   ├── services/
│   │   ├── autovrs_websocket_service.dart # ⭐ Video stream
│   │   ├── ai_detection_service.dart      # ⭐ AI API
│   │   ├── local_database_service.dart    # ⭐ Database
│   │   └── ...
│   ├── screens/
│   │   ├── vrs/
│   │   │   └── manual_vrs_screen.dart     # ⭐ Main screen
│   │   └── ...
│   └── widgets/
│       └── ...
├── pubspec.yaml                            # Dependencies
└── ... (platform-specific folders)

BE-AutoVRS/
├── TestRestAPI.ipynb                       # ⭐ Test notebook
├── ai_detection_api.py                    # AI server
├── run_ai_api.py
├── models/
│   ├── best.onnx                          # YOLOv11 ONNX
│   ├── best.pt
│   └── multi.*
└── ... (Python backend)
```

---

## ⚙️ Configuration

### VRSProvider Config Keys (SQLite tbConfig)
```
"system_status"   : "OK" | "NG" | "Error"
"system_mode"     : "auto" | "manual"
"current_model"   : "1" (model ID)
"magnification"   : "140.0"
"light_level"     : "50.0"
```

### API Base URLs (Flutter)
```dart
// apiService.dart
ApiService.baseUrl = "http://localhost:8000"  # Default (not commonly used)

// Individual services use hardcoded URLs:
AutoVRSWebSocketService    → ws://127.0.0.1:12345/
AIDetectionService         → http://localhost:8082
```

### Storage Paths
```
Windows: C:\Users\{user}\Documents\AutoVRS\autovrs.db
Linux:   ~/.local/share/
macOS:   ~/Library/Application Support/

Images: C:/Users/sonng/Desktop/APPAutoVRS/BE-AutoVRS/images_ai/
```

---

## 🎓 Class Relationships

```
┌─────────────────────────────────────────┐
│ MultiProvider (main.dart)               │
├─────────────────────────────────────────┤
│ ├─ VRSProvider                          │
│ │  └─ LocalDatabaseService              │
│ ├─ AutoVRSWebSocketService              │
│ │  └─ WebSocketChannel (12345)          │
│ ├─ AIDetectionService                   │
│ │  └─ HTTP Client → http://localhost:8082
│ ├─ NavigationProvider                   │
│ ├─ AuthProvider                         │
│ └─ ...                                  │
└─────────────────────────────────────────┘
         │
         ▼
   Consumer Widgets
         │
         ▼
   Manual VRS Screen
```

---

## 🐛 Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| No video | WebSocket not connected | Check port 12345, restart AutoVRS |
| AI detection fails | Port 8082 not running | Start AI service, check Python backend |
| Database locked | Multiple connections | Restart app, check file permissions |
| QCamber returns 404 | Wrong job/layer name | Verify job is open in QCamber |
| Image capture timeout | QCamber busy | Increase timeout, close other jobs |
| Hive initialization fails | Windows path issue | App handles gracefully, continues |

---

## 📊 Performance Tips

1. **WebSocket Optimization**
   - Use `ValueNotifier` for frame updates
   - Notify listeners only every N frames
   - Release old frames to save memory

2. **Database**
   - Use singleton pattern (LocalDatabaseService)
   - Cache queries when possible
   - Batch inserts for multiple records

3. **UI**
   - Lazy load large lists
   - Use `gaplessPlayback: true` for video
   - Minimize repaints with Consumer

4. **AI Detection**
   - Resize images if too large
   - Adjust confidence threshold (0.25 default)
   - Cache processed images

---

## 🔍 Debugging

```bash
# Enable Flutter debug logging
flutter run -v

# Check port availability (Windows PowerShell)
netstat -ano | findstr 8686
netstat -ano | findstr 12345
netstat -ano | findstr 8082

# Python backend logs
tail -f server.log

# SQLite query
sqlite3 "C:\Users\{user}\Documents\AutoVRS\autovrs.db"
SELECT * FROM tbDefect;
SELECT * FROM tbBoard;
```

---

## 📚 Key Dependencies

```yaml
provider: ^6.1.2              # State management
go_router: ^14.6.1            # Navigation
web_socket_channel: ^2.4.0    # WebSocket
http: ^1.2.2                  # HTTP client
sqflite: ^2.3.3               # SQLite
camera: ^0.10.6               # Camera
fl_chart: ^0.69.2             # Charts
```

---

**Last Updated**: October 20, 2025  
**Version**: 1.0  
**Author**: GitHub Copilot
