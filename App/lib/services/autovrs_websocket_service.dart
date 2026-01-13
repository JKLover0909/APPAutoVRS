import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AutoVRSWebSocketService extends ChangeNotifier {
  static const String defaultServerUrl = 'ws://localhost:8999';
  // SICK Camera WebSocket Stream (port 8999)
  // Old C++ module was on ws://127.0.0.1:12345/

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // ValueNotifiers for better performance
  final ValueNotifier<bool> _isConnectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Uint8List?> _currentFrameNotifier =
      ValueNotifier<Uint8List?>(null);
  final ValueNotifier<Uint8List?> _capturedImageNotifier =
      ValueNotifier<Uint8List?>(null);
  final ValueNotifier<bool> _isViewingCapturedImageNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<int> _frameCountNotifier = ValueNotifier<int>(0);

  // Legacy properties for compatibility
  bool _isConnected = false;
  Uint8List? _currentFrame;
  Uint8List? _capturedImage;
  bool _isViewingCapturedImage = false;
  Map<String, dynamic>? _lastDetectionResults;
  Map<String, dynamic>? _lastAnalysis;
  List<Map<String, dynamic>>? _capturedDetections;
  String? _lastError;
  int _frameCount = 0;

  // ValueNotifier getters for optimized UI updates
  ValueNotifier<bool> get isConnectedNotifier => _isConnectedNotifier;
  ValueNotifier<Uint8List?> get currentFrameNotifier => _currentFrameNotifier;
  ValueNotifier<Uint8List?> get capturedImageNotifier => _capturedImageNotifier;
  ValueNotifier<bool> get isViewingCapturedImageNotifier =>
      _isViewingCapturedImageNotifier;
  ValueNotifier<int> get frameCountNotifier => _frameCountNotifier;

  // Legacy getters for backward compatibility
  bool get isConnected => _isConnected;
  Uint8List? get currentFrame => _currentFrame;
  Uint8List? get capturedImage => _capturedImage;
  bool get isViewingCapturedImage => _isViewingCapturedImage;
  Map<String, dynamic>? get lastDetectionResults => _lastDetectionResults;
  Map<String, dynamic>? get lastAnalysis => _lastAnalysis;
  List<Map<String, dynamic>>? get capturedDetections => _capturedDetections;
  String? get lastError => _lastError;
  int get frameCount => _frameCount;

  // Getter để lấy detections từ lastDetectionResults
  List<Map<String, dynamic>>? get detections {
    if (_lastDetectionResults != null &&
        _lastDetectionResults!['detections'] != null) {
      return (_lastDetectionResults!['detections'] as List)
          .cast<Map<String, dynamic>>();
    }
    return null;
  }

  // Phương thức để lấy ảnh hiện tại đang hiển thị
  Uint8List? get displayImage {
    if (_isViewingCapturedImage && _capturedImage != null) {
      return _capturedImage;
    }
    return _currentFrame;
  }

  /// Kết nối đến AutoVRS WebSocket server
  Future<bool> connect({
    String serverUrl = defaultServerUrl,
    String clientId = 'flutter_client',
  }) async {
    try {
      await disconnect(); // Đóng kết nối cũ nếu có

      // SICK camera doesn't need /ws/clientId path, just direct connection
      final uri = Uri.parse(serverUrl);
      _channel = WebSocketChannel.connect(uri);

      // Lắng nghe messages từ server
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _isConnectedNotifier.value = true;
      _lastError = null;
      notifyListeners();

      // Don't send ping to SICK camera - it only streams binary JPEG
      debugPrint('✅ Connected to SICK camera backend');

      return true;
    } catch (e) {
      _lastError = 'Connection failed: $e';
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Ngắt kết nối WebSocket
  Future<void> disconnect() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }

    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    _isConnected = false;
    _currentFrame = null;
    notifyListeners();
  }

  /// Xử lý message từ server
  void _handleMessage(dynamic message) {
    try {
      if (message is Uint8List) {
        // Nếu là dữ liệu nhị phân (ảnh JPEG)
        // debugPrint('🖼️ Received JPEG frame (${message.length} bytes)');
        // TODO: Xử lý hiển thị ảnh lên UI hoặc lưu frame
        // Ví dụ: _currentFrame = message;
        _currentFrame = message;
        _currentFrameNotifier.value = message;
        _frameCount++;
        _frameCountNotifier.value = _frameCount;
        optimizeMemory();
        if (_frameCount % 5 == 0) notifyListeners();
        if (_frameCount % 30 == 0)
          // debugPrint('📹 Frame processed: $_frameCount')
          ;
      } else if (message is String) {
        // Nếu là text (JSON)
        try {
          final data = jsonDecode(message);
          if (data is Map<String, dynamic>) {
            final type =
                data['type'] ?? data['command']; // Hỗ trợ cả type và command
            if (type == 'info' || type == 'connection') {
              // Xử lý thông tin camera hoặc kết nối
              debugPrint('--- Thông tin từ Server ---');
              debugPrint('  Serial Number: ${data['serial_number']}');
              debugPrint('  Sensor: ${data['sensor_name']}');
              debugPrint(
                '  Max Resolution: ${data['max_width']}x${data['max_height']}',
              );
              debugPrint('---------------------------------');
              _handleConnectionMessage(data);
            } else if (type == 'video_frame') {
              _handleVideoFrame(data);
            } else if (type == 'capture_response' || type == 'ai_detection') {
              debugPrint('📥 CAPTURE_RESPONSE/AI_DETECTION received!');
              _handleCaptureResponse(data);
            } else if (type == 'camera_status') {
              _handleCameraStatus(data);
            } else if (type == 'pong') {
              _handlePong(data);
            } else {
              debugPrint('📩 Message type/command: $type');
            }
          } else {
            debugPrint('❌ JSON không phải Map: $data');
          }
        } catch (e) {
          debugPrint('❌ Không parse được JSON: $message');
        }
      } else {
        debugPrint('❓ Message không xác định kiểu: $message');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi xử lý message: $e');
    }
  }

  /// Xử lý video frame với base64 JPEG từ ngrok
  void _handleVideoFrame(Map<String, dynamic> data) {
    try {
      // Xử lý base64 JPEG data từ ngrok WebSocket
      final base64Data = data['data'] as String?;
      final jpegData = data['jpeg_data'] as String?; // Alternative key for JPEG

      if (base64Data != null && base64Data.isNotEmpty) {
        final frameData = base64Decode(base64Data);
        _currentFrame = frameData;
        _currentFrameNotifier.value = frameData;
      } else if (jpegData != null && jpegData.isNotEmpty) {
        final frameData = base64Decode(jpegData);
        _currentFrame = frameData;
        _currentFrameNotifier.value = frameData;
      }

      _frameCount = data['frame_info']?['frame_count'] ?? _frameCount + 1;
      _frameCountNotifier.value = _frameCount;

      // Memory optimization
      optimizeMemory();

      // Throttle notifications - chỉ notify mỗi 5 frames để tối ưu performance
      if (_frameCount % 5 == 0) {
        notifyListeners();
      }

      // Memory optimization - giới hạn log output
      if (_frameCount % 30 == 0) {
        debugPrint('📹 Frame processed: $_frameCount');
      }
    } catch (e) {
      if (_frameCount % 10 == 0) {
        // Throttle error logs
        debugPrint('Error handling video frame: $e');
      }
    }
  }

  /// Xử lý response của capture request
  Future<void> _handleCaptureResponse(Map<String, dynamic> data) async {
    debugPrint('🚀 _handleCaptureResponse CALLED');
    debugPrint('🚀 Data keys: ${data.keys.toList()}');

    final success = data['success'] as bool;
    final message = data['message'] as String;

    debugPrint('🚀 Success: $success, Message: $message');

    if (success) {
      // Lưu kết quả phát hiện lỗi và phân tích
      _lastDetectionResults =
          data['detection_results'] as Map<String, dynamic>?;
      _lastAnalysis = data['analysis'] as Map<String, dynamic>?;

      // DEBUG: Log detection data
      if (_lastDetectionResults != null) {
        final numDefects = _lastDetectionResults!['num_defects'] ?? 0;
        final detections = _lastDetectionResults!['detections'] as List?;
        debugPrint('🔍 DETECTION DATA: $numDefects defects found');
        debugPrint('🔍 Detection list: $detections');

        if (detections != null) {
          for (int i = 0; i < detections.length; i++) {
            debugPrint('🔍 Defect $i: ${detections[i]}');
          }
        }
      } else {
        debugPrint('🔍 NO DETECTION RESULTS in response');
      }

      // Xử lý ảnh base64 nếu có - kiểm tra nhiều trường có thể
      final imageData =
          data['image_data'] as String? ??
          data['processed_image_base64'] as String? ??
          data['processed_image'] as String?;
      debugPrint(
        '🔍 Image data received: ${imageData != null ? 'YES (${imageData.length} chars)' : 'NO'}',
      );
      debugPrint('🔍 Available data keys: ${data.keys.toList()}');

      if (imageData != null && imageData.isNotEmpty) {
        try {
          _capturedImage = base64Decode(imageData);
          _isViewingCapturedImage = true;
          debugPrint('🔍 Decoded image: ${_capturedImage!.length} bytes');
          if (_capturedImage != null) {
            await _saveCapturedImageToFolder(_capturedImage!);
          }
          notifyListeners();
        } catch (e) {
          _lastError = 'Failed to decode captured image: $e';
          debugPrint('❌ Failed to decode image: $e');
        }
      } else {
        debugPrint('❌ No image data received or empty');
      }
    } else {
      _lastError = message;
      notifyListeners();
    }
  }

  /// Lưu ảnh capture vào thư mục images_ai
  Future<void> _saveCapturedImageToFolder(Uint8List imageBytes) async {
    debugPrint('🖼️ Starting to save image: ${imageBytes.length} bytes');
    try {
      final folderPath =
          'C:/Users/sonng/OneDrive/Desktop/APPAutoVRS/BE-AutoVRS/images_ai';
      debugPrint('🖼️ Target folder: $folderPath');

      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        debugPrint('🖼️ Creating directory...');
        await dir.create(recursive: true);
        debugPrint('🖼️ Directory created successfully');
      } else {
        debugPrint('🖼️ Directory already exists');
      }

      final now = DateTime.now();
      final fileName =
          'capture_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.jpg';
      final filePath = '$folderPath/$fileName';
      debugPrint('🖼️ Full file path: $filePath');

      final file = File(filePath);

      // Test write simple content first
      debugPrint('🖼️ Testing file write...');
      await file.writeAsString('test');
      debugPrint('🖼️ Test write successful, now writing image bytes...');

      await file.writeAsBytes(imageBytes);

      // Verify file was written
      final fileExists = await file.exists();
      final fileSize = await file.length();
      debugPrint(
        '🖼️ ✅ File written - exists: $fileExists, size: $fileSize bytes',
      );
      debugPrint('🖼️ ✅ Successfully saved captured image to: $filePath');
    } catch (e) {
      debugPrint('❌ Error saving captured image: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Quay lại chế độ xem live camera
  void returnToLiveCamera() {
    _isViewingCapturedImage = false;
    _capturedImage = null;
    _lastDetectionResults = null;
    _lastAnalysis = null;
    debugPrint(
      'State changed: returnToLiveCamera - isViewingCapturedImage = $_isViewingCapturedImage',
    );
    notifyListeners();
  }

  /// Xử lý connection message
  void _handleConnectionMessage(Map<String, dynamic> data) {
    debugPrint('Connected to server: ${data['status']}');
  }

  /// Xử lý pong response
  void _handlePong(Map<String, dynamic> data) {
    debugPrint('Pong received from server');
  }

  /// Xử lý lỗi WebSocket
  void _handleError(error) {
    _lastError = 'WebSocket error: $error';
    _isConnected = false;
    notifyListeners();
    debugPrint('WebSocket error: $error');
  }

  /// Xử lý khi kết nối bị đóng
  void _handleDisconnect() {
    _isConnected = false;
    _currentFrame = null;
    notifyListeners();
    debugPrint('WebSocket disconnected');
  }

  void debugSetCapturedState() {
    debugPrint('🔧 DEBUG: Force setting captured state');
    _capturedImage = _currentFrame; // Sử dụng frame hiện tại làm captured image
    _isViewingCapturedImage = true;
    _capturedDetections = [
      {'x': 100, 'y': 100, 'width': 50, 'height': 50, 'confidence': 0.95},
    ]; // Test detection
    notifyListeners();
    debugPrint(
      '🔧 DEBUG: State set - isViewingCapturedImage: $_isViewingCapturedImage',
    );
  }

  /// Set captured image để hiển thị thay vì live stream
  void setCapturedImage(Uint8List imageData) {
    _capturedImage = imageData;
    notifyListeners();
    debugPrint('📸 Captured image set (${imageData.length} bytes)');
  }

  /// Set trạng thái xem captured image hay live stream
  void setViewingCapturedImage(bool isViewing) {
    _isViewingCapturedImage = isViewing;
    notifyListeners();
    debugPrint('🔄 Viewing captured image: $isViewing');
  }

  /// Gửi request chụp ảnh
  Future<void> captureImage({
    String? filename,
    bool enableDetection = true,
  }) async {
    debugPrint('📤 CAPTURE IMAGE CALLED (SICK Camera Mode)');

    if (!_isConnected) {
      debugPrint('📤 ERROR: Not connected to server');
      throw Exception('Not connected to camera server');
    }

    // SICK camera mode: Capture current frame and send to AI API
    if (_currentFrame == null) {
      debugPrint('📤 ERROR: No current frame available');
      throw Exception('No frame available to capture');
    }

    try {
      // Save current frame as captured image
      _capturedImage = _currentFrame;
      _capturedImageNotifier.value = _currentFrame;
      _isViewingCapturedImage = true;
      _isViewingCapturedImageNotifier.value = true;

      debugPrint('📸 Frame captured (${_currentFrame!.length} bytes)');

      // Send to AI detection API if enabled
      if (enableDetection) {
        await _sendToAIDetection(_currentFrame!);
      }

      notifyListeners();
    } catch (e) {
      _lastError = 'Capture failed: $e';
      debugPrint('❌ Capture error: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Send image to AI Detection API (port 8082)
  Future<void> _sendToAIDetection(Uint8List imageBytes) async {
    try {
      debugPrint('🤖 Sending to AI Detection API (port 8082)...');

      final uri = Uri.parse('http://localhost:8082/detect');
      final request = http.MultipartRequest('POST', uri);

      // Add image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Store detection results
        _lastDetectionResults = data;
        _lastAnalysis = data['analysis'] as Map<String, dynamic>?;

        debugPrint('✅ AI Detection complete: ${data['num_defects']} defects');
        debugPrint('🔍 Detection data: $data');

        notifyListeners();
      } else {
        _lastError = 'AI Detection failed: ${response.statusCode}';
        debugPrint('❌ AI API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _lastError = 'AI Detection error: $e';
      debugPrint('❌ AI Detection exception: $e');
    }
  }

  /// Gửi request lấy status
  /// DISABLED: SICK camera doesn't support JSON commands
  // Future<void> requestStatus() async {
  //   if (!_isConnected || _channel == null) {
  //     throw Exception('Not connected to server');
  //   }
  //
  //   final message = {'command': 'get_status'};
  //
  //   _channel!.sink.add(jsonEncode(message));
  // }

  /// Bật/tắt defect detection
  /// DISABLED: SICK camera doesn't support JSON commands
  /// Detection is handled separately via AI API (port 8082)
  // Future<void> setDetectionEnabled(bool enabled) async {
  //   if (!_isConnected || _channel == null) {
  //     throw Exception('Not connected to server');
  //   }
  //
  //   final message = {
  //     'command': 'set_detection',
  //     'request_id': 'detection_${DateTime.now().millisecondsSinceEpoch}',
  //     'enabled': enabled,
  //   };
  //
  //   _channel!.sink.add(jsonEncode(message));
  // }

  /// Xử lý camera status messages
  void _handleCameraStatus(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    final message = data['message'] as String?;

    if (status == 'waiting') {
      debugPrint('Camera status: $message');
      // Có thể hiển thị loading indicator trong UI
    }
  }

  /// Gửi ping để test kết nối
  /// DISABLED: SICK camera only streams binary JPEG, doesn't handle JSON commands
  // Future<void> _sendPing() async {
  //   if (!_isConnected || _channel == null) return;
  //
  //   final message = {
  //     'command': 'ping',
  //     'timestamp': DateTime.now().millisecondsSinceEpoch,
  //   };
  //
  //   _channel!.sink.add(jsonEncode(message));
  // }

  /// Memory optimization: Clear old frame data
  void _clearOldFrames() {
    // Keep only current frame, clear any cached data
    _currentFrame = null;
    _currentFrameNotifier.value = null;

    // Force garbage collection hint
    // debugPrint('🗑️ Cleared old frame data for memory optimization');
  }

  /// Optimize memory usage by cleaning up resources
  void optimizeMemory() {
    if (_frameCount % 100 == 0) {
      // Every 100 frames
      _clearOldFrames();
    }
  }

  @override
  void dispose() {
    // Dispose ValueNotifiers
    _currentFrameNotifier.dispose();
    _frameCountNotifier.dispose();

    // Disconnect WebSocket
    disconnect();

    // Clear all data
    _currentFrame = null;
    _capturedImage = null;
    _lastDetectionResults = null;
    _lastAnalysis = null;
    _capturedDetections = null;

    super.dispose();
    debugPrint('🗑️ AutoVRSWebSocketService disposed and cleaned up');
  }
}
