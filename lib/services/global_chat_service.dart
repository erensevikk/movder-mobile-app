import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// Arka planda kullanıcının tüm sohbet odalarını dinleyen global servis.
///
/// Kullanıcı chat dışına çıkınca da WebSocket bağlantılarını korur
/// ve gelen mesajları NotificationService aracılığıyla ekranda gösterir.
///
/// Kullanım:
///   GlobalChatService.instance.init(rooms);   // Odaları başlangıçta yükle
///   GlobalChatService.instance.setActiveRoom('roomId');   // Chat'e girince
///   GlobalChatService.instance.clearActiveRoom();          // Chat'ten çıkınca
class GlobalChatService {
  GlobalChatService._();
  static final GlobalChatService instance = GlobalChatService._();

  // roomId → WebSocketChannel
  final Map<String, WebSocketChannel> _channels = {};
  // roomId → StreamSubscription
  final Map<String, StreamSubscription> _subscriptions = {};

  // Kullanıcı şu an hangi odadaysa bildirim göstermemek için
  String? _activeRoomId;

  // roomId → karşı taraf kullanıcı adı (bildirimde göstermek için)
  // Chat listesinden doldurulur
  final Map<String, _RoomMeta> _roomMeta = {};

  bool _initialized = false;
  bool _isChatListVisible = false;

  // Chat list ekranı anlık güncelleyebilsin diye oda bazlı message event yayını
  final StreamController<String> _messageEventsController =
      StreamController<String>.broadcast();

  // ─── API ───────────────────────────────────────────────────

  /// Tüm sohbet odalarını getirip WebSocket bağlantılarını başlatır.
  /// [rooms] → her eleman: {roomId, username, avatarUrl, ...}
  Future<void> init(List<Map<String, dynamic>> rooms) async {
    if (!AuthService.isLoggedIn) return;

    // Önceki bağlantıları temizle
    await dispose();
    _initialized = true;

    for (final room in rooms) {
      final roomId = room['roomId']?.toString() ?? '';
      if (roomId.isEmpty) continue;

      _roomMeta[roomId] = _RoomMeta(
        username: (room['username'] ?? 'Kullanıcı').toString(),
        avatarUrl: room['avatarUrl']?.toString(),
      );

      _connectRoom(roomId);
    }
  }

  void _connectRoom(String roomId) {
    final token = AuthService.token;
    if (token == null) return;

    // ws:// protokolüne çevir
    final wsBase = ApiService.baseUrl.replaceFirst('http://', 'ws://');
    final wsUrl = Uri.parse('$wsBase/ws/chat/$roomId?token=$token');

    try {
      final channel = WebSocketChannel.connect(wsUrl);
      _channels[roomId] = channel;

      final sub = channel.stream.listen(
        (raw) => _onMessage(roomId, raw),
        onError: (e) {
          debugPrint('[GlobalChat] $roomId hata: $e');
          _reconnectLater(roomId);
        },
        onDone: () {
          debugPrint('[GlobalChat] $roomId bağlantısı kapandı');
          _reconnectLater(roomId);
        },
      );
      _subscriptions[roomId] = sub;
    } catch (e) {
      debugPrint('[GlobalChat] $roomId bağlanılamadı: $e');
    }
  }

  void _onMessage(String roomId, dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type']?.toString() ?? '';

      if (type != 'message') return;

      // Chat list ekranı aktifse listeyi anlık yenilemek için event yayınla
      _messageEventsController.add(roomId);

      // Kullanıcı şu an bu odadaysa bildirim gösterme
      if (_activeRoomId == roomId) return;

      // Kullanıcı sohbetler sekmesindeyse üstten bildirim gösterme
      if (_isChatListVisible) return;

      final content = msg['content']?.toString() ?? '';
      if (content.isEmpty) return;

      final meta = _roomMeta[roomId];
      final senderName =
          msg['username']?.toString() ?? meta?.username ?? 'Kullanıcı';

      // Kendi gönderdiğimiz mesajları bildirim olarak gösterme
      final senderId = msg['senderId']?.toString() ?? '';
      if (senderId.isNotEmpty && _isMyUserId(senderId)) return;

      NotificationService.instance.showNotification(
        senderName: senderName,
        message: content,
        avatarUrl: meta?.avatarUrl,
        roomId: roomId,
      );
    } catch (e) {
      debugPrint('[GlobalChat] Mesaj parse hatası: $e');
    }
  }

  void _reconnectLater(String roomId) {
    if (!_initialized) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (_initialized && _channels.containsKey(roomId)) {
        _channels.remove(roomId);
        _subscriptions[roomId]?.cancel();
        _subscriptions.remove(roomId);
        _connectRoom(roomId);
      }
    });
  }

  /// Kullanıcı ChatDetailScreen'e girince çağrılır.
  /// Bu odadan gelen mesajlar bildirim olarak gösterilmez.
  void setActiveRoom(String roomId) {
    _activeRoomId = roomId;
  }

  /// Kullanıcı ChatDetailScreen'den çıkınca çağrılır.
  void clearActiveRoom() {
    _activeRoomId = null;
  }

  /// Yeni oda eklenmesi gerektiğinde (yeni eşleşme geldiğinde) çağrılır.
  void addRoom({
    required String roomId,
    required String username,
    String? avatarUrl,
  }) {
    if (_channels.containsKey(roomId)) return; // Zaten bağlı
    _roomMeta[roomId] = _RoomMeta(username: username, avatarUrl: avatarUrl);
    _connectRoom(roomId);
  }

  /// Bottom navigation'da sohbetler sekmesinin görünürlüğünü bildirir.
  void setChatListVisible(bool value) {
    _isChatListVisible = value;
  }

  Stream<String> get messageEvents => _messageEventsController.stream;

  Future<void> dispose() async {
    _initialized = false;
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
    for (final ch in _channels.values) {
      await ch.sink.close();
    }
    _channels.clear();
    _roomMeta.clear();
    _activeRoomId = null;
    _isChatListVisible = false;
  }

  /// JWT token'dan userId parse eder ve karşılaştırır.
  /// Kendi mesajımızı bildirim olarak göstermemek için kullanılır.
  bool _isMyUserId(String compareUserId) {
    try {
      final token = AuthService.token;
      if (token == null) return false;
      final parts = token.split('.');
      if (parts.length < 2) return false;
      // Base64 padding düzelt
      var payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = String.fromCharCodes(
          Uri.parse('data:application/octet-stream;base64,$payload')
              .data!
              .contentAsBytes());
      final claims = jsonDecode(decoded) as Map<String, dynamic>;
      final myId = claims['userId']?.toString() ?? '';
      return myId.isNotEmpty && myId == compareUserId;
    } catch (_) {
      return false;
    }
  }
} // GlobalChatService sonu

class _RoomMeta {
  final String username;
  final String? avatarUrl;
  const _RoomMeta({required this.username, this.avatarUrl});
}
