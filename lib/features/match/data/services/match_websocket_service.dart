import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/api_service.dart';

class MatchWebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    final token = AuthService.token;
    if (token == null || token.isEmpty) {
      debugPrint('MatchWebSocketService: Token bulunamadı');
      return;
    }

    // Backend portu 8080, wsBaseUrl'i ApiService'den türetiyoruz veya env'den alıyoruz
    final wsBase = ApiService.baseUrl.replaceAll('http', 'ws');
    final wsUrl = Uri.parse('$wsBase/api/match/ws?token=$token');

    try {
      debugPrint('MatchWebSocketService: Bağlanılıyor -> $wsUrl');
      _channel = WebSocketChannel.connect(wsUrl);
      
      _channel!.stream.listen(
        (message) {
          _isConnected = true;
          try {
            final decoded = jsonDecode(message) as Map<String, dynamic>;
            _eventController.add(decoded);
          } catch (e) {
            debugPrint('MatchWebSocketService: Decode hatası: $e');
          }
        },
        onError: (error) {
          debugPrint('MatchWebSocketService: Hata: $error');
          _isConnected = false;
          _reconnect();
        },
        onDone: () {
          debugPrint('MatchWebSocketService: Bağlantı kapandı');
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint('MatchWebSocketService: Bağlantı hatası: $e');
      _isConnected = false;
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void searchStart(int tmdbId, {bool localOnly = false}) {
    _send({
      'type': 'search_start',
      'tmdbId': tmdbId,
      'localOnly': localOnly,
    });
  }

  void accept(String roomId, String targetUserId) {
    _send({
      'type': 'accept',
      'roomId': roomId,
      'targetUserId': targetUserId,
    });
  }

  void reject(String roomId, String targetUserId) {
    _send({
      'type': 'reject',
      'roomId': roomId,
      'targetUserId': targetUserId,
    });
  }

  void cancel(int tmdbId) {
    _send({
      'type': 'cancel',
      'tmdbId': tmdbId,
    });
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    } else {
      debugPrint('MatchWebSocketService: Bağlantı yok, mesaj gönderilemedi: ${data['type']}');
    }
  }

  void dispose() {
    _channel?.sink.close();
    _eventController.close();
  }
}
