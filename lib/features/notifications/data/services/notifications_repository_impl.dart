import '../../../../core/base/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../services/api_service.dart';
import '../models/notification_item_model.dart';
import '../repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<void>> deleteNotification(String notificationId) async {
    final result =
        await _apiClient.deleteJson('/api/notifications/$notificationId');
    return result.isSuccess
        ? const Result.success(null)
        : Result.failure(result.failure!);
  }

  @override
  Future<Result<List<NotificationItemModel>>> getNotifications() async {
    final result = await _apiClient.getJson('/api/notifications');
    if (result.isFailure) {
      return Result.failure(result.failure!);
    }

    final notifications =
        (result.data!['notifications'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map>()
            .map((item) =>
                NotificationItemModel.fromMap(Map<String, dynamic>.from(item)))
            .toList();

    return Result.success(notifications);
  }

  @override
  Future<void> markAllAsRead() async {
    await ApiService.put('/api/notifications/read-all', <String, dynamic>{});
  }
}
