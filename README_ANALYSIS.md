# 📖 AutoVRS System - Complete Analysis & Documentation

## 📋 What Has Been Analyzed

This documentation covers a comprehensive analysis of the **AutoVRS** (Automatic Visual Recognition System) project, including:

1. **Flutter Frontend Application** - Cross-platform UI for PCB inspection
2. **Python Backend Services** - AI detection, WebSocket streaming, hardware control
3. **API Communication** - REST APIs and WebSocket protocols
4. **Database Layer** - SQLite local storage with MVVM pattern
5. **Testing & Validation** - Jupyter Notebook for API testing

---

## 🎯 Project Overview

**AutoVRS** is an automated PCB (Printed Circuit Board) visual inspection system that:

- ✅ Captures PCB images from hardware (via QCamber)
- ✅ Streams live video via WebSocket
- ✅ Detects defects using YOLOv11 AI model
- ✅ Displays results in Flutter UI (Windows, iOS, Android, Linux, macOS)
- ✅ Stores inspection history in SQLite database
- ✅ Supports manual and automatic inspection modes

---

## 📂 Documentation Files Created

### 1. **ARCHITECTURE_ANALYSIS.md** (Comprehensive)
Complete architecture breakdown covering:
- Technology stack (Flutter + Python)
- Folder structure
- App entry point & lifecycle
- Backend services (QCamber, AutoVRS WebSocket, AI Detection)
- Database schema & relationships
- Key services & providers
- Manual VRS screen workflow
- Dependencies and authentication

**Best for**: Understanding overall system design

---

### 2. **API_FLOW_DETAILED.md** (Technical Deep-Dive)
Detailed API communication flows with diagrams:
- QCamber REST API (Port 8686) - PCB capture
- AutoVRS WebSocket (Port 12345) - Video streaming
- AI Detection API (Port 8082) - Defect detection
- Manual VRS integration
- Database integration
- Step-by-step workflows with ASCII diagrams

**Best for**: Understanding data flows & debugging

---

### 3. **QUICK_REFERENCE.md** (Quick Lookup)
Quick reference guide for quick lookups:
- Key ports and services
- Service communication matrix
- Provider methods and properties
- Database tables schema
- Screen navigation routes
- Typical workflow steps
- Common issues & solutions
- Performance tips

**Best for**: Quick lookups during development

---

## 🏗️ System Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Multi-platform)            │
├────────────────────────────────────────────────────────────┤
│  UI Layer                                                  │
│  ├─ ManualVRSScreen (Main inspection screen)              │
│  ├─ HomeScreen, StatisticsScreen, etc.                    │
│  └─ Navigation: GoRouter                                  │
│                                                            │
│  State Management (Provider)                              │
│  ├─ VRSProvider (system state)                           │
│  ├─ AuthProvider (authentication)                        │
│  ├─ NavigationProvider (routing state)                   │
│  └─ StatisticsProvider                                   │
│                                                            │
│  Services Layer                                           │
│  ├─ AutoVRSWebSocketService → Port 12345 (Video)        │
│  ├─ AIDetectionService → Port 8082 (AI API)             │
│  ├─ LocalDatabaseService (SQLite)                       │
│  ├─ FlutterCameraService                               │
│  └─ VideoFrameService                                   │
│                                                            │
│  Local Storage                                            │
│  ├─ SQLite Database (autovrs.db)                        │
│  └─ Hive Storage (key-value)                            │
└────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  QCamber API     │  │  AutoVRS WS      │  │  AI Detection    │
│  Port 8686       │  │  Port 12345      │  │  Port 8082       │
│  REST HTTP       │  │  WebSocket       │  │  REST HTTP       │
├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│ ├─ Capture PCB   │  │ ├─ Frame stream  │  │ ├─ YOLOv11       │
│ ├─ Get status    │  │ ├─ Detection     │  │ ├─ NMS filter    │
│ └─ Control       │  │ └─ Camera info   │  │ └─ Statistics    │
│    hardware      │  │                  │  │                  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                     │
        ┌────────────────────────┐
        │  Jupyter Notebook      │
        │  (TestRestAPI.ipynb)   │
        ├────────────────────────┤
        │ QCamberAPI Client      │
        │ ├─ Test connectivity   │
        │ ├─ Capture images      │
        │ └─ Diagnose issues     │
        └────────────────────────┘
