import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

enum _ChatListViewState {
  initialLoading,
  content,
  empty,
  error,
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  _ChatListViewState _viewState = _ChatListViewState.initialLoading;
  bool _isRefreshing = false;
  String? _lastErrorMessage;
  StreamSubscription<String>? _messageEventsSub;
  Timer? _refreshDebounce;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    GlobalChatService.instance.setChatListVisible(true);
    _loadChats();

    _messageEventsSub =
        GlobalChatService.instance.messageEvents.listen((roomId) {
      // İncremental update: Sadece ilgili odayı güncelle, API çağrısı yapma
      _updateChatRoomLocally(roomId);
    });
  }

  Future<void> _loadChats(
      {bool rebindGlobalWs = true, bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _viewState = _ChatListViewState.initialLoading);
    }

    final result = await ApiService.getChatRoomsWithMeta();
    if (!mounted) return;

    final bool ok = result['ok'] == true;
    final String? errorMessage = result['message']?.toString();
    final List<Map<String, dynamic>> rooms =
        (result['rooms'] as List<Map<String, dynamic>>?) ?? const [];

    if (ok) {
      setState(() {
        _chats = rooms;
        _lastErrorMessage = null;
        _viewState = rooms.isEmpty
            ? _ChatListViewState.empty
            : _ChatListViewState.content;
        _isRefreshing = false;
      });

      // Global WS bağlantılarını sadece gerektiğinde re-init et.
      // (Her yeni mesaj eventinde re-init etmek socket churn üretir.)
      if (rebindGlobalWs) {
        await GlobalChatService.instance.init(rooms);
      }
      return;
    }

    setState(() {
      _lastErrorMessage = errorMessage?.isNotEmpty == true
          ? errorMessage
          : 'Sohbetler yüklenemedi.';
      _viewState = _chats.isEmpty
          ? _ChatListViewState.error
          : _ChatListViewState.content;
      _isRefreshing = false;
    });
  }

  /// İncremental update: Sadece ilgili odayı güncelle, full API çağrısı yok
  /// Bu fonksiyon yeni mesaj event'lerinde çağrılır
  void _updateChatRoomLocally(String roomId) {
    // Odayı bul ve en üste taşı (yeni mesaj var olarak işaretle)
    final existingIndex = _chats.indexWhere((chat) => chat['roomId'] == roomId);
    if (existingIndex > 0) {
      // Odayı en üste taşı
      setState(() {
        final chat = Map<String, dynamic>.from(_chats.removeAt(existingIndex));
        chat['lastTimestamp'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        _chats.insert(0, chat);
      });
    } else if (existingIndex == 0) {
      // Zaten en üstte, sadece zamanı güncelle
      setState(() {
        _chats[0]['lastTimestamp'] =
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
      });
    }
    // Oda listede yoksa yapacak bir şey yok - tam yenileme gerekmez
  }

  void _hideChatCard(String roomId) {
    if (roomId.isEmpty) return;
    debugPrint('[CHAT-DELETE-DBG][UI] hide local card roomId=$roomId');
    setState(() {
      _chats.removeWhere((c) => (c['roomId'] ?? '').toString() == roomId);
    });
  }

  Future<void> _deleteChatForMe(String roomId) async {
    if (roomId.isEmpty) return;
    debugPrint('[CHAT-DELETE-DBG][UI] delete requested roomId=$roomId');
    _hideChatCard(roomId); // Kullanıcı aksiyonunda kartı anında kaldır.
    // Global WS tarafında da bu odayı dinlemek gereksiz hâle geldi.
    GlobalChatService.instance.removeRoom(roomId);

    final success = await ApiService.hideChatRoom(roomId);
    debugPrint(
        '[CHAT-DELETE-DBG][UI] delete result roomId=$roomId success=$success');
    if (!mounted) return;

    if (success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sohbet sunucuda silinemedi, ama bu ekranda gizlendi.',
        ),
        backgroundColor: Colors.orangeAccent,
      ),
    );
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
    GlobalChatService.instance.setChatListVisible(false);
    _refreshDebounce?.cancel();
    _messageEventsSub?.cancel();
    _searchController.dispose();
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

    List<Map<String, dynamic>> displayedChats = _chats;
    if (_isSearching && _searchQuery.trim().isNotEmpty) {
      final queryLower = _searchQuery.trim().toLowerCase();
      displayedChats = _chats.where((c) {
        final username = (c['username']?.toString() ?? '').toLowerCase();
        return username.contains(queryLower);
      }).toList();
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
                  // Sol: Başlık + alt açıklama veya Arama Inputu
                  Expanded(
                    child: _isSearching
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: 'Sohbetlerde ara...',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sohbetler',
                                style:
                                    Theme.of(context).textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Eşleşmelerinden gelen mesajlar',
                                style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.white60,
                                          fontWeight: FontWeight.w500,
                                        ) ??
                                    const TextStyle(
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
                    onTap: () {
                      setState(() {
                        if (_isSearching) {
                          _isSearching = false;
                          _searchQuery = '';
                          _searchController.clear();
                        } else {
                          _isSearching = true;
                        }
                      });
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Icon(
                        _isSearching
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        color: Colors.white54,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Aktif Eşleşme Özet Bandı ─────────────────────
            if (_lastErrorMessage != null && _chats.isNotEmpty)
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
                        _lastErrorMessage!,
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
                      onPressed: () =>
                          _loadChats(rebindGlobalWs: false, isRefresh: true),
                      child: const Text('Yenile',
                          style: TextStyle(color: Colors.orangeAccent)),
                    ),
                  ],
                ),
              ),

            if (_chats.isNotEmpty)
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
              child: _buildBody(displayedChats),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> displayedChats) {
    if (_viewState == _ChatListViewState.initialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      );
    }

    if (_viewState == _ChatListViewState.error && _chats.isEmpty) {
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
                _lastErrorMessage ?? 'Sohbetler yüklenemedi.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => _loadChats(rebindGlobalWs: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (displayedChats.isEmpty) {
      return RefreshIndicator(
        color: Colors.redAccent,
        onRefresh: () => _loadChats(rebindGlobalWs: true, isRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Text(
                _isSearching
                    ? 'Aradığınız kişiyle sohbet bulunamadı.'
                    : 'Henüz hiç eşleşmen veya sohbetin yok.',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            if (_isRefreshing) ...[
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
      onRefresh: () => _loadChats(rebindGlobalWs: false, isRefresh: true),
      child: Stack(
        children: [
          ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: displayedChats.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 1,
              ),
            ),
            itemBuilder: (context, index) {
              final chat = displayedChats[index];
              final avatarRaw = (chat['avatarUrl'] ?? '').toString().trim();
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
                onDelete: () => _deleteChatForMe(roomId),
                child: _ChatCard(
                  username: chat['username']?.toString() ?? 'Bilinmeyen',
                  avatarUrl: avatarUrl,
                  isOnline: true,
                  movieTitle:
                      chat['movieTitle']?.toString() ?? 'Bilinmeyen Film',
                  moviePoster: chat['moviePoster']?.toString() ?? '',
                  lastMessage:
                      chat['lastMessage']?.toString() ?? 'Sohbete başla...',
                  time: _formatTime(chat['lastTimestamp'] as int?),
                  unreadCount: (chat['unreadCount'] as int?) ?? 0,
                  onTap: () {
                    final roomId = chat['roomId']?.toString() ?? '';
                    final roomStatus = chat['status']?.toString() ?? '';
                    final isUnmatched = roomStatus == 'unmatched';
                    Navigator.of(context)
                        .push(
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          targetUserId: chat['targetUserId']?.toString(),
                          roomId: roomId,
                          username: chat['username']?.toString() ?? '',
                          avatarSeed: chat['avatarSeed']?.toString() ?? '',
                          avatarUrl: avatarUrl,
                          isOnline: true,
                          movieTitle: chat['movieTitle']?.toString() ?? '',
                          moviePoster: chat['moviePoster']?.toString(),
                          initialMessages: const [],
                          isUnmatched: isUnmatched,
                          unmatchedByUserId: chat['unmatchedBy']?.toString(),
                        ),
                      ),
                    )
                        .then((_) {
                      _loadChats();
                    });
                  },
                ),
              );
            },
          ),
          if (_isRefreshing)
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
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
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
      debugPrint(
          '[CHAT-DELETE-DBG][UI] drag dismiss triggered offset=$_offsetX width=$width');
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
                          debugPrint('[CHAT-DELETE-DBG][UI] trash tapped');
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
                    // Çöp kutusu alanına basıldı → sil
                    debugPrint(
                        '[CHAT-DELETE-DBG][UI] onTapUp → trash area tapped');
                    widget.onDelete();
                  } else {
                    // Kart alanına basıldı → geri kapat
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
