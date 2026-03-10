import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_detail_screen.dart';
import '../features/chat/presentation/views/chat_detail_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => MatchScreenState();
}

class MatchScreenState extends State<MatchScreen>
    with TickerProviderStateMixin {
  static const Duration _searchPollInterval = Duration(milliseconds: 500);
  // Search polling için exponential backoff
  static const Duration _maxSearchPollInterval = Duration(seconds: 2);
  // Mevcut poll interval (exponential backoff için)
  Duration _currentPollInterval = _searchPollInterval;

  bool _isScreenVisible = false;

  bool _isLocalSearch = false; // false = Genel Arama, true = Aynı Şehirde Arama
  int _queueCount = 0;
  int _watchingTmdbId = 0;
  final bool _isPreparingAssets = false;
  bool _isSearching = false;

  bool _isWatching = false;
  String _watchingMovieName = '';
  String _watchingFor = '';
  String _watchingPosterPath = '';

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _slideXAnimation;

  final List<String> _slideshowPosters = [];
  int _slideIndex = 0;
  bool _slideshowActive = false;

  int _searchRequestId = 0;
  Timer? _dotTimer;
  int _dotCount = 1;

  final TextEditingController _userSearchController = TextEditingController();
  Timer? _userSearchDebounce;
  bool _isUserSearching = false;
  List<Map<String, dynamic>> _userSearchResults = [];
  int _userSearchRequestId = 0;
  String _userCity = '';
  String _myUserId = '';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _slideXAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.35)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.35, end: -1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 65,
      ),
    ]).animate(_slideController);

    _slideController.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          _slideshowActive &&
          _slideshowPosters.isNotEmpty) {
        setState(() {
          _slideIndex = (_slideIndex + 1) % _slideshowPosters.length;
        });
        if (_isScreenVisible) {
          _slideController.forward(from: 0);
        }
      }
    });

    _loadWatchingStatus();
  }

  @override
  void dispose() {
    if (_isSearching && _watchingTmdbId > 0) {
      ApiService.cancelMatch(_watchingTmdbId);
    }
    _pulseController.dispose();
    _slideController.dispose();
    _stopDots();
    _userSearchDebounce?.cancel();
    _userSearchController.dispose();
    super.dispose();
  }

  void _startDots() {
    _stopDots();
    _dotCount = 1;
    _dotTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted || !_isSearching) return;
      setState(() {
        _dotCount = _dotCount % 3 + 1;
      });
    });
  }

  void _stopDots() {
    _dotTimer?.cancel();
    _dotTimer = null;
    _dotCount = 1;
  }

  void _onUserSearchChanged(String value) {
    _userSearchDebounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _isUserSearching = false;
        _userSearchResults = [];
      });
      return;
    }

    _userSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    final requestId = ++_userSearchRequestId;

    setState(() {
      _isUserSearching = true;
    });

    final users = await ApiService.searchUsers(query);
    if (!mounted || requestId != _userSearchRequestId) return;

    setState(() {
      _isUserSearching = false;
      _userSearchResults = users;
    });
  }

  String _posterUrl(String posterPath) {
    final clean = posterPath.trim();
    if (clean.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w780$clean';
  }

  Future<void> _loadWatchingStatus() async {
    final statusData = await ApiService.getMyWatchStatus();
    final queueCount = await ApiService.getQueueCount();

    if (!mounted) return;

    if (statusData != null && statusData['watching'] == true) {
      final status = statusData['status'];
      setState(() {
        _isWatching = true;
        _watchingMovieName = (status?['movieName'] ?? '').toString();
        _watchingFor = (statusData['watchingFor'] ?? '').toString();
        _watchingPosterPath = (status?['posterPath'] ?? '').toString();
        // Parse tmdbId defensively
        final rawTmdbId = status?['tmdbId'];
        if (rawTmdbId is int) {
          _watchingTmdbId = rawTmdbId;
        } else if (rawTmdbId != null) {
          _watchingTmdbId = int.tryParse(rawTmdbId.toString()) ?? 0;
        } else {
          _watchingTmdbId = 0;
        }
        _queueCount = queueCount;
      });
    } else if (statusData != null) {
      // Backend açıkça "watching: false" döndüyse sıfırla.
      // statusData == null ise (API hatası / timeout) mevcut state'i koru.
      setState(() {
        _isWatching = false;
        _watchingMovieName = '';
        _watchingFor = '';
        _watchingPosterPath = '';
        _watchingTmdbId = 0;
        _queueCount = queueCount;
      });
    } else {
      // API hatası → sadece kuyruk sayısını güncelle, izleme durumunu KORUMA altında tut
      setState(() {
        _queueCount = queueCount;
      });
    }

    // Kullanıcının şehrini profilinden alalım (Hangi şehirden eşleşme aradığını göstermek için)
    final profileData = await ApiService.getProfile();
    if (mounted && profileData != null) {
      setState(() {
        _userCity = (profileData['city'] ?? '').toString();
        _myUserId = (profileData['userId'] ??
                profileData['_id'] ??
                profileData['id'] ??
                '')
            .toString();
      });
    }

    if (!_slideshowActive) {
      _initBackgroundSlideshow();
    }
  }

  void setVisibility(bool visible) {
    if (_isScreenVisible == visible) return;
    setState(() {
      _isScreenVisible = visible;
    });
    if (visible && _slideshowActive) {
      // Resume or restart animation if it should be running
      if (_slideController.isCompleted) {
        _slideController.forward(from: 0);
      } else if (!_slideController.isAnimating) {
        _slideController.forward();
      }
    } else if (!visible && _slideController.isAnimating) {
      // Pause animation
      _slideController.stop();
    }
  }

  Future<void> reloadWatchingStatus() async {
    await _loadWatchingStatus();
  }

  Future<void> _initBackgroundSlideshow() async {
    final posters = await _buildTopPosterList();
    if (!mounted) return;
    await _precacheTopPosters(posters);
    if (!mounted) return;
    if (posters.isNotEmpty) {
      _startSlideshow(posters);
    }
  }

  Future<List<String>> _buildTopPosterList() async {
    final movies = await ApiService.getTopActiveMovies(limit: 10);

    final posters = <String>[];
    final seenTmdb = <int>{};
    final seenPosterPaths = <String>{};

    for (final movie in movies) {
      final posterPath = (movie['posterPath'] ?? '').toString().trim();
      final tmdbIdRaw = movie['tmdbId'];
      final tmdbId = tmdbIdRaw is int
          ? tmdbIdRaw
          : int.tryParse(tmdbIdRaw?.toString() ?? '') ?? 0;

      if (posterPath.isEmpty ||
          tmdbId <= 0 ||
          seenTmdb.contains(tmdbId) ||
          seenPosterPaths.contains(posterPath)) {
        continue;
      }

      seenTmdb.add(tmdbId);
      seenPosterPaths.add(posterPath);
      posters.add(posterPath);

      if (posters.length == 5) break;
    }

    if (posters.length < 5) {
      final trending = await ApiService.getTrending();
      final sortedTrending = List.of(trending)
        ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));

      for (final movie in sortedTrending) {
        final posterPath = (movie.posterPath ?? '').trim();
        final tmdbId = movie.id;

        if (posterPath.isEmpty ||
            tmdbId <= 0 ||
            seenTmdb.contains(tmdbId) ||
            seenPosterPaths.contains(posterPath)) {
          continue;
        }

        seenTmdb.add(tmdbId);
        seenPosterPaths.add(posterPath);
        posters.add(posterPath);

        if (posters.length == 5) break;
      }
    }

    final watchingPoster = _watchingPosterPath.trim();
    if (posters.length < 5 &&
        watchingPoster.isNotEmpty &&
        !seenPosterPaths.contains(watchingPoster)) {
      posters.add(watchingPoster);
    }

    return posters.take(5).toList();
  }

  Future<void> _precacheTopPosters(List<String> posters) async {
    for (final posterPath in posters) {
      final url = _posterUrl(posterPath);
      if (url.isEmpty) continue;
      await precacheImage(CachedNetworkImageProvider(url), context);
    }
  }

  void _startSlideshow(List<String> posters) {
    _slideshowPosters
      ..clear()
      ..addAll(posters);

    if (_slideshowPosters.isEmpty) {
      _stopSlideshow();
      return;
    }

    setState(() {
      _slideIndex = 0;
      _slideshowActive = true;
    });

    if (_isScreenVisible) {
      _slideController.forward(from: 0);
    }
  }

  void _stopSlideshow() {
    _slideController.stop();
    setState(() {
      _slideshowActive = false;
      _slideIndex = 0;
      _slideshowPosters.clear();
    });
  }

  Future<void> _startSearch() async {
    if (_isSearching || !_isWatching) return;

    final currentRequestId = ++_searchRequestId;
    // Her aramada interval'i sıfırla
    _currentPollInterval = _searchPollInterval;

    setState(() {
      _isSearching = true;
    });
    _startDots();

    bool keepSearching = true;
    while (keepSearching &&
        context.mounted &&
        currentRequestId == _searchRequestId) {
      final matchRes = await ApiService.checkMatch(
        _watchingTmdbId,
        localOnly: _isLocalSearch,
      );

      if (!context.mounted || currentRequestId != _searchRequestId) break;

      if (matchRes != null && matchRes['matched'] == true) {
        // Eşleşme bulundu - interval'i sıfırla
        _currentPollInterval = _searchPollInterval;
        keepSearching = false;
        final matchData = matchRes['match'];

        final user1Id = (matchData?['user1Id'] ?? '').toString();
        final user2Id = (matchData?['user2Id'] ?? '').toString();
        final user1Name = (matchData?['user1Name'] ?? '').toString();
        final user2Name = (matchData?['user2Name'] ?? '').toString();
        final roomId = (matchData?['roomId'] ?? '').toString();

        final String targetUserId = (_myUserId == user1Id) ? user2Id : user1Id;
        final String otherUserName =
            (_myUserId == user1Id) ? user2Name : user1Name;

        if (!mounted) return;

        setState(() => _isSearching = false);
        _stopDots();

        // O anki arama request ID'sini kaydet ki devam etmemiz gerekirse bilelim
        final currentReqIdSnapshot = currentRequestId;

        // Tam ekran kabul/red ekranı
        // overlay kapandığında bool bir sonuç döndürelim:
        // true: sohbet odasına geçildi (bu aramayı tamamen durdur)
        // false: reddedildi veya zaman aşımı (aynı arama ile devam et/yeniden sıraya gir)
        final bool chatJoined = await Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                transitionDuration: const Duration(milliseconds: 350),
                pageBuilder: (_, __, ___) => MatchFoundOverlay(
                  otherUserName: otherUserName,
                  targetUserId: targetUserId,
                  myUserId: _myUserId,
                  roomId: roomId,
                  movieName: _watchingMovieName,
                  posterUrl: _watchingPosterPath.isNotEmpty
                      ? _posterUrl(_watchingPosterPath)
                      : null,
                ),
              ),
            ) ??
            false;

        if (!mounted || currentRequestId != currentReqIdSnapshot) break;

        if (chatJoined) {
          // Sohbet odasına başarıyla geçildi -> aramayı tamamen komple bitir.
          keepSearching = false;
        } else {
          // Ya kendisi reddetti, ya karşı taraf reddetti, ya da süre bitti. -> tekrar sıraya gir
          // API tarafında iptal endpointini de çagırabiliriz ama zaten timeout olduğunda süre bitmiş olur.
          setState(() {
            _isSearching = true; // Tekrar arama UI'sine dön
          });
          _startDots();
          // Interval'i sıfırla çünkü yeni arama başladı
          _currentPollInterval = _searchPollInterval;
        }
      } else {
        // Eşleşme bulunamadı - exponential backoff uygula
        await Future.delayed(_currentPollInterval);
        // Bir sonraki bekleme süresini artır (max'e kadar)
        _currentPollInterval = Duration(
          milliseconds:
              (_currentPollInterval.inMilliseconds * 1.5).round().clamp(
                    _searchPollInterval.inMilliseconds,
                    _maxSearchPollInterval.inMilliseconds,
                  ),
        );
      }
    }
  }

  Future<void> _cancelSearch() async {
    setState(() {
      _isSearching = false;
      _searchRequestId++; // Break the loop
    });
    // Interval'i sıfırla
    _currentPollInterval = _searchPollInterval;
    _stopDots();

    if (_watchingTmdbId > 0) {
      await ApiService.cancelMatch(_watchingTmdbId);
    }
  }

  Widget _buildBackground() {
    final hasSlideshow = _slideshowActive && _slideshowPosters.isNotEmpty;

    if (hasSlideshow) {
      final currentPosterPath = _slideshowPosters[_slideIndex];
      final nextPosterPath =
          _slideshowPosters[(_slideIndex + 1) % _slideshowPosters.length];
      final currentUrl = _posterUrl(currentPosterPath);
      final nextUrl = _posterUrl(nextPosterPath);

      Widget buildPoster(String url) {
        if (url.isEmpty) return Container(color: const Color(0xFF0F0F0F));
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorWidget: (_, __, ___) =>
              Container(color: const Color(0xFF0F0F0F)),
          placeholder: (_, __) => Container(color: const Color(0xFF0F0F0F)),
        );
      }

      return AnimatedBuilder(
        animation: _slideController,
        builder: (context, child) {
          final width = MediaQuery.of(context).size.width;
          final x = _slideXAnimation.value * width;

          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: Offset(x, 0),
                child: SizedBox.expand(child: buildPoster(currentUrl)),
              ),
              Transform.translate(
                offset: Offset(x + width, 0),
                child: SizedBox.expand(child: buildPoster(nextUrl)),
              ),
            ],
          );
        },
      );
    }

    if (_watchingPosterPath.trim().isNotEmpty) {
      final url = _posterUrl(_watchingPosterPath);
      if (url.isNotEmpty) {
        return SizedBox.expand(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            errorWidget: (_, __, ___) =>
                Container(color: const Color(0xFF0F0F0F)),
            placeholder: (_, __) => Container(color: const Color(0xFF0F0F0F)),
          ),
        );
      }
    }

    return Container(color: const Color(0xFF0F0F0F));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top,
            child: Container(
              color: const Color(0xFF0F0F0F),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0.86),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                // ── Ana içerik (arama kutusu + sayfa) ──────────────
                Column(
                  children: [
                    const SizedBox(height: 8),
                    // Sadece arama kutusu (sonuçlar overlay olarak aşağıda)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: TextField(
                        controller: _userSearchController,
                        onChanged: _onUserSearchChanged,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Kullanıcı adı ile ara...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white70),
                          // Input doluysa çarpı (temizle) ikonu göster
                          suffixIcon: _userSearchController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _userSearchController.clear();
                                    setState(() {
                                      _isUserSearching = false;
                                      _userSearchResults = [];
                                    });
                                  },
                                  child: const Icon(Icons.close,
                                      color: Colors.white54, size: 18),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.10),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Birlikte İzle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_alt_outlined,
                              color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Şu an $_queueCount kişi eşleşmeyi bekliyor',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onHorizontalDragEnd: (details) {
                              if (_isSearching || _isPreparingAssets) return;
                              if (details.primaryVelocity! < -300) {
                                setState(() => _isLocalSearch = true);
                              } else if (details.primaryVelocity! > 300) {
                                setState(() => _isLocalSearch = false);
                              }
                            },
                            child: Container(
                              color: Colors.transparent,
                              height: 320,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    height: 300,
                                    width: 300,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        if (_isSearching)
                                          Positioned(
                                            left: 65,
                                            top: 65,
                                            child: AnimatedBuilder(
                                              animation: _pulseController,
                                              builder: (context, child) {
                                                final scale = 1.0 +
                                                    (_pulseController.value *
                                                        0.15);
                                                return Transform.scale(
                                                  scale: scale,
                                                  child: Container(
                                                    width: 170,
                                                    height: 170,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: (_isLocalSearch
                                                                ? Colors
                                                                    .blueAccent
                                                                : Colors
                                                                    .redAccent)
                                                            .withValues(
                                                                alpha: 1 -
                                                                    _pulseController
                                                                        .value),
                                                        width: 3,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        if (_isLocalSearch) ...[
                                          _buildGenelCircle(),
                                          _buildSehirCircle(),
                                        ] else ...[
                                          _buildSehirCircle(),
                                          _buildGenelCircle(),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSearching && _watchingMovieName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Text(
                                    '$_watchingMovieName filmi için eşleşme aranıyor ${'.' * _dotCount}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (_isSearching && _watchingMovieName.isNotEmpty)
                                const SizedBox(height: 10),
                              if (!_isWatching && !_isSearching)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'Eşleşme aramak için lütfen izlemekte olduğunuz bir filmi seçiniz.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (!_isWatching && !_isSearching)
                                const SizedBox(height: 10),
                              if (_isWatching &&
                                  _watchingMovieName.isNotEmpty &&
                                  !_isSearching)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.redAccent
                                            .withValues(alpha: 0.45)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.play_circle_fill,
                                          color: Colors.redAccent, size: 18),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          _watchingFor.isNotEmpty
                                              ? 'Aktif Durum: $_watchingMovieName izliyorsun · $_watchingFor'
                                              : 'Aktif Durum: $_watchingMovieName izliyorsun',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    onPressed: (!_isWatching && !_isSearching)
                                        ? null
                                        : _isSearching
                                            ? _cancelSearch
                                            : _startSearch,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          (!_isWatching && !_isSearching)
                                              ? Colors.grey[850]
                                              : _isSearching
                                                  ? Colors.grey[800]
                                                  : (_isLocalSearch
                                                      ? Colors.blueAccent
                                                      : Colors.redAccent),
                                      shadowColor: _isSearching ||
                                              (!_isWatching && !_isSearching)
                                          ? Colors.transparent
                                          : (_isLocalSearch
                                              ? Colors.blueAccent
                                              : Colors.redAccent),
                                      elevation: _isSearching ||
                                              (!_isWatching && !_isSearching)
                                          ? 0
                                          : 8,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isSearching
                                        ? const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.close,
                                                  color: Colors.white),
                                              SizedBox(width: 12),
                                              Text(
                                                'Aramayı İptal Et',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                  _isLocalSearch
                                                      ? Icons.my_location
                                                      : Icons.search,
                                                  color: (!_isWatching)
                                                      ? Colors.white54
                                                      : Colors.white),
                                              const SizedBox(width: 12),
                                              Text(
                                                _isLocalSearch
                                                    ? 'Şehrimde Eşleşme Ara'
                                                    : 'Genel Eşleşme Ara',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: (!_isWatching)
                                                      ? Colors.white54
                                                      : Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Arama Sonuclari Overlay (sayfa icerigini itmez)
                if (_userSearchController.text.trim().length >= 2)
                  Positioned(
                    top: 76, // arama kutusu yüksekliği kadar aşağıda başla
                    left: 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isUserSearching
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              )
                            : _userSearchResults.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Text(
                                      'Kullanıcı bulunamadı',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: _userSearchResults.length,
                                    separatorBuilder: (_, __) => Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.08)),
                                    itemBuilder: (context, index) {
                                      final user = _userSearchResults[index];
                                      final username =
                                          (user['username'] ?? '').toString();
                                      final city =
                                          (user['city'] ?? '').toString();
                                      final userId =
                                          (user['userId'] ?? user['_id'] ?? '')
                                              .toString();
                                      final avatarRaw = (user['avatarUrl'] ??
                                              user['avatar_url'] ??
                                              '')
                                          .toString()
                                          .trim();
                                      final avatarUrl = avatarRaw.isEmpty
                                          ? ''
                                          : (avatarRaw.startsWith('http://') ||
                                                  avatarRaw
                                                      .startsWith('https://')
                                              ? avatarRaw
                                              : (avatarRaw.startsWith('/')
                                                  ? '${ApiService.baseUrl}$avatarRaw'
                                                  : '${ApiService.baseUrl}/$avatarRaw'));
                                      final hasAvatar = avatarUrl.isNotEmpty;

                                      return ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              const Color(0xFF2A2A2A),
                                          child: hasAvatar
                                              ? ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl: avatarUrl,
                                                    width: 40,
                                                    height: 40,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) =>
                                                        const Icon(
                                                      Icons.person,
                                                      color: Colors.white54,
                                                      size: 22,
                                                    ),
                                                    placeholder: (_, __) =>
                                                        const Icon(
                                                      Icons.person,
                                                      color: Colors.white54,
                                                      size: 22,
                                                    ),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.person,
                                                  color: Colors.white54,
                                                  size: 22,
                                                ),
                                        ),
                                        title: Text(username,
                                            style: const TextStyle(
                                                color: Colors.white)),
                                        subtitle: Text(
                                          city.isNotEmpty
                                              ? city
                                              : 'Şehir bilgisi yok',
                                          style: const TextStyle(
                                              color: Colors.white54),
                                        ),
                                        onTap: userId.isEmpty
                                            ? null
                                            : () {
                                                setState(() {
                                                  _userSearchResults.clear();
                                                  // isUserSearching = false;  // Zaten bitmiş olmalı
                                                  // Aramayı sıfırlayabilirsiniz
                                                });
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        UserDetailScreen(
                                                      userId: userId,
                                                      isMe:
                                                          false, // Başkasının profili
                                                    ),
                                                  ),
                                                );
                                              },
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenelCircle() {
    final isActive = !_isLocalSearch;
    final size = isActive ? 170.0 : 110.0;
    final left = isActive ? 65.0 : 20.0;
    final top = isActive ? 65.0 : 40.0;

    return AnimatedPositioned(
      key: const ValueKey('genel'),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {
          if (!_isSearching && !_isPreparingAssets && _isLocalSearch) {
            setState(() => _isLocalSearch = false);
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: isActive ? 1.0 : 0.4,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = (_isSearching && isActive)
                  ? 1.0 + (_pulseController.value * 0.05)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? Colors.redAccent.withValues(alpha: 0.2)
                        : const Color(0xFF1E1E1E),
                    border: Border.all(
                      color: isActive ? Colors.redAccent : Colors.white24,
                      width: isActive ? 4 : 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                              blurRadius: 25,
                              spreadRadius: 5,
                            )
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.public,
                            color: isActive ? Colors.white : Colors.white70,
                            size: isActive ? 54 : 28),
                        SizedBox(height: isActive ? 8 : 4),
                        Text('Genel',
                            style: TextStyle(
                                color: isActive ? Colors.white : Colors.white70,
                                fontSize: isActive ? 18 : 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSehirCircle() {
    final isActive = _isLocalSearch;
    final size = isActive ? 170.0 : 110.0;
    final left = isActive ? 65.0 : 170.0;
    final top = isActive ? 65.0 : 40.0;

    return AnimatedPositioned(
      key: const ValueKey('sehir'),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {
          if (!_isSearching && !_isPreparingAssets && !_isLocalSearch) {
            setState(() => _isLocalSearch = true);
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: isActive ? 1.0 : 0.4,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = (_isSearching && isActive)
                  ? 1.0 + (_pulseController.value * 0.05)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? Colors.blueAccent.withValues(alpha: 0.2)
                        : const Color(0xFF1E1E1E),
                    border: Border.all(
                      color: isActive ? Colors.blueAccent : Colors.white24,
                      width: isActive ? 4 : 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.4),
                              blurRadius: 25,
                              spreadRadius: 5,
                            )
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_city,
                            color: isActive ? Colors.white : Colors.white70,
                            size: isActive ? 54 : 28),
                        SizedBox(height: isActive ? 8 : 4),
                        Text(_userCity.isNotEmpty ? _userCity : 'Şehrimde',
                            style: TextStyle(
                                color: isActive ? Colors.white : Colors.white70,
                                fontSize: isActive ? 18 : 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── EŞLEŞME KABUL/RED OVERLAY ─────────────────────────────────────────────

class MatchFoundOverlay extends StatefulWidget {
  final String otherUserName;
  final String targetUserId;
  final String myUserId;
  final String roomId;
  final String movieName;
  final String? posterUrl;

  const MatchFoundOverlay({
    super.key,
    required this.otherUserName,
    required this.targetUserId,
    required this.myUserId,
    required this.roomId,
    required this.movieName,
    this.posterUrl,
  });

  @override
  State<MatchFoundOverlay> createState() => _MatchFoundOverlayState();
}

class _MatchFoundOverlayState extends State<MatchFoundOverlay>
    with TickerProviderStateMixin {
  // ── Animasyonlar ───────────────────────────────────────────
  late AnimationController _entranceController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  // ── Countdown ──────────────────────────────────────────────
  static const int _totalSeconds = 5;
  double _progress = 1.0; // 1.0 → 0.0
  Timer? _countdownTimer;
  int _remaining = _totalSeconds;

  // ── Kabul durumu ────────────────────────────────────────────
  bool _accepted = false;
  bool _isNavigating = false;
  Timer? _pollTimer;

  // ── Profil fotoğrafları ─────────────────────────────────────
  String? _myAvatarUrl;
  String? _otherAvatarUrl;

  @override
  void initState() {
    super.initState();

    // Giriş animasyonları
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn =
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();

    _startCountdown();
    _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    final myProfile = await ApiService.getProfile();
    final otherProfile = await ApiService.getUserProfile(widget.targetUserId);
    if (!mounted) return;
    setState(() {
      _myAvatarUrl = _resolveAvatarUrl(myProfile?['avatarUrl']);
      _otherAvatarUrl = _resolveAvatarUrl(otherProfile?['avatarUrl']);
    });
  }

  String? _resolveAvatarUrl(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http')) return s;
    return '${ApiService.baseUrl}$s';
  }

  void _startCountdown() {
    // OPTIMIZED: 100ms interval yeterli hassasiyet sağlar, 50ms yerine daha az CPU kullanır
    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed = (_totalSeconds * 1000 - timer.tick * 50)
          .clamp(0, _totalSeconds * 1000);
      setState(() {
        _progress = elapsed / (_totalSeconds * 1000);
        _remaining = (elapsed / 1000).ceil();
      });
      if (elapsed <= 0) {
        timer.cancel();
        if (_accepted) {
          setState(() {
            _progress = 0;
            _remaining = 0;
          });
          return;
        }
        _pollTimer?.cancel();
        // Süre bitti ve kullanıcı kabul etmediyse modal kapansın, aramaya devam
        if (mounted) {
          Navigator.of(context).pop(false);
        }
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _isNavigating) return;
      final status = await ApiService.getMatchAcceptStatus(widget.roomId);
      if (!mounted) return;

      if (status != null && status['bothAccepted'] == true) {
        // İkisi de kabul etti → sohbete geç
        final finalRoomId = (status['roomId'] ?? widget.roomId).toString();
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        _navigateToChat(finalRoomId);
      } else if (status != null && status['rejected'] == true) {
        // Karşı taraf reddetti → modal kapansın, aramaya devam
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pop(false);
        }
      }
    });
  }

  Future<void> _accept() async {
    if (_accepted || _isNavigating) return;
    setState(() => _accepted = true);
    // Countdown timer'ı DURDURMUYORUZ — süre devam ediyor

    final result = await ApiService.acceptMatch(
      roomId: widget.roomId,
      targetUserId: widget.targetUserId,
    );

    if (!mounted) return;

    if (result != null && result['bothAccepted'] == true) {
      final finalRoomId = (result['roomId'] ?? widget.roomId).toString();
      _countdownTimer?.cancel();
      _navigateToChat(finalRoomId);
    } else {
      // Karşı taraf henüz kabul etmedi → poll yap (süre devam ediyor)
      _startPolling();
    }
  }

  Future<void> _reject() async {
    if (_isNavigating) return;
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    // Arkada Redis match cache'i temizle, böylece aynı kişiyle anında tekrar eşleşmeyiz
    await ApiService.rejectMatch(
      roomId: widget.roomId,
      targetUserId: widget.targetUserId,
    );

    if (mounted) {
      // false döndürerek MatchScreen'in arama döngüsüne tekrar girmesini sağla
      Navigator.of(context).pop(false);
    }
  }

  void _navigateToChat(String finalRoomId) {
    if (_isNavigating || !mounted) return;
    setState(() => _isNavigating = true);
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    // true döndürerek MatchScreen'de arama döngüsünü tamamen kapatmasını sağla
    Navigator.of(context).pop(true);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          username: widget.otherUserName,
          avatarSeed: widget.targetUserId,
          avatarUrl: _otherAvatarUrl,
          isOnline: true,
          movieTitle: widget.movieName,
          moviePoster: widget.posterUrl,
          targetUserId: widget.targetUserId,
          roomId: finalRoomId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Widget _avatarWidget(String? url, double size) {
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _defaultAvatar(size),
          placeholder: (_, __) => _defaultAvatar(size),
        ),
      );
    }
    return _defaultAvatar(size);
  }

  Widget _defaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1E1E1E),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.52,
        color: Colors.white54,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Karanlık arka plan (blur effect) ─────────────────
          GestureDetector(
            onTap: () {}, // Taps through disabled
            child: Container(
              color: Colors.black.withValues(alpha: 0.85),
            ),
          ),

          // ── Film afişi soluk arka plan ─────────────────────────
          if (widget.posterUrl != null && widget.posterUrl!.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: CachedNetworkImage(
                  imageUrl: widget.posterUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

          // ── İçerik ─────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: AnimatedBuilder(
                animation: _slideUp,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: child,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Başlık ──────────────────────────────────
                    const Text(
                      '🎉 Eşleşme Bulundu!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.movieName} izlerken eşleştin',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 42),

                    // ── İki kullanıcı avatarı + VS ───────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ben
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFE53935),
                                    Color(0xFFFF6F60)
                                  ],
                                ),
                              ),
                              child: _avatarWidget(_myAvatarUrl, 80),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Sen',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                        // VS ayırıcı
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Text(
                                  '❤️',
                                  style: TextStyle(fontSize: 24),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Karşı taraf
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF1565C0),
                                    Color(0xFF42A5F5)
                                  ],
                                ),
                              ),
                              child: _avatarWidget(_otherAvatarUrl, 80),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.otherUserName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // ── Açıklama metni ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _accepted
                            ? '${widget.otherUserName} de kabul etsin bekleniyor...'
                            : '${widget.otherUserName} ile sohbet etmek ister misin?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Butonlar ─────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        children: [
                          // Reddet
                          Expanded(
                            child: GestureDetector(
                              onTap: _accepted ? null : _reject,
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                      alpha: _accepted ? 0.03 : 0.07),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _accepted
                                          ? Colors.white10
                                          : Colors.white24),
                                ),
                                child: Center(
                                  child: Text(
                                    'Reddet',
                                    style: TextStyle(
                                      color: _accepted
                                          ? Colors.white30
                                          : Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Kabul Et
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: _accepted ? null : _accept,
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _accepted
                                        ? [
                                            const Color(0xFF555555),
                                            const Color(0xFF777777)
                                          ]
                                        : [
                                            const Color(0xFFE53935),
                                            const Color(0xFFFF6F60)
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: _accepted
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFFE53935)
                                                .withValues(alpha: 0.45),
                                            blurRadius: 18,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _accepted
                                            ? Icons.check_circle
                                            : Icons.chat_bubble_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _accepted ? 'Kabul Edildi' : 'Kabul Et',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Progress bar (countdown) ──────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: _progress, end: _progress),
                              duration: const Duration(milliseconds: 50),
                              builder: (_, val, __) => LinearProgressIndicator(
                                value: val,
                                minHeight: 5,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color.lerp(Colors.redAccent,
                                      Colors.greenAccent, _progress)!,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_remaining saniye',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
