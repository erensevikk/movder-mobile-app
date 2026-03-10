import '../../../../app/app_scope.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../models/movie.dart';

class HomeRadarViewModel extends BaseViewModel {
  HomeRadarViewModel()
      : _debouncer = Debouncer(const Duration(milliseconds: 500));

  final Debouncer _debouncer;

  ViewStatus status = ViewStatus.initial;
  List<Movie> trendingMovies = <Movie>[];
  List<Movie> mindfuckMovies = <Movie>[];
  List<Movie> exMovies = <Movie>[];
  List<Movie> horrorMovies = <Movie>[];
  List<Movie> indieMovies = <Movie>[];
  List<Movie> searchResults = <Movie>[];
  bool isSearching = false;
  String query = '';

  @override
  Future<void> initialize() async {
    await loadTrending();
  }

  Future<void> loadTrending() async {
    status = ViewStatus.loading;
    notifyListeners();

    final repository = AppScope.instance.moviesRepository;
    final results = await Future.wait<List<Movie>>(<Future<List<Movie>>>[
      repository.getTrending(),
      repository.getDiscoverMovies('878,9648'),
      repository.getDiscoverMovies('10749,18'),
      repository.getDiscoverMovies('27,53'),
      repository.getDiscoverMovies('10402,36'),
    ]);

    trendingMovies = results[0];
    mindfuckMovies = results[1];
    exMovies = results[2];
    horrorMovies = results[3];
    indieMovies = results[4];
    status = ViewStatus.content;
    notifyListeners();
  }

  void onSearchChanged(String value) {
    query = value;
    notifyListeners();

    if (value.trim().length < 2) {
      searchResults = <Movie>[];
      isSearching = false;
      notifyListeners();
      return;
    }

    _debouncer.run(() async {
      isSearching = true;
      notifyListeners();
      searchResults =
          await AppScope.instance.moviesRepository.searchMovies(value.trim());
      isSearching = false;
      notifyListeners();
    });
  }

  @override
  Future<void> disposeViewModel() async {
    _debouncer.dispose();
    await super.disposeViewModel();
  }
}
