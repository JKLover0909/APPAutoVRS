# PLC Gateway API - Integration Guide

## 📋 Tổng quan

**PLC Gateway API** là REST API tích hợp giữa Flutter App, PLC Omron, SICK Camera và AI Detection để tự động hóa quy trình kiểm tra lỗi PCB.

### Workflow hoàn chỉnh:

```
Flutter App (Manual VRS)
    ↓ Lấy tọa độ defect từ SQLite
    ↓
    ↓ POST /api/inspect-defect
    ↓
PLC Gateway API (Python)
    ↓
    ├─→ 1. Gửi X,Y đến PLC Omron (D2810, D2910)
    ├─→ 2. Trigger PLC (D3000 = 1 → 0)
    ├─→ 3. Đợi 2 giây (PLC di chuyển camera)
    ├─→ 4. Capture ảnh (sink.snap_single)
    └─→ 5. Gửi ảnh đến AI API (port 8082)
    ↓
    ↓ Response với AI detections
    ↓
Flutter App
    └─→ Cập nhật database, hiển thị kết quả
```

---

## 🚀 Khởi động hệ thống

### 1. Khởi động AI Detection API
```bash
cd BE-AutoVRS
conda activate autovrs
python run_ai_api.py
```
- Port: **8082**
- Endpoint: `POST /api/ai-detection`

### 2. Khởi động PLC Gateway API
```bash
cd BE-AutoVRS
python run_plc_gateway.py
```
- Port: **8083**
- API Docs: http://localhost:8083/docs

### 3. Kiểm tra kết nối

#### Test PLC:
```bash
curl http://localhost:8083/api/test-plc
```

#### Test Camera:
```bash
curl http://localhost:8083/api/test-camera
```

---

## 📡 API Endpoints

### **POST /api/inspect-defect**

Endpoint chính để inspect một defect.

**Request Body:**
```json
{
  "defect_x": 1234.5,
  "defect_y": 678.9,
  "board_id": "BOARD001",
  "defect_id": 123,
  
  "plc_pc_ip": "192.168.3.101",
  "plc_ip": "192.168.3.1",
  "plc_port": 9600,
  "plc_mem_area": "D",
  "plc_x_addr": 2810,
  "plc_y_addr": 2910,
  "plc_trigger_addr": 3000,
  "plc_move_timeout_ms": 2000,
  
  "ai_confidence_threshold": 0.25,
  "ai_api_url": "http://localhost:8082/api/ai-detection"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Inspection completed successfully",
  "step": "completed",
  "plc_coords": {"x": 1234.5, "y": 678.9},
  "image_captured": true,
  "ai_detections": [
    {
      "class_id": 0,
      "class_name": "KhuyetMach",
      "class_name_vi": "Khuyết mạch",
      "confidence": 0.85,
      "verdict": "OK",
      "reason_text": "Bề rộng lỗi (25%) <= 1/3 bề rộng mạch",
      "measurements": {
        "defect_width_px": 30.5,
        "trace_width_px": 120.0,
        "width_ratio": 0.25
      }
    }
  ],
  "ai_verdict": "OK",
  "ai_statistics": {
    "total_defects": 1,
    "defect_types": {"Khuyết mạch": 1},
    "system_verdict": "OK"
  },
  "timing": {
    "plc_connect": 0.05,
    "plc_send": 0.08,
    "plc_wait": 2.0,
    "camera_capture": 0.15,
    "ai_detection": 0.35,
    "total": 2.63
  }
}
```

---

## 📱 Flutter Integration

### 1. Import service
```dart
import 'package:your_app/services/plc_gateway_service.dart';
```

### 2. Tạo instance
```dart
final plcService = PlcGatewayService(
  baseUrl: 'http://localhost:8083'
);
```

### 3. Gọi inspect defect
```dart
Future<void> inspectDefectWithPLC(double x, double y) async {
  try {
    // Hiển thị loading
    showDialog(
      context: context,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );
    
    // Gọi PLC Gateway API
    final result = await plcService.inspectDefect(
      defectX: x,
      defectY: y,
      boardId: currentBoardId,
      defectId: currentDefectId,
      plcMoveTimeoutMs: 2000,  // 2 giây đợi PLC
    );
    
    // Đóng loading
    Navigator.pop(context);
    
    // Xử lý kết quả
    if (result.success && result.hasAiResults) {
      // Cập nhật database với AI results
      await updateDefectWithAiResults(
        defectId: currentDefectId,
        aiDetections: result.aiDetections!,
        verdict: result.aiVerdict ?? 'NG',
      );
      
      // Hiển thị kết quả
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Kết quả AI'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Verdict: ${result.aiVerdict}'),
              Text('Defects: ${result.defectCount}'),
              Text('Time: ${result.totalTime?.toStringAsFixed(2)}s'),
            ],
          ),
        ),
      );
    } else {
      // Lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
  } catch (e) {
    Navigator.pop(context);
    print('❌ Error: $e');
  }
}
```

