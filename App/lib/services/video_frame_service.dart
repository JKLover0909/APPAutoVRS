import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Service để kết nối với Python Video Frame Streaming Server
/// Port: 8081 (khác với AutoVRS WebSocket port 8000)
class VideoFrameService extends ChangeNotifier {
  static final VideoFrameService _instance = VideoFrameService._internal();
  factory VideoFrameService() => _instance;
  VideoFrameService._internal();

  // WebSocket connection
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  // Connection state
  bool _isConnected = false;
  bool _shouldReconnect = true;
  String _serverUrl = 'ws://localhost:8081';

  // Video frame data
  Uint8List? _currentFrame;
  int _frameId = 0;
  int _videoWidth = 0;
  int _videoHeight = 0;
  double _videoFps = 30.0;
  int _totalFrames = 0;
  DateTime? _lastFrameTime;

  // Statistics
  int _framesReceived = 0;
  int _connectionAttempts = 0;

  // Getters
  bool get isConnected => _isConnected;
  Uint8List? get currentFrame => _currentFrame;
  int get frameId => _frameId;
  int get videoWidth => _videoWidth;
  int get videoHeight => _videoHeight;
  double get videoFps => _videoFps;
  int get totalFrames => _totalFrames;
  int get framesReceived => _framesReceived;
  bool get hasFrame => _currentFrame != null;

  /// Kết nối tới Video Frame Server
  Future<bool> connect({String? customUrl}) async {
    try {
      if (customUrl != null) {
        _serverUrl = customUrl;
      }

      _shouldReconnect = true;
      _connectionAttempts++;

      debugPrint('🎬 [VideoFrameService] Connecting to: $_serverUrl (Attempt: $_connectionAttempts)');

      // Tạo WebSocket connection
      _channel = IOWebSocketChannel.connect(Uri.parse(_serverUrl));

      // Lắng nghe messages
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
      );

      _isConnected = true;
      _startHeartbeat();

      debugPrint('✅ [VideoFrameService] Connected successfully');
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('❌ [VideoFrameService] Connection failed: $e');
      _isConnected = false;
      _scheduleReconnect();
      notifyListeners();
      return false;
    }
  }

  /// Ngắt kết nối
  void disconnect() {
    _shouldReconnect = false;
    _stopHeartbeat();
    _stopReconnectTimer();

    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _currentFrame = null;

    debugPrint('🛑 [VideoFrameService] Disconnected');
    notifyListeners();
  }

  /// Xử lý message từ server
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final messageType = data['type'] as String?;

      switch (messageType) {
        case 'video_info':
          _handleVideoInfo(data);
          break;
        case 'video_frame':
          _handleVideoFrame(data);
          break;
        default:
          debugPrint('🤷 [VideoFrameService] Unknown message type: $messageType');
      }
    } catch (e) {
      debugPrint('❌ [VideoFrameService] Error parsing message: $e');
    }
  }

  /// Xử lý thông tin video
  void _handleVideoInfo(Map<String, dynamic> data) {
    try {
      _videoWidth = data['width'] ?? 0;
      _videoHeight = data['height'] ?? 0;
      _videoFps = (data['fps'] ?? 30.0).toDouble();
      _totalFrames = data['total_frames'] ?? 0;

      debugPrint('📹 [VideoFrameService] Video Info Received:');
      debugPrint('   📏 Resolution: ${_videoWidth}x$_videoHeight');
      debugPrint('   ⚡ FPS: $_videoFps');
      debugPrint('   🎬 Total Frames: $_totalFrames');
      debugPrint('   ⏱️ Duration: ${(_totalFrames / _videoFps).toStringAsFixed(2)}s');

      notifyListeners();
    } catch (e) {
      debugPrint('❌ [VideoFrameService] Error handling video info: $e');
    }
  }

  /// Xử lý video frame
  void _handleVideoFrame(Map<String, dynamic> data) {
    try {
      final base64Data = data['image_data'] as String?;
      if (base64Data == null) return;

      // Decode base64 thành Uint8List
      _currentFrame = base64Decode(base64Data);
      _frameId = data['frame_id'] ?? _frameId + 1;
      _framesReceived++;
      _lastFrameTime = DateTime.now();

      // Log statistics mỗi 100 frames
      if (_framesReceived % 100 == 0) {
        debugPrint('📊 [VideoFrameService] Frames received: $_framesReceived, Current frame: $_frameId');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ [VideoFrameService] Error handling video frame: $e');
    }
  }

  /// Xử lý lỗi connection
  void _onError(error) {
    debugPrint('❌ [VideoFrameService] Connection error: $error');
    _isConnected = false;
    _scheduleReconnect();
    notifyListeners();
  }

  /// Xử lý khi connection bị ngắt
  void _onDisconnected() {
    debugPrint('🔌 [VideoFrameService] Connection lost');
    _isConnected = false;
    _stopHeartbeat();

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
    
    notifyListeners();
  }

  /// Lên lịch reconnect
  void _scheduleReconnect() {
    _stopReconnectTimer();
    
    const reconnectDelay = Duration(seconds: 3);
    debugPrint('🔄 [VideoFrameService] Scheduling reconnect in ${reconnectDelay.inSeconds}s...');
    
    _reconnectTimer = Timer(reconnectDelay, () {
      if (_shouldReconnect && !_isConnected) {
        connect();
      }
    });
  }

  /// Bắt đầu heartbeat
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        try {
          final ping = jsonEncode({
            'type': 'ping',
            'timestamp': DateTime.now().toIso8601String(),
          });
          _channel!.sink.add(ping);
        } catch (e) {
          debugPrint('❌ [VideoFrameService] Heartbeat error: $e');
        }
      }
    });
  }

  /// Dừng heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Dừng reconnect timer
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Lấy thống kê kết nối
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _isConnected,
      'serverUrl': _serverUrl,
      'framesReceived': _framesReceived,
      'currentFrameId': _frameId,
      'connectionAttempts': _connectionAttempts,
      'videoWidth': _videoWidth,
      'videoHeight': _videoHeight,
      'videoFps': _videoFps,
      'totalFrames': _totalFrames,
      'lastFrameTime': _lastFrameTime?.toIso8601String(),
      'hasFrame': hasFrame,
    };
  }

  /// Làm sạch tài nguyên
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
