# 🔄 Chi Tiết API Communication Flow

## 1️⃣ QCamber API Flow - Chụp Ảnh PCB

### Jupyter Notebook (TestRestAPI.ipynb) Request

```
┌─────────────────────────────────────────────────────────┐
│  Jupyter Notebook Cell                                  │
│  api.capture_pcb_with_image(                            │
│    job_name="tgz2",                                     │
│    layer_name="l2",                                     │
│    x=1.5, y=2.0,                                        │
│    zoom=128.0                                           │
│  )                                                       │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  HTTP POST /api/capture                                 │
│  Content-Type: application/json                         │
│                                                          │
│  {                                                      │
│    "requestId": "req_abc123def456",                     │
│    "jobName": "tgz2",                                   │
│    "layerName": "l2",                                   │
│    "x": 1.5,                                            │
│    "y": 2.0,                                            │
│    "zoom": 128.0                                        │
│  }                                                       │
└─────────────────────────────────────────────────────────┘
         │
         │ Network: localhost:8686
         ▼
┌─────────────────────────────────────────────────────────┐
│  QCamber Server (Port 8686)                             │
│  ├─ Parse job_name (PCB project)                        │
│  ├─ Find layer_name (layer level to capture)            │
│  ├─ Calculate coordinates (x, y with zoom)              │
│  ├─ Control imaging hardware                            │
│  ├─ Capture image at coordinates                        │
│  └─ Save temporary file                                 │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  HTTP Response (200 OK)                                 │
│  Content-Type: image/png (or application/json)          │
│                                                          │
│  Option A: PNG Image Binary Data                        │
│  ├─ Raw PNG bytes (typically 50-500KB)                  │
│  └─ PIL.Image can parse directly                        │
│                                                          │
│  Option B: JSON Acknowledgment                          │
│  {                                                      │
│    "status": "success",                                 │
│    "requestId": "req_abc123def456",                     │
│    "message": "Capture initiated"                       │
│  }                                                       │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Jupyter Notebook Processing                            │
│  ├─ Receive response                                    │
│  ├─ Check Content-Type header                           │
│  ├─ If image/png:                                       │
│  │  └─ image = Image.open(BytesIO(response.content))    │
│  ├─ If application/json:                                │
│  │  └─ image = None (wait for next request)             │
│  └─ Return (metadata, image)                            │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Result Handling                                        │
│  if image:                                              │
│    ├─ image.save("output.png")  # Save to disk          │
│    ├─ plt.imshow(image)         # Display               │
│    └─ image.size                # Get dimensions        │
│  else:                                                  │
│    └─ Print error message                               │
└─────────────────────────────────────────────────────────┘
```

### QCamberAPI Helper Methods

```python
class QCamberAPI:
    def __init__(self, base_url="http://localhost:8686"):
        self.base_url = base_url
        self.session = requests.Session()  # Connection pooling
    
    # ✅ Test if server is running
    def is_server_running(self) -> bool:
        try:
            response = self.session.get(
                f"{self.base_url}/api/status",
                timeout=2
            )
            return response.status_code == 200
        except:
            return False
    
    # ✅ Check server status
    def check_status(self) -> dict:
        try:
            response = self.session.get(
                f"{self.base_url}/api/status",
                timeout=5
            )
            return response.json()
        except requests.exceptions.RequestException as e:
            return {"error": str(e)}
    
    # ✅ Capture PCB (simple request)
    def capture_pcb(self, job_name, layer_name, x=0, y=0, zoom=1.0) -> dict:
        payload = {
            "jobName": job_name,
            "layerName": layer_name,
            "x": x, "y": y,
            "zoom": zoom
        }
        response = self.session.post(
            f"{self.base_url}/api/capture",
            json=payload,
            timeout=10
        )
        return response.json()
    
    # ✅ Capture PCB with image response
    def capture_pcb_with_image(self, job_name, layer_name, x=0, y=0, 
                               zoom=1.0, timeout=30):
        """
        Returns: (metadata: dict, image: PIL.Image or None)
        """
        import uuid
        from PIL import Image
        from io import BytesIO
        import time
        
        request_id = f"req_{uuid.uuid4().hex[:16]}"
        payload = {
            "requestId": request_id,
            "jobName": job_name,
            "layerName": layer_name,
            "x": x, "y": y,
            "zoom": zoom
        }
        
        try:
            response = self.session.post(
                f"{self.base_url}/api/capture",
                json=payload,
                timeout=timeout
            )
            
            if response.status_code != 200:
                return {"error": f"HTTP {response.status_code}"}, None
            
            content_type = response.headers.get('Content-Type', '')
            
            # 📥 Receive PNG image
            if 'image/png' in content_type:
                image = Image.open(BytesIO(response.content))
                metadata = {
                    "requestId": request_id,
                    "jobName": job_name,
                    "layerName": layer_name,
                    "x": x, "y": y,
                    "zoom": zoom,
                    "imageSize": len(response.content)
                }
                return metadata, image
            
            # 📥 Receive JSON acknowledgment
            elif 'application/json' in content_type:
                ack = response.json()
                time.sleep(1)  # Wait for processing
                return ack, None
            
            else:
                return {
                    "error": f"Unexpected content type: {content_type}"
                }, None
                
        except requests.exceptions.Timeout:
            return {"error": "Timeout"}, None
        except Exception as e:
            return {"error": str(e)}, None
```