### 4. Tích hợp vào Manual VRS Screen

```dart
// Trong manual_vrs_screen.dart
// Thêm button "Auto Inspect" cho mỗi defect

ElevatedButton.icon(
  icon: Icon(Icons.auto_fix_high),
  label: Text('Auto Inspect'),
  onPressed: () async {
    // Lấy tọa độ defect từ database
    final defect = await localDb.getDefectById(defectId);
    
    // Gọi PLC + Camera + AI
    await inspectDefectWithPLC(
      defect['pos_x'],
      defect['pos_y'],
    );
  },
)
```

---

## ⚙️ Cấu hình

### PLC Omron Registers

| Register | Mô tả | Data Type | Giá trị |
|----------|-------|-----------|---------|
| D2810-D2811 | X Coordinate | Float (2 words) | Pixel position |
| D2910-D2911 | Y Coordinate | Float (2 words) | Pixel position |
| D3000 | Trigger | Int (1 word) | 1 = New data, 0 = Idle |

### Network Configuration

```
PC (192.168.3.101)
  ↓ UDP 9600
PLC Omron (192.168.3.1)
  ↓
Camera/Robot Movement
```

### Timing Settings

- **PLC Move Timeout**: 2000ms (2 giây)
  - Thời gian đợi PLC di chuyển camera đến vị trí
  - Có thể điều chỉnh theo tốc độ thực tế

- **Camera Capture Timeout**: 1000ms
  - Timeout cho snap_single()
  
- **AI Detection Timeout**: 30s
  - Timeout cho HTTP request đến AI API

---

## 🐛 Troubleshooting

### 1. PLC Connection Failed
```
❌ Error: PLC connection failed
```

**Giải pháp:**
- Kiểm tra IP PLC: `ping 192.168.3.1`
- Kiểm tra `ClassLibrary.dll` có trong thư mục BE-AutoVRS
- Test bằng `python_cli.py` trước

### 2. Camera Capture Failed
```
❌ Error: Failed to capture image
```

**Giải pháp:**
- Kiểm tra SICK camera đã kết nối: IC Imaging Control 4
- Kiểm tra `imagingcontrol4` đã cài: `pip list | grep imaging`
- Chạy `run_sick_camera.py` riêng để test

### 3. AI API Not Available
```
❌ Error: Connection refused (8082)
```

**Giải pháp:**
- Khởi động AI API: `python run_ai_api.py`
- Kiểm tra: `curl http://localhost:8082/`

### 4. PLC Timeout
```
⚠️ PLC di chuyển chậm hơn 2 giây
```

**Giải pháp:**
- Tăng `plc_move_timeout_ms` trong request
- Hoặc cấu hình trong Flutter:
  ```dart
  plcMoveTimeoutMs: 3000,  // 3 giây
  ```

---

## 📊 Performance

**Typical timing:**
- PLC Connect: ~50ms
- PLC Send: ~80ms
- PLC Wait: 2000ms (fixed)
- Camera Capture: ~150ms
- AI Detection: ~300-500ms
- **Total: ~2.6-2.8 seconds**

---

## 🔒 Production Checklist

- [ ] PLC IP cấu hình đúng
- [ ] Camera driver đã cài đặt
- [ ] AI API đang chạy (port 8082)
- [ ] PLC Gateway API đang chạy (port 8083)
- [ ] Test với 1 defect trước
- [ ] Kiểm tra tọa độ conversion (pixel → mm nếu cần)
- [ ] Backup database trước khi test hàng loạt

---

## 📝 Next Steps

**Tính năng mở rộng:**
1. **Batch inspect** - Scan nhiều defects liên tiếp
2. **Real-time progress** - WebSocket updates
3. **Coordinate conversion** - Pixel → PLC units (mm/pulse)
4. **PLC feedback** - Đọc register xác nhận đã di chuyển xong
5. **Image history** - Lưu ảnh captured vào database

---

## 📞 Support

- GitHub Issues: [APPAutoVRS](https://github.com/JKLover0909/APPAutoVRS)
- Documentation: `/BE-AutoVRS/TESTING_GUIDE.md`
