import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String username;
  final String avatarSeed;
  final bool isOnline;
  final String movieTitle;
  final String? moviePoster; // Film posteri URL'si (arka plan için)
  final List<Map<String, dynamic>> initialMessages;
  final String? targetUserId; // Backend id (null ise buton devre dışı)
  final String? roomId;

  const ChatDetailScreen({
    super.key,
    required this.username,
    required this.avatarSeed,
    required this.isOnline,
    required this.movieTitle,
    this.moviePoster,
    this.initialMessages = const [],
    this.targetUserId,
    this.roomId,
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
    _loadFriendStatus();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    if (widget.roomId == null) return;

    _chatService.connect(widget.roomId!);
    _chatService.messageStream.listen((msg) {
      if (!mounted) return;

      final type = msg['type'];

      if (type == 'message') {
        setState(() {
          _messages.add({
            'text': msg['content'] ?? '',
            'isMe': msg['userId'] ==
                null, // Kendim yollamadıysam target id vardır, ama kendi yolladığım zaten anında ekleniyo
            'time': _currentTime(),
            'status': msg['status'] ?? 'delivered',
            ...msg,
          });
        });
        _scrollToBottom();
      } else if (type == 'read_receipt') {
        // Ekrandaki tüm kendi attığım sent/delivered mesajları read yap
        setState(() {
          for (var m in _messages) {
            if (m['isMe'] == true &&
                (m['status'] == 'sent' || m['status'] == 'delivered')) {
              m['status'] = 'read';
            }
          }
        });
      } else if (type == 'unmatch') {
        _handleUnmatchState();
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

  Future<void> _loadFriendStatus() async {
    if (widget.targetUserId == null) return;
    final status = await ApiService.getFriendStatus(widget.targetUserId!);
    if (mounted) setState(() => _friendStatus = status);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    // Sadece chat servisine yolla, mesaj servisten geldiğinde (echoed) veya lokalden eklenmesi gerektiğinde stream'den listeye eklenecek
    _chatService.sendMessage(text.trim());
    _messageController.clear();

    // Lokal olarak listeye ekle ki anında ekranımızda da gözüksün
    setState(() {
      _messages.add({
        'content': text.trim(),
        'isMe': true,
        'time': _currentTime(),
        'status': 'sent',
      });
    });

    _scrollToBottom();
  }

  // Duruma göre buton görünümü
  Color get _friendButtonColor {
    switch (_friendStatus) {
      case 'friends':
        return Colors.greenAccent;
      case 'pending_sent':
        return Colors.blueAccent;
      default:
        return Colors.redAccent;
    }
  }

  IconData get _friendButtonIcon {
    switch (_friendStatus) {
      case 'friends':
        return Icons.favorite_rounded;
      case 'pending_sent':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.person_add_alt_1_rounded;
    }
  }

  String get _friendButtonLabel {
    switch (_friendStatus) {
      case 'friends':
        return 'Arkadaş';
      case 'pending_sent':
        return 'İstek gönderildi';
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Film Posteri Arka Plan ──────────────────────
          if (poster != null && poster.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                poster,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                      const Color(0xFF0F0F0F).withOpacity(0.85),
                      const Color(0xFF0F0F0F).withOpacity(0.90),
                    ],
                  ),
                ),
              ),
            ),

          // ── İçerik ─────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Üst AppBar ─────────────────────────────────
                _buildAppBar(),

                // ── Film Eşleşme Bandı ─────────────────────────
                _buildMovieBanner(),

                // ── Sohbet Alanı ───────────────────────────────
                Expanded(
                  child: hasMessages ? _buildMessageList() : _buildEmptyState(),
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
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://api.dicebear.com/7.x/avataaars/png?seed=${widget.avatarSeed}',
                    ),
                    fit: BoxFit.cover,
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
                      color: Colors.redAccent.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.movieTitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.redAccent.withOpacity(0.8),
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
          if (widget.targetUserId != null)
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
                        color: Colors.greenAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.4)),
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
                        color: Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.4)),
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
            else
              GestureDetector(
                onTap: (_friendStatus == 'friends' ||
                        _friendStatus == 'pending_sent' ||
                        _isFriendLoading)
                    ? null
                    : _toggleFriend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _friendButtonColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _friendButtonColor.withOpacity(0.4),
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
            Colors.redAccent.withOpacity(0.08),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                  ? Colors.redAccent.withOpacity(0.2)
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
                    ? Colors.redAccent.withOpacity(0.25)
                    : Colors.white.withOpacity(0.06),
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
                        color: Colors.white.withOpacity(0.3),
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
                color: Colors.redAccent.withOpacity(0.08),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.15), width: 2),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: Colors.redAccent.withOpacity(0.5),
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
                color: Colors.white.withOpacity(0.3),
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
                      color: Colors.redAccent.withOpacity(0.2),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
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
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.25),
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
                    color: Colors.redAccent.withOpacity(0.3),
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
