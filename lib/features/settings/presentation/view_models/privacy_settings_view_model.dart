import '../../../../app/app_scope.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../profile/data/models/privacy_settings_model.dart';

class PrivacySettingsViewModel extends BaseViewModel {
  ViewStatus status = ViewStatus.initial;
  PrivacySettingsModel settings = const PrivacySettingsModel(
    watchingVisibility: 'friends_and_matches',
    profileVisibility: 'public',
    searchDiscoverable: true,
  );

  @override
  Future<void> initialize() async {
    status = ViewStatus.loading;
    notifyListeners();

    final result =
        await AppScope.instance.settingsRepository.getPrivacySettings();
    if (result.isFailure) {
      status = ViewStatus.error;
      setError(result.failure!.message);
      return;
    }

    settings = result.data!;
    status = ViewStatus.content;
    notifyListeners();
  }

  Future<void> update({
    String? watchingVisibility,
    String? profileVisibility,
    bool? searchDiscoverable,
  }) async {
    final result = await guard(
      () => AppScope.instance.settingsRepository.updatePrivacySettings(
        watchingVisibility: watchingVisibility,
        profileVisibility: profileVisibility,
        searchDiscoverable: searchDiscoverable,
      ),
    );

    if (result.isFailure) {
      emitEffect(ShowSnackbarEffect(message: result.failure!.message));
      return;
    }

    settings = result.data!;
    emitEffect(
        const ShowSnackbarEffect(message: 'Gizlilik ayarlari guncellendi.'));
    notifyListeners();
  }
}
