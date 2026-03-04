/// Film veri modeli — Go backend'den gelen TMDB verilerini temsil eder
class Movie {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String releaseDate;
  final double voteAverage;
  final int voteCount;
  final String? originalTitle;
  final List<int> genreIds;
  final int? runtime;
  final bool isOverviewFallback;
  int watcherCount; // Canlı izleyici sayısı (Go backend'den eklenecek)

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    this.originalTitle,
    this.genreIds = const [],
    this.runtime,
    this.isOverviewFallback = false,
    this.watcherCount = 0,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    // Liste ekranlarından "genre_ids" gelebilir, veya Detay ekranından "genres" gelebilir.
    List<int> parsedGenreIds = [];
    if (json['genre_ids'] != null) {
      parsedGenreIds = List<int>.from(json['genre_ids']);
    } else if (json['genres'] != null) {
      parsedGenreIds =
          (json['genres'] as List).map((genre) => genre['id'] as int).toList();
    }

    return Movie(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: json['release_date'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      originalTitle: json['original_title'],
      runtime: json['runtime'],
      genreIds: parsedGenreIds,
      isOverviewFallback: json['is_overview_fallback'] ?? false,
      watcherCount: json['watcher_count'] ?? 0,
    );
  }

  /// TMDB poster URL'si (w500 boyutu - orijinal kaliteli)
  String get posterUrl =>
      posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '';

  /// TMDB poster URL'si (w200 boyutu - arama sonuçları için düşük bellek kullanımı)
  String get posterUrlW200 =>
      posterPath != null ? 'https://image.tmdb.org/t/p/w200$posterPath' : '';

  /// TMDB backdrop URL'si (w780 boyutu)
  String get backdropUrl => backdropPath != null
      ? 'https://image.tmdb.org/t/p/w780$backdropPath'
      : '';

  /// Yayın yılı (sadece ilk 4 karakter)
  String get releaseYear =>
      releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';

  /// TMDB Genre ID'lerini Türkçe isimlere çevirir (İlgili tür haritasına göre)
  String get genreNames {
    if (genreIds.isEmpty) return "Bilinmiyor";

    const Map<int, String> genreMap = {
      28: "Aksiyon",
      12: "Macera",
      16: "Animasyon",
      35: "Komedi",
      80: "Suç",
      99: "Belgesel",
      18: "Dram",
      10751: "Aile",
      14: "Fantastik",
      36: "Tarih",
      27: "Korku",
      10402: "Müzik",
      9648: "Gizem",
      10749: "Romantik",
      878: "Bilim Kurgu",
      10770: "TV Filmi",
      53: "Gerilim",
      10752: "Savaş",
      37: "Vahşi Batı",
    };

    return genreIds.map((id) => genreMap[id] ?? "Diğer").take(2).join(", ");
  }

  /// Film süresini kullanıcı dostu formata çevirir (169 -> 2 saat 49 dakika)
  String get runtimeFormatted {
    if (runtime == null || runtime! <= 0) return "";
    final int hours = runtime! ~/ 60;
    final int minutes = runtime! % 60;

    if (hours > 0 && minutes > 0) {
      return "$hours saat $minutes dakika";
    } else if (hours > 0) {
      return "$hours saat";
    } else {
      return "$minutes dakika";
    }
  }
}
