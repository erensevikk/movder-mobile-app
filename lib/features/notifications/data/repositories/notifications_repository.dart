import '../../../../core/base/result.dart';
import '../models/notification_item_model.dart';

abstract class NotificationsRepository {
  Future<Result<List<NotificationItemModel>>> getNotifications();

  Future<void> markAllAsRead();

  Future<Result<void>> deleteNotification(String notificationId);
}
