import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../models/movie.dart';
import '../../data/models/match_model.dart';
import '../../data/repositories/match_repository.dart' as repo;

class MatchScreenViewModel extends BaseViewModel {
  MatchScreenViewModel({
    required repo.MatchRepository repository,
  })  : _repository = repository,
        _debouncer = Debouncer(const Duration(milliseconds: 350));

  final repo.MatchRepository _repository;
  final Debouncer _debouncer;

  // Timer for polling
  Timer? _pollingTimer;
  Duration _currentPollInterval = const Duration(milliseconds: 500);
  static const Duration _minPollInterval = Duration(milliseconds: 500);
  static const Duration _maxPollInterval = Duration(seconds: 2);

  // State
  MatchStatus status = MatchStatus.idle;
  int queueCount = 0;
  Movie? selectedMovie;
  MatchModel? currentMatch;
  bool isSearching = false;
  bool isLocalSearch = false;

  // User search
  bool isUserSearching = false;
  String userSearchQuery = '';
  List<UserSearchResult> userSearchResults = [];
  final TextEditingController userSearchController = TextEditingController();

  // Watch status
  bool isWatching = false;
  Movie? watchingMovie;
  String? myAvatarUrl;

  bool _isVisible = false;

  @override
  Future<void> initialize() async {
    await loadWatchStatus();
    // In a real app, get current user avatar from a profile service
    // We'll set it here manually for visual demonstration in the search view
  }

  /// Shell'den çağrılır - görünürlük değiştiğinde
  void setVisibility(bool visible) {
    if (_isVisible == visible) return;
    _isVisible = visible;
    if (visible) {
      loadWatchStatus();
    }
  }

  /// Shell'den çağrılır - izleme durumunu yenilemek için
  Future<void> reloadWatchingStatus() async {
    await loadWatchStatus();
  }

  /// İzleme durumunu yükle
  Future<void> loadWatchStatus() async {
    final watchStatus = await _repository.getWatchStatus();
    if (watchStatus != null) {
      isWatching = true;
      watchingMovie = Movie(
        id: watchStatus.tmdbId,
        title: watchStatus.movieName,
        overview: '',
        releaseDate: '',
        voteAverage: 0.0,
        voteCount: 0,
        posterPath: watchStatus.posterUrl,
      );
      notifyListeners();
    }
  }

  /// Film seçildiğinde aramaya başla
  Future<void> selectMovie(Movie movie, {bool localSearch = false}) async {
    selectedMovie = movie;
    isLocalSearch = localSearch;
    isSearching = true;
    status = MatchStatus.searching;
    _currentPollInterval = _minPollInterval;
    notifyListeners();

    // Queue'a katıl
    final result = await _repository.joinQueue(MatchSearchParams(
      tmdbId: movie.id,
      movieName: movie.title,
      posterUrl: movie.posterPath,
      isLocalSearch: localSearch,
    ));

    if (result.isFailure) {
      status = MatchStatus.error;
      setError(result.failure?.message);
      isSearching = false;
      notifyListeners();
      return;
    }

    queueCount = result.data?.queueCount ?? 0;
    notifyListeners();

    // Polling başlat
    _startPolling();
  }

  /// Aramayı iptal et
  Future<void> cancelSearch() async {
    _stopPolling();
    isSearching = false;
    selectedMovie = null;
    status = MatchStatus.idle;
    queueCount = 0;
    currentMatch = null;
    notifyListeners();

    if (selectedMovie != null) {
      await _repository.cancelMatch(selectedMovie!.id);
    }
  }

  /// Polling başlat
  void _startPolling() {
    _stopPolling();
    _pollingTimer =
        Timer.periodic(_currentPollInterval, (_) => _checkForMatch());
  }

  /// Polling durdur
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Eşleşme kontrolü
  Future<void> _checkForMatch() async {
    if (selectedMovie == null) return;

    final result = await _repository.checkQueueStatus(selectedMovie!.id);

    if (result.isFailure) {
      // Hata durumunda exponential backoff
      _increasePollInterval();
      notifyListeners();
      return;
    }

    final match = result.data;
    if (match != null) {
      // Eşleşme bulundu!
      _stopPolling();
      currentMatch = match;
      status = MatchStatus.found;
      isSearching = false;
      notifyListeners();
      return;
    }

    // Eşleşme yok - queue count güncelle
    // Exponential backoff
    _increasePollInterval();
    notifyListeners();
  }

  /// Poll interval'ı artır (exponential backoff)
  void _increasePollInterval() {
    final newInterval = _currentPollInterval * 2;
    if (newInterval <= _maxPollInterval) {
      _currentPollInterval = newInterval;
      // Timer'ı yeni interval ile yeniden başlat
      _startPolling();
    }
  }

  /// Kullanıcı araması
  void onUserSearchChanged(String query) {
    userSearchQuery = query;
    notifyListeners();

    if (query.trim().length < 2) {
      isUserSearching = false;
      userSearchResults = [];
      notifyListeners();
      return;
    }

    _debouncer.run(() => _searchUsers(query.trim()));
  }

  Future<void> _searchUsers(String query) async {
    isUserSearching = true;
    notifyListeners();

    final result = await _repository.searchUsers(query);

    isUserSearching = false;
    if (result.isSuccess) {
      userSearchResults = result.data ?? [];
    } else {
      userSearchResults = [];
    }
    notifyListeners();
  }

  /// Eşlemeyi kabul et
  Future<void> acceptMatch() async {
    if (currentMatch == null) return;

    final result = await _repository.acceptMatch(currentMatch!.roomId);
    if (result.isSuccess) {
      status = MatchStatus.accepted;
      // Navigation View tarafından dinlenecek - şimdilik sadece state değiş
      emitEffect(const ShowSnackbarEffect(
        message: 'Eşleşme kabul edildi! Sohbet başlıyor...',
      ));
      emitEffect(const PopEffect());
    } else {
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'Eşleşme kabul edilemedi.',
      ));
    }
    notifyListeners();
  }

  /// Eşlemeyi reddet
  Future<void> rejectMatch() async {
    if (currentMatch == null) return;

    final result = await _repository.rejectMatch(currentMatch!.roomId);
    if (result.isSuccess) {
      currentMatch = null;
      status = MatchStatus.rejected;
      // Tekrar aramaya devam et
      isSearching = true;
      _currentPollInterval = _minPollInterval;
      _startPolling();
    } else {
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'Eşleşme reddedilemedi.',
      ));
    }
    notifyListeners();
  }

  /// İzlemeye başla
  Future<void> startWatching(Movie movie) async {
    final success = await _repository.startWatching(movie);
    if (success) {
      isWatching = true;
      watchingMovie = movie;
      notifyListeners();
      emitEffect(ShowSnackbarEffect(
        message: 'Durumunuz ${movie.title} izliyor olarak güncellendi!',
      ));
    } else {
      emitEffect(const ShowSnackbarEffect(
        message: 'İzleme durumu başlatılamadı.',
      ));
    }
  }

  /// İzlemeyi durdur
  Future<void> stopWatching() async {
    final success = await _repository.stopWatching();
    if (success) {
      isWatching = false;
      watchingMovie = null;
      notifyListeners();
      emitEffect(const ShowSnackbarEffect(
        message: 'İzleme durumunuz sonlandı.',
      ));
    }
  }

  @override
  Future<void> disposeViewModel() async {
    _stopPolling();
    _debouncer.dispose();
    await super.disposeViewModel();
  }
}
