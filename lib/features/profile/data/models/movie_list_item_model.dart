class MovieListItemModel {
  const MovieListItemModel({
    required this.tmdbId,
    required this.movieName,
    required this.posterUrl,
  });

  factory MovieListItemModel.fromMap(Map<String, dynamic> map) {
    return MovieListItemModel(
      tmdbId: int.tryParse((map['tmdbId'] ?? '0').toString()) ?? 0,
      movieName: (map['movieName'] ?? '').toString(),
      posterUrl: (map['posterUrl'] ?? '').toString(),
    );
  }

  final int tmdbId;
  final String movieName;
  final String posterUrl;
}