---

## 2️⃣ AutoVRS WebSocket Flow - Live Video Streaming

### Connection Setup

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App (main.dart)                                │
│  ├─ MultiProvider initialization                        │
│  └─ AutoVRSWebSocketService.connect()                   │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  WebSocket Connection Request                           │
│  ws://127.0.0.1:12345/ws/flutter_client                │
│  ├─ clientId: "flutter_client"                          │
│  ├─ Path: /ws/{clientId}                                │
│  └─ Protocol: RFC 6455 (WebSocket)                      │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  AutoVRS WebSocket Server (Port 12345)                  │
│  ├─ Accept connection from flutter_client               │
│  ├─ Send connection acknowledgment                       │
│  └─ Start streaming video frames                        │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Connection Message (Type: connection/info)             │
│  ├─ Serial Number: ...                                  │
│  ├─ Sensor Name: ...                                    │
│  ├─ Max Resolution: 1920x1080                           │
│  └─ Frame Rate: 30fps                                   │
└─────────────────────────────────────────────────────────┘
```

### Continuous Video Frame Streaming

```
AutoVRS Server continuously sends:

Frame 1 (T=0ms)
├─ Binary data: JPEG frame (100KB)
└─ Timestamp: 0

Frame 2 (T=33ms)
├─ Binary data: JPEG frame (95KB)
└─ Timestamp: 33

Frame 3 (T=66ms)
├─ Binary data: JPEG frame (98KB)
└─ Timestamp: 66

... (continuous @ 30fps = 1 frame every ~33ms)
```

### Message Types from AutoVRS

```
1. Connection Message (JSON)
   {
     "type": "connection" | "info",
     "serial_number": "...",
     "sensor_name": "...",
     "max_width": 1920,
     "max_height": 1080
   }

2. Video Frame (Binary)
   Uint8List (raw JPEG data)
   └─ Stored in _currentFrame

3. Capture Response (JSON)
   {
     "type": "capture_response",
     "timestamp": 1634567890,
     "status": "success"
   }

4. AI Detection (JSON)
   {
     "type": "ai_detection",
     "detections": [
       {
         "bbox": [100, 200, 300, 400],
         "confidence": 0.95,
         "class_name": "solder_joint"
       }
     ]
   }

5. Camera Status (JSON)
   {
     "type": "camera_status",
     "status": "running" | "idle",
     "resolution": "1920x1080"
   }

6. Ping/Pong (for keepalive)
   {
     "type": "pong"
   }
```

### Frame Processing in Flutter

```dart
// From autovrs_websocket_service.dart

void _handleMessage(dynamic message) {
  if (message is Uint8List) {
    // Binary JPEG frame
    _currentFrame = message;
    _currentFrameNotifier.value = message;
    _frameCount++;
    _frameCountNotifier.value = _frameCount;
    
    // Optimize memory
    optimizeMemory();
    
    // Notify UI (less frequently to avoid jank)
    if (_frameCount % 5 == 0) {
      notifyListeners();
    }
  } 
  else if (message is String) {
    // JSON message
    final data = jsonDecode(message);
    final type = data['type'];
    
    if (type == 'connection') {
      _handleConnectionMessage(data);
    } 
    else if (type == 'ai_detection') {
      _handleCaptureResponse(data);
      _lastDetectionResults = data;
    }
    // ... etc
  }
}
```

### UI Update with ValueNotifier

```dart
// Optimized for performance

