import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/base/base_state.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../models/movie.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../movies/presentation/views/movie_detail_screen.dart';
import '../view_models/home_radar_view_model.dart';

class HomeRadarScreen extends StatefulWidget {
  const HomeRadarScreen({super.key});

  @override
  State<HomeRadarScreen> createState() => _HomeRadarScreenState();
}

class _HomeRadarScreenState extends State<HomeRadarScreen>
    with ViewModelBindingMixin<HomeRadarScreen, HomeRadarViewModel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  HomeRadarViewModel createViewModel() => HomeRadarViewModel();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget buildWithViewModel(BuildContext context, HomeRadarViewModel vm) {
    final hasSearchQuery = vm.query.trim().length >= 2;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Column(
          children: <Widget>[
            Container(
              height: MediaQuery.of(context).padding.top,
              color: const Color(0xFF0F0F0F),
            ),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: vm.onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Ne izliyorsun?',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon:
                          const Icon(Icons.clear, color: Colors.grey, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        vm.onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      body: vm.status == ViewStatus.loading
          ? const LoadingView()
          : hasSearchQuery
              ? _SearchResults(
                  isLoading: vm.isSearching,
                  results: vm.searchResults,
                )
              : _TrendingView(
                  trendingMovies: vm.trendingMovies,
                  mindfuckMovies: vm.mindfuckMovies,
                  exMovies: vm.exMovies,
                  horrorMovies: vm.horrorMovies,
                  indieMovies: vm.indieMovies,
                ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.isLoading,
    required this.results,
  });

  final bool isLoading;
  final List<Movie> results;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingView();
    }

    if (results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.search_off, color: Colors.grey, size: 60),
            SizedBox(height: 12),
            Text(
              'Sonuç bulunamadı',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) => _SearchResultCard(movie: results[index]),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              child: movie.posterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      width: 90,
                      height: 130,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 90,
                      height: 130,
                      color: const Color(0xFF2A2A2A),
                      child: const Icon(Icons.movie, color: Colors.grey),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (movie.releaseYear.isNotEmpty)
                      Text(
                        movie.releaseYear,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      movie.genreNames,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      movie.overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
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
}

class _TrendingView extends StatelessWidget {
  const _TrendingView({
    required this.trendingMovies,
    required this.mindfuckMovies,
    required this.exMovies,
    required this.horrorMovies,
    required this.indieMovies,
  });

  final List<Movie> trendingMovies;
  final List<Movie> mindfuckMovies;
  final List<Movie> exMovies;
  final List<Movie> horrorMovies;
  final List<Movie> indieMovies;

  @override
  Widget build(BuildContext context) {
    final topTrending = trendingMovies.take(10).toList();
    final restTrending =
        trendingMovies.length > 10 ? trendingMovies.sublist(10) : <Movie>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          _CategorySection(title: 'Şu An Popüler', movies: topTrending),
          if (restTrending.isNotEmpty)
            _CategorySection(title: 'Daha Fazla Keşfet', movies: restTrending),
          _CategorySection(
              title: 'Bilim Kurgu & Gizem', movies: mindfuckMovies),
          _CategorySection(title: 'Dram & Romantik', movies: exMovies),
          _CategorySection(title: 'Korku & Gerilim', movies: horrorMovies),
          _CategorySection(title: 'Müzik & Tarih', movies: indieMovies),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.movies,
  });

  final String title;
  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: movies.length,
            itemBuilder: (context, index) =>
                _MoviePosterCard(movie: movies[index]),
          ),
        ),
      ],
    );
  }
}

class _MoviePosterCard extends StatelessWidget {
  const _MoviePosterCard({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
      ),
      child: Container(
        width: 135,
        margin: const EdgeInsets.only(right: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              movie.posterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: const Color(0xFF1E1E1E),
                      child: const Icon(Icons.movie, color: Colors.grey),
                    ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0.45, 1.0],
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      movie.releaseYear,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
