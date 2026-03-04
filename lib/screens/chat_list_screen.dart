import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/global_chat_service.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  final int refreshSignal;

  const ChatListScreen({super.key, this.refreshSignal = 0});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  StreamSubscription<String>? _messageEventsSub;
  Timer? _refreshDebounce;
  final Set<String> _hiddenRoomIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadChats();

    _messageEventsSub = GlobalChatService.instance.messageEvents.listen((_) {
      // Çok hızlı ardışık eventlerde API'yi spam etmemek için debounce
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
        _refreshChatsOnly();
      });
    });
  }

  Future<void> _loadChats({bool rebindGlobalWs = true}) async {
    setState(() => _isLoading = true);
    final rooms = await ApiService.getChatRooms();
    if (!mounted) return;
    setState(() {
      _chats = _applyHiddenFilter(rooms);
      _isLoading = false;
    });

    // Global WS bağlantılarını sadece gerektiğinde re-init et.
    // (Her yeni mesaj eventinde re-init etmek socket churn üretir.)
    if (rebindGlobalWs) {
      await GlobalChatService.instance.init(rooms);
    }
  }

  Future<void> _refreshChatsOnly() async {
    final rooms = await ApiService.getChatRooms();
    if (!mounted) return;
    setState(() {
      _chats = _applyHiddenFilter(rooms);
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _applyHiddenFilter(
      List<Map<String, dynamic>> rooms) {
    if (_hiddenRoomIds.isEmpty) return rooms;
    return rooms.where((room) {
      final roomId = (room['roomId'] ?? '').toString();
      return roomId.isNotEmpty && !_hiddenRoomIds.contains(roomId);
    }).toList();
  }

  void _hideChatCard(String roomId) {
    if (roomId.isEmpty) return;
    setState(() {
      _hiddenRoomIds.add(roomId);
      _chats.removeWhere((c) => (c['roomId'] ?? '').toString() == roomId);
    });
  }

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadChats(rebindGlobalWs: true);
    }
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _messageEventsSub?.cancel();
    super.dispose();
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null || timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    if (isToday) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('dd.MM.yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    int totalUnread = 0;
    for (var c in _chats) {
      totalUnread += (c['unreadCount'] as int? ?? 0);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık Alanı ──────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Row(
                children: [
                  // Sol: Başlık + alt açıklama
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sohbetler',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Eşleşmelerinden gelen mesajlar',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sağ: Arama ikonu
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white54,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // ── Aktif Eşleşme Özet Bandı ─────────────────────
            if (!_isLoading && _chats.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.redAccent.withValues(alpha: 0.12),
                      Colors.redAccent.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_chats.length} aktif sohbet',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (totalUnread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$totalUnread okunmamış',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ── Sohbet Listesi ────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.redAccent))
                  : _chats.isEmpty
                      ? const Center(
                          child: Text(
                            'Henüz hiç eşleşmen veya sohbetin yok.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _chats.length,
                          separatorBuilder: (_, __) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Divider(
                              color: Colors.white.withValues(alpha: 0.06),
                              height: 1,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final chat = _chats[index];
                            final avatarRaw =
                                (chat['avatarUrl'] ?? '').toString().trim();
                            final avatarUrl = avatarRaw.isEmpty
                                ? ''
                                : (avatarRaw.startsWith('http://') ||
                                        avatarRaw.startsWith('https://')
                                    ? avatarRaw
                                    : (avatarRaw.startsWith('/')
                                        ? '${ApiService.baseUrl}$avatarRaw'
                                        : '${ApiService.baseUrl}/$avatarRaw'));

                            final roomId = (chat['roomId'] ?? '').toString();

                            return _SwipeToDeleteChatItem(
                              key: ValueKey('chat-swipe-$roomId-$index'),
                              onDelete: () => _hideChatCard(roomId),
                              child: _ChatCard(
                                username: chat['username']?.toString() ??
                                    'Bilinmeyen',
                                avatarUrl: avatarUrl,
                                isOnline:
                                    true, // TODO: Redis ile online state eklenecek
                                movieTitle: chat['movieTitle']?.toString() ??
                                    'Bilinmeyen Film',
                                moviePoster:
                                    chat['moviePoster']?.toString() ?? '',
                                lastMessage: chat['lastMessage']?.toString() ??
                                    'Sohbete başla...',
                                time:
                                    _formatTime(chat['lastTimestamp'] as int?),
                                unreadCount: (chat['unreadCount'] as int?) ?? 0,
                                onTap: () {
                                  Navigator.of(context)
                                      .push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailScreen(
                                        targetUserId:
                                            chat['targetUserId']?.toString(),
                                        roomId: chat['roomId']?.toString(),
                                        username:
                                            chat['username']?.toString() ?? '',
                                        avatarSeed:
                                            chat['avatarSeed']?.toString() ??
                                                '',
                                        avatarUrl: avatarUrl,
                                        isOnline: true,
                                        movieTitle:
                                            chat['movieTitle']?.toString() ??
                                                '',
                                        moviePoster:
                                            chat['moviePoster']?.toString(),
                                        initialMessages: const [], // Geçmiş içeride çekilecek
                                      ),
                                    ),
                                  )
                                      .then((_) {
                                    // Geri dönünce listeyi tazele ki okundu bilgileri sıfırlansın
                                    _loadChats();
                                  });
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sohbet Kartı Bileşeni ─────────────────────────────────────
class _ChatCard extends StatelessWidget {
  final String username;
  final String avatarUrl;
  final bool isOnline;
  final String movieTitle;
  final String moviePoster;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final VoidCallback? onTap;

  const _ChatCard({
    required this.username,
    required this.avatarUrl,
    required this.isOnline,
    required this.movieTitle,
    required this.moviePoster,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = unreadCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread ? const Color(0xFF1A1A1A) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? Colors.redAccent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // ── Avatar + Online Durumu ────────────────────────
            Stack(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasUnread
                          ? Colors.redAccent.withValues(alpha: 0.5)
                          : Colors.white24,
                      width: 2,
                    ),
                    color: const Color(0xFF1E1E1E),
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 22,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 22,
                          ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0F0F0F),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // ── Orta Bilgi Alanı ─────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kullanıcı adı + zaman
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight:
                              hasUnread ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: hasUnread ? Colors.redAccent : Colors.white38,
                          fontSize: 12,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Eşleşme Film Etiketi (ikon + başlık tek rozet)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.movie,
                              size: 12,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              movieTitle,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Son mesaj + okunmamış badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread ? Colors.white70 : Colors.white38,
                            fontSize: 13,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeToDeleteChatItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeToDeleteChatItem({
    super.key,
    required this.child,
    required this.onDelete,
  });

  @override
  State<_SwipeToDeleteChatItem> createState() => _SwipeToDeleteChatItemState();
}

class _SwipeToDeleteChatItemState extends State<_SwipeToDeleteChatItem> {
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
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
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
              onHorizontalDragEnd: (d) =>
                  _handleDragEnd(d, constraints.maxWidth),
              onTap: () {
                if (_offsetX != 0) {
                  setState(() => _offsetX = 0);
                  return;
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