Consumer<AutoVRSWebSocketService>(
  builder: (context, wsService, child) {
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: wsService.currentFrameNotifier,
      builder: (context, frame, child) {
        if (frame == null) {
          return Center(child: CircularProgressIndicator());
        }
        
        return Image.memory(
          frame,
          fit: BoxFit.cover,
          gaplessPlayback: true,  // Reduce flickering
        );
      },
    );
  },
)
```

---

## 3️⃣ AI Detection Flow

### Step-by-Step Process

```
┌──────────────────────────────────────────────────┐
│ 1. User captures frame                           │
│    (Click "Chụp lại" button in ManualVRSScreen)  │
└──────────────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│ 2. Extract current frame                         │
│    Uint8List currentFrame =                      │
│      webSocketService.currentFrame               │
└──────────────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│ 3. Convert to Base64                             │
│    String base64Image =                          │
│      base64Encode(currentFrame)                  │
└──────────────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│ 4. Build AI Detection Request                    │
│    {                                             │
│      "image_base64": "iVBORw0KGgo...",          │
│      "confidence_threshold": 0.25,               │
│      "iou_threshold": 0.1                        │
│    }                                             │
└──────────────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│ 5. HTTP POST to AI Detection Service             │
│    POST http://localhost:8082/api/ai-detection   │
│    Content-Type: application/json                │
└──────────────────────────────────────────────────┘
         │
         │ Network
         ▼
┌──────────────────────────────────────────────────┐
│ AI Detection Service (Python, Port 8082)         │
│                                                  │
│ 6. Receive image                                 │
│    ├─ Decode Base64 to bytes                     │
│    ├─ Load image from bytes                      │
│    └─ Resize/preprocess if needed                │
│                                                  │
│ 7. Run YOLOv11 Inference                         │
│    ├─ Model: best.onnx or best.pt                │
│    ├─ Input: preprocessed image                  │
│    └─ Output: raw predictions                    │
│                                                  │
│ 8. Post-processing                               │
│    ├─ Apply NMS (Non-Max Suppression)             │
│    ├─ Filter by confidence_threshold             │
│    ├─ Format bounding boxes                      │
│    └─ Calculate statistics                       │
│                                                  │
│ 9. Create processed image (optional)             │
│    ├─ Draw bounding boxes on image               │
│    ├─ Add labels and confidence                  │
│    ├─ Encode to PNG                              │
│    └─ Convert to Base64                          │
│                                                  │
│ 10. Build response                               │
│     {                                            │
│       "success": true,                           │
│       "detections": [...],                       │
│       "statistics": {...},                       │
│       "processed_image_base64": "...",           │
│       "timestamp": "2024-10-20T10:30:00"         │
│     }                                            │
└──────────────────────────────────────────────────┘
                     │
                     ▼ HTTP Response (200 OK)
         │
         │ Network
         ▼
┌──────────────────────────────────────────────────┐
│ Flutter App receives response                    │
│                                                  │
│ 11. Parse JSON response                          │
│     AIDetectionResult result =                   │
│       AIDetectionResult.fromJson(json)           │
│                                                  │
│ 12. Extract detection data                       │
│     ├─ List<DefectDetection> detections          │
│     ├─ Uint8List processedImage                  │
│     ├─ Map<String, dynamic> statistics           │
│     └─ DateTime timestamp                        │
│                                                  │
│ 13. Display results on UI                        │
│     ├─ Show bounding boxes over image            │
│     ├─ Display defect count                      │
│     ├─ Show confidence scores                    │
│     └─ Allow user to confirm/reject              │
│                                                  │
│ 14. User confirms judgment (OK or NG)            │
│                                                  │
│ 15. Save to database                             │
│     ├─ Insert into tbDefect table                │
│     ├─ Store defect type                         │
│     ├─ Store judgment (OK/NG)                    │
│     └─ Store coordinates                         │
│                                                  │
│ 16. Move to next defect                          │
│     _currentDefectIndex++                        │
└──────────────────────────────────────────────────┘
```

### AI Detection Data Structures

```dart
class AIDetectionResult {
  final bool success;
  final String message;
  final List<DefectDetection> detections;
  final Uint8List? processedImage;
  final Map<String, dynamic> statistics;
  final DateTime timestamp;
}

class DefectDetection {
  final List<int> bbox;              // [x1, y1, x2, y2]
  final double confidence;           // 0.0 - 1.0
  final int classId;                 // Class index
  final String className;            // "solder_joint"
  final String classNameVi;          // "chỗ hàn"
  final Map<String, int> coordinates; // {"x": 150, "y": 250}
}
```

---

## 4️⃣ Manual VRS Screen Integration

### Screen State Management

```dart
class _ManualVRSScreenState extends State<ManualVRSScreen> {
  // Defect list
  List<Map<String, dynamic>> _defects = [];
  int _currentDefectIndex = 0;
  
  // Analysis state
  bool _isAnalyzing = false;
  bool _hasAnalysisResult = false;
  AIDetectionResult? _analysisResult;
  
  // Services
  late AIDetectionService _aiDetectionService;
  late AutoVRSWebSocketService _webSocketService;
  
  @override
  void initState() {
    // Load defects from database
    _loadDefectsForBoard(boardId);
    
    // Connect to WebSocket
    _connectToBackend(_webSocketService);
  }
  
