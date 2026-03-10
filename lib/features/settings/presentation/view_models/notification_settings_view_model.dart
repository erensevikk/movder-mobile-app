import '../../../../app/app_scope.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../data/models/notification_settings_model.dart';

class NotificationSettingsViewModel extends BaseViewModel {
  ViewStatus status = ViewStatus.initial;
  NotificationSettingsModel settings = const NotificationSettingsModel(
    pushEnabled: true,
    matchAlerts: true,
    messageAlerts: true,
    friendAlerts: true,
    inAppSounds: true,
    vibration: true,
  );

  @override
  Future<void> initialize() async {
    status = ViewStatus.loading;
    notifyListeners();

    final result =
        await AppScope.instance.settingsRepository.getNotificationSettings();
    if (result.isFailure) {
      status = ViewStatus.error;
      setError(result.failure!.message);
      return;
    }

    settings = result.data!;
    status = ViewStatus.content;
    notifyListeners();
  }

  Future<void> update(NotificationSettingsModel next) async {
    settings = next;
    notifyListeners();

    final result = await guard(
      () =>
          AppScope.instance.settingsRepository.updateNotificationSettings(next),
    );

    if (result.isFailure) {
      emitEffect(ShowSnackbarEffect(message: result.failure!.message));
      return;
    }

    settings = result.data!;
    notifyListeners();
  }
}
