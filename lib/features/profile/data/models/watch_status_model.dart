class WatchStatusModel {
  const WatchStatusModel({
    required this.movieName,
    required this.posterPath,
    required this.tmdbId,
    required this.watchingFor,
  });

  factory WatchStatusModel.fromMap(Map<String, dynamic> map) {
    final status =
        map['status'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return WatchStatusModel(
      movieName: (status['movieName'] ?? '').toString(),
      posterPath: (status['posterPath'] ?? '').toString(),
      tmdbId: int.tryParse((status['tmdbId'] ?? '0').toString()) ?? 0,
      watchingFor: (map['watchingFor'] ?? '').toString(),
    );
  }

  final String movieName;
  final String posterPath;
  final int tmdbId;
  final String watchingFor;
}
