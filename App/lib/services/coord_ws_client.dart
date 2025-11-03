import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef OnMessage = void Function(Map<String, dynamic> msg);

class CoordWsClient {
  final String uri;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  OnMessage? onMessage;

  CoordWsClient({this.uri = 'ws://127.0.0.1:8765'});

  Future<void> connect() async {
    await disconnect();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(uri));
      debugPrint('CoordWsClient: connected to $uri');
      _sub = _channel!.stream.listen(
        (dynamic msg) {
          try {
            if (msg is String) {
              final data = jsonDecode(msg) as Map<String, dynamic>;
              debugPrint(
                'CoordWsClient: received message ${data['type'] ?? ''}',
              );
              onMessage?.call(data);
            }
          } catch (e, st) {
            debugPrint('CoordWsClient: error parsing message: $e\n$st');
          }
        },
        onDone: () {
          debugPrint('CoordWsClient: connection closed');
          _cleanup();
        },
        onError: (err, st) {
          debugPrint('CoordWsClient: connection error: $err\n$st');
          _cleanup();
        },
      );
    } catch (e, st) {
      debugPrint('CoordWsClient: failed to connect to $uri: $e\n$st');
      _cleanup();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _cleanup();
  }

  void _cleanup() {
    _sub = null;
    _channel = null;
  }

  void sendCoords({
    required int boardId,
    required int defectId,
    required num x,
    required num y,
  }) {
    final msg = {
      'type': 'coords',
      'board_id': boardId,
      'defect_id': defectId,
      'x': x,
      'y': y,
    };
    final jsonMsg = jsonEncode(msg);
    if (_channel == null) {
      debugPrint(
        'CoordWsClient: cannot send coords, not connected. msg=$jsonMsg',
      );
      return;
    }
    try {
      _channel!.sink.add(jsonMsg);
      debugPrint('CoordWsClient: sent coords: $jsonMsg');
    } catch (e, st) {
      debugPrint('CoordWsClient: failed to send coords: $e\n$st');
    }
  }

  /// Send the raw coordinates string (e.g. "4.0,4.0") instead of numeric x/y
  void sendCoordsString({
    required int boardId,
    required int defectId,
    required String coords,
  }) {
    final msg = {
      'type': 'coords',
      'board_id': boardId,
      'defect_id': defectId,
      'coordinates': coords,
    };
    final jsonMsg = jsonEncode(msg);
    if (_channel == null) {
      debugPrint(
        'CoordWsClient: cannot send coords (string), not connected. msg=$jsonMsg',
      );
      return;
    }
    try {
      _channel!.sink.add(jsonMsg);
      debugPrint('CoordWsClient: sent coords (string): $jsonMsg');
    } catch (e, st) {
      debugPrint('CoordWsClient: failed to send coords (string): $e\n$st');
    }
  }

  void sendResult(Map<String, dynamic> result) {
    final msg = {'type': 'result', 'result': result};
    final jsonMsg = jsonEncode(msg);
    if (_channel == null) {
      debugPrint(
        'CoordWsClient: cannot send result, not connected. result=$jsonMsg',
      );
      return;
    }
    try {
      _channel!.sink.add(jsonMsg);
      debugPrint('CoordWsClient: sent result');
    } catch (e, st) {
      debugPrint('CoordWsClient: failed to send result: $e\n$st');
    }
  }
}
