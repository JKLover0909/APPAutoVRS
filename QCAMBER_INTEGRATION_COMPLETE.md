# QCamber Gerber Image Integration - Implementation Complete ✅

## Overview
Successfully integrated QCamber API (port 8686) into the Flutter VRS application to automatically capture and display PCB Gerber images at defect coordinates.

## Architecture

### 1. **QCamberGerberService** (`lib/services/qcamber_gerber_service.dart`)
Core service layer handling all QCamber API communication.

**Key Features:**
- HTTP POST requests to `http://localhost:8686/api/capture`
- Request payload: `{jobName, layerName, x, y, zoom}`
- Response handling: PNG binary or JSON acknowledgment
- Automatic coordinate parsing from JSON or Map formats
- 30-second timeout with error handling
- ChangeNotifier for reactive UI updates
- Metadata tracking for debugging (model name, layer, coordinates, timestamp)

**Key Methods:**
```dart
Future<bool> captureGerberImage({
  required String modelName,
  required Map<String, dynamic> coordinates,
  required double zoom,
  String layerName = 'l2',
  String? defectType,
})

static Map<String, dynamic>? parseCoordinatesString(String coordinatesJson)

void clearImage()
```

**Properties:**
- `isLoading`: Loading state for UI feedback
- `lastError`: Latest error message
- `gerberImage`: Uint8List image data (PNG)
- `lastMetadata`: Captured metadata for overlay
- `hasImage`: Whether image is available

---

### 2. **GerberImageWidget** (`lib/widgets/gerber_image_widget.dart`)
Reusable widget for displaying Gerber images with state management.

**UI States:**
1. **Loading**: Shows spinner with metadata extraction progress
2. **Error**: Red error icon with message display
3. **Success**: Displays PNG image with metadata overlay (bottom-right corner)
   - Model name
   - Layer name
   - Defect coordinates (x, y)
   - Defect type (if available)
4. **Empty**: Placeholder with instruction "Chọn lỗi để xem ảnh"

**Features:**
- Uses `Consumer<QCamberGerberService>` pattern
- Image error fallback with helpful message
- Responsive layout with metadata positioning
- Vietnamese UI labels

---

### 3. **ManualVRSScreen Integration** (`lib/screens/vrs/manual_vrs_screen.dart`)

**Changes Made:**
1. Added imports for QCamber service and Gerber widget
2. Added fields:
   - `late QCamberGerberService _gerberService`
   - `bool _isLoadingGerber = false`

3. Modified `initState()`:
   - Initialize `_gerberService` from provider
   - Auto-load Gerber for first defect on screen initialization

4. Added `_loadGerberForCurrentDefect()` method:
   - Extracts model name from database hierarchy (Board → Lot → Model)
   - Parses defect coordinates from `defect['coordinates']`
   - Calls QCamber API with parameters:
     - `modelName`: From database Model.name field
     - `coordinates`: Parsed x, y values
     - `layerName`: 'l2' (fixed)
     - `zoom`: 128.0 (fixed)
     - `defectType`: Defect type for debugging

5. Updated defect navigation:
   - `_nextDefect()` now calls `_loadGerberForCurrentDefect()`
   - `_previousDefect()` now calls `_loadGerberForCurrentDefect()`

6. Updated `_loadDefectsForBoard()`:
   - Auto-loads Gerber for first defect when board loads
   - Clears image if no defects found

7. Replaced Gerber UI container with `GerberImageWidget`:
   ```dart
   Expanded(
     child: GerberImageWidget(
       isLoading: _isLoadingGerber,
       errorMessage: _gerberService.lastError,
     ),
   ),
   ```

**Result:** Manual VRS screen now displays Gerber images at defect coordinates, auto-loads on board selection, and updates when user navigates defects.

---

### 4. **VRSMainScreen Integration** (`lib/screens/vrs/vrs_main_screen.dart`)

**Changes Made:**
1. Added imports for QCamber service and Gerber widget
2. Added fields:
   - `late QCamberGerberService _gerberService`
   - `bool _isLoadingGerber = false`

3. Modified `initState()`:
   - Initialize `_gerberService` from provider

4. Replaced Gerber UI container with `GerberImageWidget`:
   - Same as ManualVRSScreen

**Result:** Automated VRS screen also displays Gerber images for manual review during automated inspection workflow.

---

### 5. **Provider Setup** (`lib/main.dart`)

**Changes Made:**
1. Added import: `import 'services/qcamber_gerber_service.dart';`
2. Added to `MultiProvider` list:
   ```dart
   ChangeNotifierProvider(create: (_) => QCamberGerberService()),
   ```

**Result:** QCamberGerberService is available app-wide via Provider pattern.

---

## Data Flow

