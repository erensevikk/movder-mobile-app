import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/base/base_state.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
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
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Bildirimler',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        flexibleSpace: Column(
          children: <Widget>[
            Container(
              height: MediaQuery.of(context).padding.top,
              color: const Color(0xFF0F0F0F),
            ),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
      body: switch (vm.status) {
        ViewStatus.loading => const LoadingView(),
        ViewStatus.empty => const EmptyView(
            title: 'Henuz bildiriminiz yok',
            message: 'Eslesme ve mesaj hareketleri burada gorunecek.',
          ),
        ViewStatus.error => ErrorView(
            message: vm.errorMessage ?? 'Bildirimler yuklenemedi.',
            onRetry: vm.load,
          ),
        _ => RefreshIndicator(
            color: Colors.redAccent,
            backgroundColor: const Color(0xFF1E1E1E),
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
                    color: Colors.redAccent.withValues(alpha: 0.18),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child:
                        const Icon(Icons.delete_outline, color: Colors.white),
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationItemModel item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.type) {
      'friend_request' => Colors.blueAccent,
      'match' => Colors.redAccent,
      _ => Colors.white54,
    };
    final icon = switch (item.type) {
      'friend_request' => Icons.person_add_alt_1_rounded,
      'match' => Icons.local_fire_department_rounded,
      _ => Icons.notifications,
    };

    return Container(
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E1E),
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
                          color: item.isRead ? Colors.white70 : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(item.createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  style: const TextStyle(
                    color: Colors.white60,
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
