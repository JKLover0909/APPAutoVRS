import 'dart:convert';
import 'dart:io';
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
    double confidenceThreshold = 0.25,
    double iouThreshold = 0.1,
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

        // Lưu ảnh processed nếu có
        if (_lastResult!.processedImage != null) {
          await _saveProcessedImage(_lastResult!.processedImage!);
        }

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

  /// Lưu ảnh đã xử lý AI detection vào thư mục
  Future<void> _saveProcessedImage(Uint8List imageBytes) async {
    debugPrint(
      '🖼️ Starting to save processed image: ${imageBytes.length} bytes',
    );
    try {
      final folderPath =
          'C:/Users/sonng/OneDrive/Desktop/APPAutoVRS/BE-AutoVRS/images_ai';
      debugPrint('🖼️ Target folder: $folderPath');

      final dir = Directory(folderPath);
      final dirExists = await dir.exists();
      debugPrint('🖼️ Directory exists: $dirExists');

      if (!dirExists) {
        debugPrint('🖼️ Creating directory...');
        await dir.create(recursive: true);
        debugPrint('🖼️ Directory created successfully');
      }

      final now = DateTime.now();
      final fileName =
          'ai_processed_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.jpg';
      final filePath = '$folderPath/$fileName';
      debugPrint('🖼️ Full file path: $filePath');

      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      // Verify file was written
      final fileExists = await file.exists();
      final fileSize = await file.length();
      debugPrint(
        '🖼️ ✅ File written - exists: $fileExists, size: $fileSize bytes',
      );
      debugPrint('🖼️ ✅ Successfully saved AI processed image to: $filePath');
    } catch (e) {
      debugPrint('❌ Error saving processed image: $e');
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
