import '../../../../core/base/result.dart';
import '../../../../models/movie.dart';
import '../models/match_model.dart';

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
