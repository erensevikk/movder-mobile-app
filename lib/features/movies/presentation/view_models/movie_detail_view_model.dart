import '../../../../app/app_scope.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../models/movie.dart';

class MovieDetailViewModel extends BaseViewModel {
  MovieDetailViewModel(this.movie);

  Movie movie;
  bool isWatchingThis = false;
  bool isLoadingWatchStatus = true;

  @override
  Future<void> initialize() async {
    await Future.wait(<Future<void>>[
      loadMovieDetails(),
      loadWatchStatus(),
    ]);
  }

  Future<void> loadMovieDetails() async {
    final detailedMovie =
        await AppScope.instance.moviesRepository.getMovieDetails(movie.id);
    if (detailedMovie != null) {
      movie = detailedMovie;
      notifyListeners();
    }
  }

  Future<void> loadWatchStatus() async {
    final status = await AppScope.instance.moviesRepository.getMyWatchStatus();
    isWatchingThis = status?.tmdbId == movie.id;
    isLoadingWatchStatus = false;
    notifyListeners();
  }

  Future<void> toggleWatchStatus() async {
    isLoadingWatchStatus = true;
    notifyListeners();

    final success = isWatchingThis
        ? await AppScope.instance.moviesRepository.stopWatching()
        : await AppScope.instance.moviesRepository.startWatching(movie);

    isLoadingWatchStatus = false;
    if (!success) {
      emitEffect(
        const ShowSnackbarEffect(message: 'İzleme durumu güncellenemedi.'),
      );
      notifyListeners();
      return;
    }

    isWatchingThis = !isWatchingThis;
    notifyListeners();
    emitEffect(
      ShowSnackbarEffect(
        message: isWatchingThis
            ? 'Durumunuz ${movie.title} izliyor olarak güncellendi.'
            : 'İzleme durumunuz sonlandı.',
      ),
    );
  }
}
