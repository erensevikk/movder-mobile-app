import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);

    final response = await ApiService.get('/api/notifications');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _notifications = data['notifications'] ?? [];
        _isLoading = false;
      });

      // Bildirimleri çektikten sonra arka planda okundu işaretleyelim
      _markAllAsRead();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.put('/api/notifications/read-all', {});
    } catch (e) {
      debugPrint('Mark all as read error: $e');
    }
  }

  void _hideNotificationCard(String notificationId) {
    if (notificationId.isEmpty) return;
    setState(() {
      _notifications.removeWhere(
        (item) => (item['id'] ?? '').toString() == notificationId,
      );
    });
  }

  Future<void> _deleteNotification(String notificationId) async {
    if (notificationId.isEmpty) return;
    _hideNotificationCard(notificationId);

    final response =
        await ApiService.delete('/api/notifications/$notificationId');
    if (!mounted) return;

    if (response.statusCode == 200) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildirim sunucudan silinemedi, ama listeden gizlendi.'),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return DateFormat('HH:mm').format(date);
      } else if (difference.inDays < 7) {
        return '${difference.inDays} g önce';
      } else {
        return DateFormat('dd.MM.yyyy').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Bildirimler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        flexibleSpace: Column(
          children: [
            Container(
              height: MediaQuery.of(context).padding.top,
              color: const Color(0xFF0F0F0F),
            ),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: Colors.redAccent,
                  backgroundColor: const Color(0xFF1E1E1E),
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => Divider(
                        color: Colors.white.withValues(alpha: 0.05), height: 1),
                    itemBuilder: (context, index) {
                      final req = _notifications[index];
                      final isRead = req['isRead'] ?? false;
                      final notificationId = (req['id'] ?? '').toString();
                      return _SwipeToDeleteNotificationItem(
                        key: ValueKey(
                          'notif-swipe-$notificationId-$index',
                        ),
                        onDelete: () => _deleteNotification(notificationId),
                        child: _buildNotificationItem(req, isRead),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Resim yerine ikon kurgusu (Eğer elinizde Orbit illustration png'si varsa değiştirebilirsiniz)
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.notifications_off_rounded,
                  size: 60,
                  color: Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Henüz bildiriminiz yok',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Film deneyimi paylaştıkça güzelleşir.\nHemen eşleşme ara ve sohbete başla.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Arkadaş davet etme aksiyonu
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF00BFA5), // Tasarımdaki yeşil renk
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Arkadaşlarını Davet Et',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif, bool isRead) {
    final avatarUrl = notif['avatar'] as String?;
    final title = notif['title'] ?? '';
    final message = notif['message'] ?? '';
    final type = notif['type'] ?? '';
    final dateStr = notif['createdAt'] ?? '';

    IconData getIconForType() {
      if (type == 'friend_request') return Icons.person_add_alt_1_rounded;
      if (type == 'match') return Icons.local_fire_department_rounded;
      return Icons.notifications;
    }

    Color getColorForType() {
      if (type == 'friend_request') return Colors.blueAccent;
      if (type == 'match') return Colors.redAccent;
      return Colors.white54;
    }

    return Container(
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar veya İkon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E1E),
              border:
                  Border.all(color: getColorForType().withValues(alpha: 0.5)),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Icon(
                        getIconForType(),
                        color: getColorForType().withValues(alpha: 0.6),
                        size: 20,
                      ),
                      errorWidget: (_, __, ___) => Icon(
                        getIconForType(),
                        color: getColorForType(),
                        size: 20,
                      ),
                    )
                  : Icon(getIconForType(), color: getColorForType(), size: 20),
            ),
          ),
          const SizedBox(width: 14),
          // İçerik
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isRead ? Colors.white70 : Colors.white,
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatTime(dateStr),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: isRead ? Colors.white54 : Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (!isRead) ...[
            const SizedBox(width: 10),
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _SwipeToDeleteNotificationItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeToDeleteNotificationItem({
    super.key,
    required this.child,
    required this.onDelete,
  });

  @override
  State<_SwipeToDeleteNotificationItem> createState() =>
      _SwipeToDeleteNotificationItemState();
}

class _SwipeToDeleteNotificationItemState
    extends State<_SwipeToDeleteNotificationItem> {
  static const double _maxReveal = 64;
  static const double _dismissThresholdRatio = 0.62;
  static const double _openThreshold = 36;

  double _offsetX = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    final next = (_offsetX + details.delta.dx).clamp(-_maxReveal * 2, 0.0);
    setState(() => _offsetX = next);
  }

  void _handleDragEnd(DragEndDetails details, double width) {
    final dismissThreshold = width * _dismissThresholdRatio;
    if (-_offsetX >= dismissThreshold) {
      widget.onDelete();
      return;
    }

    if (-_offsetX >= _openThreshold) {
      setState(() => _offsetX = -_maxReveal);
    } else {
      setState(() => _offsetX = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: _offsetX == 0
                      ? Colors.transparent
                      : Colors.redAccent.withValues(alpha: 0.9),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: _maxReveal,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: widget.onDelete,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: (details) =>
                  _handleDragEnd(details, constraints.maxWidth),
              onTapUp: (details) {
                if (_offsetX == 0) return;

                final cardRight = constraints.maxWidth + _offsetX;
                if (details.localPosition.dx > cardRight) {
                  widget.onDelete();
                } else {
                  setState(() => _offsetX = 0);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(_offsetX, 0, 0),
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}
