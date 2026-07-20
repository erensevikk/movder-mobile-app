import '../../../../app/app_scope.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../models/movie.dart';
import '../../../profile/data/models/movie_list_item_model.dart';
import '../../../profile/data/models/movie_list_model.dart';

class ListDetailViewModel extends BaseViewModel {
  ListDetailViewModel({
    required MovieListModel list,
    required this.isMe,
  })  : _debouncer = Debouncer(const Duration(milliseconds: 350)),
        listId = list.id,
        listName = list.name,
        items = List<MovieListItemModel>.from(list.items);

  final Debouncer _debouncer;
  final bool isMe;
  final String listId;
  String listName;
  List<MovieListItemModel> items;
  bool isEditing = false;
  final Set<int> pendingRemovals = <int>{};
  List<Movie> searchResults = <Movie>[];
  bool isSearching = false;

  void toggleEdit() {
    isEditing = !isEditing;
    if (!isEditing) {
      pendingRemovals.clear();
    }
    notifyListeners();
  }

  void markForRemoval(int tmdbId) {
    if (pendingRemovals.contains(tmdbId)) {
      pendingRemovals.remove(tmdbId);
    } else {
      pendingRemovals.add(tmdbId);
    }
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    notifyListeners();
  }

  Future<void> commitChanges() async {
    setLoading(true);

    for (final tmdbId in pendingRemovals.toList()) {
      await AppScope.instance.listsRepository
          .removeMovieFromList(listId, tmdbId);
      items.removeWhere((item) => item.tmdbId == tmdbId);
      pendingRemovals.remove(tmdbId);
    }

    await AppScope.instance.listsRepository.reorderList(
      listId,
      items.map((item) => item.tmdbId).toList(),
    );

    setLoading(false);
    isEditing = false;
    notifyListeners();
    emitEffect(const ShowSnackbarEffect(message: 'Liste güncellendi.'));
  }

  Future<void> rename(String newName) async {
    final renamed =
        await AppScope.instance.listsRepository.renameList(listId, newName);
    if (renamed == null) {
      emitEffect(
          const ShowSnackbarEffect(message: 'Liste adı güncellenemedi.'));
      return;
    }
    listName = renamed.name;
    items = renamed.items;
    notifyListeners();
  }

  Future<void> delete() async {
    final success = await AppScope.instance.listsRepository.deleteList(listId);
    if (!success) {
      emitEffect(const ShowSnackbarEffect(message: 'Liste silinemedi.'));
      return;
    }
    emitEffect(const ShowSnackbarEffect(message: 'Liste silindi.'));
    emitEffect(const PopEffect(true));
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

  Future<void> addMovie(Movie movie) async {
    final success = await AppScope.instance.listsRepository.addMovieToList(
      listId: listId,
      movie: movie,
    );
    if (!success) {
      emitEffect(const ShowSnackbarEffect(message: 'Film eklenemedi.'));
      return;
    }

    items = <MovieListItemModel>[
      ...items,
      MovieListItemModel(
        tmdbId: movie.id,
        movieName: movie.title,
        posterUrl: movie.posterUrl,
      ),
    ];
    notifyListeners();
  }

  @override
  Future<void> disposeViewModel() async {
    _debouncer.dispose();
    await super.disposeViewModel();
  }
}
