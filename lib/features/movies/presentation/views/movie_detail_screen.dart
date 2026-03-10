import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../models/movie.dart';
import '../view_models/movie_detail_view_model.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movie,
  });

  final Movie movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with
        ViewModelBindingMixin<MovieDetailScreen, MovieDetailViewModel>,
        ViewEffectListenerMixin<MovieDetailScreen, MovieDetailViewModel> {
  @override
  MovieDetailViewModel createViewModel() => MovieDetailViewModel(widget.movie);

  @override
  Widget buildWithViewModel(BuildContext context, MovieDetailViewModel vm) {
    final movie = vm.movie;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: <Widget>[
          _buildSliverAppBar(context, movie),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHeaderInfo(movie),
                  const SizedBox(height: 24),
                  _buildActionButtons(vm),
                  const SizedBox(height: 24),
                  const Text(
                    'Özet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (movie.isOverviewFallback)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Bu film, henüz Türkçe özet içermediğinden dolayı İngilizce özet gösteriliyor.',
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
                    movie.overview.isNotEmpty
                        ? movie.overview
                        : 'Bu film için detaylı bir özet bulunmuyor.',
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
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Movie movie) {
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      backgroundColor: const Color(0xFF0F0F0F),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl:
                  movie.backdropUrl.isNotEmpty ? movie.backdropUrl : movie.posterUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFF1E1E1E)),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF1E1E1E)),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0xFF0F0F0F)],
                  stops: <double>[0.5, 1],
                ),
              ),
            ),
            if (movie.watcherCount > 0)
              Positioned(
                top: 60,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      width: 1,
                    ),
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
                        '${movie.watcherCount} kişi şu an izliyor',
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

  Widget _buildHeaderInfo(Movie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        if (movie.originalTitle != null && movie.originalTitle != movie.title)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              movie.originalTitle!,
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
                    movie.voteAverage.toStringAsFixed(1),
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
            Text(
              movie.releaseYear,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (movie.runtime != null && movie.runtime! > 0) ...[
              const SizedBox(width: 12),
              const Text(
                '•',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Text(
                movie.runtimeFormatted,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          movie.genreNames,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(MovieDetailViewModel vm) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: vm.isLoadingWatchStatus ? null : vm.toggleWatchStatus,
            icon: vm.isLoadingWatchStatus
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    vm.isWatchingThis ? Icons.stop_circle_rounded : Icons.play_circle_fill,
                    color: Colors.white,
                  ),
            label: Text(
              vm.isWatchingThis ? 'İzlemeyi Bitir' : 'Şu an İzliyorum',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: vm.isWatchingThis ? Colors.redAccent.shade700 : Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.star_border_rounded,
              color: Colors.white70,
              size: 28,
            ),
            tooltip: 'Listeye Ekle',
          ),
        ),
      ],
    );
  }
}
