import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../models/movie.dart';
import '../../../chat/presentation/views/chat_detail_screen.dart';
import '../../data/models/match_model.dart';
import '../../data/repositories/match_repository.dart' as repo;
import '../../data/services/match_websocket_service.dart';

class MatchScreenViewModel extends BaseViewModel {
  MatchScreenViewModel({
    required repo.MatchRepository repository,
    required MatchWebSocketService wsService,
  })  : _repository = repository,
        _wsService = wsService,
        _debouncer = Debouncer(const Duration(milliseconds: 350));

  final repo.MatchRepository _repository;
  final MatchWebSocketService _wsService;
  final Debouncer _debouncer;

  StreamSubscription? _wsSubscription;

  // Global queue polling
  Timer? _globalQueueTimer;

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
    _initWebSocket();
  }

  void _initWebSocket() {
    _wsSubscription?.cancel();
    _wsService.connect();
    _wsSubscription = _wsService.events.listen(_handleWebSocketEvent);
  }

  void _handleWebSocketEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    
    switch (type) {
      case 'searching':
        queueCount = (event['queueCount'] as num?)?.toInt() ?? queueCount;
        notifyListeners();
        break;
        
      case 'match_found':
        final match = MatchModel(
          roomId: event['roomId'] as String,
          targetUserId: event['targetUserId'] as String,
          username: event['targetUserName'] as String,
          avatarUrl: '', // Backend'den gelmiyor ise opsiyonel veya ayrı çekilir
          movie: Movie(
            id: (event['tmdbId'] as num).toInt(),
            title: event['movieName'] as String,
            overview: '',
            releaseDate: '',
            posterPath: '',
            voteAverage: 0,
            voteCount: 0,
          ),
          isOnline: true,
        );
        currentMatch = match;
        status = MatchStatus.found;
        isSearching = false;
        notifyListeners();
        break;

      case 'partner_accepted':
        // Karşı taraf kabul etti, UI'da bir belirti gösterilebilir
        // Bizim durumumuzda sadece hem ikisi kabul ettiğinde navigation yapıyoruz
        break;

      case 'accepted':
        status = MatchStatus.accepted;
        notifyListeners();
        break;

      case 'both_accepted':
        final roomId = event['roomId'] as String;
        _completeMatchAndNavigate(roomId);
        break;

      case 'rejected':
        rejectMatchLocal();
        emitEffect(const ShowSnackbarEffect(
          message: 'Eşleşme sonlandırıldı. Aramaya devam ediliyor...',
        ));
        break;

      case 'cancelled':
        isSearching = false;
        status = MatchStatus.idle;
        notifyListeners();
        break;

      case 'error':
        setError(event['message'] as String?);
        notifyListeners();
        break;
    }
  }

  /// Shell'den çağrılır - görünürlük değiştiğinde
  void setVisibility(bool visible) {
    if (_isVisible == visible) return;
    _isVisible = visible;
    if (visible) {
      loadWatchStatus();
      _stopGlobalQueuePolling();
    }
  }

  /// Global kuyruk sayısını çek
  Future<void> fetchGlobalQueueCount() async {
    final result = await _repository.getQueueCount();
    if (result.isSuccess) {
      queueCount = result.data ?? 0;
      notifyListeners();
    }
  }

  void _startGlobalQueuePolling() {
    _stopGlobalQueuePolling();
    fetchGlobalQueueCount();
    _globalQueueTimer = Timer.periodic(const Duration(seconds: 20), (_) => fetchGlobalQueueCount());
  }

  void _stopGlobalQueuePolling() {
    _globalQueueTimer?.cancel();
    _globalQueueTimer = null;
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
    notifyListeners();

    // WebSocket üzerinden aramayı başlat
    _wsService.searchStart(movie.id, localOnly: localSearch);
  }

  /// Aramayı iptal et
  Future<void> cancelSearch() async {
    if (selectedMovie != null) {
      _wsService.cancel(selectedMovie!.id);
    }
    
    isSearching = false;
    selectedMovie = null;
    status = MatchStatus.idle;
    queueCount = 0;
    currentMatch = null;
    notifyListeners();
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
    _wsService.accept(currentMatch!.roomId, currentMatch!.targetUserId);
  }

  void _completeMatchAndNavigate(String roomId) {
    if (currentMatch != null) {
      final match = currentMatch!;
      
      // Navigate to chat
      emitEffect(NavigateToEffect(
        replace: false, // Normal push yapalım ki tab yapısı/ana navigator kırılmasın
        pageBuilder: (context) => ChatDetailScreen(
          roomId: roomId,
          targetUserId: match.targetUserId,
          username: match.username,
          movieTitle: match.movie.title,
          avatarUrl: match.avatarUrl,
        ),
      ));
      
      // Reset match state after a slight delay to allow navigation to occur smoothly
      Future.delayed(const Duration(milliseconds: 300), () {
        currentMatch = null;
        status = MatchStatus.idle;
        notifyListeners();
      });
    } else {
      status = MatchStatus.idle;
      notifyListeners();
    }

    emitEffect(const ShowSnackbarEffect(
      message: 'Eşleşme tamamlandı! Sohbet başlıyor...',
    ));
  }
  
  
  /// Karsı taraf reddettiginde, arama duruma getirmek
  void rejectMatchLocal() {
    currentMatch = null;
    status = MatchStatus.idle; // Idle'a cekiyoruz ki modal kapansın anında
    isSearching = false;
    notifyListeners();
  }

  /// Eşlemeyi reddet
  Future<void> rejectMatch() async {
    if (currentMatch == null) return;
    _wsService.reject(currentMatch!.roomId, currentMatch!.targetUserId);
    rejectMatchLocal();
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
    _wsSubscription?.cancel();
    _wsService.dispose();
    _stopGlobalQueuePolling();
    _debouncer.dispose();
    await super.disposeViewModel();
  }
}
