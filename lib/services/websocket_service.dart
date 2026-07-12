import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketService._();

  static final WebSocketService instance = WebSocketService._();

  static const String socketUrl = "ws://192.168.100.241:81";

  WebSocketChannel? _channel;

  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Timer? _reconnectTimer;

  final StreamController<String> _messageController =
      StreamController.broadcast();

  Stream<String> get messages => _messageController.stream;

  // Kết nối với Web Socket

  void connect() {
    if (_isConnected) return;

    print("Đang kết nối WebSocket...");

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(socketUrl),
      );

      _channel!.stream.listen(
        (message) {
          if (!_isConnected) {
            _isConnected = true;
            print("Đã kết nối ESP32");
          }

          _messageController.add(message.toString());
        },
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
      );
    } catch (_) {
      _onDisconnect();
    }
  }

  // Ngắt kết nối WebSocket

  void _onDisconnect() {
    if (_isConnected) {
      print("Mất kết nối ESP32");
    }

    _isConnected = false;

    _channel = null;

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(
      const Duration(seconds: 3),
      () {
        print("Reconnect...");
        connect();
      },
    );
  }

  // Gửi tin nhắn

  void send(String json) {
    if (!_isConnected) {
      print("Chưa kết nối");
      return;
    }

    _channel?.sink.add(json);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
  }
}