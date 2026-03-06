import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';

class ChatService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  void connect(String roomId) {
    if (_channel != null) return;

    final token = AuthService.token;
    if (token == null) return;

    // TODO: Update URL specifically to your backend deployment
    // Example: ws://192.168.1.100:8080 or wss://yourdomain.com
    final wsUrl = Uri.parse('ws://10.0.2.2:8080/ws/chat/$roomId?token=$token');

    try {
      final channel = WebSocketChannel.connect(wsUrl);
      _channel = channel;

      channel.ready.then((_) {
        if (_channel != channel) return;

        channel.stream.listen(
          (message) {
            try {
              final decoded = jsonDecode(message) as Map<String, dynamic>;
              _messageController.add(decoded);
            } catch (e) {
              debugPrint('Error decoding WebSocket message: $e');
            }
          },
          onError: (error) {
            debugPrint('WebSocket Hatası: $error');
          },
          onDone: () {
            debugPrint('WebSocket Bağlantısı Koptu');
            if (_channel == channel) {
              _channel = null;
            }
          },
        );
      }).catchError((error) {
        debugPrint('WebSocket Bağlantı Hatası: $error');
        if (_channel == channel) {
          _channel = null;
        }
      });
    } catch (e) {
      debugPrint('WebSocket Bağlantı Hatası: $e');
      _channel = null;
    }
  }

  bool sendMessage(String text, {String? clientMessageId}) {
    if (_channel != null && text.isNotEmpty) {
      final msg = {
        'type': 'message',
        'content': text.trim(),
        if (clientMessageId != null && clientMessageId.isNotEmpty)
          'clientMessageId': clientMessageId,
      };
      _channel!.sink.add(jsonEncode(msg));
      return true;
    }
    return false;
  }

  void sendReadReceipt() {
    if (_channel != null) {
      final msg = {
        'type': 'read_receipt',
      };
      _channel!.sink.add(jsonEncode(msg));
    }
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
    _messageController.close();
  }
}
