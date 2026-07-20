import '../../../../core/base/result.dart';
import '../../../../models/movie.dart';
import '../models/match_model.dart';

abstract class MatchRepository {
  /// Eşleşme kuyruğuna katıl
  Future<Result<QueueStatusModel>> joinQueue(MatchSearchParams params);

  /// Genel kuyruk kişi sayısını al
  Future<Result<int>> getQueueCount();

  /// Kuyruk durumunu kontrol et
  Future<Result<MatchModel?>> checkQueueStatus(int tmdbId);

  /// Eşlemeyi iptal et
  Future<Result<void>> cancelMatch(int tmdbId);

  /// Eşlemeyi kabul et
  Future<Result<Map<String, dynamic>>> acceptMatch(String roomId, String targetUserId);

  /// Eşlemeyi reddet
  Future<Result<void>> rejectMatch(String roomId, String targetUserId);

  /// Eşleşme kabul durumunu al
  Future<Result<Map<String, dynamic>>> getMatchAcceptStatus(String roomId);

  /// Kullanıcı ara
  Future<Result<List<UserSearchResult>>> searchUsers(String query);

  /// İzleme durumunu al
  Future<WatchStatusModel?> getWatchStatus();

  /// İzlemeye başla
  Future<bool> startWatching(Movie movie);

  /// İzlemeyi durdur
  Future<bool> stopWatching();
}
