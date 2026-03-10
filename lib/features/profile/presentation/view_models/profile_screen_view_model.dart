import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../features/auth/presentation/views/login_screen.dart';
import '../../../../features/auth/presentation/views/register_screen.dart';
import '../../../../features/settings/presentation/views/notification_settings_screen.dart';
import '../../../../features/settings/presentation/views/privacy_settings_screen.dart';
import '../../../../features/settings/presentation/views/settings_screen.dart';
import '../../../../screens/settings/help_support_screen.dart';
import '../../../../screens/user_detail_screen.dart';
import '../../data/models/movie_list_model.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/watch_status_model.dart';

class ProfileScreenViewModel extends BaseViewModel {
  ViewStatus status = ViewStatus.initial;
  bool isLoggedIn = false;
  ProfileModel? profile;
  WatchStatusModel? watchStatus;
  List<MovieListModel> lists = <MovieListModel>[];

  @override
  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    isLoggedIn = AppScope.instance.authStorage.isLoggedIn;
    if (!isLoggedIn) {
      profile = null;
      watchStatus = null;
      lists = <MovieListModel>[];
      status = ViewStatus.content;
      notifyListeners();
      return;
    }

    status = ViewStatus.loading;
    notifyListeners();

    final profileRepository = AppScope.instance.profileRepository;
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      profileRepository.getMyProfile(),
      profileRepository.getMyWatchStatus(),
      profileRepository.getMyLists(),
    ]);

    profile = results[0] as ProfileModel?;
    watchStatus = results[1] as WatchStatusModel?;
    lists = results[2] as List<MovieListModel>;
    isLoggedIn = profile != null;
    status = isLoggedIn ? ViewStatus.content : ViewStatus.empty;
    notifyListeners();
  }

  String get coverImageUrl {
    final coverUrl = profile?.coverUrl ?? '';
    if (coverUrl.isNotEmpty) {
      return coverUrl;
    }

    for (final list in _orderedListsForCover) {
      for (final item in list.items) {
        final posterUrl = item.posterUrl.trim();
        if (posterUrl.isEmpty) continue;
        if (posterUrl.startsWith('http')) {
          return posterUrl;
        }
        return 'https://image.tmdb.org/t/p/w780$posterUrl';
      }
    }

    return '';
  }

  List<MovieListModel> get _orderedListsForCover {
    final favorites = lists
        .where((list) => list.name.toLowerCase().contains('favori'))
        .toList();
    final others = lists
        .where((list) => !list.name.toLowerCase().contains('favori'))
        .toList();
    return <MovieListModel>[...favorites, ...others];
  }

  Future<void> logout() async {
    await AppScope.instance.profileRepository.logout();
    emitEffect(const ShowSnackbarEffect(message: 'Cikis yapildi.'));
    await refresh();
  }

  void openLogin() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildLogin));
  }

  void openRegister() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildRegister));
  }

  void openProfileDetails() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildUserDetail));
  }

  void openImport() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildImportDetail));
  }

  void openSettings() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildSettings));
  }

  void openNotificationSettings() {
    emitEffect(
      const NavigateToEffect(pageBuilder: _buildNotificationSettings),
    );
  }

  void openPrivacySettings() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildPrivacySettings));
  }

  void openHelp() {
    emitEffect(const NavigateToEffect(pageBuilder: _buildHelp));
  }
}

Widget _buildLogin(BuildContext context) => const LoginScreen();

Widget _buildRegister(BuildContext context) => const RegisterScreen();

Widget _buildSettings(BuildContext context) => const SettingsScreen();

Widget _buildNotificationSettings(BuildContext context) =>
    const NotificationSettingsScreen();

Widget _buildPrivacySettings(BuildContext context) =>
    const PrivacySettingsScreen();

Widget _buildHelp(BuildContext context) => const HelpSupportScreen();

Widget _buildUserDetail(BuildContext context) => const UserDetailScreen(
      userId: '',
      isMe: true,
    );

Widget _buildImportDetail(BuildContext context) => const UserDetailScreen(
      userId: '',
      isMe: true,
      openImportOnStart: true,
    );
