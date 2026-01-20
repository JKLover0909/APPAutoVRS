import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service để kết nối với QCamber API (Port 8686)
/// Lấy ảnh Gerber từ tọa độ defect
class QCamberGerberService extends ChangeNotifier {
  static const String _baseUrl = 'http://localhost:8686';
  static const String _defaultLayer = 'l1'; // Changed from l2 to l1
  static const double _defaultZoom = 2024.0;

  bool _isLoading = false;
  String? _lastError;
  Uint8List? _gerberImage;
  Map<String, dynamic>? _lastMetadata;

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  Uint8List? get gerberImage => _gerberImage;
  Map<String, dynamic>? get lastMetadata => _lastMetadata;
  bool get hasImage => _gerberImage != null;

  /// Gửi request tới QCamber để lấy ảnh Gerber
  ///
  /// Parameters:
  /// - modelName: Tên model (job name) từ tbModel.name
  /// - coordinates: Map chứa x, y từ defect ('{"x": 150, "y": 250}')
  /// - defectType: (optional) Loại defect để hiển thị
  /// - layerName: (default: 'l2') Tên layer
  /// - zoom: (default: 128.0) Mức zoom
  /// - timeout: (default: 30) Timeout in seconds
  ///
  /// Returns: true nếu thành công, false nếu lỗi
  Future<bool> captureGerberImage({
    required String modelName,
    required Map<String, dynamic> coordinates,
    String? defectType,
    String layerName = _defaultLayer,
    double zoom = _defaultZoom,
    int timeout = 30,
  }) async {
    _isLoading = true;
    _lastError = null;
    _gerberImage = null;
    _lastMetadata = null;
    notifyListeners();

    try {
      debugPrint(
        '🔍 QCamber: Requesting gerber image for model=$modelName, coords=$coordinates, layer=$layerName, zoom=$zoom',
      );

      // Extract x, y từ coordinates
      final x = _extractCoordinate(coordinates, 'x');
      final y = _extractCoordinate(coordinates, 'y');

      if (x == null || y == null) {
        throw Exception(
          'Tọa độ không hợp lệ: x=$x, y=$y. Coordinates format: {"x": 150, "y": 250}',
        );
      }

      // Build request payload
      final payload = {
        'jobName': modelName,
        'layerName': layerName,
        'x': x,
        'y': y,
        'zoom': 8096.0, // Doubled from 4048.0
      };

      debugPrint('📤 QCamber Payload: ${jsonEncode(payload)}');

      // Send POST request
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/capture'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(
            Duration(seconds: timeout),
            onTimeout: () {
              throw TimeoutException(
                'QCamber request timeout after $timeout seconds',
              );
            },
          );

      debugPrint('📥 QCamber Response: Status=${response.statusCode}');

      if (response.statusCode != 200) {
        _lastError = 'HTTP ${response.statusCode}: ${response.body}';
        debugPrint('❌ QCamber Error: $_lastError');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check content type
      final contentType = response.headers['content-type'] ?? '';
      debugPrint('📋 Content-Type: $contentType');

      if (contentType.contains('image/png')) {
        // Nhận trực tiếp ảnh PNG
        _gerberImage = response.bodyBytes;
        _lastMetadata = {
          'modelName': modelName,
          'layerName': layerName,
          'x': x,
          'y': y,
          'zoom': zoom,
          'defectType': defectType,
          'imageSize': _gerberImage!.length,
          'timestamp': DateTime.now().toIso8601String(),
        };

        debugPrint(
          '✅ QCamber Success: Received PNG image (${_gerberImage!.length} bytes)',
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else if (contentType.contains('application/json')) {
        // JSON response (acknowledgment)
        final jsonResponse = jsonDecode(response.body);
        _lastMetadata = jsonResponse;
        _lastError =
            'QCamber returned acknowledgment but no image data. Response: $jsonResponse';
        debugPrint('⚠️ QCamber: $_lastError');
        _isLoading = false;
        notifyListeners();
        return false;
      } else {
        _lastError = 'Unexpected content type: $contentType';
        debugPrint('❌ QCamber: $_lastError');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on TimeoutException catch (e) {
      _lastError = 'Timeout: ${e.message}';
      debugPrint('❌ QCamber Timeout: $_lastError');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = 'Error: $e';
      debugPrint('❌ QCamber Exception: $_lastError');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Extract numeric value từ coordinates map
  /// Hỗ trợ cả JSON string và Map object
  double? _extractCoordinate(Map<String, dynamic> coordinates, String key) {
    try {
      final value = coordinates[key];
      if (value == null) return null;

      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value);
      }
      return null;
    } catch (e) {
      debugPrint('Error extracting coordinate $key: $e');
      return null;
    }
  }

  /// Parse coordinates string thành Map
  /// Hỗ trợ hai format:
  /// 1. JSON format: '{"x": 150.5, "y": 250.3}'
  /// 2. Semicolon format: '1.518795;2.0109942'
  static Map<String, dynamic>? parseCoordinatesString(String coordinatesStr) {
    try {
      if (coordinatesStr.isEmpty) return null;

      // Format 1: JSON string '{"x": 150, "y": 250}'
      if (coordinatesStr.startsWith('{')) {
        final parsed = jsonDecode(coordinatesStr);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
        return null;
      }

      // Format 2: Semicolon-separated 'x;y' (e.g., '1.518795;2.0109942')
      if (coordinatesStr.contains(';')) {
        final parts = coordinatesStr.split(';');
        if (parts.length >= 2) {
          final x = double.tryParse(parts[0].trim());
          final y = double.tryParse(parts[1].trim());
          if (x != null && y != null) {
            return {'x': x, 'y': y};
          }
        }
        return null;
      }

      // Không nhận diện được format
      debugPrint('Warning: Unknown coordinate format: $coordinatesStr');
      return null;
    } catch (e) {
      debugPrint('Error parsing coordinates: $e');
      return null;
    }
  }

  /// Clear cached image
  void clearImage() {
    _gerberImage = null;
    _lastMetadata = null;
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    clearImage();
    super.dispose();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
