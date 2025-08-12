import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class AutoVRSWebSocketService extends ChangeNotifier {
  static const String defaultServerUrl = 'wss://5d0fc6ea5f81.ngrok-free.app/';

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
    debugPrint(
      '🖼️ displayImage called - isViewingCaptured: $_isViewingCapturedImage',
    );
    debugPrint('🖼️ _capturedImage available: ${_capturedImage != null}');
    debugPrint('🖼️ _currentFrame available: ${_currentFrame != null}');

    if (_isViewingCapturedImage && _capturedImage != null) {
      debugPrint(
        '🖼️ Returning captured image (${_capturedImage!.length} bytes)',
      );
      return _capturedImage;
    } else {
      debugPrint(
        '🖼️ Returning current frame (${_currentFrame?.length ?? 0} bytes)',
      );
      return _currentFrame;
    }
  }

  /// Kết nối đến AutoVRS WebSocket server
  Future<bool> connect({
    String serverUrl = defaultServerUrl,
    String clientId = 'flutter_client',
  }) async {
    try {
      await disconnect(); // Đóng kết nối cũ nếu có

      final uri = Uri.parse('$serverUrl/ws/$clientId');
      _channel = WebSocketChannel.connect(uri);

      // Lắng nghe messages từ server
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _lastError = null;
      notifyListeners();

      // Gửi ping để test kết nối
      await _sendPing();

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
      final data = jsonDecode(message.toString());
      final messageType = data['type'];

      debugPrint('📥 Message received: $messageType');

      switch (messageType) {
        case 'video_frame':
          _handleVideoFrame(data);
          break;
        case 'capture_response':
          debugPrint('📥 CAPTURE_RESPONSE received!');
          _handleCaptureResponse(data);
          break;
        case 'connection':
          _handleConnectionMessage(data);
          break;
        case 'camera_status':
          _handleCameraStatus(data);
          break;
        case 'pong':
          _handlePong(data);
          break;
        default:
          debugPrint('Unknown message type: $messageType');
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
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
  void _handleCaptureResponse(Map<String, dynamic> data) {
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

      // Xử lý ảnh base64 nếu có
      final imageData = data['image_data'] as String?;

      if (imageData != null && imageData.isNotEmpty) {
        try {
          _capturedImage = base64Decode(imageData);
          _isViewingCapturedImage = true;
          notifyListeners();
        } catch (e) {
          _lastError = 'Failed to decode captured image: $e';
        }
      } else {
        debugPrint('❌ No image data received or empty');
      }
    } else {
      _lastError = message;
      notifyListeners();
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
    debugPrint('📤 CAPTURE IMAGE CALLED');

    if (!_isConnected || _channel == null) {
      debugPrint('📤 ERROR: Not connected to server');
      throw Exception('Not connected to server');
    }

    final message = {
      'type': 'capture_image',
      'request_id': 'capture_${DateTime.now().millisecondsSinceEpoch}',
      'enable_detection': enableDetection,
      if (filename != null) 'filename': filename,
    };

    debugPrint('📤 Sending message: $message');
    _channel!.sink.add(jsonEncode(message));
    debugPrint('📤 Message sent to WebSocket');
  }

  /// Gửi request lấy status
  Future<void> requestStatus() async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to server');
    }

    final message = {'type': 'get_status'};

    _channel!.sink.add(jsonEncode(message));
  }

  /// Bật/tắt defect detection
  Future<void> setDetectionEnabled(bool enabled) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to server');
    }

    final message = {
      'type': 'set_detection',
      'request_id': 'detection_${DateTime.now().millisecondsSinceEpoch}',
      'enabled': enabled,
    };

    _channel!.sink.add(jsonEncode(message));
  }

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
  Future<void> _sendPing() async {
    if (!_isConnected || _channel == null) return;

    final message = {
      'type': 'ping',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _channel!.sink.add(jsonEncode(message));
  }

  /// Memory optimization: Clear old frame data
  void _clearOldFrames() {
    // Keep only current frame, clear any cached data
    _currentFrame = null;
    _currentFrameNotifier.value = null;

    // Force garbage collection hint
    debugPrint('🗑️ Cleared old frame data for memory optimization');
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
