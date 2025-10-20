import 'package:flutter/material.dart';

/// Extension cho manual_vrs_screen.dart
/// Chứa logic load Gerber image khi click vào defect
///
/// Thêm vào class _ManualVRSScreenState:
///
/// ```dart
/// late QCamberGerberService _gerberService;
/// bool _isLoadingGerber = false;
///
/// @override
/// void initState() {
///   super.initState();
///   _gerberService = QCamberGerberService();
///   // ... rest of initState
/// }
///
/// @override
/// void dispose() {
///   _gerberService.dispose();
///   // ... rest of dispose
/// }
/// ```

/// Helper function để lấy Gerber image khi chọn defect
///
/// Thêm hàm này vào _ManualVRSScreenState
///
/// ```dart
/// Future<void> _loadGerberForCurrentDefect() async {
///   if (_defects.isEmpty) return;
///
///   setState(() => _isLoadingGerber = true);
///
///   try {
///     // Get current defect
///     final defect = _defects[_currentDefectIndex];
///
///     // Get model name từ database hierarchy
///     final boardId = int.tryParse(Provider.of<VRSProvider>(context, listen: false).currentBoard) ?? 0;
///     final board = await _db.getBoardById(boardId);
///
///     if (board == null) throw Exception('Board not found');
///
///     final lotId = board['tbLotid_lot'];
///     final lot = await _db.getLotById(lotId);
///
///     if (lot == null) throw Exception('Lot not found');
///
///     final modelId = lot['tbModelid_model'];
///     final model = await _db.getModelById(modelId);
///
///     if (model == null) throw Exception('Model not found');
///
///     // Extract coordinates from defect
///     Map<String, dynamic> coordinates = {};
///     final coordinatesStr = defect['coordinates'] as String?;
///
///     if (coordinatesStr != null && coordinatesStr.isNotEmpty) {
///       try {
///         coordinates = QCamberGerberService.parseCoordinatesString(coordinatesStr) ?? {};
///       } catch (e) {
///         debugPrint('Error parsing coordinates: $e');
///       }
///     }
///
///     // Request Gerber image
///     final success = await _gerberService.captureGerberImage(
///       modelName: model['name'] ?? 'Model_${model['id_model']}',
///       coordinates: coordinates,
///       defectType: defect['type'],
///       layerName: 'l2',
///       zoom: 128.0,
///     );
///
///     if (success) {
///       debugPrint('✅ Gerber image loaded successfully');
///     } else {
///       debugPrint('❌ Failed to load Gerber image: ${_gerberService.lastError}');
///     }
///   } catch (e) {
///     debugPrint('Error loading Gerber: $e');
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('Lỗi tải ảnh Gerber: $e')),
///     );
///   } finally {
///     if (mounted) {
///       setState(() => _isLoadingGerber = false);
///     }
///   }
/// }
/// ```

/// Thêm vào defect list item click handler
///
/// ```dart
/// onTap: () {
///   setState(() {
///     _currentDefectIndex = index;
///   });
///   // Load Gerber image cho defect mới
///   _loadGerberForCurrentDefect();
/// }
/// ```

/// Hoặc tự động load khi navigate defect
///
/// ```dart
/// void _nextDefect() {
///   if (_currentDefectIndex < _defects.length - 1) {
///     setState(() {
///       _currentDefectIndex++;
///     });
///     _loadGerberForCurrentDefect();
///   }
/// }
///
/// void _previousDefect() {
///   if (_currentDefectIndex > 0) {
///     setState(() {
///       _currentDefectIndex--;
///     });
///     _loadGerberForCurrentDefect();
///   }
/// }
/// ```

class GerberIntegrationGuide {
  static const String importStatements = '''
import '../../services/qcamber_gerber_service.dart';
import '../../widgets/gerber_image_widget.dart';
''';

  static const String stateVariables = '''
late QCamberGerberService _gerberService;
bool _isLoadingGerber = false;
''';

