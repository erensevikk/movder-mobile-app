import '../../services/api_service.dart';

class UrlResolver {
  static String? resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;

    // Remote URLs
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // Local uploads
    if (path.startsWith('/uploads/')) {
      return '${ApiService.baseUrl}$path';
    }

    // TMDB relative paths
    if (path.startsWith('/')) {
      return 'https://image.tmdb.org/t/p/w500$path';
    }

    return path;
  }
}
