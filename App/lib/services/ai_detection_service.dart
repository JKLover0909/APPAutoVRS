import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AIDetectionResult {
  final bool success;
  final String message;
  final List<DefectDetection> detections;
  final Uint8List? processedImage;
  final Map<String, dynamic> statistics;
  final DateTime timestamp;

  AIDetectionResult({
    required this.success,
    required this.message,
    required this.detections,
    this.processedImage,
    required this.statistics,
    required this.timestamp,
  });

  factory AIDetectionResult.fromJson(Map<String, dynamic> json) {
    return AIDetectionResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      detections:
          (json['detections'] as List?)
              ?.map((d) => DefectDetection.fromJson(d))
              .toList() ??
          [],
      processedImage: json['processed_image_base64'] != null
          ? base64Decode(json['processed_image_base64'])
          : null,
      statistics: json['statistics'] ?? {},
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class DefectDetection {
  final List<int> bbox;
  final double confidence;
  final int classId;
  final String className;
  final String classNameVi;
  final Map<String, int> coordinates;

  DefectDetection({
    required this.bbox,
    required this.confidence,
    required this.classId,
    required this.className,
    required this.classNameVi,
    required this.coordinates,
  });

  factory DefectDetection.fromJson(Map<String, dynamic> json) {
    return DefectDetection(
      bbox: List<int>.from(json['bbox'] ?? []),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      classId: json['class_id'] ?? 0,
      className: json['class_name'] ?? '',
      classNameVi: json['class_name_vi'] ?? '',
      coordinates: Map<String, int>.from(json['coordinates'] ?? {}),
    );
  }
}

class AIDetectionService extends ChangeNotifier {
  static const String _baseUrl = 'http://localhost:8082';

  bool _isLoading = false;
  String? _lastError;
  AIDetectionResult? _lastResult;

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  AIDetectionResult? get lastResult => _lastResult;

  Future<AIDetectionResult?> detectDefects({
    required Uint8List imageData,
    double confidenceThreshold = 0.5,
    double iouThreshold = 0.4,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      // Convert image to base64
      final base64Image = base64Encode(imageData);

      // Prepare request
      final request = {
        'image_base64': base64Image,
        'confidence_threshold': confidenceThreshold,
        'iou_threshold': iouThreshold,
      };

      debugPrint('🤖 Sending AI detection request...');

      // Send POST request
      final response = await http.post(
        Uri.parse('$_baseUrl/api/ai-detection'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _lastResult = AIDetectionResult.fromJson(responseData);

        debugPrint(
          '✅ AI detection successful: ${_lastResult!.detections.length} defects found',
        );

        return _lastResult;
      } else {
        _lastError = 'HTTP ${response.statusCode}: ${response.body}';
        debugPrint('❌ AI detection failed: $_lastError');
        return null;
      }
    } catch (e) {
      _lastError = 'Network error: $e';
      debugPrint('❌ AI detection error: $_lastError');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Health check failed: $e');
      return false;
    }
  }

  void clearResults() {
    _lastResult = null;
    _lastError = null;
    notifyListeners();
  }
}
