import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../services/watching_service.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late Movie currentMovie;
  bool _isWatchingThis = false;
  bool _isLoadingWatchStatus = true;

  @override
  void initState() {
    super.initState();
    currentMovie = widget.movie;
    _fetchFullDetails();
    _checkWatchStatus();
  }

  Future<void> _checkWatchStatus() async {
    // Sadece bu filmi izleyip izlemediğini kontrol et
    final statusData = await ApiService.getMyWatchStatus();
    if (mounted) {
      if (statusData != null && statusData['watching'] == true) {
        final tmdbId = statusData['status']['tmdbId'];
        if (tmdbId == currentMovie.id) {
          setState(() {
            _isWatchingThis = true;
          });
        }
      }
      setState(() {
        _isLoadingWatchStatus = false;
      });
    }
  }

  Future<void> _toggleWatchStatus() async {
    setState(() {
      _isLoadingWatchStatus = true;
    });

    if (_isWatchingThis) {
      // İzlemeyi bitir
      final success = await WatchingService.instance.stopWatching();
      if (success && mounted) {
        setState(() {
          _isWatchingThis = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İzleme durumunuz sonlandı.')),
        );
      }
    } else {
      // İzlemeye başla
      final success = await WatchingService.instance.startWatching(
        currentMovie.id,
        currentMovie.title,
        currentMovie.posterUrl,
      );
      if (success && mounted) {
        setState(() {
          _isWatchingThis = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Durumunuz ${currentMovie.title} izliyor olarak güncellendi!')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İzleme durumu başlatılamadı.')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingWatchStatus = false;
      });
    }
  }

  Future<void> _fetchFullDetails() async {
    // API'den "runtime" gibi ekstra verileri almak için film detayı isteği
    final detailedMovie = await ApiService.getMovieDetails(currentMovie.id);
    if (detailedMovie != null && mounted) {
      setState(() {
        // Mevcut verilerin üzerine, runtime gibi sadece detaydan gelen verileri bindir
        currentMovie = detailedMovie;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  const Text(
                    "Özet",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (currentMovie.isOverviewFallback)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.amber, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Bu film, henüz Türkçe özet içermediğinden dolayı İngilizce özet gösteriliyor.",
                              style: TextStyle(
                                color: Colors.amber.shade200,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    currentMovie.overview.isNotEmpty
                        ? currentMovie.overview
                        : "Bu film için detaylı bir özet bulunmuyor.",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 400.0,
      pinned: true,
      backgroundColor: const Color(0xFF0F0F0F),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Arka plan resmi (Backdrop veya Poster)
            CachedNetworkImage(
              imageUrl: currentMovie.backdropUrl.isNotEmpty
                  ? currentMovie.backdropUrl
                  : currentMovie.posterUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFF1E1E1E)),
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFF1E1E1E)),
            ),
            // Karartma efekti (gradient)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF0F0F0F)],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            // Canlı izleyici rozeti (Eğer varsa)
            if (currentMovie.watcherCount > 0)
              Positioned(
                top: 60,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${currentMovie.watcherCount} kişi şu an izliyor",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentMovie.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        if (currentMovie.originalTitle != null &&
            currentMovie.originalTitle != currentMovie.title)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              currentMovie.originalTitle!,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Puan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    currentMovie.voteAverage.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Yıl
            Text(
              currentMovie.releaseYear,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (currentMovie.runtime != null && currentMovie.runtime! > 0) ...[
              const SizedBox(width: 12),
              const Text(
                "•",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Text(
                currentMovie.runtimeFormatted,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Film Türleri
        Text(
          currentMovie.genreNames,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoadingWatchStatus ? null : _toggleWatchStatus,
            icon: _isLoadingWatchStatus
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(
                    _isWatchingThis
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_fill,
                    color: Colors.white),
            label: Text(
              _isWatchingThis ? "İzlemeyi Bitir" : "Şu an İzliyorum",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isWatchingThis
                  ? Colors.redAccent.shade700
                  : Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Listeye / Favorilere Ekle Butonu
        Container(
          height: 56, // Kırmızı butonla aynı hizada olması için
          width: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: IconButton(
            onPressed: () {
              // todo: İleride "Hangi listeye eklemek istersiniz?" bottom sheet'i açılacak
              // ignore: todo
            },
            icon: const Icon(
              Icons.star_border_rounded,
              color: Colors.white70,
              size: 28,
            ),
            tooltip: "Listeye Ekle",
          ),
        ),
      ],
    );
  }
}
