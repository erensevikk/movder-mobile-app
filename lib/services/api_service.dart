import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import 'auth_service.dart';

/// Go backend'e istek atan servis katmanı
/// Flutter hiçbir zaman doğrudan TMDB'ye istek atmaz
class ApiService {
  // Android emülatörden localhost'a erişim için özel IP
  static const String baseUrl = 'http://10.0.2.2:8080';

  static Future<http.Response> get(String path) async {
    final token = AuthService.token;
    return http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  static Future<http.Response> put(
      String path, Map<String, dynamic> body) async {
    final token = AuthService.token;
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> post(
      String path, Map<String, dynamic> body) async {
    final token = AuthService.token;
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String path) async {
    final token = AuthService.token;
    return http.delete(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// Film arama — Go backend'deki /search endpoint'ini çağırır
  static Future<List<Movie>> searchMovies(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query.trim())}'),
          )
          .timeout(const Duration(seconds: 4));

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

  static Future<Map<String, dynamic>?> getProfile() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getPrivacySettings() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/account/privacy'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final settings = data['privacySettings'];
        if (settings is Map<String, dynamic>) {
          return settings;
        }
        if (settings is Map) {
          return Map<String, dynamic>.from(settings);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updatePrivacySettings({
    String? watchingVisibility,
    String? profileVisibility,
    bool? searchDiscoverable,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    final body = <String, dynamic>{};
    if (watchingVisibility != null) {
      body['watchingVisibility'] = watchingVisibility;
    }
    if (profileVisibility != null) {
      body['profileVisibility'] = profileVisibility;
    }
    if (searchDiscoverable != null) {
      body['searchDiscoverable'] = searchDiscoverable;
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/account/privacy'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final settings = data['privacySettings'];
        if (settings is Map<String, dynamic>) {
          return settings;
        }
        if (settings is Map) {
          return Map<String, dynamic>.from(settings);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Profil bilgilerini (açıklama ve/veya avatar) günceller
  static Future<Map<String, dynamic>?> updateProfile({
    String? description,
    Uint8List? imageBytes,
    String? imageFileName,
    Uint8List? coverImageBytes,
    String? coverImageFileName,
    bool deleteCover = false,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/profile'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      if (description != null) {
        request.fields['description'] = description;
      }

      if (imageBytes != null && imageFileName != null) {
        request.files.add(
          http.MultipartFile.fromBytes('avatar', imageBytes,
              filename: imageFileName),
        );
      }

      if (coverImageBytes != null && coverImageFileName != null) {
        request.files.add(
          http.MultipartFile.fromBytes('cover', coverImageBytes,
              filename: coverImageFileName),
        );
      }

      if (deleteCover) {
        request.fields['delete_cover'] = 'true';
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {'error': 'Güncelleme başarısız: ${response.statusCode}'};
    } catch (e) {
      return {'error': 'Güncelleme sırasında hata: $e'};
    }
  }

  /// Kullanıcının anlık izleme durumunu getir
  static Future<Map<String, dynamic>?> getMyWatchStatus() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Aktif kullanıcıların izlediği en popüler filmleri getir (posterPath dolu olanlar)
  static Future<List<Map<String, dynamic>>> getTopActiveMovies({
    int limit = 10,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status/top-movies?limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List raw = data['movies'] ?? [];
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  /// Username'e göre kullanıcı ara
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return [];

    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/users/search?q=${Uri.encodeComponent(cleanQuery)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List raw = data['users'] ?? [];
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Başka bir kullanıcının profilini getir
  static Future<Map<String, dynamic>?> getUserProfile(
      String targetUserId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$targetUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(milliseconds: 2000));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// İzleme durumu belirle
  static Future<bool> setWatchStatus({
    required int tmdbId,
    required String movieName,
    required String posterPath,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'tmdbId': tmdbId,
          'movieName': movieName,
          'posterPath': posterPath,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// İzlemeyi bitir
  static Future<bool> removeWatchStatus() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// İzleme durumunu yenile (Heartbeat)
  static Future<bool> heartbeatStatus() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return false;

    try {
      // PATCH isteği
      final response = await http.patch(
        Uri.parse('$baseUrl/api/status/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Arkadaşlık isteği gönder (karşılıklı onay mantığı backend'de)
  /// Dönen map: { "status": "pending" | "friends", "message": "..." }
  static Future<Map<String, dynamic>?> sendFriendRequest(
      String targetUserId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/friends/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'targetUserId': targetUserId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      // Hata durumunda da mesajı dön
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// İki kullanıcı arasındaki arkadaşlık durumunu sorgula
  /// Döner: "none" | "pending_sent" | "pending_received" | "friends"
  static Future<String> getFriendStatus(String targetUserId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return 'none';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/friends/status/$targetUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['status'] ?? 'none').toString();
      }
      return 'none';
    } catch (_) {
      return 'none';
    }
  }

  /// Arkadaş listesini getir
  static Future<List<Map<String, dynamic>>> getFriends() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/friends'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List raw = data['friends'] ?? [];
        return raw.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Arkadaşlıktan çıkar veya gelen/giden isteği iptal et
  static Future<bool> removeFriend(String targetUserId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/friends/$targetUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcıyı engelle
  static Future<bool> blockUser(String targetUserId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/block/$targetUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Eşleşmeyi iptal et
  static Future<bool> unmatchUser(String targetUserId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/unmatch/$targetUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Yeni Liste (Kategori) Oluştur
  static Future<Map<String, dynamic>?> createList({
    required String name,
    required String description,
    bool isPublic = true,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/lists/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'isPublic': isPublic,
        }),
      );

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Kullanıcının kendi (kategori) listelerini getir
  static Future<List<Map<String, dynamic>>> getMyLists() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/lists/my'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body);
        return raw.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Belirli bir kullanıcının genel listelerini getir
  static Future<List<Map<String, dynamic>>> getUserLists(String userId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/lists/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body);
        return raw.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Bir listeye ait içerikleri/filmleri getir
  static Future<List<Map<String, dynamic>>> getListItems(String listId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/lists/$listId/items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body);
        return raw.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Bir filme ait özel listeye film ekler
  static Future<Map<String, dynamic>?> addMovieToList({
    required String listId,
    required int tmdbId,
    required String movieName,
    required String posterUrl,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/lists/items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'listId': listId,
          'tmdbId': tmdbId,
          'movieName': movieName,
          'posterUrl': posterUrl,
        }),
      );

      if (response.statusCode == 409 ||
          response.statusCode == 400 ||
          response.statusCode == 403 ||
          response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {'error': 'Ekleme başarısız: ${response.statusCode}'};
    } catch (e) {
      return {'error': 'Sistem hatası: $e'};
    }
  }

  /// Belirli bir listeden bir filmi siler
  static Future<bool> removeMovieFromList(String listId, int tmdbId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/lists/$listId/items/$tmdbId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Bir listeyi ve tüm içeriklerini siler
  static Future<bool> deleteList(String listId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/lists/$listId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Bir listenin film sıralamasını günceller
  static Future<bool> reorderList(String listId, List<int> tmdbIds) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/lists/$listId/reorder'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'tmdbIds': tmdbIds}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Bir listenin adını değiştirir
  static Future<Map<String, dynamic>?> renameList(
      String listId, String newName) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/lists/$listId/rename'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': newName}),
      );
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  /// Aktif eşleşme arar
  static Future<Map<String, dynamic>?> checkMatch(
    int tmdbId, {
    bool localOnly = false,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final uri = Uri.parse(
        '$baseUrl/api/match/check?tmdbId=$tmdbId&localOnly=${localOnly ? '1' : '0'}',
      );
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Aramayı iptal eder (kuyruktan çıkarır)
  static Future<void> cancelMatch(int tmdbId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return;

    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/match/cancel'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'tmdbId': tmdbId}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// Toplam kuyruk bekleyen kişi sayısını getirir
  static Future<int> getQueueCount() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return 0;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/match/queue-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['queueCount'] ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Letterboxd dosyasını parse edip önizleme üretir (ZIP veya CSV)
  static Future<Map<String, dynamic>?> previewLetterboxdImport({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/lists/import/preview'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      if (response.statusCode == 200 && data != null) return data;

      if (data != null) {
        return {
          'error': (data['error'] ?? 'Onizleme alinamadi').toString(),
          'errorCode': (data['errorCode'] ?? '').toString(),
          'statusCode': response.statusCode,
        };
      }

      return {
        'error':
            'Onizleme hatasi (HTTP ${response.statusCode}): ${response.body}',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'error': 'Onizleme sirasinda baglanti hatasi: $e'};
    }
  }

  /// Letterboxd importunu commit eder
  static Future<Map<String, dynamic>?> commitLetterboxdImport({
    required String previewToken,
    String strategy = 'merge',
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/lists/import/commit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'previewToken': previewToken,
          'strategy': strategy,
        }),
      );

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      if (response.statusCode == 200 && data != null) return data;

      if (data != null) {
        return {
          'error': (data['error'] ?? 'Import islemi basarisiz').toString(),
          'errorCode': (data['errorCode'] ?? '').toString(),
          'statusCode': response.statusCode,
        };
      }

      return {
        'error':
            'Import hatasi (HTTP ${response.statusCode}): ${response.body}',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'error': 'Import sirasinda baglanti hatasi: $e'};
    }
  }

  /// Eşleşmeyi kabul et — karşı taraf da kabul ettiyse roomId döner
  static Future<Map<String, dynamic>?> acceptMatch({
    required String roomId,
    required String targetUserId,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/match/accept'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'roomId': roomId, 'targetUserId': targetUserId}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Eşleşmeyi reddet — kuyruk aramasında kalmaya devam eder ama aynı kişiyle tekrar hemen eşleşmemeyi sağlar.
  static Future<void> rejectMatch({
    required String roomId,
    required String targetUserId,
  }) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return;

    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/match/reject'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'roomId': roomId, 'targetUserId': targetUserId}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Karşı tarafın kabul durumunu sorgula (polling)
  static Future<Map<String, dynamic>?> getMatchAcceptStatus(
      String roomId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/match/accept-status?roomId=${Uri.encodeComponent(roomId)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Aktif sohbet odalarını listeler
  static Future<List<Map<String, dynamic>>> getChatRooms() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body);
        return raw.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Bir odanın sohbet geçmişini döner
  static Future<List<Map<String, dynamic>>> getChatMessages(
      String roomId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/rooms/$roomId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List raw = jsonDecode(response.body);
        return raw.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Sohbeti yalnızca mevcut kullanıcı için gizler (sohbet listesinden kaldırır)
  static Future<bool> hideChatRoom(String roomId) async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) {
      debugPrint('[CHAT-DELETE-DBG][API] token missing roomId=$roomId');
      return false;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/chat/rooms/$roomId');
      debugPrint('[CHAT-DELETE-DBG][API] DELETE $uri roomId=$roomId');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint(
          '[CHAT-DELETE-DBG][API] response status=${response.statusCode} body=${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CHAT-DELETE-DBG][API] exception roomId=$roomId err=$e');
      return false;
    }
  }
}
