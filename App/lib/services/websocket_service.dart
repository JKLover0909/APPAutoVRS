import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  StreamController<Map<String, dynamic>>? _aiProgressController;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  
  bool _isConnected = false;
  bool _shouldReconnect = true;
  String? _serverUrl;
  
  // Getters
  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>>? get messages => _messageController?.stream;
  Stream<Map<String, dynamic>>? get aiProgress => _aiProgressController?.stream;

  Future<void> connect(String serverUrl) async {
    try {
      _serverUrl = serverUrl;
      _shouldReconnect = true;
      
      print('[WebSocket] Connecting to: $serverUrl');
      
      // Create WebSocket connection
      _channel = IOWebSocketChannel.connect(Uri.parse(serverUrl));
      
      // Initialize stream controllers
      _messageController = StreamController<Map<String, dynamic>>.broadcast();
      _aiProgressController = StreamController<Map<String, dynamic>>.broadcast();
      
      // Listen to messages
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
      );
      
      _isConnected = true;
      _startPingTimer();
      
      print('[WebSocket] Connected successfully');
      
      // Subscribe to AI updates
      await subscribeToAIUpdates();
      
    } catch (e) {
      print('[WebSocket] Connection failed: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      print('[WebSocket] Received: $data');
      
      // Route message to appropriate stream
      if (data['type'] == 'ai_progress') {
        _aiProgressController?.add(data);
      } else {
        _messageController?.add(data);
      }
      
      // Handle pong response
      if (data['type'] == 'pong') {
        print('[WebSocket] Pong received');
      }
      
    } catch (e) {
      print('[WebSocket] Error parsing message: $e');
    }
  }

  void _onError(error) {
    print('[WebSocket] Error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _onDisconnected() {
    print('[WebSocket] Disconnected');
    _isConnected = false;
    _stopPingTimer();
    
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _serverUrl == null) return;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && _shouldReconnect) {
        print('[WebSocket] Attempting to reconnect...');
        connect(_serverUrl!);
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        sendMessage({'type': 'ping'});
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> sendMessage(Map<String, dynamic> message) async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] Cannot send message - not connected');
      return;
    }

    try {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
      print('[WebSocket] Sent: $jsonMessage');
    } catch (e) {
      print('[WebSocket] Error sending message: $e');
    }
  }

  Future<void> subscribeToAIUpdates() async {
    await sendMessage({
      'type': 'subscribe_ai_updates'
    });
  }

  Future<void> requestSystemStatus() async {
    await sendMessage({
      'type': 'get_system_status'
    });
  }

  Future<void> testBroadcast() async {
    await sendMessage({
      'type': 'test_broadcast',
      'message': 'Test from Flutter client'
    });
  }

  void disconnect() {
    print('[WebSocket] Disconnecting...');
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _stopPingTimer();
    
    _channel?.sink.close();
    _messageController?.close();
    _aiProgressController?.close();
    
    _isConnected = false;
    _channel = null;
    _messageController = null;
    _aiProgressController = null;
  }

  void dispose() {
    disconnect();
  }
}

// Convenience class for AI progress updates
class AIProgress {
  final int percentage;
  final String message;
  final DateTime timestamp;

  AIProgress({
    required this.percentage,
    required this.message,
    required this.timestamp,
  });

  factory AIProgress.fromJson(Map<String, dynamic> json) {
    return AIProgress(
      percentage: json['percentage'] ?? 0,
      message: json['message'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// Convenience class for system status
class SystemStatus {
  final String status;
  final int connectedClients;
  final String serverTime;
  final String uptime;

  SystemStatus({
    required this.status,
    required this.connectedClients,
    required this.serverTime,
    required this.uptime,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      status: json['status'] ?? 'unknown',
      connectedClients: json['connected_clients'] ?? 0,
      serverTime: json['server_time'] ?? '',
      uptime: json['uptime'] ?? '',
    );
  }
}
