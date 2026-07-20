import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../data/models/chat_model.dart';
import '../../data/services/chat_repository_impl.dart';

class ChatDetailViewModel extends BaseViewModel {
  ChatDetailViewModel({
    required String roomId,
    required String targetUserId,
    String? username,
    String? movieTitle,
    String? avatarSeed,
    String? avatarUrl,
    bool isOnline = false,
    String? moviePoster,
    ChatRepositoryImpl? repository,
  })  : _roomId = roomId,
        _targetUserId = targetUserId,
        _username = username,
        _movieTitle = movieTitle,
        _avatarSeed = avatarSeed,
        _avatarUrl = avatarUrl,
        _isOnline = isOnline,
        _moviePoster = moviePoster,
        _repository = repository ?? const ChatRepositoryImpl();

  final ChatRepositoryImpl _repository;
  final String _roomId;
  final String _targetUserId;
  final String? _username;
  final String? _movieTitle;
  final String? _avatarSeed;
  final String? _avatarUrl;
  final bool _isOnline;
  final String? _moviePoster;

  // State
  List<ChatMessageModel> _messages = [];
  final TextEditingController messageController = TextEditingController();
  bool _isSending = false;
  FriendStatus _friendStatus = FriendStatus.none;
  bool _showActions = false;

  // Getters
  List<ChatMessageModel> get messages => _messages;
  bool get isSending => _isSending;
  FriendStatus get friendStatus => _friendStatus;
  bool get showActions => _showActions;
  String get roomId => _roomId;
  String get targetUserId => _targetUserId;
  String get username =>
      (_username != null && _username!.isNotEmpty) ? _username! : 'Kullanıcı';
  String get movieTitle =>
      (_movieTitle != null && _movieTitle!.isNotEmpty) ? _movieTitle! : '';
  String? get avatarSeed => _avatarSeed;
  String? get avatarUrl =>
      (_avatarUrl != null && _avatarUrl!.isNotEmpty) ? _avatarUrl : null;
  bool get isOnline => _isOnline;
  String? get moviePoster =>
      (_moviePoster != null && _moviePoster!.isNotEmpty) ? _moviePoster : null;

  @override
  Future<void> initialize() async {
    await Future.wait([
      loadMessages(),
      loadFriendStatus(),
    ]);
  }

