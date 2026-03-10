import '../../../../core/base/result.dart';
import '../../../../models/movie.dart';

/// Eşleşme sonucu modeli
class MatchModel {
  const MatchModel({
    required this.roomId,
    required this.targetUserId,
    required this.username,
    this.avatarUrl,
    required this.movie,
    required this.isOnline,
  });

  final String roomId;
  final String targetUserId;
  final String username;
  final String? avatarUrl;
  final Movie movie;
  final bool isOnline;
}

/// Kuyruk durumu modeli
class QueueStatusModel {
  const QueueStatusModel({
    required this.inQueue,
    required this.queueCount,
    required this.position,
  });

  final bool inQueue;
  final int queueCount;
  final int position;
}

/// Eşleşme durumu
enum MatchStatus {
  idle,
  searching,
  found,
  accepted,
  rejected,
  error,
}

/// Eşleşme arama parametreleri
class MatchSearchParams {
  const MatchSearchParams({
    required this.tmdbId,
    this.movieName,
    this.posterUrl,
    this.isLocalSearch = false,
    this.city,
  });

  final int tmdbId;
  final String? movieName;
  final String? posterUrl;
  final bool isLocalSearch;
  final String? city;
}

/// Repository arayüzü
abstract class MatchRepository {
  /// Eşleşme kuyruğuna katıl
  Future<Result<QueueStatusModel>> joinQueue(MatchSearchParams params);

  /// Kuyruk durumunu kontrol et
  Future<Result<MatchModel?>> checkQueueStatus(int tmdbId);

  /// Eşlemeyi iptal et
  Future<Result<void>> cancelMatch(int tmdbId);

  /// Eşlemeyi kabul et
  Future<Result<void>> acceptMatch(String roomId);

  /// Eşlemeyi reddet
  Future<Result<void>> rejectMatch(String roomId);

  /// Kullanıcı ara
  Future<Result<List<UserSearchResult>>> searchUsers(String query);

  /// İzleme durumunu al
  Future<WatchStatusModel?> getWatchStatus();

  /// İzlemeye başla
  Future<bool> startWatching(Movie movie);

  /// İzlemeyi durdur
  Future<bool> stopWatching();
}

/// Kullanıcı arama sonucu
class UserSearchResult {
  const UserSearchResult({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.city,
    this.isOnline = false,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final String? city;
  final bool isOnline;
}

/// İzleme durumu
class WatchStatusModel {
  const WatchStatusModel({
    required this.tmdbId,
    required this.movieName,
    required this.posterUrl,
    required this.startedAt,
  });

  final int tmdbId;
  final String movieName;
  final String posterUrl;
  final DateTime startedAt;
}