  Future<void> _captureAndAnalyze() async {
    // Get current frame
    Uint8List? frame = _webSocketService.currentFrame;
    
    // Send to AI detection
    setState(() => _isAnalyzing = true);
    
    AIDetectionResult? result = await _aiDetectionService.detectDefects(
      imageData: frame!,
      confidenceThreshold: 0.25,
      iouThreshold: 0.1,
    );
    
    setState(() {
      _isAnalyzing = false;
      _hasAnalysisResult = true;
      _analysisResult = result;
    });
  }
}
```

### UI Layout

```
┌─────────────────────────────────────────┐
│  Manual VRS Screen                      │
├─────────────────────────────────────────┤
│                                         │
│  [Live Camera Stream Area]              │
│  ┌─────────────────────────────────────┐│
│  │                                     ││
│  │    Current Frame from WebSocket     ││
│  │    (640x480 or actual resolution)   ││
│  │                                     ││
│  └─────────────────────────────────────┘│
│                                         │
├─────────────────────────────────────────┤
│  [Defect Information Panel]              │
│  ┌─────────────────────────────────────┐│
│  │ Defect #1 / 5                      ││
│  │ Type: Short Circuit                 ││
│  │ Position: X=150, Y=250              ││
│  │ Size: 2mm x 1.5mm                   ││
│  │ Status: Pending                     ││
│  └─────────────────────────────────────┘│
│                                         │
├─────────────────────────────────────────┤
│  [Action Buttons]                       │
│  [Previous] [Capture & Analyze] [Next]  │
│  [OK]       [NG]        [Save]          │
├─────────────────────────────────────────┤
│  [Analysis Results Panel]                │
│  (Hidden until analysis complete)        │
│  ┌─────────────────────────────────────┐│
│  │ Detections: 3                       ││
│  │ ├─ Solder Joint (95% confidence)    ││
│  │ ├─ Short Circuit (88% confidence)   ││
│  │ └─ Open Circuit (92% confidence)    ││
│  │ Status: OK / NG                     ││
│  └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘
```

---

## 5️⃣ Database Integration

### Data Flow: Capture → Database

```
1. Defect captured by AI detection
   ├─ bbox: [100, 200, 300, 400]
   ├─ confidence: 0.95
   ├─ className: "solder_joint"
   └─ timestamp: 2024-10-20T10:30:00

2. Flutter app processes
   ├─ Convert bbox to coordinates (center point)
   ├─ Format coordinates as JSON: {"x": 200, "y": 300}
   └─ User confirms judgment: "NG"

3. Insert into tbDefect table
   {
     "type": "solder_joint",
     "judgement": "NG",
     "height": 50.0,
     "width": 100.0,
     "time": "2024-10-20T10:30:00",
     "coordinates": "{\"x\": 200, \"y\": 300}",
     "url_image": "./images_ai/detection_001.png",
     "tbBoardid_board": 5
   }

4. Update statistics
   ├─ Increment tbBoard.defect_quantity
   ├─ Recalculate tbLot.NG_rate
   └─ Refresh VRSProvider (_totalCount, _ngCount)
```

### Database Schema Relationship

```
tbModel (AI Models)
  ├─ id_model: 1
  └─ name: "Model_001"
       │
       ▼
tbLot (Batches)
  ├─ id_lot: 1
  └─ tbModelid_model: 1
       │
       ▼
tbBoard (PCBs)
  ├─ id_board: 1
  ├─ defect_quantity: 3
  └─ tbLotid_lot: 1
       │
       ▼
tbDefect (Defects)
  ├─ id_defect: 1
  ├─ type: "solder_joint"
  ├─ judgement: "NG"
  └─ tbBoardid_board: 1
```

---

## Summary: Complete Workflow

```
[User Actions]
1. Start App
   └─> Initialize MultiProvider
   └─> Auto-connect to AutoVRS WebSocket (Port 12345)

2. Live View
   └─> Receive frames from WebSocket
   └─> Display on screen in real-time

3. Capture & Analyze
   └─> Click "Chụp lại" button
   └─> Extract current frame
   └─> Send to AI Detection API (Port 8082)
   └─> Receive detection results
   └─> Display processed image with boxes

4. User Review
   └─> User sees detected defects
   └─> Confirms judgment (OK or NG)
   └─> Comments/Notes (optional)

5. Save to Database
   └─> Insert defect record into tbDefect
   └─> Update board statistics
   └─> Move to next defect

6. Test PCB API (from Jupyter)
   └─> Connect to QCamber API (Port 8686)
   └─> Capture specific layer and coordinates
   └─> Receive PNG image
   └─> Display and analyze
```

---

**Generated by**: GitHub Copilot  
**Date**: October 20, 2025
