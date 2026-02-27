import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  // ── Mock Sohbet Verisi ──────────────────────────────────────
  static final List<Map<String, dynamic>> _mockChats = [
    {
      'username': 'yagmur_snm',
      'avatarSeed': 'yagmur_snm',
      'isOnline': true,
      'movieTitle': 'Interstellar',
      'moviePoster':
          'https://image.tmdb.org/t/p/w92/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
      'lastMessage': 'O sahne efsaneydi, Cooper geri döndüğünde ağladım 😭',
      'time': '14:32',
      'unreadCount': 3,
      'messages': [
        {
          'text': 'Selam! Interstellar izliyor musun sen de?',
          'isMe': false,
          'time': '14:10'
        },
        {
          'text': 'Evet! Tam kara delik sahnesindeyim 🚀',
          'isMe': true,
          'time': '14:12'
        },
        {
          'text': 'O sahne efsane, bekle birazdan ağlayacaksın 😄',
          'isMe': false,
          'time': '14:15'
        },
        {'text': 'Haha hazırım!', 'isMe': true, 'time': '14:20'},
        {
          'text': 'O sahne efsaneydi, Cooper geri döndüğünde ağladım 😭',
          'isMe': false,
          'time': '14:32'
        },
      ],
    },
    {
      'username': 'cinema_addict',
      'avatarSeed': 'cinema_addict',
      'isOnline': false,
      'movieTitle': 'Inception',
      'moviePoster':
          'https://image.tmdb.org/t/p/w92/ljsZTbVsrQSqZgWeep2B1QiDKuh.jpg',
      'lastMessage': 'Totem hâlâ dönüyor mu sence? 🤔',
      'time': 'Dün',
      'unreadCount': 0,
      'messages': [],
    },
  ];

  @override
  Widget build(BuildContext context) {
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
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withOpacity(0.12),
                    Colors.redAccent.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
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
                  const Text(
                    '2 aktif sohbet',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '3 okunmamış',
                      style: TextStyle(
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
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _mockChats.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Divider(
                    color: Colors.white.withOpacity(0.06),
                    height: 1,
                  ),
                ),
                itemBuilder: (context, index) {
                  final chat = _mockChats[index];
                  return _ChatCard(
                    username: chat['username'] as String,
                    avatarSeed: chat['avatarSeed'] as String,
                    isOnline: chat['isOnline'] as bool,
                    movieTitle: chat['movieTitle'] as String,
                    moviePoster: chat['moviePoster'] as String,
                    lastMessage: chat['lastMessage'] as String,
                    time: chat['time'] as String,
                    unreadCount: chat['unreadCount'] as int,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            username: chat['username'] as String,
                            avatarSeed: chat['avatarSeed'] as String,
                            isOnline: chat['isOnline'] as bool,
                            movieTitle: chat['movieTitle'] as String,
                            initialMessages: (chat['messages'] as List<dynamic>)
                                .cast<Map<String, dynamic>>(),
                          ),
                        ),
                      );
                    },
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
  final String avatarSeed;
  final bool isOnline;
  final String movieTitle;
  final String moviePoster;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final VoidCallback? onTap;

  const _ChatCard({
    required this.username,
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
                ? Colors.redAccent.withOpacity(0.2)
                : Colors.white.withOpacity(0.06),
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
                          ? Colors.redAccent.withOpacity(0.5)
                          : Colors.white24,
                      width: 2,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(
                        'https://api.dicebear.com/7.x/avataaars/png?seed=$avatarSeed',
                      ),
                      fit: BoxFit.cover,
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

                  // Eşleşme Film Etiketi
                  Row(
                    children: [
                      // Mini film posteri
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          moviePoster,
                          width: 18,
                          height: 26,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 18,
                            height: 26,
                            color: Colors.white12,
                            child: const Icon(Icons.movie,
                                size: 12, color: Colors.white24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.2)),
                        ),
                        child: Text(
                          movieTitle,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
