import 'dart:convert';

import 'package:http/http.dart' as http;

import '../base/app_failure.dart';
import '../base/result.dart';
import '../services/auth_storage_service.dart';
import 'request_config.dart';

class ApiClient {
  ApiClient({
    required AuthStorageService authStorage,
    http.Client? httpClient,
  })  : _authStorage = authStorage,
        _httpClient = httpClient ?? http.Client();

  static const String baseUrl = 'http://10.0.2.2:8080';

  final AuthStorageService _authStorage;
  final http.Client _httpClient;

  Future<Result<Map<String, dynamic>>> getJson(
    String path, {
    RequestConfig config = const RequestConfig(),
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(config),
    );
    return _decodeMap(response);
  }

  Future<Result<List<dynamic>>> getJsonList(
    String path, {
    RequestConfig config = const RequestConfig(),
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(config),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is List<dynamic>) {
        return Result.success(decoded);
      }
      return const Result.success(<dynamic>[]);
    }

    return Result.failure(_failureFromResponse(response));
  }

  Future<Result<Map<String, dynamic>>> postJson(
    String path, {
    Map<String, dynamic>? body,
    RequestConfig config = const RequestConfig(),
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(config),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decodeMap(response);
  }

  Future<Result<Map<String, dynamic>>> putJson(
    String path, {
    Map<String, dynamic>? body,
    RequestConfig config = const RequestConfig(),
  }) async {
    final response = await _httpClient.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(config),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decodeMap(response);
  }

  Future<Result<Map<String, dynamic>>> deleteJson(
    String path, {
    RequestConfig config = const RequestConfig(),
  }) async {
    final response = await _httpClient.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers(config),
    );
    return _decodeMap(response);
  }

  Map<String, String> _headers(RequestConfig config) {
    final token = _authStorage.token;
    return <String, String>{
      'Content-Type': 'application/json',
      if (config.requiresAuth && token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  Result<Map<String, dynamic>> _decodeMap(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return Result.success(decoded);
      }
      return const Result.success(<String, dynamic>{});
    }

    return Result.failure(_failureFromResponse(response));
  }

  AppFailure _failureFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return AppFailure(
          message: (decoded['error'] ??
                  decoded['message'] ??
                  'İşlem başarısız oldu.')
              .toString(),
          code: decoded['code']?.toString(),
          detail: decoded,
        );
      }
    } catch (_) {}

    return AppFailure(
      message: 'İşlem başarısız oldu. (${response.statusCode})',
      code: response.statusCode.toString(),
    );
  }
}
