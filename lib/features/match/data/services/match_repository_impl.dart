import '../../../../core/base/app_failure.dart';
import '../../../../core/base/result.dart';
import '../../../../models/movie.dart';
import '../../../../services/api_service.dart';
import '../models/match_model.dart';
import '../repositories/match_repository.dart' as repo;

class MatchRepositoryImpl implements repo.MatchRepository {
  MatchRepositoryImpl();

  Movie? _lastMovie;

  @override
  Future<Result<QueueStatusModel>> joinQueue(MatchSearchParams params) async {
    try {
      final result = await ApiService.checkMatch(
        params.tmdbId,
        localOnly: params.isLocalSearch,
      );

      if (result == null || result['error'] != null) {
        return const Result.failure(
          AppFailure(message: 'Eşleşme başlatılamadı.'),
        );
      }

      final inQueue = result['inQueue'] == true;
      final queueCount = (result['queueCount'] as num?)?.toInt() ?? 0;
      final position = (result['position'] as num?)?.toInt() ?? 0;

      return Result.success(QueueStatusModel(
        inQueue: inQueue,
        queueCount: queueCount,
        position: position,
      ));
    } catch (e) {
      return Result.failure(AppFailure(message: 'Hata: $e'));
    }
  }

  @override
  Future<Result<MatchModel?>> checkQueueStatus(int tmdbId) async {
    try {
      final result = await ApiService.checkMatch(tmdbId);

      if (result == null) {
        return const Result.success(null);
      }

      if (result['error'] != null) {
        return Result.failure(
          AppFailure(message: result['error']?.toString() ?? 'Eşleşme hatası'),
        );
      }

      final matchedUser = result['matchedUser'];
      if (matchedUser == null) {
        return const Result.success(null);
      }

      final roomId = result['roomId']?.toString();
      if (roomId == null) {
        return const Result.failure(
          AppFailure(message: 'Oda ID alınamadı.'),
        );
      }

      return Result.success(MatchModel(
        roomId: roomId,
        targetUserId: matchedUser['userId']?.toString() ??
            matchedUser['_id']?.toString() ??
            '',
        username: matchedUser['username']?.toString() ?? 'Bilinmeyen',
        avatarUrl: matchedUser['avatarUrl']?.toString(),
        movie: _lastMovie ??
            Movie(
              id: tmdbId,
              title: '',
              overview: '',
              releaseDate: '',
              voteAverage: 0.0,
              voteCount: 0,
            ),
        isOnline: matchedUser['isOnline'] == true,
      ));
    } catch (e) {
      return Result.failure(AppFailure(message: 'Hata: $e'));
    }
  }

  @override
  Future<Result<void>> cancelMatch(int tmdbId) async {
    try {
      await ApiService.cancelMatch(tmdbId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppFailure(message: 'İptal hatası: $e'));
    }
  }

  @override
  Future<Result<void>> acceptMatch(String roomId) async {
    try {
      // roomId'den targetUserId çıkarılabilir veya ayrı parametre gerekli
      // Şimdilik boş bırakıyorum - çağrıdan önce doldurulmalı
      final result = await ApiService.acceptMatch(
        roomId: roomId,
        targetUserId: '',
      );
      if (result == null || result['error'] != null) {
        return const Result.failure(
          AppFailure(message: 'Eşleşme kabul edilemedi.'),
        );
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppFailure(message: 'Hata: $e'));
    }
  }

  @override
  Future<Result<void>> rejectMatch(String roomId) async {
    try {
      await ApiService.rejectMatch(
        roomId: roomId,
        targetUserId: '',
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppFailure(message: 'Hata: $e'));
    }
  }

  @override
  Future<Result<List<UserSearchResult>>> searchUsers(String query) async {
    try {
      final results = await ApiService.searchUsers(query);
      final users = results.map((u) {
        return UserSearchResult(
          userId: u['userId']?.toString() ??
              u['_id']?.toString() ??
              u['id']?.toString() ??
              '',
          username: u['username']?.toString() ?? '',
          avatarUrl: u['avatarUrl']?.toString(),
          city: u['city']?.toString(),
          isOnline: u['isOnline'] == true,
        );
      }).toList();
      return Result.success(users);
    } catch (e) {
      return Result.failure(AppFailure(message: 'Kullanıcı arama hatası: $e'));
    }
  }

  @override
  Future<WatchStatusModel?> getWatchStatus() async {
    try {
      final result = await ApiService.getMyWatchStatus();
      if (result == null || result['watching'] != true) {
        return null;
      }

      final status = result['status'] as Map<String, dynamic>?;
      if (status == null) return null;

      return WatchStatusModel(
        tmdbId: status['tmdbId'] as int,
        movieName: status['movieName']?.toString() ?? '',
        posterUrl: status['posterUrl']?.toString() ?? '',
        startedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> startWatching(Movie movie) async {
    _lastMovie = movie;
    return await ApiService.setWatchStatus(
      tmdbId: movie.id,
      movieName: movie.title,
      posterPath: movie.posterPath ?? '',
    );
  }

  @override
  Future<bool> stopWatching() async {
    return await ApiService.removeWatchStatus();
  }
}
