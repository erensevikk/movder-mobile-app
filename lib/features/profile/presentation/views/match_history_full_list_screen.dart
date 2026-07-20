import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../screens/user_detail_screen.dart';
import '../../data/models/match_history_model.dart';
import '../../../../services/api_service.dart';

class MatchHistoryFullListScreen extends StatefulWidget {
  const MatchHistoryFullListScreen({super.key});

  @override
  State<MatchHistoryFullListScreen> createState() => _MatchHistoryFullListScreenState();
}

class _MatchHistoryFullListScreenState extends State<MatchHistoryFullListScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<MatchHistoryItemModel> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _fetchPage();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchPage();
      }
    });
  }

  Future<void> _fetchPage() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final resp = await ApiService.getMatchHistory(page: _currentPage, limit: _limit);
    if (resp != null) {
      final newItems = (resp['items'] as List<dynamic>?)
              ?.map((e) => MatchHistoryItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <MatchHistoryItemModel>[];

      setState(() {
        _items.addAll(newItems);
        _currentPage++;
        if (newItems.length < _limit) {
          _hasMore = false;
        }
      });
    } else {
      setState(() {
        _hasMore = false;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Eşleşme Geçmişi',
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textHigh),
      ),
      body: _items.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _items.isEmpty && !_isLoading
              ? const Center(
                  child: Text(
                    'Henüz eşleşme geçmişiniz yok.',
                    style: TextStyle(color: AppColors.textMedium),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == _items.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      );
                    }

                    final item = _items[index];
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserDetailScreen(
                              userId: item.matchedUserId,
                              isMe: false,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.surface,
                              backgroundImage: (item.avatarUrl != null && item.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(
                                      item.avatarUrl!.startsWith('http')
                                          ? item.avatarUrl!
                                          : 'http://10.0.2.2:8080${item.avatarUrl}',
                                    )
                                  : null,
                              child: (item.avatarUrl == null || item.avatarUrl!.isEmpty)
                                  ? const Icon(Icons.person, color: AppColors.textMedium)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.username ?? 'Kullanıcı',
                                    style: const TextStyle(
                                      color: AppColors.textHigh,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Film: ${item.movieName}',
                                    style: const TextStyle(
                                      color: AppColors.textMedium,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