```

---

## 🔌 Communication Ports Summary

| Port | Service | Type | Direction | Purpose |
|------|---------|------|-----------|---------|
| **8686** | QCamber | REST HTTP | Flutter ←→ QCamber | PCB imaging control |
| **12345** | AutoVRS | WebSocket | Flutter ← Server | Live video stream |
| **8082** | AI Detection | REST HTTP | Flutter ←→ AI | Defect detection |
| **8081** | Video Stream | WebSocket | Flutter ← Server | Alternative video |
| **8000** | Backend API | REST HTTP | (Legacy) | General API |

---

## 📊 Key Data Models

### Application State (VRSProvider)
```
System Status (OK/NG/Error)
  └─ Auto/Manual Mode
      └─ Current Model
          └─ Current Lot
              └─ Current Board
                  └─ Defects List
                      └─ Statistics (OK count, NG count, NG rate)
```

### Detection Result (AIDetectionService)
```
Image Input (Uint8List)
  → YOLOv11 Inference
    → List<DefectDetection>
        ├─ Bounding Box [x1, y1, x2, y2]
        ├─ Confidence (0.0-1.0)
        ├─ Class ID & Name
        └─ Coordinates (center point)
    → Processed Image (with boxes drawn)
    → Statistics
```

---

## 🔄 Main Workflows

### Workflow 1: Live Inspection
```
1. Connect to AutoVRS WebSocket (12345)
2. Receive live JPEG frames (30fps)
3. Display on UI in real-time
4. User clicks "Capture & Analyze"
5. Extract current frame
6. Send to AI Detection (8082)
7. Show results with bounding boxes
8. User confirms judgment (OK/NG)
9. Save to database
```

### Workflow 2: PCB Capture (from Jupyter)
```
1. Initialize QCamberAPI client
2. Check if server running
3. POST /api/capture with coordinates
4. QCamber captures image
5. Return PNG image binary
6. Save or display
```

### Workflow 3: AI Detection
```
1. Get image from WebSocket frame
2. Convert to Base64
3. POST to /api/ai-detection
4. Python: YOLOv11 inference
5. Python: Post-process results
6. Return JSON with detections
7. Draw boxes on image
8. Display on UI
```

---

## 💾 Database Schema

```
tbModel (1 to Many) → tbLot
tbLot   (1 to Many) → tbBoard
tbBoard (1 to Many) → tbDefect
tbConfig (1 to 1) → Settings

Typical Hierarchy:
Model_001
  ├─ Lot_001
  │   ├─ Board_001 (defects: 2)
  │   │   ├─ Defect_001 (type: short_circuit, judgement: NG)
  │   │   └─ Defect_002 (type: solder_joint, judgement: OK)
  │   └─ Board_002 (defects: 0)
  └─ Lot_002
      ├─ Board_003
      └─ Board_004
```

---

## 🎬 Screen Layout - Manual VRS

```
┌─────────────────────────────────┐
│ Manual VRS Screen               │
├─────────────────────────────────┤
│ [Live Camera Feed]              │  ← From WebSocket (12345)
│  ┌───────────────────────────┐  │
│  │     JPEG Frame Stream     │  │  ← 640x480 or actual size
│  │      (30fps update)       │  │  ← Uint8List converted to Image
│  └───────────────────────────┘  │
│                                 │
│ [Defect Panel] [Analysis Panel] │
│  Defect #1/5                    │  ← From database (tbDefect)
│  Type: Solder Joint             │  ← From AI detection or manual
│  Position: X=150, Y=250         │
│  Status: Pending                │
│                                 │
│ [Buttons]                       │
│ [◀ Prev] [Capture] [Next ▶]     │
│ [✓ OK] [✗ NG] [💾 Save]         │
├─────────────────────────────────┤
│ Analysis Results (After capture)│
│ Detections: 3                   │  ← From AI Detection (8082)
│ ├─ Defect A (95% conf)          │
│ ├─ Defect B (88% conf)          │
│ └─ Defect C (92% conf)          │
│ [Processed Image with boxes]    │
└─────────────────────────────────┘
```

---

## 🚀 Startup Sequence

```
1. main()
   ├─ Initialize Flutter engine
   ├─ Setup sqflite for Windows/Linux/macOS
   ├─ Initialize Hive storage
   ├─ Initialize LocalDatabaseService
   └─ Run AutoVRSApp()

