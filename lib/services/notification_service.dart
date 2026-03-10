import 'dart:async';
import 'package:flutter/material.dart';

/// Gelen mesaj bildirimini temsil eden model
class InAppNotification {
  final String senderName;
  final String message;
  final String? avatarUrl; // Kullanıcının gerçek avatar URL'si
  final String? roomId; // Tıklanınca o odaya gidebilmek için

  const InAppNotification({
    required this.senderName,
    required this.message,
    this.avatarUrl,
    this.roomId,
  });
}

/// Uygulama genelinde sohbet bildirimlerini yöneten servis.
///
/// Kullanım:
///   NotificationService.instance.showNotification(...)
///
/// Overlay gösterimi için [NotificationService.init(context)] ile
/// BuildContext'in overlay'ine erişim sağlanmalıdır.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  OverlayState? _overlayState;
  OverlayEntry? _entry;
  Timer? _hideTimer;

  // Bildirim içeriğini reaktif güncelleyebilmek için ValueNotifier kullanıyoruz
  final ValueNotifier<InAppNotification?> _notifNotifier =
      ValueNotifier<InAppNotification?>(null);

  /// Ana Overlay'e erişim için MaterialApp'in içindeki context ile çağırılır.
  void init(BuildContext context) {
    _overlayState = Overlay.of(context);
  }

  /// Yeni mesaj geldiğinde çağırılır.
  /// Eğer ekranda zaten bir bildirim varsa mesajı günceller ve sayacı sıfırlar.
  void showNotification({
    required String senderName,
    required String message,
    String? avatarUrl,
    String? roomId,
    VoidCallback? onTap,
  }) {
    if (_overlayState == null) return;

    final notif = InAppNotification(
      senderName: senderName,
      message: message,
      avatarUrl: avatarUrl,
      roomId: roomId,
    );

    // Sayacı sıfırla (aynı kişiden veya başkasından mesaj gelse de)
    _hideTimer?.cancel();

    if (_entry != null) {
      // Bildirim ekranda zaten var → sadece içeriği güncelle
      _notifNotifier.value = notif;
    } else {
      // Yeni bildirim ekle
      _notifNotifier.value = notif;
      _entry = OverlayEntry(
        builder: (_) => _NotificationBubble(
          notifier: _notifNotifier,
          onTap: onTap,
          onDismiss: _dismiss,
        ),
      );
      _overlayState!.insert(_entry!);
    }

    // 4 saniye sonra kapat
    _hideTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _entry?.remove();
    _entry = null;
    _notifNotifier.value = null;
  }
}

// ─────────────────────────────────────────────────────────────
// BİLDİRİM BALONCUĞU WIDGET'I
// ─────────────────────────────────────────────────────────────
class _NotificationBubble extends StatefulWidget {
  final ValueNotifier<InAppNotification?> notifier;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _NotificationBubble({
    required this.notifier,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<_NotificationBubble> createState() => _NotificationBubbleState();
}

class _NotificationBubbleState extends State<_NotificationBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 330),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: ValueListenableBuilder<InAppNotification?>(
              valueListenable: widget.notifier,
              builder: (_, notif, __) {
                if (notif == null) return const SizedBox.shrink();
                return _BubbleContent(
                  notif: notif,
                  onTap: widget.onTap,
                  onDismiss: widget.onDismiss,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleContent extends StatelessWidget {
  final InAppNotification notif;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _BubbleContent({
    required this.notif,
    required this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onDismiss();
        onTap?.call();
      },
      onHorizontalDragEnd: (details) {
        // Sağa/sola sürükle = kapat
        if (details.primaryVelocity != null &&
            details.primaryVelocity!.abs() > 200) {
          onDismiss();
        }
      },
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2A2A2A),
                border:
                    Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                image: notif.avatarUrl != null && notif.avatarUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(notif.avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: notif.avatarUrl == null || notif.avatarUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white38, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            // Metinler
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.senderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.message,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Küçük mesaj ikonları
            const Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.redAccent, size: 16),
          ],
        ),
      ),
    );
  }
}
