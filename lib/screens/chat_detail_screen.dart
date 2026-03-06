import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/global_chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String username;
  final String avatarSeed;
  final String? avatarUrl;
  final bool isOnline;
  final String movieTitle;
  final String? moviePoster; // Film posteri URL'si (arka plan için)
  final List<Map<String, dynamic>> initialMessages;
  final String? targetUserId; // Backend id (null ise buton devre dışı)
  final String? roomId;
  final bool isUnmatched;
  final String? unmatchedByUserId;

  const ChatDetailScreen({
    super.key,
    required this.username,
    required this.avatarSeed,
    this.avatarUrl,
    required this.isOnline,
    required this.movieTitle,
    this.moviePoster,
    this.initialMessages = const [],
    this.targetUserId,
    this.roomId,
    this.isUnmatched = false,
    this.unmatchedByUserId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late List<Map<String, dynamic>> _messages;

  // Akıllı mesaj servisi
  final ChatService _chatService = ChatService();

  // Arkadaşlık durumu: "none" | "pending_sent" | "pending_received" | "friends"
  String _friendStatus = 'none';
  bool _isFriendLoading = false;
  String? _myUserId;
  Timer? _friendStatusPollTimer;
  bool _isUnmatched = false;
  bool _unmatchedByMe = false;
  int _friendStatusRequestSeq = 0;
  int _friendStatusWsVersion = 0;
  final GlobalKey _friendsMenuAnchorKey = GlobalKey();
  double? _friendsMenuWidth;

  // ── Hızlı Mesajlar (ilk mesaj için) ──────────────────────
  static const List<String> _quickMessages = [
    'Selam! 👋',
    'Kaçıncı dakikadasın?',
    'Bu film efsane değil mi? 🔥',
    'İlk kez mi izliyorsun?',
    'Spoiler verme sakın 😄',
    'Birlikte izlemek harika!',
  ];

  @override
  void initState() {
    super.initState();
    _messages = List<Map<String, dynamic>>.from(widget.initialMessages);
    _isUnmatched = widget.isUnmatched;
    _loadMyUserId();
    _loadFriendStatus(trigger: 'init');
    _startFriendStatusPolling();
    _setupWebSocket();
    // Bu odaya girdiğimizde global dinleyiciye haber ver
    // Böylece aynı odadan gelen mesajlar bildirim balonu olarak gösterilmez
    if (widget.roomId != null) {
      GlobalChatService.instance.setActiveRoom(widget.roomId!);
    }
  }

  Future<void> _loadMyUserId() async {
    final profile = await ApiService.getProfile();
    if (mounted && profile != null) {
      setState(() {
        _myUserId =
            (profile['userId'] ?? profile['_id'] ?? profile['id'])?.toString();
        if (_isUnmatched) {
          final unmatchedByUserId = widget.unmatchedByUserId ?? '';
          _unmatchedByMe =
              unmatchedByUserId.isNotEmpty && unmatchedByUserId == _myUserId;
        }
      });
      // Geçmiş mesajları yükle
      if (widget.roomId != null) {
        await _loadMessages();
      }

      setState(() {
        // WebSocket'ten önce gelen mesajların isMe'sini geriye dönük düzeltelim
        for (var m in _messages) {
          if (m['senderId'] != null) {
            m['isMe'] = m['senderId'] == _myUserId;
          }
        }
      });
    }
  }

  Future<void> _loadMessages() async {
    if (widget.roomId == null) return;
    final history = await ApiService.getChatMessages(widget.roomId!);
    if (!mounted) return;

    setState(() {
      _messages = history.map((m) {
        return {
          'text': m['content'] ?? '',
          'isMe': m['senderId'] == _myUserId,
          'time': _formatTimestamp(m['timestamp']),
          'status': m['status'] ?? 'delivered',
          'senderId': m['senderId'],
        };
      }).toList();
    });
    _scrollToBottom();
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return _currentTime();
    final int timestamp = (ts is int) ? ts : int.tryParse(ts.toString()) ?? 0;
    if (timestamp == 0) return _currentTime();

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('HH:mm').format(date);
  }

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
        debugPrint(
          '[FRIENDS-MENU-WIDTH-DBG] measured friends_button_width=$measured',
        );
      }
    });
  }

  void _setupWebSocket() {
    if (widget.roomId == null) return;

    _chatService.connect(widget.roomId!);
    _chatService.messageStream.listen((msg) {
      if (!mounted) return;

      final type = msg['type'];
      debugPrint(
        '[CHAT-DBG] ws_event type=$type senderId=${msg['senderId']} status=${msg['status']} myUserId=$_myUserId roomId=${widget.roomId}',
      );

      if (type == 'message') {
        // Kendi mesaj echo'sunda yeni bubble eklemek yerine lokal mesajın status'unu merge et
        if (_myUserId != null && msg['senderId'] == _myUserId) {
          final incomingContent = (msg['content'] ?? '').toString();
          final incomingStatus = (msg['status'] ?? 'delivered').toString();
          bool merged = false;

          setState(() {
            for (int i = _messages.length - 1; i >= 0; i--) {
              final m = _messages[i];
              final isMe = m['isMe'] == true;
              final text = (m['text'] ?? '').toString();
              final status = (m['status'] ?? 'sent').toString();
              final isPending = status == 'sent' || status == 'delivered';

              if (isMe && text == incomingContent && isPending) {
                m['status'] = incomingStatus;
                if (msg['timestamp'] != null) {
                  m['time'] = _formatTimestamp(msg['timestamp']);
                }
                merged = true;
                break;
              }
            }

            // İçerik bazlı eşleşme olmazsa en son pending kendi mesajını güncelle (fallback)
            if (!merged) {
              for (int i = _messages.length - 1; i >= 0; i--) {
                final m = _messages[i];
                final isMe = m['isMe'] == true;
                final status = (m['status'] ?? 'sent').toString();
                final isPending = status == 'sent' || status == 'delivered';
                if (isMe && isPending) {
                  m['status'] = incomingStatus;
                  if (msg['timestamp'] != null) {
                    m['time'] = _formatTimestamp(msg['timestamp']);
                  }
                  merged = true;
                  break;
                }
              }
            }
          });

          debugPrint(
            '[CHAT-DBG] own_message_echo_merged senderId=${msg['senderId']} status=$incomingStatus merged=$merged',
          );
          return;
        }

        setState(() {
          _messages.add({
            'text': msg['content'] ?? '',
            'isMe': _myUserId != null ? (msg['senderId'] == _myUserId) : false,
            'time': _currentTime(),
            'status': msg['status'] ?? 'delivered',
            ...msg,
          });
        });
        _scrollToBottom();

        // Karşıdan yeni mesaj geldiyse (ekran açıksa) anında okundu bilgisi gönder
        _chatService.sendReadReceipt();
      } else if (type == 'read_receipt') {
        debugPrint('[CHAT-DBG] read_receipt_received roomId=${widget.roomId}');
        // Ekrandaki tüm kendi attığım sent/delivered mesajları read yap
        setState(() {
          for (var m in _messages) {
            if (m['isMe'] == true &&
                (m['status'] == 'sent' || m['status'] == 'delivered')) {
              m['status'] = 'read';
            }
          }
        });
      } else if (type == 'friend_status_changed') {
        _friendStatusWsVersion++;
        final wsVersion = _friendStatusWsVersion;
        _applyOptimisticFriendStatusFromEvent(msg, wsVersion: wsVersion);
        _loadFriendStatus(trigger: 'ws_event', minWsVersion: wsVersion);
      } else if (type == 'unmatch') {
        final senderId = msg['senderId']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _isUnmatched = true;
            _unmatchedByMe = senderId.isNotEmpty && senderId == _myUserId;
          });
        }
      }
    });

    // Odaya ilk girdiğimizde 'read_receipt' yollayarak karşı tarafın mesajlarını okundu yapalım
    Future.delayed(const Duration(milliseconds: 500), () {
      _chatService.sendReadReceipt();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _applyOptimisticFriendStatusFromEvent(Map<String, dynamic> msg,
      {required int wsVersion}) {
    final senderId = msg['senderId']?.toString();
    final receiverId = msg['receiverId']?.toString();
    final targetUserId = widget.targetUserId;
    final myUserId = _myUserId;

    if (senderId == null || receiverId == null || targetUserId == null) {
      return;
    }
    if (myUserId == null) {
      return;
    }

    String? optimistic;

    // Karşı taraf bir aksiyon yaptıysa
    if (senderId == targetUserId && receiverId == myUserId) {
      if (_friendStatus == 'none') {
        optimistic = 'pending_received';
      } else if (_friendStatus == 'pending_sent') {
        optimistic = 'friends';
      } else if (_friendStatus == 'friends') {
        optimistic = 'none';
      }
    }

    // Ben aksiyon yaptıysam (diğer cihaz/senaryo geri yankısı)
    if (senderId == myUserId && receiverId == targetUserId) {
      if (_friendStatus == 'none') {
        optimistic = 'pending_sent';
      } else if (_friendStatus == 'pending_received') {
        optimistic = 'friends';
      } else if (_friendStatus == 'pending_sent' ||
          _friendStatus == 'friends') {
        optimistic = 'none';
      }
    }

    if (optimistic == null || optimistic == _friendStatus) {
      return;
    }

    if (mounted) {
      setState(() => _friendStatus = optimistic!);
    }
  }

  Future<void> _loadFriendStatus(
      {String trigger = 'manual', int? minWsVersion}) async {
    if (widget.targetUserId == null) return;

    final requestId = ++_friendStatusRequestSeq;
    final requestStartWsVersion = _friendStatusWsVersion;

    final status = await ApiService.getFriendStatus(widget.targetUserId!);

    if (!mounted) return;

    if (requestId != _friendStatusRequestSeq) {
      return;
    }

    if (trigger == 'polling' &&
        requestStartWsVersion < _friendStatusWsVersion) {
      return;
    }

    if (minWsVersion != null && _friendStatusWsVersion > minWsVersion) {
      return;
    }

    setState(() => _friendStatus = status);
  }

  void _startFriendStatusPolling() {
    if (widget.targetUserId == null) return;
    _friendStatusPollTimer?.cancel();
    _friendStatusPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadFriendStatus(trigger: 'polling'),
    );
  }

  @override
  void dispose() {
    _friendStatusPollTimer?.cancel();
    // Chat ekranından çıkınca global dinleyicide aktif oda bayrağını sıfırla
    GlobalChatService.instance.clearActiveRoom();
    // Ekrandan çıkınca websocket'i kapat; aksi halde odada var görünmeye devam eder
    _chatService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (_isUnmatched) return;
    if (text.trim().isEmpty) return;

    // Sadece chat servisine yolla, mesaj servisten geldiğinde (echoed) veya lokalden eklenmesi gerektiğinde stream'den listeye eklenecek
    _chatService.sendMessage(text.trim());
    _messageController.clear();

    // Lokal olarak listeye ekle ki anında ekranımızda da gözüksün
    setState(() {
      _messages.add({
        'text': text.trim(),
        'isMe': true,
        'time': _currentTime(),
        'status': 'sent',
      });
    });
    debugPrint(
      '[CHAT-DBG] local_message_appended status=sent roomId=${widget.roomId} myUserId=$_myUserId',
    );

    _scrollToBottom();
  }

  // Duruma göre buton görünümü
  Color get _friendButtonColor {
    switch (_friendStatus) {
      case 'friends':
        return Colors.greenAccent;
      case 'pending_sent':
        return Colors.orangeAccent;
      default:
        return Colors.redAccent;
    }
  }

  IconData get _friendButtonIcon {
    switch (_friendStatus) {
      case 'friends':
        return Icons.check_rounded;
      case 'pending_sent':
        return Icons.cancel_schedule_send_rounded;
      default:
        return Icons.person_add_alt_1_rounded;
    }
  }

  String get _friendButtonLabel {
    switch (_friendStatus) {
      case 'friends':
        return 'Arkadaşlar';
      case 'pending_sent':
        return 'İsteği İptal Et';
      default:
        return 'Arkadaş Ekle';
    }
  }

  String _currentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleFriend() async {
    if (widget.targetUserId == null) return;
    if (_friendStatus == 'friends') return; // Zaten arkadaş

    setState(() => _isFriendLoading = true);

    final result = await ApiService.sendFriendRequest(widget.targetUserId!);

    if (!mounted) return;
    setState(() => _isFriendLoading = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı hatası. Lütfen tekrar dene.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final newStatus = (result['status'] ?? 'none').toString();
    final message = (result['message'] ?? '').toString();
    setState(() => _friendStatus = newStatus);

    final isMutual = newStatus == 'friends';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isMutual ? Icons.favorite_rounded : Icons.person_add_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isMutual ? Colors.greenAccent.shade700 : const Color(0xFF1E4B6E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isMutual ? 4 : 3),
      ),
    );
  }

  Future<void> _cancelSentFriendRequest() async {
    if (widget.targetUserId == null) return;
    setState(() => _isFriendLoading = true);

    final success = await ApiService.removeFriend(widget.targetUserId!);
    if (!mounted) return;

    setState(() => _isFriendLoading = false);
    if (success) {
      setState(() => _friendStatus = 'none');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arkadaşlık isteği iptal edildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İstek iptal edilemedi.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _respondToRequest(bool accept) async {
    if (widget.targetUserId == null) return;
    setState(() => _isFriendLoading = true);

    if (accept) {
      // Kabul edince normal arkadaş ekleme isteği atılır (karşılıklı onaylanır)
      final result = await ApiService.sendFriendRequest(widget.targetUserId!);
      if (!mounted) return;

      setState(() => _isFriendLoading = false);

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bağlantı hatası.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final newStatus = (result['status'] ?? 'none').toString();
      setState(() => _friendStatus = newStatus);
    } else {
      // Reddetme işlemi
      final success = await ApiService.removeFriend(widget.targetUserId!);
      if (!mounted) return;

      setState(() => _isFriendLoading = false);

      if (success) {
        setState(() => _friendStatus = 'none');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşlem başarısız.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRemoveFriendConfirmDialog() async {
    if (widget.targetUserId == null) return;

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text('Arkadaşı Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${widget.username} adlı kullanıcıyı arkadaş listesinden kaldırmak istiyor musun?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Vazgeç', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Onayla', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;

    setState(() => _isFriendLoading = true);
    final success = await ApiService.removeFriend(widget.targetUserId!);
    if (!mounted) return;

    setState(() => _isFriendLoading = false);

    if (success) {
      setState(() => _friendStatus = 'none');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arkadaşlıktan çıkarıldı.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadFriendStatus(trigger: 'remove_friend_confirmed');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Arkadaşlıktan çıkarma başarısız.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMessages = _messages.isNotEmpty;
    // Poster URL'sini yüksek kaliteye çekiyoruz (w780 gibi)
    String? poster = widget.moviePoster;
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
                  top: false, // üstten zaten SizedBox ile boşluk verdik
                  child: Column(
                    children: [
                      // ── Üst AppBar ─────────────────────────────────
                      _buildAppBar(),

                      // ── Film Eşleşme Bandı ─────────────────────────
                      _buildMovieBanner(),

                      // ── Sohbet Alanı ───────────────────────────────
                      Expanded(
                        child: hasMessages
                            ? _buildMessageList()
                            : _buildEmptyState(),
                      ),

                      // ── Hızlı Mesajlar (sadece boş sohbette) ──────
                      if (!hasMessages) _buildQuickMessages(),

                      // ── Mesaj Giriş Alanı ──────────────────────────
                      _buildMessageInput(),
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
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 0.5),
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
                  child: (widget.avatarUrl != null &&
                          widget.avatarUrl!.trim().isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: widget.avatarUrl!,
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
              if (widget.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF0F0F0F), width: 2),
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
                  widget.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
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
                        widget.movieTitle,
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
          if (widget.targetUserId != null && !_isUnmatched)
            if (_friendStatus == 'pending_received')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap:
                        _isFriendLoading ? null : () => _respondToRequest(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
                    onTap: _isFriendLoading
                        ? null
                        : () => _respondToRequest(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
            else if (_friendStatus == 'friends')
              PopupMenuButton<String>(
                enabled: !_isFriendLoading,
                color: const Color(0xFF1E1E1E),
                offset: const Offset(0, 42),
                constraints: _friendsMenuWidth == null
                    ? const BoxConstraints(minWidth: 0)
                    : BoxConstraints.tightFor(width: _friendsMenuWidth),
                onOpened: () {
                  _captureFriendsMenuWidth();
                  debugPrint(
                    '[FRIENDS-MENU-WIDTH-DBG] menu_open anchor_width=${_friendsMenuWidth ?? -1}',
                  );
                },
                onSelected: (value) {
                  if (value == 'remove_friend') {
                    _showRemoveFriendConfirmDialog();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'remove_friend',
                    child: SizedBox(
                      width: (_friendsMenuWidth ?? 0) > 0
                          ? _friendsMenuWidth
                          : null,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _friendButtonColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _friendButtonColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isFriendLoading)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _friendButtonColor,
                          ),
                        )
                      else ...[
                        Icon(_friendButtonIcon,
                            size: 16, color: _friendButtonColor),
                        const SizedBox(width: 4),
                        Text(
                          _friendButtonLabel,
                          style: TextStyle(
                            color: _friendButtonColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_drop_down_rounded,
                            size: 18, color: _friendButtonColor),
                      ],
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _isFriendLoading
                    ? null
                    : (_friendStatus == 'pending_sent'
                        ? _cancelSentFriendRequest
                        : _toggleFriend),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _friendButtonColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _friendButtonColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isFriendLoading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _friendButtonColor),
                            )
                          : Icon(_friendButtonIcon,
                              size: 16, color: _friendButtonColor),
                      const SizedBox(width: 4),
                      Text(
                        _friendButtonLabel,
                        style: TextStyle(
                          color: _friendButtonColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          // Seçenekler Menüsü (Üç Nokta)
          if (widget.targetUserId != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF1E1E1E),
              offset: const Offset(0, 55),
              onSelected: (value) {
                if (value == 'unmatch') {
                  _showUnmatchDialog();
                } else if (value == 'block') {
                  _showBlockDialog();
                }
              },
              itemBuilder: (context) => [
                if (!_isUnmatched)
                  const PopupMenuItem(
                    value: 'unmatch',
                    height: 38,
                    child: Text(
                      'Eşleşmeyi iptal et',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'block',
                  height: 38,
                  child: Text(
                    'Engelle',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showUnmatchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Eşleşmeyi İptal Et',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Bu kişiyle olan eşleşmenizi iptal etmek istediğinize emin misiniz?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Vazgeç', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.targetUserId != null) {
                final success =
                    await ApiService.unmatchUser(widget.targetUserId!);
                if (success && mounted) {
                  _handleUnmatchState();
                }
              }
            },
            child: const Text('İptal Et',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Kullanıcıyı Engelle',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Bu kişiyi engellemek istediğinize emin misiniz? Bir daha eşleşmeyeceksiniz.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Vazgeç', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.targetUserId != null) {
                final success =
                    await ApiService.blockUser(widget.targetUserId!);
                if (success && mounted) {
                  _handleUnmatchState();
                }
              }
            },
            child: const Text('Engelle',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _handleUnmatchState() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Eşleşme İptal Edildi',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Bu kullanıcıyla olan eşleşmeniz iptal edildi. Artık mesajlaşamazsınız.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialogu kapat
              Navigator.pop(context); // Chat ekranından çık (isteğe bağlı)
            },
            child:
                const Text('Tamam', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  // ── FİLM EŞLEŞME BANDI ───────────────────────────────────
  Widget _buildMovieBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.redAccent.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, size: 14, color: Colors.white24),
          const SizedBox(width: 8),
          Text(
            '${widget.movieTitle} izlerken eşleştiniz',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── MESAJ LİSTESİ ─────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final bool isMe = msg['isMe'] as bool;
        final String text = msg['text'] as String;
        final String time = msg['time'] as String;
        final String status =
            (msg['status'] ?? 'sent') as String; // sent, delivered, read

        IconData statusIcon = Icons.check;
        Color statusColor = Colors.white30;

        if (status == 'delivered') {
          statusIcon = Icons.done_all;
        } else if (status == 'read') {
          statusIcon = Icons.done_all;
          statusColor = Colors.blueAccent;
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
              ],
            ),
          ),
        );
      },
    );
  }

  // ── BOŞ SOHBET DURUMU ─────────────────────────────────────
  Widget _buildEmptyState() {
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
  Widget _buildQuickMessages() {
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
                onTap: () => _sendMessage(msg),
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
  Widget _buildMessageInput() {
    if (_isUnmatched) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded,
                size: 16, color: Colors.redAccent.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _unmatchedByMe
                    ? 'Eşleşmeyi iptal ettiniz. Artık mesaj gönderemezsiniz.'
                    : '${widget.username} eşleşmeyi iptal etti. Artık mesaj gönderemezsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                controller: _messageController,
                focusNode: _focusNode,
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
                onSubmitted: (text) => _sendMessage(text),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Gönder butonu
          GestureDetector(
            onTap: () => _sendMessage(_messageController.text),
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
              child: const Icon(
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
