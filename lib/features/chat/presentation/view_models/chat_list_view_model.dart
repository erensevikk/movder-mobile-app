import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../data/models/chat_model.dart';
import '../../data/services/chat_repository_impl.dart';
import '../views/chat_detail_screen.dart';

class ChatListViewModel extends BaseViewModel {
  ChatListViewModel({ChatRepositoryImpl? repository})
      : _repository = repository ?? const ChatRepositoryImpl();

  final ChatRepositoryImpl _repository;

  // State
  List<ChatRoomModel> _rooms = [];
  String? _error;

  // Search State
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  // Getters
  List<ChatRoomModel> get rooms => _rooms;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => _rooms.isEmpty && !isLoading;

  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;

  int get totalUnreadCount {
    int total = 0;
    for (var room in _rooms) {
      total += room.unreadCount;
    }
    return total;
  }

  List<ChatRoomModel> get displayedRooms {
    if (!_isSearching || _searchQuery.trim().isEmpty) {
      return _rooms;
    }
    final queryLower = _searchQuery.trim().toLowerCase();
    return _rooms.where((room) {
      return room.username.toLowerCase().contains(queryLower);
    }).toList();
  }

  @override
  Future<void> initialize() async {
    searchController.addListener(_onSearchChanged);
    await loadChatRooms();
  }

  void _onSearchChanged() {
    _searchQuery = searchController.text;
    notifyListeners();
  }

  void toggleSearch() {
    _isSearching = !_isSearching;
    if (!_isSearching) {
      _searchQuery = '';
      searchController.clear();
    }
    notifyListeners();
  }

  Future<void> loadChatRooms() async {
    setLoading(true);
    setError(null);

    final result = await _repository.getChatRooms();

    if (result.isSuccess) {
      _rooms = result.data ?? [];
    } else {
      _error =
          result.failure?.message ?? 'Sohbet odaları yüklenirken hata oluştu';
    }
    setLoading(false);
  }

  Future<void> hideChat(String roomId) async {
    // Hide locally immediately
    _rooms.removeWhere((room) => room.roomId == roomId);
    notifyListeners();

    // Call API
    final result = await _repository.hideChat(roomId);

    if (result.isFailure) {
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'Sohbet sunucuda silinemedi',
      ));
    }
  }

  void onChatTap(ChatRoomModel room) {
    emitEffect(NavigateToEffect(
      pageBuilder: (context) => _buildChatDetailPage(room),
    ));
  }

  Widget _buildChatDetailPage(ChatRoomModel room) {
    return ChatDetailScreen(
      roomId: room.roomId,
      targetUserId: room.targetUserId,
      username: room.username,
      movieTitle: room.movieTitle,
      avatarSeed: room.avatarSeed,
      avatarUrl: room.avatarUrl,
      isOnline: room.isOnline,
      moviePoster: room.moviePoster,
    );
  }

  Future<void> onRefresh() => loadChatRooms();

  @override
  Future<void> disposeViewModel() async {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    await super.disposeViewModel();
  }
}
