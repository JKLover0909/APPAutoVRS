"""
WebSocket Service for Flutter Frontend
Tích hợp vào Flutter app để kết nối với AutoVRS Backend
"""

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class AutoVRSWebSocketService extends ChangeNotifier {
  static const String defaultServerUrl = 'ws://localhost:8000';
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  Uint8List? _currentFrame;
  String? _lastError;
  int _frameCount = 0;
  
  // Getters
  bool get isConnected => _isConnected;
  Uint8List? get currentFrame => _currentFrame;
  String? get lastError => _lastError;
  int get frameCount => _frameCount;
  
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
      
      switch (messageType) {
        case 'video_frame':
          _handleVideoFrame(data);
          break;
        case 'capture_response':
          _handleCaptureResponse(data);
          break;
        case 'connection':
          _handleConnectionMessage(data);
          break;
        case 'pong':
          _handlePong(data);
          break;
        default:
          print('Unknown message type: $messageType');
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }
  
  /// Xử lý video frame
  void _handleVideoFrame(Map<String, dynamic> data) {
    try {
      final base64Data = data['data'] as String;
      _currentFrame = base64Decode(base64Data);
      _frameCount = data['frame_info']?['frame_count'] ?? _frameCount + 1;
      notifyListeners();
    } catch (e) {
      print('Error handling video frame: $e');
    }
  }
  
  /// Xử lý response của capture request
  void _handleCaptureResponse(Map<String, dynamic> data) {
    final success = data['success'] as bool;
    final message = data['message'] as String;
    
    if (success) {
      print('Capture successful: $message');
      // Có thể trigger callback hoặc event tại đây
    } else {
      print('Capture failed: $message');
      _lastError = message;
      notifyListeners();
    }
  }
  
  /// Xử lý connection message
  void _handleConnectionMessage(Map<String, dynamic> data) {
    print('Connected to server: ${data['status']}');
  }
  
  /// Xử lý pong response
  void _handlePong(Map<String, dynamic> data) {
    print('Pong received from server');
  }
  
  /// Xử lý lỗi WebSocket
  void _handleError(error) {
    _lastError = 'WebSocket error: $error';
    _isConnected = false;
    notifyListeners();
    print('WebSocket error: $error');
  }
  
  /// Xử lý khi kết nối bị đóng
  void _handleDisconnect() {
    _isConnected = false;
    _currentFrame = null;
    notifyListeners();
    print('WebSocket disconnected');
  }
  
  /// Gửi request chụp ảnh
  Future<void> captureImage({String? filename}) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to server');
    }
    
    final message = {
      'type': 'capture_image',
      'request_id': 'capture_${DateTime.now().millisecondsSinceEpoch}',
      if (filename != null) 'filename': filename,
    };
    
    _channel!.sink.add(jsonEncode(message));
  }
  
  /// Gửi request lấy status
  Future<void> requestStatus() async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to server');
    }
    
    final message = {
      'type': 'get_status',
    };
    
    _channel!.sink.add(jsonEncode(message));
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
  
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
