import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<dynamic> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get('/api/users/blocked');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _blockedUsers = data['blockedUsers'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String targetId, String username) async {
    try {
      final response =
          await ApiService.post('/api/users/unblock/$targetId', {});
      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$username adlı kullanıcının engeli kaldırıldı.')),
        );
        _fetchBlockedUsers(); // Listeyi yenile
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Engel kaldırılırken bir hata oluştu.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı hatası.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Engellenen Kullanıcılar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withValues(alpha: 0.05), height: 1),
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    final id = user['id'] ?? '';
                    final username = user['username'] ?? 'Bilinmeyen';
                    final avatarRaw =
                        (user['avatarUrl'] ?? '').toString().trim();
                    final avatarUrl = avatarRaw.isEmpty
                        ? ''
                        : (avatarRaw.startsWith('http://') ||
                                avatarRaw.startsWith('https://')
                            ? avatarRaw
                            : (avatarRaw.startsWith('/')
                                ? '${ApiService.baseUrl}$avatarRaw'
                                : '${ApiService.baseUrl}/$avatarRaw'));

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1E1E1E),
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
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: Colors.white54,
                                  ),
                                )
                              : const Icon(Icons.person, color: Colors.white54),
                        ),
                      ),
                      title: Text(
                        username,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      trailing: TextButton(
                        onPressed: () => _unblockUser(id, username),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          backgroundColor: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Engeli Kaldır',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block,
              size: 60, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          const Text(
            'Engellenen kimse yok',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
