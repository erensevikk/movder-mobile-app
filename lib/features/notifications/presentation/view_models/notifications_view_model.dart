import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../data/models/notification_item_model.dart';

class NotificationsViewModel extends BaseViewModel {
  ViewStatus status = ViewStatus.initial;
  List<NotificationItemModel> notifications = <NotificationItemModel>[];

  bool get isLoggedIn => AppScope.instance.authStorage.isLoggedIn;

  @override
  Future<void> initialize() async {
    if (isLoggedIn) {
      await load();
    }
  }

  Future<void> load() async {
    if (!isLoggedIn) return;

    status = ViewStatus.loading;
    notifyListeners();

    final result =
        await AppScope.instance.notificationsRepository.getNotifications();
    if (result.isFailure) {
      status = ViewStatus.error;
      setError(result.failure!.message);
      return;
    }

    notifications = result.data!;
    status = notifications.isEmpty ? ViewStatus.empty : ViewStatus.content;
    notifyListeners();
    await AppScope.instance.notificationsRepository.markAllAsRead();
  }

  Future<void> deleteNotification(String notificationId) async {
    final previous = List<NotificationItemModel>.from(notifications);
    notifications =
        notifications.where((item) => item.id != notificationId).toList();
    status = notifications.isEmpty ? ViewStatus.empty : ViewStatus.content;
    notifyListeners();

    final result = await AppScope.instance.notificationsRepository
        .deleteNotification(notificationId);
    if (result.isSuccess) {
      return;
    }

    notifications = previous;
    status = notifications.isEmpty ? ViewStatus.empty : ViewStatus.content;
    notifyListeners();
    emitEffect(
      const ShowSnackbarEffect(
        message: 'Bildirim silinemedi.',
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }
}
