import '../../../../app/app_scope.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/validators.dart';
import '../../../../models/movie.dart';

class CreateListViewModel extends BaseViewModel {
  CreateListViewModel()
      : _debouncer = Debouncer(const Duration(milliseconds: 350));

  final Debouncer _debouncer;

  String title = '';
  String description = '';
  String? titleError;
  List<Movie> searchResults = <Movie>[];
  List<Movie> selectedMovies = <Movie>[];
  bool isSearching = false;

  void updateTitle(String value) {
    title = value;
    titleError = null;
    notifyListeners();
  }

  void updateDescription(String value) {
    description = value;
  }

  void onSearchChanged(String value) {
    final query = value.trim();
    if (query.length < 2) {
      searchResults = <Movie>[];
      isSearching = false;
      notifyListeners();
      return;
    }

    _debouncer.run(() async {
      isSearching = true;
      notifyListeners();
      searchResults = await AppScope.instance.moviesRepository.searchMovies(
        query,
      );
      isSearching = false;
      notifyListeners();
    });
  }

  void toggleMovie(Movie movie) {
    final exists = selectedMovies.any((item) => item.id == movie.id);
    if (exists) {
      selectedMovies.removeWhere((item) => item.id == movie.id);
    } else {
      selectedMovies.add(movie);
    }
    notifyListeners();
  }

  Future<void> createList() async {
    titleError = Validators.required(title, 'Liste adi zorunlu.');
    notifyListeners();
    if (titleError != null || selectedMovies.isEmpty) {
      return;
    }

    final created = await guard(
      () => AppScope.instance.listsRepository.createList(
        name: title.trim(),
        description: description.trim(),
      ),
    );
    if (created.isFailure || created.data == null) {
      emitEffect(
        ShowSnackbarEffect(
          message: created.failure?.message ?? 'Liste olusturulamadi.',
        ),
      );
      return;
    }

    final list = created.data!;
    for (final movie in selectedMovies) {
      await AppScope.instance.listsRepository.addMovieToList(
        listId: list.id,
        movie: movie,
      );
    }

    emitEffect(const ShowSnackbarEffect(message: 'Liste olusturuldu.'));
    emitEffect(const PopEffect(true));
  }

  @override
  Future<void> disposeViewModel() async {
    _debouncer.dispose();
    await super.disposeViewModel();
  }
}
