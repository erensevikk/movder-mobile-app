import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../data/services/chat_repository_impl.dart';
import '../view_models/chat_list_view_model.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => ChatListScreenState();
}

class ChatListScreenState extends State<ChatListScreen>
    with
        ViewModelBindingMixin<ChatListScreen, ChatListViewModel>,
        ViewEffectListenerMixin<ChatListScreen, ChatListViewModel> {
  @override
  ChatListViewModel createViewModel() => ChatListViewModel(
        repository: const ChatRepositoryImpl(),
      );

  @override
  Widget buildWithViewModel(BuildContext context, ChatListViewModel vm) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: MediaQuery.of(context).padding.top,
              color: const Color(0xFF0F0F0F),
            ),
            // ── Başlık Alanı ──────────────────────────────────
            _buildHeader(vm),

            // ── Aktif Eşleşme Özet Bandı ─────────────────────
            if (vm.hasError && vm.rooms.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.error ?? 'Bağlantı sorunu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => vm.loadChatRooms(),
                      child: const Text('Yenile',
                          style: TextStyle(color: Colors.orangeAccent)),
                    ),
                  ],
                ),
              ),

            if (vm.rooms.isNotEmpty)
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
                      '${vm.rooms.length} aktif sohbet',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (vm.totalUnreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${vm.totalUnreadCount} okunmamış',
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
              child: _buildBody(vm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ChatListViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Row(
        children: [
          // Sol: Başlık + alt açıklama veya Arama Inputu
          Expanded(
            child: vm.isSearching
                ? TextField(
                    controller: vm.searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Sohbetlerde ara...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sohbetler',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text(
                        'Eşleşmelerinden gelen mesajlar',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
          // Sağ: Arama ikonu
          GestureDetector(
            onTap: vm.toggleSearch,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(
                vm.isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: Colors.white54,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ChatListViewModel vm) {
    if (vm.isLoading && vm.rooms.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      );
    }

    if (vm.hasError && vm.rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.orangeAccent, size: 38),
              const SizedBox(height: 10),
              Text(
                vm.error ?? 'Sohbetler yüklenemedi.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: vm.loadChatRooms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Tekrar Dene',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final displayedRooms = vm.displayedRooms;

    if (displayedRooms.isEmpty) {
      return RefreshIndicator(
        color: Colors.redAccent,
        onRefresh: vm.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Text(
                vm.isSearching
                    ? 'Aradığınız kişiyle sohbet bulunamadı.'
                    : 'Henüz hiç eşleşmen veya sohbetin yok.',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            if (vm.isLoading) ...[
              const SizedBox(height: 14),
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: vm.onRefresh,
      child: Stack(
        children: [
          ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: displayedRooms.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 1,
              ),
            ),
            itemBuilder: (context, index) {
              final room = displayedRooms[index];
              return _SwipeToDeleteChatItem(
                key: ValueKey('chat-swipe-${room.roomId}-$index'),
                onDelete: () => vm.hideChat(room.roomId),
                child: _ChatCard(
                  username: room.username,
                  avatarUrl: room.avatarUrl,
                  avatarSeed: room.avatarSeed,
                  isOnline: room.isOnline,
                  movieTitle: room.movieTitle ?? 'Bilinmeyen Film',
                  moviePoster: room.moviePoster ?? '',
                  lastMessage: room.lastMessage ?? 'Sohbete başla...',
                  time: _formatTime(room.lastMessageTime),
                  unreadCount: room.unreadCount,
                  onTap: () => vm.onChatTap(room),
                ),
              );
            },
          ),
          if (vm.isLoading)
            Positioned(
              top: 10,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Yenileniyor',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final isToday =
        now.year == time.year && now.month == time.month && now.day == time.day;

    if (isToday) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year}';
    }
  }
}

// ── Sohbet Kartı Bileşeni ─────────────────────────────────────
class _ChatCard extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final String? avatarSeed;
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
    required this.avatarSeed,
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
                    child: (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white38,
                                size: 28,
                              ),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 28,
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
                      Expanded(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                        onPressed: () {
                          widget.onDelete();
                        },
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
              onTapUp: (TapUpDetails details) {
                if (_offsetX != 0) {
                  // Kartın görsel sağ kenarı (negatif offset olduğu için)
                  final cardRight = constraints.maxWidth + _offsetX;
                  if (details.localPosition.dx > cardRight) {
                    widget.onDelete();
                  } else {
                    setState(() => _offsetX = 0);
                  }
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
