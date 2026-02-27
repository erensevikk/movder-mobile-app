import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class WatchingService {
  // Singleton nesnesi
  static final WatchingService instance = WatchingService._internal();

  WatchingService._internal();

  Timer? _heartbeatTimer;
  bool _isWatching = false;

  bool get isWatching => _isWatching;

  /// Film izlemeye başla. Hem backend'e POST atar hem de periyodik heartbeat başlatır.
  Future<bool> startWatching(
      int tmdbId, String movieName, String posterPath) async {
    // 1. Backend'e izlemeye başlama isteği
    final success = await ApiService.setWatchStatus(
      tmdbId: tmdbId,
      movieName: movieName,
      posterPath: posterPath,
    );

    if (success) {
      _isWatching = true;
      _startHeartbeatTimer();
      debugPrint('WatchingService: Started watching $movieName ($tmdbId)');
      return true;
    }
    return false;
  }

  /// İzlemeyi bırak. Backend'e DELETE atar ve heartbeat timer'ı durdurur.
  Future<bool> stopWatching() async {
    final success = await ApiService.removeWatchStatus();

    if (success) {
      _isWatching = false;
      _stopHeartbeatTimer();
      debugPrint('WatchingService: Stopped watching');
      return true;
    }
    return false;
  }

  /// Her 14 dakikada bir (TTL 15 dakika olduğu için güvenli pay) backend'e PING atar.
  void _startHeartbeatTimer() {
    _stopHeartbeatTimer(); // Varsa eskisini kapat

    _heartbeatTimer =
        Timer.periodic(const Duration(minutes: 14), (timer) async {
      debugPrint('WatchingService: Sending heartbeat ping...');
      final heartbeatSuccess = await ApiService.heartbeatStatus();

      if (!heartbeatSuccess) {
        // Backend'den 404 (Süresi dolmuş/bulunamadı) veya başka hata döndüyse,
        // otomatik izleme modundan çık.
        debugPrint(
            'WatchingService: Heartbeat failed. Stopping watch status locally.');
        _isWatching = false;
        _stopHeartbeatTimer();
      } else {
        debugPrint('WatchingService: Heartbeat success. TTL extended.');
      }
    });
  }

  /// Timer'ı temizle
  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Kullanıcı çıkış yaptığında temizle
  void dispose() {
    _isWatching = false;
    _stopHeartbeatTimer();
  }
}
