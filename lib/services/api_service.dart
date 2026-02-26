import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';

/// Go backend'e istek atan servis katmanı
/// Flutter hiçbir zaman doğrudan TMDB'ye istek atmaz
class ApiService {
  // Android emülatörden localhost'a erişim için özel IP
  static const String baseUrl = 'http://10.0.2.2:8080';

  /// Film arama — Go backend'deki /search endpoint'ini çağırır
  static Future<List<Movie>> searchMovies(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query.trim())}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'] ?? [];
        return results.map((json) => Movie.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Film detayı — Go backend'deki /movie/:id endpoint'ini çağırır
  static Future<Movie?> getMovieDetails(int tmdbId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/movie/$tmdbId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Movie.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Trend filmler — Go backend'deki /trending endpoint'ini çağırır
  static Future<List<Movie>> getTrending() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trending'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'] ?? [];
        return results.map((json) => Movie.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Özel Listeler (Gecenin 3'ünde Beyin Yakanlar vs.)
  static Future<List<Movie>> getDiscoverMovies(String genres,
      {String sortBy = 'popularity.desc'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/discover?genres=$genres&sort_by=$sortBy'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'] ?? [];
        return results.map((json) => Movie.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