2. AutoVRSApp.build()
   ├─ Setup MultiProvider with providers:
   │  ├─ NavigationProvider
   │  ├─ AuthProvider
   │  ├─ VRSProvider
   │  ├─ StatisticsProvider
   │  ├─ FlutterCameraService
   │  ├─ AutoVRSWebSocketService.connect() ⭐
   │  └─ AIDetectionService
   └─ Setup MaterialApp.router with GoRouter

3. AutoVRSWebSocketService.connect()
   ├─ Create WebSocket connection to ws://127.0.0.1:12345/
   ├─ Listen for messages
   ├─ Start receiving video frames
   └─ Update _currentFrameNotifier on each frame

4. MainLayout() displays
   ├─ Navigation rail/drawer
   └─ Current screen (HomeScreen by default)
```

---

## 🐍 Python Backend Structure

```
BE-AutoVRS/
├── TestRestAPI.ipynb          # Test notebook for QCamber API
├── ai_detection_api.py        # AI detection endpoint (8082)
├── run_ai_api.py              # Start AI service
├── models/
│   ├── best.onnx              # YOLOv11 ONNX model
│   ├── best.pt                # PyTorch model
│   └── multi.*                # Multi-scale models
├── server/
│   └── ws_coord_server.py     # WebSocket server (12345)
├── Image_input/               # Input images
├── Image_output/              # Output images
└── requirements_ai.txt        # Python dependencies
```

---

## 🧪 Testing with Jupyter Notebook

### TestRestAPI.ipynb

**Purpose**: Test QCamber REST API (Port 8686)

**Key Components**:
1. **QCamberAPI Class** - Helper to interact with REST API
2. **Test Functions** - Check connectivity, get status, capture images
3. **Diagnostics** - Troubleshoot connection issues
4. **Visualization** - Display captured images with matplotlib

**Usage**:
```python
# Initialize
api = QCamberAPI("http://localhost:8686")

# Check if server is running
if api.is_server_running():
    print("✅ Server running")

# Get status
status = api.check_status()

# Capture PCB image
metadata, image = api.capture_pcb_with_image(
    job_name="tgz2",
    layer_name="l2",
    x=1.5, y=2.0,
    zoom=128.0
)

if image:
    plt.imshow(image)
    plt.show()
```

---

## 📋 Key File Locations

### Frontend (Dart/Flutter)
```
App/
├── lib/main.dart                           # Entry point ⭐
├── lib/providers/vrs_provider.dart         # Main state ⭐
├── lib/services/autovrs_websocket_service.dart  # WebSocket ⭐
├── lib/services/ai_detection_service.dart       # AI API ⭐
├── lib/screens/vrs/manual_vrs_screen.dart       # Main screen ⭐
├── lib/services/local_database_service.dart     # Database ⭐
└── pubspec.yaml                            # Dependencies ⭐
```

### Backend (Python)
```
BE-AutoVRS/
├── TestRestAPI.ipynb                       # Test notebook ⭐
├── ai_detection_api.py                     # AI service ⭐
├── models/best.onnx                        # AI model ⭐
└── server/ws_coord_server.py               # WebSocket server ⭐
```

---

## 🔗 Useful Commands

### Flutter
```bash
# Run app
flutter run -d windows  # or ios, android, linux, macos

# Build
flutter build windows

# Check dependencies
flutter pub get

# Analyze code
flutter analyze

# Format code
dart format lib/
```

### Python
```bash
# Install dependencies
pip install -r requirements_ai.txt

# Run AI detection service
python run_ai_api.py

# Run WebSocket server
python server/ws_coord_server.py

# Run Jupyter notebook
jupyter notebook TestRestAPI.ipynb
```

### SQLite
```bash
# Query database
sqlite3 "C:\Users\{user}\Documents\AutoVRS\autovrs.db"

