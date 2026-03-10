import '../../../../models/movie.dart';
import '../../../../services/api_service.dart';
import '../../../../services/watching_service.dart';
import '../../../profile/data/models/watch_status_model.dart';
import '../repositories/movies_repository.dart';

class MoviesRepositoryImpl implements MoviesRepository {
  @override
  Future<List<Movie>> getDiscoverMovies(
    String genres, {
    String sortBy = 'popularity.desc',
  }) {
    return ApiService.getDiscoverMovies(genres, sortBy: sortBy);
  }

  @override
  Future<Movie?> getMovieDetails(int movieId) {
    return ApiService.getMovieDetails(movieId);
  }

  @override
  Future<WatchStatusModel?> getMyWatchStatus() async {
    final data = await ApiService.getMyWatchStatus();
    if (data == null || data['watching'] != true) {
      return null;
    }
    return WatchStatusModel.fromMap(data);
  }

  @override
  Future<List<Movie>> getTrending() {
    return ApiService.getTrending();
  }

  @override
  Future<List<Movie>> searchMovies(String query) {
    return ApiService.searchMovies(query);
  }

  @override
  Future<bool> startWatching(Movie movie) {
    return WatchingService.instance.startWatching(
      movie.id,
      movie.title,
      movie.posterUrl,
    );
  }

  @override
  Future<bool> stopWatching() {
    return WatchingService.instance.stopWatching();
  }
}
