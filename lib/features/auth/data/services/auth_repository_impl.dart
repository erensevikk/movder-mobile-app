import '../../../../core/base/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/request_config.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../shared/models/app_user.dart';
import '../repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required ApiClient apiClient,
    required AuthStorageService authStorage,
  })  : _apiClient = apiClient,
        _authStorage = authStorage;

  final ApiClient _apiClient;
  final AuthStorageService _authStorage;

  @override
  Future<Result<AppUser>> login({
    required String identifier,
    required String password,
  }) async {
    final result = await _apiClient.postJson(
      '/login',
      body: <String, dynamic>{
        'identifier': identifier,
        'password': password,
      },
      config: const RequestConfig(requiresAuth: false),
    );

    if (result.isFailure) {
      return Result.failure(result.failure!);
    }

    final data = result.data!;
    final token = (data['token'] ?? '').toString();
    if (token.isNotEmpty) {
      await _authStorage.saveToken(token);
    }

    return Result.success(
      AppUser(
        id: (data['userId'] ?? '').toString(),
        username: (data['username'] ?? '').toString(),
      ),
    );
  }

  @override
  Future<Result<AppUser>> register({
    required String username,
    required String email,
    required String password,
    required String city,
    required DateTime birthDate,
    required bool kvkkApproved,
    required bool termsApproved,
  }) async {
    final result = await _apiClient.postJson(
      '/register',
      body: <String, dynamic>{
        'username': username,
        'email': email,
        'password': password,
        'city': city,
        'birthYear': birthDate.year,
        'birthDate':
            '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        'kvkkApproved': kvkkApproved,
        'termsApproved': termsApproved,
      },
      config: const RequestConfig(requiresAuth: false),
    );

    if (result.isFailure) {
      return Result.failure(result.failure!);
    }

    final data = result.data!;
    final token = (data['token'] ?? '').toString();
    if (token.isNotEmpty) {
      await _authStorage.saveToken(token);
    }

    return Result.success(
      AppUser(
        id: (data['userId'] ?? '').toString(),
        username: (data['username'] ?? username).toString(),
        email: email,
        city: city,
      ),
    );
  }

  @override
  Future<void> logout() async {
    await _authStorage.clearToken();
  }
}
