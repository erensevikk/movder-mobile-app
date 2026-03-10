import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../features/profile/presentation/views/user_detail_screen.dart';
import '../../../../services/api_service.dart';
import '../../data/models/match_model.dart';
import '../../data/services/match_repository_impl.dart';
import '../view_models/match_screen_view_model.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => MatchScreenState();
}

class MatchScreenState extends State<MatchScreen>
    with
        TickerProviderStateMixin,
        ViewModelBindingMixin<MatchScreen, MatchScreenViewModel>,
        ViewEffectListenerMixin<MatchScreen, MatchScreenViewModel> {

  void setVisibility(bool visible) {
    viewModel.setVisibility(visible);
    if (visible && _slideshowActive) {
      if (_slideController.isCompleted) {
        _slideController.forward(from: 0);
      } else if (!_slideController.isAnimating) {
        _slideController.forward();
      }
    } else if (!visible && _slideController.isAnimating) {
      _slideController.stop();
    }
  }

  Future<void> reloadWatchingStatus() async {
    await viewModel.reloadWatchingStatus();
  }

  @override
  MatchScreenViewModel createViewModel() => MatchScreenViewModel(
        repository: MatchRepositoryImpl(),
      );

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _slideXAnimation;

  final List<String> _slideshowPosters = [];
  int _slideIndex = 0;
  bool _slideshowActive = false;

  Timer? _dotTimer;
  int _dotCount = 1;

  String _userCity = '';

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
        _slideController.forward(from: 0);
      }
    });

    _initBackgroundSlideshow();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _stopDots();
    super.dispose();
  }

  Future<void> _initBackgroundSlideshow() async {
    final posters = await _buildTopPosterList();
    if (!mounted) return;
    await _precacheTopPosters(posters);
    if (!mounted) return;
    if (posters.isNotEmpty) {
      _startSlideshow(posters);
    }
    final profileData = await ApiService.getProfile();
    if (mounted && profileData != null) {
      setState(() {
        _userCity = (profileData['city'] ?? '').toString();
      });
    }
  }

  Future<List<String>> _buildTopPosterList() async {
    final movies = await ApiService.getTopActiveMovies(limit: 10);
    final posters = <String>[];
    for (final movie in movies) {
      final posterPath = (movie['posterPath'] ?? '').toString().trim();
      if (posterPath.isNotEmpty && !posters.contains(posterPath)) {
        posters.add(posterPath);
        if (posters.length == 5) break;
      }
    }
    if (posters.length < 5) {
      final trending = await ApiService.getTrending();
      final sortedTrending = List.of(trending)
        ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
      for (final movie in sortedTrending) {
        final posterPath = (movie.posterPath ?? '').trim();
        if (posterPath.isNotEmpty && !posters.contains(posterPath)) {
          posters.add(posterPath);
          if (posters.length == 5) break;
        }
      }
    }
    // Also add watching movie if not already there
    final watchingPoster = viewModel.watchingMovie?.posterPath?.trim() ?? '';
    if (posters.length < 5 && watchingPoster.isNotEmpty && !posters.contains(watchingPoster)) {
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

  String _posterUrl(String posterPath) {
    if (posterPath.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w780$posterPath';
  }

  void _startSlideshow(List<String> posters) {
    _slideshowPosters
      ..clear()
      ..addAll(posters);
    if (_slideshowPosters.isEmpty) return;
    setState(() {
      _slideIndex = 0;
      _slideshowActive = true;
    });
    _slideController.forward(from: 0);
  }

  void _startDots() {
    _stopDots();
    _dotCount = 1;
    _dotTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) return;
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

  Widget _buildBackground(MatchScreenViewModel vm) {
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

    if (vm.watchingMovie?.posterPath != null) {
      return SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: _posterUrl(vm.watchingMovie!.posterPath!),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorWidget: (_, __, ___) =>
              Container(color: const Color(0xFF0F0F0F)),
          placeholder: (_, __) => Container(color: const Color(0xFF0F0F0F)),
        ),
      );
    }

    return Container(color: const Color(0xFF0F0F0F));
  }

  @override
  Widget buildWithViewModel(BuildContext context, MatchScreenViewModel vm) {
    if (vm.isSearching && _dotTimer == null) {
      _startDots();
    } else if (!vm.isSearching && _dotTimer != null) {
      _stopDots();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(vm),
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
                Column(
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: TextField(
                        controller: vm.userSearchController,
                        onChanged: vm.onUserSearchChanged,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Kullanıcı adı ile ara...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white70),
                          suffixIcon: vm.userSearchController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    vm.userSearchController.clear();
                                    vm.onUserSearchChanged('');
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
                            'Şu an ${vm.queueCount} kişi eşleşmeyi bekliyor',
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
                              if (vm.isSearching) return;
                              if (details.primaryVelocity! < -300) {
                                setState(() => vm.isLocalSearch = true);
                              } else if (details.primaryVelocity! > 300) {
                                setState(() => vm.isLocalSearch = false);
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
                                        if (vm.isSearching)
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
                                                        color: (vm.isLocalSearch
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
                                        if (vm.isLocalSearch) ...[
                                          _buildGenelCircle(vm),
                                          _buildSehirCircle(vm),
                                        ] else ...[
                                          _buildSehirCircle(vm),
                                          _buildGenelCircle(vm),
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
                              if (vm.isSearching && vm.watchingMovie != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Text(
                                    '${vm.watchingMovie!.title} filmi için eşleşme aranıyor ${'.' * _dotCount}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (vm.isSearching && vm.watchingMovie != null)
                                const SizedBox(height: 10),
                              if (!vm.isWatching && !vm.isSearching)
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
                              if (!vm.isWatching && !vm.isSearching)
                                const SizedBox(height: 10),
                              if (vm.isWatching &&
                                  vm.watchingMovie != null &&
                                  !vm.isSearching)
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
                                          'Aktif Durum: ${vm.watchingMovie!.title} izliyorsun',
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
                                    onPressed: (!vm.isWatching && !vm.isSearching)
                                        ? null
                                        : vm.isSearching
                                            ? vm.cancelSearch
                                            : () => vm.selectMovie(vm.watchingMovie!, localSearch: vm.isLocalSearch),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          (!vm.isWatching && !vm.isSearching)
                                              ? Colors.grey[850]
                                              : vm.isSearching
                                                  ? Colors.grey[800]
                                                  : (vm.isLocalSearch
                                                      ? Colors.blueAccent
                                                      : Colors.redAccent),
                                      shadowColor: vm.isSearching ||
                                              (!vm.isWatching && !vm.isSearching)
                                          ? Colors.transparent
                                          : (vm.isLocalSearch
                                              ? Colors.blueAccent
                                              : Colors.redAccent),
                                      elevation: vm.isSearching ||
                                              (!vm.isWatching && !vm.isSearching)
                                          ? 0
                                          : 8,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: vm.isSearching
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
                                                  vm.isLocalSearch
                                                      ? Icons.my_location
                                                      : Icons.search,
                                                  color: (!vm.isWatching)
                                                      ? Colors.white54
                                                      : Colors.white),
                                              const SizedBox(width: 12),
                                              Text(
                                                vm.isLocalSearch
                                                    ? 'Şehrimde Eşleşme Ara'
                                                    : 'Genel Eşleşme Ara',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: (!vm.isWatching)
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
                if (vm.userSearchController.text.trim().length >= 2)
                  Positioned(
                    top: 76, 
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
                        child: vm.isUserSearching
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
                            : vm.userSearchResults.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Text(
                                      'Kullanıcı bulunamadı',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: vm.userSearchResults.length,
                                    separatorBuilder: (_, __) => Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.08)),
                                    itemBuilder: (context, index) {
                                      final user = vm.userSearchResults[index];
                                      final username = user.username;
                                      final city = user.city ?? '';
                                      final userId = user.userId;
                                      final avatarUrl = user.avatarUrl ?? '';
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
                                        onTap: () {
                                          vm.userSearchController.clear();
                                          vm.onUserSearchChanged('');
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  UserDetailScreen(
                                                userId: userId,
                                                isMe: false, 
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
          if (vm.status == MatchStatus.found && vm.currentMatch != null)
            MatchFoundOverlayWidget(vm: vm),
        ],
      ),
    );
  }

  Widget _buildGenelCircle(MatchScreenViewModel vm) {
    final isActive = !vm.isLocalSearch;
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
          if (!vm.isSearching) {
            setState(() => vm.isLocalSearch = false);
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: isActive ? 1.0 : 0.4,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = (vm.isSearching && isActive)
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

  Widget _buildSehirCircle(MatchScreenViewModel vm) {
    final isActive = vm.isLocalSearch;
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
          if (!vm.isSearching) {
            setState(() => vm.isLocalSearch = true);
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: isActive ? 1.0 : 0.4,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = (vm.isSearching && isActive)
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

class MatchFoundOverlayWidget extends StatefulWidget {
  final MatchScreenViewModel vm;

  const MatchFoundOverlayWidget({
    super.key,
    required this.vm,
  });

  @override
  State<MatchFoundOverlayWidget> createState() => _MatchFoundOverlayWidgetState();
}

class _MatchFoundOverlayWidgetState extends State<MatchFoundOverlayWidget>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  static const int _totalSeconds = 5;
  double _progress = 1.0;
  Timer? _countdownTimer;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed = (_totalSeconds * 1000 - timer.tick * 100).clamp(0, _totalSeconds * 1000); 
      setState(() {
        _progress = elapsed / (_totalSeconds * 1000);
      });
      if (elapsed <= 0) {
        timer.cancel();
        if (_accepted) return;
        if (mounted) {
           widget.vm.rejectMatch();
        }
      }
    });
  }

  Future<void> _accept() async {
    if (_accepted) return;
    setState(() => _accepted = true);
    await widget.vm.acceptMatch();
  }

  Future<void> _reject() async {
    _countdownTimer?.cancel();
    await widget.vm.rejectMatch();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _countdownTimer?.cancel();
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
    final match = widget.vm.currentMatch;
    if (match == null) return const SizedBox.shrink();
    
    final movieName = match.movie.title;
    final posterUrl = match.movie.posterPath != null ? 'https://image.tmdb.org/t/p/w780${match.movie.posterPath}' : null;
    final otherUserName = match.username;
    final otherAvatarUrl = match.avatarUrl?.startsWith('http') == true ? match.avatarUrl : (match.avatarUrl != null ? '${ApiService.baseUrl}${match.avatarUrl}' : null);
    final myAvatarUrl = widget.vm.myAvatarUrl; 

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {},
            child: Container(
              color: Colors.black.withValues(alpha: 0.85),
            ),
          ),
          if (posterUrl != null && posterUrl.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
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
                      '$movieName izlerken eşleştin',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 42),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                              child: _avatarWidget(myAvatarUrl, 80),
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
                              child: _avatarWidget(otherAvatarUrl, 80),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              otherUserName,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _accepted
                            ? '$otherUserName de kabul etsin bekleniyor...'
                            : '$otherUserName ile sohbet etmek ister misin?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _reject,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Reddet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _accept,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accepted ? Colors.green : Colors.redAccent,
                                foregroundColor: Colors.white,
                                elevation: _accepted ? 0 : 8,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                shadowColor: Colors.redAccent.withValues(alpha: 0.5),
                              ),
                              child: Text(
                                _accepted ? 'Bekleniyor...' : 'Kabul Et',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          color: _progress > 0.3 ? Colors.greenAccent : Colors.redAccent,
                          minHeight: 6,
                        ),
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
