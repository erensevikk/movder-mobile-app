import '../core/services/auth_storage_service.dart';

class AuthService {
  static AuthStorageService get _storage => AuthStorageService.instance;

  static Future<void> init() => _storage.init();

  static String? get token => _storage.token;

  static bool get isLoggedIn => _storage.isLoggedIn;

  static Future<void> saveToken(String token) => _storage.saveToken(token);

  static Future<void> clearToken() => _storage.clearToken();
}
