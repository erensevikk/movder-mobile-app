import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/base/base_state.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../data/models/notification_item_model.dart';
import '../view_models/notifications_view_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with
        ViewModelBindingMixin<NotificationScreen, NotificationsViewModel>,
        ViewEffectListenerMixin<NotificationScreen, NotificationsViewModel> {
  @override
  NotificationsViewModel createViewModel() => NotificationsViewModel();

  @override
  Widget buildWithViewModel(BuildContext context, NotificationsViewModel vm) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Bildirimler',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: !vm.isLoggedIn
          ? _GuestNotificationView(vm: vm)
          : switch (vm.status) {
              ViewStatus.loading => const LoadingView(),
              ViewStatus.empty => const EmptyView(
                  title: 'Henüz bildiriminiz yok',
                  message: 'Eşleşme ve mesaj hareketleri burada görünecek.',
                ),
              ViewStatus.error => ErrorView(
                  message: vm.errorMessage ?? 'Bildirimler yüklenemedi.',
                  onRetry: vm.load,
                ),
              _ => RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: vm.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: vm.notifications.length,
                    separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withValues(alpha: 0.05), height: 1),
                    itemBuilder: (context, index) {
                      final item = vm.notifications[index];
                      return Dismissible(
                        key: ValueKey<String>(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: AppColors.warning.withValues(alpha: 0.18),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        onDismissed: (_) => vm.deleteNotification(item.id),
                        child: _NotificationTile(item: item),
                      );
                    },
                  ),
                ),
            },
    );
  }
}

class _GuestNotificationView extends StatelessWidget {
  final NotificationsViewModel vm;
  const _GuestNotificationView({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 32.0, right: 32.0, top: 32.0, bottom: 60.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 10,
                )
              ],
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 106),
          const Text(
            'Bildirimleri Görmek İçin Giriş Yapın',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textHigh,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Film zevkinize uyan yeni eşleşmelerden ve mesajlardan haberdar olmak için hesabınıza giriş yapın.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textMedium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/auth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Giriş Yap / Üye Ol',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationItemModel item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.type) {
      'friend_request' => AppColors.secondary,
      'match' => AppColors.primary,
      _ => AppColors.textMedium,
    };
    final icon = switch (item.type) {
      'friend_request' => Icons.person_add_alt_1_rounded,
      'match' => Icons.local_fire_department_rounded,
      _ => Icons.notifications,
    };

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: ClipOval(
              child: item.avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.avatarUrl,
                      fit: BoxFit.cover,
                    )
                  : Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: item.isRead
                              ? AppColors.textMedium
                              : AppColors.textHigh,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(item.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  style: const TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    final parsed = DateTime.tryParse(dateStr)?.toLocal();
    if (parsed == null) return '';

    final difference = DateTime.now().difference(parsed);
    if (difference.inDays == 0) {
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} g once';
    }
    return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
  }
}
