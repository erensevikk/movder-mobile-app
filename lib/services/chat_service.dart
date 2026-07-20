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

  Completer<void>? _readyCompleter;

  Future<void> connect(String roomId) async {
    if (_channel != null && _readyCompleter?.isCompleted == true) {
      return;
    }

    final token = AuthService.token;
    if (token == null || token.isEmpty) {
      throw StateError('Token bulunamadı');
    }

    const wsBase = String.fromEnvironment('WS_BASE_URL',
        defaultValue: 'ws://10.0.2.2:8080');
    final wsUrl = Uri.parse('$wsBase/ws/chat/$roomId?token=$token');

    try {
      final channel = WebSocketChannel.connect(wsUrl);
      _channel = channel;
      _readyCompleter = Completer<void>();

      channel.ready.then((_) {
        if (_channel != channel) return;
        if (!(_readyCompleter?.isCompleted ?? true)) {
          _readyCompleter?.complete();
        }

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
              _readyCompleter = null;
            }
          },
        );
      }).catchError((error) {
        debugPrint('WebSocket Bağlantı Hatası: $error');
        if (!(_readyCompleter?.isCompleted ?? true)) {
          _readyCompleter?.completeError(error);
        }
        if (_channel == channel) {
          _channel = null;
          _readyCompleter = null;
        }
      });

      await _readyCompleter?.future.timeout(const Duration(seconds: 3),
          onTimeout: () {
        throw TimeoutException('WebSocket bağlantısı zaman aşımına uğradı');
      });
    } catch (e) {
      debugPrint('WebSocket Bağlantı Hatası: $e');
      _channel = null;
      _readyCompleter = null;
      rethrow;
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

  Future<bool> sendMessageAsync(String text, {String? clientMessageId}) async {
    if (_channel == null || _readyCompleter == null) return false;

    try {
      await _readyCompleter!.future.timeout(const Duration(seconds: 2));
      return sendMessage(text, clientMessageId: clientMessageId);
    } catch (_) {
      return false;
    }
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
    _readyCompleter = null;
    _messageController.close();
  }
}
