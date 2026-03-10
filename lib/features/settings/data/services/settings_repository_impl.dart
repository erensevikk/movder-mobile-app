import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/base/app_failure.dart';
import '../../../../core/base/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../services/api_service.dart';
import '../../../profile/data/models/privacy_settings_model.dart';
import '../models/account_info_model.dart';
import '../models/notification_settings_model.dart';
import '../repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required ApiClient apiClient,
    required AuthStorageService authStorage,
  })  : _apiClient = apiClient,
        _authStorage = authStorage;

  final ApiClient _apiClient;
  final AuthStorageService _authStorage;

  @override
  Future<Result<void>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final result = await _apiClient.putJson(
      '/api/account/password',
      body: <String, dynamic>{
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
    );
    return result.isSuccess
        ? const Result.success(null)
        : Result.failure(result.failure!);
  }

  @override
  Future<Result<void>> deleteAccount() async {
    final result = await _apiClient.deleteJson('/api/account');
    if (result.isFailure) {
      return Result.failure(result.failure!);
    }
    await _authStorage.clearToken();
    return const Result.success(null);
  }

  @override
  Future<Result<AccountInfoModel>> getAccountInfo() async {
    final profile = await ApiService.getProfile();
    if (profile == null) {
      return const Result.failure(
        AppFailure(message: 'Profil bilgileri alinamadi.'),
      );
    }

    return Result.success(
      AccountInfoModel(
        username: (profile['username'] ?? '').toString(),
        email: (profile['email'] ?? '').toString(),
        city: (profile['city'] ?? '').toString(),
      ),
    );
  }

  @override
  Future<Result<NotificationSettingsModel>> getNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await ApiService.get('/api/account/notifications');
      final data = response.statusCode == 200
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      final backend = data['notificationSettings'] as Map<String, dynamic>? ??
          <String, dynamic>{};

      return Result.success(
        NotificationSettingsModel(
          pushEnabled: backend['pushEnabled'] != false,
          matchAlerts: backend['matchAlerts'] != false,
          messageAlerts: backend['messageAlerts'] != false,
          friendAlerts: backend['friendAlerts'] != false,
          inAppSounds: prefs.getBool('inAppSounds') ?? true,
          vibration: prefs.getBool('vibration') ?? true,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppFailure(
          message: 'Bildirim ayarlari yuklenemedi.',
          detail: error,
        ),
      );
    }
  }

  @override
  Future<Result<PrivacySettingsModel>> getPrivacySettings() async {
    final settings = await ApiService.getPrivacySettings();
    return Result.success(PrivacySettingsModel.fromMap(settings));
  }

  @override
  Future<Result<void>> updateAccountInfo(AccountInfoModel model) async {
    final result = await _apiClient.putJson(
      '/api/account/info',
      body: <String, dynamic>{
        'username': model.username,
        'email': model.email,
        'city': model.city,
      },
    );

    return result.isSuccess
        ? const Result.success(null)
        : Result.failure(result.failure!);
  }

  @override
  Future<Result<NotificationSettingsModel>> updateNotificationSettings(
    NotificationSettingsModel model,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('inAppSounds', model.inAppSounds);
      await prefs.setBool('vibration', model.vibration);

      await ApiService.put('/api/account/notifications', <String, dynamic>{
        'pushEnabled': model.pushEnabled,
        'matchAlerts': model.matchAlerts,
        'messageAlerts': model.messageAlerts,
        'friendAlerts': model.friendAlerts,
      });

      return Result.success(model);
    } catch (error) {
      return Result.failure(
        AppFailure(
          message: 'Bildirim ayarlari guncellenemedi.',
          detail: error,
        ),
      );
    }
  }

  @override
  Future<Result<PrivacySettingsModel>> updatePrivacySettings({
    String? watchingVisibility,
    String? profileVisibility,
    bool? searchDiscoverable,
  }) async {
    final updated = await ApiService.updatePrivacySettings(
      watchingVisibility: watchingVisibility,
      profileVisibility: profileVisibility,
      searchDiscoverable: searchDiscoverable,
    );

    if (updated == null) {
      return const Result.failure(
        AppFailure(message: 'Gizlilik ayarlari guncellenemedi.'),
      );
    }

    return Result.success(PrivacySettingsModel.fromMap(updated));
  }
}
