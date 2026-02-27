import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with TickerProviderStateMixin {
  bool _isLocalSearch = false; // false = Genel Arama, true = Aynı Şehirde Arama
  final int _queueCount = 42; // Temsili bekleyen sayısı

  bool _isPreparingAssets = false;
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
          _slideshowPosters.isNotEmpty &&
          _isSearching) {
        setState(() {
          _slideIndex = (_slideIndex + 1) % _slideshowPosters.length;
        });
        _slideController.forward(from: 0);
      }
    });

    _loadWatchingStatus();
  }

  @override
  void dispose() {
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

  Future<void> _openUserProfile(String userId) async {
    final profile = await ApiService.getUserProfile(userId);
    if (!mounted) return;
    if (profile == null) return;

    final username = (profile['username'] ?? '').toString();
    final city = (profile['city'] ?? '').toString();
    final isFriend = profile['isFriend'] == true;
    final isMatched = profile['isMatched'] == true;
    final canSeeWatching = profile['canSeeWatching'] == true;
    final watching = profile['watching'] == true;

    final status = profile['status'] as Map<String, dynamic>?;
    final movieName = (status?['movieName'] ?? '').toString();
    final watchingFor = (profile['watchingFor'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$username',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  city.isNotEmpty ? city : 'Şehir bilgisi yok',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoBadge(
                      isFriend ? 'Arkadaş' : 'Arkadaş değil',
                      isFriend ? Colors.greenAccent : Colors.white24,
                    ),
                    _buildInfoBadge(
                      isMatched ? 'Eşleşmiş' : 'Eşleşmemiş',
                      isMatched ? Colors.blueAccent : Colors.white24,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (canSeeWatching && watching && movieName.isNotEmpty)
                  Text(
                    watchingFor.isNotEmpty
                        ? 'Anlık izliyor: $movieName · $watchingFor'
                        : 'Anlık izliyor: $movieName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (!canSeeWatching)
                  const Text(
                    'Bu kullanıcının anlık izleme durumu yalnızca arkadaşlara veya eşleşen kullanıcılara açıktır.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  )
                else
                  const Text(
                    'Kullanıcı şu an aktif olarak bir şey izlemiyor.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUserSearchSection() {
    final hasQuery = _userSearchController.text.trim().length >= 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          TextField(
            controller: _userSearchController,
            onChanged: _onUserSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Kullanıcı adı ile ara...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.10),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (hasQuery)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
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
                          separatorBuilder: (_, __) =>
                              Divider(color: Colors.white.withOpacity(0.08)),
                          itemBuilder: (context, index) {
                            final user = _userSearchResults[index];
                            final username =
                                (user['username'] ?? '').toString();
                            final city = (user['city'] ?? '').toString();
                            final userId = (user['userId'] ?? user['_id'] ?? '')
                                .toString();

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                child: Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                username,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                city.isNotEmpty ? city : 'Şehir bilgisi yok',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              onTap: userId.isEmpty
                                  ? null
                                  : () => _openUserProfile(userId),
                            );
                          },
                        ),
            ),
        ],
      ),
    );
  }

  String _posterUrl(String posterPath) {
    final clean = posterPath.trim();
    if (clean.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w780$clean';
  }

  Future<void> _loadWatchingStatus() async {
    final statusData = await ApiService.getMyWatchStatus();
    if (!mounted) return;

    if (statusData != null && statusData['watching'] == true) {
      final status = statusData['status'];
      setState(() {
        _isWatching = true;
        _watchingMovieName = (status?['movieName'] ?? '').toString();
        _watchingFor = (statusData['watchingFor'] ?? '').toString();
        _watchingPosterPath = (status?['posterPath'] ?? '').toString();
      });
    } else {
      setState(() {
        _isWatching = false;
        _watchingMovieName = '';
        _watchingFor = '';
        _watchingPosterPath = '';
      });
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

    _slideController.forward(from: 0);
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
    if (_isSearching || _isPreparingAssets) return;

    final currentRequestId = ++_searchRequestId;

    setState(() {
      _isPreparingAssets = true;
    });

    final posters = await _buildTopPosterList();

    if (!mounted || currentRequestId != _searchRequestId) return;

    await _precacheTopPosters(posters);

    if (!mounted || currentRequestId != _searchRequestId) return;

    setState(() {
      _isPreparingAssets = false;
      _isSearching = true;
    });
    _startDots();

    if (posters.isNotEmpty) {
      _startSlideshow(posters);
    } else {
      _stopSlideshow();
    }

    // Sahte arama süreci (3 saniye sonra eşleşme bulundu ekranı)
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || currentRequestId != _searchRequestId) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                _isLocalSearch ? Icons.location_on : Icons.public,
                color: _isLocalSearch ? Colors.blueAccent : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              const Text('Eşleşme Bulundu!',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            _isLocalSearch
                ? 'Seninle aynı şehirde Inception izleyen biriyle eşleştin!'
                : 'Dünyanın bir ucunda seninle aynı anda Inception izleyen biriyle eşleştin!',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (!mounted) return;
                setState(() {
                  _isSearching = false;
                });
                _stopSlideshow();
                _stopDots();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isLocalSearch ? Colors.blueAccent : Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sohbete Başla',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBackground() {
    final hasSlideshow =
        _isSearching && _slideshowActive && _slideshowPosters.isNotEmpty;

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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.72),
                  Colors.black.withOpacity(0.86),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildUserSearchSection(),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
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
                        'Şu an $_queueCount kişi eşleşme bekliyor',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isWatching &&
                    _watchingMovieName.isNotEmpty &&
                    !_isSearching)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.redAccent.withOpacity(0.45)),
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
                Expanded(
                  child: GestureDetector(
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
                      child: Center(
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
                                      final scale =
                                          1.0 + (_pulseController.value * 0.15);
                                      return Transform.scale(
                                        scale: scale,
                                        child: Container(
                                          width: 170,
                                          height: 170,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: (_isLocalSearch
                                                      ? Colors.blueAccent
                                                      : Colors.redAccent)
                                                  .withOpacity(1 -
                                                      _pulseController.value),
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
                if (_isSearching && _watchingMovieName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: (_isSearching || _isPreparingAssets)
                          ? null
                          : _startSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLocalSearch
                            ? Colors.blueAccent
                            : Colors.redAccent,
                        shadowColor: _isLocalSearch
                            ? Colors.blueAccent
                            : Colors.redAccent,
                        elevation: (_isSearching || _isPreparingAssets) ? 0 : 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: (_isSearching || _isPreparingAssets)
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    _isLocalSearch
                                        ? Icons.my_location
                                        : Icons.search,
                                    color: Colors.white),
                                const SizedBox(width: 12),
                                Text(
                                  _isLocalSearch
                                      ? 'Şehrimde Eşleşme Ara'
                                      : 'Genel Eşleşme Ara',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
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
                        ? Colors.redAccent.withOpacity(0.2)
                        : const Color(0xFF1E1E1E),
                    border: Border.all(
                      color: isActive ? Colors.redAccent : Colors.white24,
                      width: isActive ? 4 : 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.4),
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
                        ? Colors.blueAccent.withOpacity(0.2)
                        : const Color(0xFF1E1E1E),
                    border: Border.all(
                      color: isActive ? Colors.blueAccent : Colors.white24,
                      width: isActive ? 4 : 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.4),
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
                        Text('Şehrimde',
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
