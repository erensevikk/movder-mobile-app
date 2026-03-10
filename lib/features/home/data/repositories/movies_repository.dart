import '../../../../models/movie.dart';
import '../../../profile/data/models/watch_status_model.dart';

abstract class MoviesRepository {
  Future<List<Movie>> getTrending();

  Future<List<Movie>> getDiscoverMovies(
    String genres, {
    String sortBy,
  });

  Future<List<Movie>> searchMovies(String query);

  Future<Movie?> getMovieDetails(int movieId);

  Future<WatchStatusModel?> getMyWatchStatus();

  Future<bool> startWatching(Movie movie);

  Future<bool> stopWatching();
}