  static const String initState = '''
@override
void initState() {
  super.initState();
  
  // Initialize AI Detection Service
  _aiDetectionService = AIDetectionService();
  _videoFrameService = VideoFrameService();
  _gerberService = QCamberGerberService();  // ADD THIS
  
  // Kết nối AutoVRS WebSocket khi khởi tạo màn hình
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final webSocketService = Provider.of<AutoVRSWebSocketService>(
      context,
      listen: false,
    );
    _connectToBackend(webSocketService);
    
    // AUTO LOAD GERBER FOR FIRST DEFECT  ADD THIS
    if (_defects.isNotEmpty) {
      _loadGerberForCurrentDefect();
    }
  });
}
''';

  static const String dispose = '''
@override
void dispose() {
  _aiDetectionService.dispose();
  _videoFrameService.dispose();
  _gerberService.dispose();  // ADD THIS
  super.dispose();
}
''';

  static const String loadGerberMethod = '''
Future<void> _loadGerberForCurrentDefect() async {
  if (_defects.isEmpty) {
    _gerberService.clearImage();
    return;
  }
  
  if (mounted) {
    setState(() => _isLoadingGerber = true);
  }
  
  try {
    // Get current defect
    final defect = _defects[_currentDefectIndex];
    
    // Get model name from database hierarchy
    final boardId = int.tryParse(
      Provider.of<VRSProvider>(context, listen: false).currentBoard,
    ) ?? 0;
    
    final board = await _db.getBoardById(boardId);
    if (board == null) throw Exception('Board not found');
    
    final lotId = board['tbLotid_lot'];
    final lot = await _db.getLotById(lotId);
    if (lot == null) throw Exception('Lot not found');
    
    final modelId = lot['tbModelid_model'];
    final model = await _db.getModelById(modelId);
    if (model == null) throw Exception('Model not found');
    
    // Extract coordinates from defect
    Map<String, dynamic> coordinates = {};
    final coordinatesStr = defect['coordinates'] as String?;
    
    if (coordinatesStr != null && coordinatesStr.isNotEmpty) {
      try {
        coordinates = 
          QCamberGerberService.parseCoordinatesString(coordinatesStr) ?? {};
      } catch (e) {
        debugPrint('Error parsing coordinates: \$e');
      }
    }
    
    // Request Gerber image from QCamber (Port 8686)
    final success = await _gerberService.captureGerberImage(
      modelName: model['name'] ?? 'Model_\${model['id_model']}',
      coordinates: coordinates,
      defectType: defect['type'],
      layerName: 'l2',  // Fixed layer name
      zoom: 128.0,      // Fixed zoom level
    );
    
    if (success) {
      debugPrint('✅ Gerber image loaded');
    } else {
      debugPrint('❌ Failed to load Gerber: \${_gerberService.lastError}');
    }
  } catch (e) {
    debugPrint('Error loading Gerber: \$e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải ảnh Gerber: \$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoadingGerber = false);
    }
  }
}
''';

  static const String updateDefectNavigation = '''
void _nextDefect() {
  if (_defects.isNotEmpty && _currentDefectIndex < _defects.length - 1) {
    setState(() {
      _currentDefectIndex++;
    });
    _loadGerberForCurrentDefect();  // ADD THIS LINE
  }
}

void _previousDefect() {
  if (_defects.isNotEmpty && _currentDefectIndex > 0) {
    setState(() {
      _currentDefectIndex--;
    });
    _loadGerberForCurrentDefect();  // ADD THIS LINE
  }
}
''';

  static const String gerberImageWidget = '''
// Thay thế vùng hiển thị "Ảnh từ Thiết kế Gerber" bằng:

// OLD: Container(...)
// NEW:
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ảnh từ Thiết kế Gerber',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_isLoadingGerber)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        SizedBox(height: 12),
        Expanded(
          child: GerberImageWidget(
            isLoading: _isLoadingGerber,
            errorMessage: _gerberService.lastError,
          ),
        ),
      ],
    ),
  ),
)
''';
}
