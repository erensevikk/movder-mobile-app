import '../../../../core/base/result.dart';
import '../../../profile/data/models/privacy_settings_model.dart';
import '../models/account_info_model.dart';
import '../models/notification_settings_model.dart';

abstract class SettingsRepository {
  Future<Result<AccountInfoModel>> getAccountInfo();

  Future<Result<void>> updateAccountInfo(AccountInfoModel model);

  Future<Result<void>> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  Future<Result<PrivacySettingsModel>> getPrivacySettings();

  Future<Result<PrivacySettingsModel>> updatePrivacySettings({
    String? watchingVisibility,
    String? profileVisibility,
    bool? searchDiscoverable,
  });

  Future<Result<NotificationSettingsModel>> getNotificationSettings();

  Future<Result<NotificationSettingsModel>> updateNotificationSettings(
    NotificationSettingsModel model,
  );

  Future<Result<void>> deleteAccount();
}