# View tables
.tables

# Query records
SELECT * FROM tbDefect;
SELECT * FROM tbBoard WHERE defect_quantity > 0;
```

---

## ✨ Key Features

### Manual VRS Screen
- ✅ Live video stream (30fps)
- ✅ Defect list navigation
- ✅ Capture & AI analysis
- ✅ Manual judgment confirmation
- ✅ Save to database

### AI Detection
- ✅ YOLOv11-based defect detection
- ✅ Configurable confidence threshold
- ✅ NMS (Non-Max Suppression) filtering
- ✅ Bounding box visualization
- ✅ Class name in English & Vietnamese

### Database
- ✅ SQLite for local storage
- ✅ MVVM pattern with Provider
- ✅ Model-Lot-Board-Defect hierarchy
- ✅ Configuration persistence
- ✅ Defect history tracking

### Authentication
- ✅ Worker mode ("worker" password)
- ✅ Admin mode ("admin" password)
- ✅ Role-based access control

---

## 🎓 Learning Paths

### For UI/Frontend Developers
1. Read: `QUICK_REFERENCE.md` - Overview
2. Read: `ARCHITECTURE_ANALYSIS.md` - App structure
3. Study: `lib/main.dart` - App initialization
4. Study: `lib/screens/vrs/manual_vrs_screen.dart` - Main screen
5. Study: `lib/providers/vrs_provider.dart` - State management

### For Backend/Integration Developers
1. Read: `QUICK_REFERENCE.md` - Ports & services
2. Read: `API_FLOW_DETAILED.md` - API flows
3. Study: `lib/services/ai_detection_service.dart` - AI API
4. Study: `lib/services/autovrs_websocket_service.dart` - WebSocket
5. Study: `BE-AutoVRS/TestRestAPI.ipynb` - API testing

### For Full-Stack Developers
1. Start with `ARCHITECTURE_ANALYSIS.md` (full picture)
2. Deep-dive with `API_FLOW_DETAILED.md` (interactions)
3. Use `QUICK_REFERENCE.md` (daily reference)
4. Study both frontend and backend code

---

## 🤝 Integration Points

### Flutter ↔ QCamber
- Protocol: HTTP REST
- Port: 8686
- Use: Capture PCB images with specific coordinates
- Tested by: `TestRestAPI.ipynb`

### Flutter ↔ AutoVRS
- Protocol: WebSocket
- Port: 12345
- Use: Real-time video streaming
- Update rate: 30fps

### Flutter ↔ AI Detection
- Protocol: HTTP REST (POST)
- Port: 8082
- Use: Send frame for analysis, receive detections
- Format: Base64-encoded image → JSON results

### Flutter ↔ Local Database
- Type: SQLite
- Location: `C:\Users\{user}\Documents\AutoVRS\autovrs.db`
- Use: Store models, lots, boards, defects
- Patterns: CRUD operations via LocalDatabaseService

---

## 🎯 Next Steps

1. **For New Developers**: Start with `QUICK_REFERENCE.md`
2. **For Integration**: Study `API_FLOW_DETAILED.md`
3. **For Deep Understanding**: Read `ARCHITECTURE_ANALYSIS.md`
4. **For Troubleshooting**: Use `QUICK_REFERENCE.md` Common Issues section

---

## 📞 Quick Reference Links

- **Ports**: See `QUICK_REFERENCE.md` → "Key Ports"
- **Providers**: See `QUICK_REFERENCE.md` → "Providers"
- **Workflows**: See `API_FLOW_DETAILED.md` → "Complete Workflow"
- **Database**: See `QUICK_REFERENCE.md` → "Database Tables"
- **Navigation**: See `QUICK_REFERENCE.md` → "Screen Navigation"
- **Issues**: See `QUICK_REFERENCE.md` → "Common Issues & Solutions"

---

## 📝 Documentation Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Oct 20, 2025 | Initial comprehensive analysis |

---

**Generated by**: GitHub Copilot  
**Date**: October 20, 2025  
**Project**: AutoVRS - Automatic Visual Recognition System
