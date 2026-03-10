import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageService {
  AuthStorageService._();

  static final AuthStorageService instance = AuthStorageService._();

  static const String tokenKey = 'auth_token';

  String? _token;

  String? get token => _token;

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    _token = token;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    _token = null;
  }
}