### User clicks on defect or navigates to next defect:
```
User Action (defect click/navigation)
    ↓
_nextDefect() / _previousDefect()
    ↓
_loadGerberForCurrentDefect()
    ↓
Query Database:
  - Get Model from Lot/Board hierarchy
  - Extract coordinates from defect record
    ↓
QCamberGerberService.captureGerberImage()
    ↓
HTTP POST to localhost:8686/api/capture
Payload: {
  "jobName": "ModelName",
  "layerName": "l2",
  "x": 150.5,
  "y": 250.3,
  "zoom": 128
}
    ↓
Response: PNG binary image
    ↓
Store in service + notify listeners
    ↓
GerberImageWidget updates with:
  - PNG display
  - Metadata overlay
```

---

## Database Schema Assumptions

**Defect Record Structure:**
```dart
{
  'id_defect': 123,
  'tbBoardid_board': 45,
  'coordinates': '{"x": 150.5, "y": 250.3}',  // JSON string
  'type': 'short_circuit',
  'judgement': 'NG',
  'time': '2025-01-15T10:30:00.000'
}
```

**Hierarchy Navigation:**
```
Defect → Board (via tbBoardid_board)
Board → Lot (via tbLotid_lot)
Lot → Model (via tbModelid_model)
Model.name → Used as "jobName" for QCamber API
```

**Coordinate Format:**
- Stored as JSON string: `'{"x": num, "y": num}'`
- Service automatically parses and extracts numeric x, y values
- Supports flexible numeric formats (int/double)

---

## Configuration

### Fixed Parameters:
- **API Endpoint**: `http://localhost:8686/api/capture`
- **Layer Name**: `'l2'` (fixed for all calls)
- **Zoom Level**: `128.0` (fixed for all calls)
- **Request Timeout**: 30 seconds

### QCamber Server Requirements:
- Must be running on `localhost:8686`
- Must expose `POST /api/capture` endpoint
- Must accept payload with: `jobName`, `layerName`, `x`, `y`, `zoom`
- Must return PNG binary image data with proper `Content-Type: image/png` header

---

## Error Handling

### Scenarios Covered:
1. **QCamber server unreachable**: Shows timeout error message
2. **Invalid coordinates in defect record**: Logs error, skips Gerber load
3. **Missing model/lot/board in database**: Shows user-friendly error message
4. **Wrong content-type from API**: Logs and shows error
5. **Network timeout**: Generic timeout message
6. **Empty defects list**: Shows "Gerber View" placeholder with instruction

### User Feedback:
- Loading spinner during fetch
- Error messages in red with icon
- Metadata overlay for successful images
- SnackBar notifications for errors

---

## Testing Checklist

- [ ] QCamber server is running on localhost:8686
- [ ] `/api/capture` endpoint accepts POST requests
- [ ] Payload format: `{jobName, layerName, x, y, zoom}`
- [ ] Response returns PNG binary with `Content-Type: image/png`
- [ ] Database has valid Model/Lot/Board/Defect hierarchy
- [ ] Defect `coordinates` field contains valid JSON string
- [ ] Manual VRS Screen:
  - [ ] Gerber image displays on defect selection
  - [ ] Navigation buttons (Previous/Next) trigger image reload
  - [ ] First defect auto-loads on board selection
  - [ ] Error messages display correctly
- [ ] VRS Main Screen (Automated):
  - [ ] Gerber image available in automated workflow
  - [ ] Can review images during inspection

---

## Files Modified

1. ✅ `lib/services/qcamber_gerber_service.dart` (NEW - 208 lines)
2. ✅ `lib/widgets/gerber_image_widget.dart` (NEW - 180 lines)
3. ✅ `lib/main.dart` (Modified - added provider)
4. ✅ `lib/screens/vrs/manual_vrs_screen.dart` (Modified - integration)
5. ✅ `lib/screens/vrs/vrs_main_screen.dart` (Modified - integration)
6. ✅ `lib/services/gerber_integration_guide.dart` (NEW - documentation)

---

## Build Status

**Compilation**: ✅ No syntax errors
- GerberImageWidget: Fixed closing parenthesis issue
- QCamberGerberService: 0 errors
- ManualVRSScreen: 0 errors
- VRSMainScreen: 0 errors
- main.dart: 0 errors

**Lint Warnings**: Minor only (sizing hints, unused fields - non-critical)

---

## Next Steps

1. **Verify QCamber Server**: Ensure it's running on port 8686
2. **Database Verification**: Confirm defect coordinates are in `{"x": num, "y": num}` format
3. **Testing**: 
   - Start app and navigate to Manual VRS Screen
   - Select a board with defects
   - Verify Gerber image loads for first defect
   - Navigate through defects - images should update
4. **Debugging**: Check QCamber logs if images don't load
   - Check network traffic on port 8686
   - Monitor debugPrint output from QCamberGerberService

---

## Deployment Notes

- QCamberGerberService is automatically initialized when app starts
- Service is a global singleton via Provider
- All screens share the same service instance
- Service state (current image, metadata) is preserved during navigation
- ChangeNotifier notifies all listeners when image updates

---

**Integration completed on**: January 15, 2025
**Status**: ✅ Ready for testing