  Future<void> loadMessages() async {
    setLoading(true);

    final result = await _repository.getMessages(_roomId);

    if (result.isSuccess) {
      _messages = result.data ?? [];
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final first = _messages.isNotEmpty ? _messages.first : null;
      final last = _messages.isNotEmpty ? _messages.last : null;
      final monotonic = _isMonotonicAscending(_messages);
      debugPrint(
        '[CHAT-DIAG][DETAIL][LOAD] roomId=$_roomId messageCount=${_messages.length} first={id:${first?.id}, isMe:${first?.isMe}, time:${first?.timestamp.toIso8601String()}} last={id:${last?.id}, isMe:${last?.isMe}, text:"${last?.text}", time:${last?.timestamp.toIso8601String()}, status:${last?.status}} sortedAscending=$monotonic',
      );
    } else {
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'Mesajlar yüklenemedi',
      ));
    }
    setLoading(false);
  }

  Future<void> loadFriendStatus() async {
    final result = await _repository.getFriendStatus(_targetUserId);

    if (result.isSuccess) {
      _friendStatus = result.data ?? FriendStatus.none;
      notifyListeners();
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    debugPrint(
      '[CHAT-DIAG][DETAIL][SEND_START] roomId=$_roomId textLen=${text.length} text="$text" currentMessageCount=${_messages.length}',
    );

    _isSending = true;
    messageController.clear();
    notifyListeners();

    // Önce UI'ı güncelle
    final tempMessage = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      senderId: 'me',
      isMe: true,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
    );
    _messages.add(tempMessage);
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final tempMonotonic = _isMonotonicAscending(_messages);
    debugPrint(
      '[CHAT-DIAG][DETAIL][SEND_TEMP] roomId=$_roomId messageCount=${_messages.length} sortedAscending=$tempMonotonic',
    );
    notifyListeners();

    // API çağrısı yap
    final result = await _repository.sendMessage(_roomId, text);
    debugPrint(
      '[CHAT-DIAG][DETAIL][SEND_RESULT] roomId=$_roomId success=${result.isSuccess} failure=${result.failure?.message}',
    );

    _isSending = false;

    if (result.isFailure) {
      // Mesaj gönderilemedi - hata göster
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'Mesaj gönderilemedi',
      ));
      // Başarısız mesajı kaldır
      _messages.removeWhere((m) => m.id == tempMessage.id);
    } else {
      // Mesaj başarılı - durumu güncelle
      final index = _messages.indexWhere((m) => m.id == tempMessage.id);
      if (index >= 0) {
        _messages[index] = ChatMessageModel(
          id: tempMessage.id,
          text: text,
          senderId: 'me',
          isMe: true,
          timestamp: tempMessage.timestamp,
          status: MessageStatus.sent,
        );
      }
    }

    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final finalFirst = _messages.isNotEmpty ? _messages.first : null;
    final finalLast = _messages.isNotEmpty ? _messages.last : null;
    final finalMonotonic = _isMonotonicAscending(_messages);
    debugPrint(
      '[CHAT-DIAG][DETAIL][SEND_DONE] roomId=$_roomId messageCount=${_messages.length} first={id:${finalFirst?.id}, time:${finalFirst?.timestamp.toIso8601String()}} last={id:${finalLast?.id}, isMe:${finalLast?.isMe}, text:"${finalLast?.text}", time:${finalLast?.timestamp.toIso8601String()}, status:${finalLast?.status}} sortedAscending=$finalMonotonic',
    );
    notifyListeners();
  }

  bool _isMonotonicAscending(List<ChatMessageModel> list) {
    if (list.length < 2) return true;
    for (var i = 1; i < list.length; i++) {
      if (list[i].timestamp.isBefore(list[i - 1].timestamp)) {
        return false;
      }
    }
    return true;
  }

  void toggleActions() {
    _showActions = !_showActions;
    notifyListeners();
  }

  Future<void> sendFriendRequest() async {
    final result = await _repository.sendFriendRequest(_targetUserId);

    if (result.isSuccess) {
      _friendStatus = FriendStatus.pendingSent;
      notifyListeners();
      emitEffect(const ShowSnackbarEffect(
        message: 'Arkadaşlık isteği gönderildi',
      ));
    } else {
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'İstek gönderilemedi',
      ));
    }
  }

  Future<void> removeFriend() async {
    final result = await _repository.removeFriend(_targetUserId);

    if (result.isSuccess) {
      _friendStatus = FriendStatus.none;
      notifyListeners();
      emitEffect(const ShowSnackbarEffect(
        message: 'Arkadaşlık kaldırıldı',
      ));
    } else {
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'İşlem başarısız',
      ));
    }
  }

  Future<void> unmatchUser() async {
    final result = await _repository.unmatchUser(_targetUserId);

    if (result.isSuccess) {
      emitEffect(const PopEffect());
    } else {
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'Eşleşme sonlandırılamadı',
      ));
    }
  }

  Future<void> blockUser() async {
    final result = await _repository.blockUser(_targetUserId);

    if (result.isSuccess) {
      emitEffect(const PopEffect());
    } else {
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'Kullanıcı engellenemedi',
      ));
    }
  }

  Future<void> hideChat() async {
    final result = await _repository.hideChat(_roomId);

    if (result.isSuccess) {
      emitEffect(const PopEffect());
    } else {
      emitEffect(ShowSnackbarEffect(
        message: result.failure?.message ?? 'Sohbet gizlenemedi',
      ));
    }
  }

  @override
  Future<void> disposeViewModel() async {
    messageController.dispose();
    await super.disposeViewModel();
  }
}
