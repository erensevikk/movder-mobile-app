import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../core/theme/app_colors.dart';
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: !vm.isLoggedIn
            ? _GuestMessagesView(vm: vm)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: MediaQuery.of(context).padding.top,
              color: Colors.transparent,
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
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.error ?? 'Bağlantı sorunu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMedium,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => vm.loadChatRooms(),
                      child: const Text('Yenile',
                          style: TextStyle(color: AppColors.warning)),
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
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.primary.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${vm.rooms.length} aktif sohbet',
                      style: const TextStyle(
                        color: AppColors.textMedium,
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
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${vm.totalUnreadCount} okunmamış',
                          style: const TextStyle(
                            color: AppColors.primary,
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
                    style: const TextStyle(
                        color: AppColors.textHigh, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Sohbetlerde ara...',
                      hintStyle: TextStyle(color: AppColors.textMedium),
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
                              ?.copyWith(color: AppColors.textHigh)),
                      const SizedBox(height: 4),
                      const Text(
                        'Eşleşmelerinden gelen mesajlar',
                        style: TextStyle(
                          color: AppColors.textMedium,
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(
                vm.isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: AppColors.textMedium,
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
        child: CircularProgressIndicator(color: AppColors.primary),
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
                  color: AppColors.warning, size: 38),
              const SizedBox(height: 10),
              Text(
                vm.error ?? 'Sohbetler yüklenemedi.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textMedium, fontSize: 13),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: vm.loadChatRooms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Tekrar Dene',
                    style: TextStyle(color: AppColors.textHigh)),
              ),
            ],
          ),
        ),
      );
    }

    final displayedRooms = vm.displayedRooms;

    if (displayedRooms.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
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
                style: const TextStyle(color: AppColors.textMedium),
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
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
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
                color: AppColors.textHigh.withValues(alpha: 0.06),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Yenileniyor',
                      style:
                          TextStyle(color: AppColors.textMedium, fontSize: 11),
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
          color: hasUnread
              ? AppColors.surface
              : AppColors.background.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.textHigh.withValues(alpha: 0.06),
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
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.textHigh.withValues(alpha: 0.24),
                      width: 2,
                    ),
                    color: AppColors.surface,
                  ),
                  child: ClipOval(
                    child: (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: Icon(
                                Icons.person,
                                color: AppColors.textMedium,
                                size: 28,
                              ),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              color: AppColors.textMedium,
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: AppColors.textMedium,
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
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.background,
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
                            color: AppColors.textHigh,
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
                          color: hasUnread
                              ? AppColors.primary
                              : AppColors.textMedium,
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
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.movie,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              movieTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
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
                            color: hasUnread
                                ? AppColors.textHigh
                                : AppColors.textMedium,
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
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: AppColors.textHigh,
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
                  color: _offsetX < -1
                      ? AppColors.primary.withValues(alpha: 0.9)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: _maxReveal,
                    child: Center(
                      child: _offsetX < -8
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: AppColors.textHigh,
                              ),
                              onPressed: () {
                                widget.onDelete();
                              },
                            )
                          : const SizedBox.shrink(),
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

class _GuestMessagesView extends StatelessWidget {
  final ChatListViewModel vm;
  const _GuestMessagesView({required this.vm});

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
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 106),
          const Text(
            'Mesajları Görmek İçin Giriş Yapın',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textHigh,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Eşleştiğiniz kişilerle sohbete başlamak ve mesajları okumak için hesabınıza giriş yapın.',
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
