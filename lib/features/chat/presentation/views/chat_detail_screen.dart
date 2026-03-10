import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../data/models/chat_model.dart';
import '../../data/services/chat_repository_impl.dart';
import '../view_models/chat_detail_view_model.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.roomId,
    required this.targetUserId,
    this.username,
    this.movieTitle,
    this.avatarSeed,
    this.avatarUrl,
    this.isOnline = false,
    this.moviePoster,
  });

  final String roomId;
  final String targetUserId;
  final String? username;
  final String? movieTitle;
  final String? avatarSeed;
  final String? avatarUrl;
  final bool isOnline;
  final String? moviePoster;

  @override
  State<ChatDetailScreen> createState() => ChatDetailScreenState();
}

class ChatDetailScreenState extends State<ChatDetailScreen>
    with
        ViewModelBindingMixin<ChatDetailScreen, ChatDetailViewModel>,
        ViewEffectListenerMixin<ChatDetailScreen, ChatDetailViewModel> {
  final GlobalKey _friendsMenuAnchorKey = GlobalKey();
  double? _friendsMenuWidth;

  static const List<String> _quickMessages = [
    'Selam! 👋',
    'Kaçıncı dakikadasın?',
    'Bu film efsane değil mi? 🔥',
    'İlk kez mi izliyorsun?',
    'Spoiler verme sakın 😄',
    'Birlikte izlemek harika!',
  ];

  @override
  ChatDetailViewModel createViewModel() => ChatDetailViewModel(
        roomId: widget.roomId,
        targetUserId: widget.targetUserId,
        username: widget.username,
        movieTitle: widget.movieTitle,
        avatarSeed: widget.avatarSeed,
        avatarUrl: widget.avatarUrl,
        isOnline: widget.isOnline,
        moviePoster: widget.moviePoster,
        repository: const ChatRepositoryImpl(),
      );

  void _captureFriendsMenuWidth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _friendsMenuAnchorKey.currentContext;
      if (ctx == null) return;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox) return;

      final measured = ro.size.width;
      if (measured <= 0) return;
      if (_friendsMenuWidth != measured) {
        setState(() {
          _friendsMenuWidth = measured;
        });
      }
    });
  }

  @override
  Widget buildWithViewModel(BuildContext context, ChatDetailViewModel vm) {
    final bool hasMessages = vm.messages.isNotEmpty;
    // Poster URL'sini yüksek kaliteye çekiyoruz (w780 gibi)
    String? poster = vm.moviePoster;
    if (poster != null && poster.contains('/w92/')) {
      poster = poster.replaceFirst('/w92/', '/w780/');
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(
        children: [
          // Status bar alanı — her zaman siyah
          SizedBox(height: MediaQuery.of(context).padding.top),

          // İçerik: arka plan görseli burada başlar (status bar'ın altı)
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Film Posteri Arka Plan ──────────────────────
                if (poster != null && poster.isNotEmpty)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: poster,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF1E1E1E),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),

                // ── Koyu Overlay (poster gözü almasın) ─────────
                if (poster != null && poster.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF0F0F0F).withValues(alpha: 0.85),
                            const Color(0xFF0F0F0F).withValues(alpha: 0.90),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── İçerik ─────────────────────────────────────
                SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // ── Üst AppBar ─────────────────────────────────
                      _buildAppBar(vm),

                      // ── Film Eşleşme Bandı ─────────────────────────
                      if (vm.movieTitle.isNotEmpty) _buildMovieBanner(vm),

                      // ── Sohbet Alanı ───────────────────────────────
                      Expanded(
                        child: hasMessages
                            ? _buildMessageList(vm)
                            : _buildEmptyState(vm),
                      ),

                      // ── Hızlı Mesajlar (sadece boş sohbette) ──────
                      if (!hasMessages) _buildQuickMessages(vm),

                      // ── Mesaj Giriş Alanı ──────────────────────────
                      _buildMessageInput(vm),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ÜSTTEKI APPBAR ────────────────────────────────────────
  Widget _buildAppBar(ChatDetailViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Geri butonu
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white70, size: 22),
          ),

          // Avatar
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                  color: const Color(0xFF1E1E1E),
                ),
                child: ClipOval(
                  child: (vm.avatarUrl != null && vm.avatarUrl!.trim().isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: vm.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.white38,
                              size: 22,
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
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
              if (vm.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F0F0F), width: 2),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // Sol: Kullanıcı adı + altında film adı
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (vm.movieTitle.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.movie_outlined,
                        size: 13,
                        color: Colors.redAccent.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          vm.movieTitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Sağ: Arkadaş Ekle butonu
          if (vm.friendStatus == FriendStatus.pendingReceived)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    // Mapped to remove/accept based on view model.
                    // Currently no accept friend request endpoint on VM directly.
                    // Will send friend request which implies accepting when mutual.
                    vm.sendFriendRequest();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.4)),
                    ),
                    child: const Text('Kabul et',
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => vm.removeFriend(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: const Text('Reddet',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          else if (vm.friendStatus == FriendStatus.friends)
            PopupMenuButton<String>(
              color: const Color(0xFF1E1E1E),
              offset: const Offset(0, 42),
              constraints: _friendsMenuWidth == null
                  ? const BoxConstraints(minWidth: 0)
                  : BoxConstraints.tightFor(width: _friendsMenuWidth),
              onOpened: () {
                _captureFriendsMenuWidth();
              },
              onSelected: (value) {
                if (value == 'remove_friend') {
                  vm.removeFriend();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'remove_friend',
                  child: SizedBox(
                    width: (_friendsMenuWidth ?? 0) > 0 ? _friendsMenuWidth : null,
                    child: const Text(
                      'Arkadaşı sil',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              child: AnimatedContainer(
                key: _friendsMenuAnchorKey,
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 16, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text(
                      'Arkadaşlar',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down_rounded,
                        size: 18, color: Colors.greenAccent),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {
                if (vm.friendStatus == FriendStatus.none) {
                  vm.sendFriendRequest();
                } else if (vm.friendStatus == FriendStatus.pendingSent) {
                  vm.removeFriend(); // Serves as cancel
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getFriendButtonColor(vm.friendStatus).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _getFriendButtonColor(vm.friendStatus).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getFriendButtonIcon(vm.friendStatus),
                        size: 16, color: _getFriendButtonColor(vm.friendStatus)),
                    const SizedBox(width: 4),
                    Text(
                      _getFriendButtonLabel(vm.friendStatus),
                      style: TextStyle(
                        color: _getFriendButtonColor(vm.friendStatus),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Seçenekler Menüsü (Üç Nokta)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1E1E1E),
            offset: const Offset(0, 55),
            onSelected: (value) {
              if (value == 'unmatch') {
                vm.unmatchUser();
              } else if (value == 'block') {
                vm.blockUser();
              } else if (value == 'hide') {
                vm.hideChat();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'unmatch',
                height: 38,
                child: Text(
                  'Eşleşmeyi iptal et',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              PopupMenuItem(
                value: 'block',
                height: 38,
                child: Text(
                  'Engelle',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
              PopupMenuItem(
                value: 'hide',
                height: 38,
                child: Text(
                  'Sohbeti gizle',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getFriendButtonColor(FriendStatus status) {
    if (status == FriendStatus.pendingSent) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  IconData _getFriendButtonIcon(FriendStatus status) {
    if (status == FriendStatus.pendingSent) {
      return Icons.cancel_schedule_send_rounded;
    }
    return Icons.person_add_alt_1_rounded;
  }

  String _getFriendButtonLabel(FriendStatus status) {
    if (status == FriendStatus.pendingSent) return 'İsteği İptal Et';
    return 'Arkadaş Ekle';
  }

  // ── FİLM EŞLEŞME BANDI ───────────────────────────────────
  Widget _buildMovieBanner(ChatDetailViewModel vm) {
    final rawPoster = vm.moviePoster?.trim() ?? '';
    final bannerPoster = rawPoster.isEmpty
        ? ''
        : (rawPoster.startsWith('http')
            ? rawPoster
            : 'https://image.tmdb.org/t/p/w200$rawPoster');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(
              child: bannerPoster.isNotEmpty
                  ? Opacity(
                      opacity: 0.18,
                      child: CachedNetworkImage(
                        imageUrl: bannerPoster,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: const Color(0xFF121212)),
                      ),
                    )
                  : Container(color: const Color(0xFF121212)),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF121212).withValues(alpha: 0.94),
                      const Color(0xFF121212).withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 14,
                    color: Colors.redAccent.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${vm.movieTitle} izlerken eşleştiniz',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MESAJ LİSTESİ ─────────────────────────────────────────
  Widget _buildMessageList(ChatDetailViewModel vm) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: vm.messages.length,
      itemBuilder: (context, index) {
        // Reverse indexing due to reverse: true in ListView
        final msg = vm.messages[vm.messages.length - 1 - index];
        final bool isMe = msg.isMe;
        final String text = msg.text;
        final String time =
            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
        final MessageStatus status = msg.status;

        IconData statusIcon = Icons.access_time_rounded;
        Color statusColor = Colors.white30;

        if (status == MessageStatus.sent) {
          statusIcon = Icons.check;
        } else if (status == MessageStatus.delivered) {
          statusIcon = Icons.done_all;
        } else if (status == MessageStatus.read) {
          statusIcon = Icons.done_all;
          statusColor = Colors.blueAccent;
        } else if (status == MessageStatus.failed) {
          statusIcon = Icons.error_outline_rounded;
          statusColor = Colors.redAccent;
        }

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    isMe ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight:
                    isMe ? const Radius.circular(4) : const Radius.circular(16),
              ),
              border: Border.all(
                color: isMe
                    ? Colors.redAccent.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(statusIcon, size: 12, color: statusColor),
                    ],
                  ],
                ),
                if (isMe && status == MessageStatus.failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: () {
                         // Send message text again from input if failed.
                         // For simplicity, we can load it to the controller.
                         vm.messageController.text = text;
                         vm.sendMessage();
                      },
                      child: const Text(
                        'Tekrar gönder',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── BOŞ SOHBET DURUMU ─────────────────────────────────────
  Widget _buildEmptyState(ChatDetailViewModel vm) {
    if (vm.isLoading) {
       return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.08),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.15), width: 2),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: Colors.redAccent.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Henüz mesaj yok',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk adımı at! Hızlı mesajlardan birini seç\nveya kendi mesajını yaz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HIZLI MESAJLAR ────────────────────────────────────────
  Widget _buildQuickMessages(ChatDetailViewModel vm) {
    if (vm.isLoading) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Hızlı Mesajlar',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickMessages.map((msg) {
              return GestureDetector(
                onTap: () {
                   vm.messageController.text = msg;
                   vm.sendMessage();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    msg,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── MESAJ GİRİŞ ALANI ─────────────────────────────────────
  Widget _buildMessageInput(ChatDetailViewModel vm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Metin alanı
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: vm.messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => vm.sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Gönder butonu
          GestureDetector(
            onTap: vm.isSending ? null : () => vm.sendMessage(),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.redAccent, Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: vm.isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
