import 'package:flutter/foundation.dart';
import '../../../../core/base/app_failure.dart';
import '../../../../core/base/result.dart';
import '../../../../core/utils/url_resolver.dart';
import '../../../../services/api_service.dart';
import '../models/chat_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl();

  @override
  Future<Result<List<ChatRoomModel>>> getChatRooms() async {
    try {
      final rawRooms = await ApiService.getChatRooms();
      final rooms = rawRooms.map((e) => Map<String, dynamic>.from(e)).toList();
      
      // Enrich missing usernames or avatarUrls from target user profile if necessary
      for (var room in rooms) {
        final needsUsername = _resolveUsername(room) == 'Bilinmeyen';
        final hasEmptyAvatar = (room['avatarUrl']?.toString() ?? '').trim().isEmpty;

        if (needsUsername || hasEmptyAvatar) {
          final targetUserId = room['targetUserId']?.toString() ??
              room['otherUserId']?.toString();
          
          if (targetUserId != null && targetUserId.isNotEmpty) {
            final profile = await ApiService.getUserProfile(targetUserId);
            if (profile != null) {
              if (needsUsername) {
                final newUsername = (profile['username'] ?? '').toString().trim();
                if (newUsername.isNotEmpty) {
                  room['username'] = newUsername;
                }
              }
              if (hasEmptyAvatar) {
                final newAvatarUrl = (profile['avatarUrl'] ?? '').toString().trim();
                if (newAvatarUrl.isNotEmpty) {
                  room['avatarUrl'] = newAvatarUrl;
                }
              }
            }
          }
        }
      }

      final chatRooms = rooms.map(_parseChatRoom).toList();
      return Result.success(chatRooms);
    } catch (e) {
      return Result.failure(
          AppFailure(message: 'Sohbet odaları alınamadı: $e'));
    }
  }

  ChatRoomModel _parseChatRoom(Map<String, dynamic> json) {
    return ChatRoomModel(
      roomId: json['roomId']?.toString() ?? '',
      targetUserId: json['targetUserId']?.toString() ??
          json['otherUserId']?.toString() ??
          '',
      username: _resolveUsername(json),
      avatarSeed: json['avatarSeed']?.toString(),
      avatarUrl: _resolveAvatarUrl(json['avatarUrl']?.toString()),
      movieTitle: json['movieTitle']?.toString(),
      moviePoster: _resolveMoviePosterUrl(json['moviePoster']?.toString()),
      lastMessage: json['lastMessage']?.toString(),
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'].toString())
          : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      isOnline: json['isOnline'] == true,
    );
  }

  String _resolveUsername(Map<String, dynamic> room) {
    // Debug: Print all keys to understand the API response
    debugPrint('Chat room keys: ${room.keys.toList()}');
    debugPrint('Chat room data: $room');

    final candidates = [
      room['username'],
      room['targetUsername'],
      room['otherUsername'],
      room['matchedUsername'],
      room['displayName'],
      room['name'],
      room['otherUser']?['username'],
      room['targetUser']?['username'],
      room['user']?['username'],
      room['sender']?['username'],
    ];
    for (final candidate in candidates) {
      if (candidate != null) {
        final value = candidate.toString().trim();
        if (value.isNotEmpty) return value;
      }
    }
    return 'Bilinmeyen';
  }

  String? _resolveAvatarUrl(String? avatarUrl) {
    return UrlResolver.resolveImageUrl(avatarUrl);
  }

  String? _resolveMoviePosterUrl(String? posterUrl) {
    return UrlResolver.resolveImageUrl(posterUrl);
  }

  @override
  Future<Result<List<ChatMessageModel>>> getMessages(String roomId) async {
    try {
      final messages = await ApiService.getChatMessages(roomId);
      final chatMessages = messages.map(_parseMessage).toList();
      return Result.success(chatMessages);
    } catch (e) {
      return Result.failure(AppFailure(message: 'Mesajlar alınamadı: $e'));
    }
  }

  ChatMessageModel _parseMessage(Map<String, dynamic> json) {
    // Backend returns: _id, senderId, content, timestamp (unix int), status, isMe
    return ChatMessageModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      text: json['content']?.toString() ?? json['text']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      isMe: json['isMe'] == true,
      timestamp: _parseTimestamp(json['timestamp']),
      status: _parseStatus(json['status']?.toString()),
    );
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    // Unix timestamp (int veya num) — backend integer döner
    if (timestamp is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        timestamp > 9999999999 ? timestamp.toInt() : timestamp.toInt() * 1000,
      );
    }

    // String olarak gelirse: ISO parse dene, başarısız olursa unix dene
    final str = timestamp.toString();
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed;

    final asInt = int.tryParse(str);
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        asInt > 9999999999 ? asInt : asInt * 1000,
      );
    }

    return DateTime.now();
  }

  MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return MessageStatus.pending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  @override
  Future<Result<ChatMessageModel>> sendMessage(
      String roomId, String text) async {
    // WebSocket üzerinden gönderilecek - şimdilik placeholder
    // Gerçek implementasyon ChatSocketService kullanacak
    return Result.success(ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      senderId: 'me',
      isMe: true,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
    ));
  }

  @override
  Future<Result<void>> hideChat(String roomId) async {
    try {
      await ApiService.hideChatRoom(roomId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppFailure(message: 'Sohbet gizlenemedi: $e'));
    }
  }

  @override
  Future<Result<FriendStatus>> getFriendStatus(String targetUserId) async {
    try {
      final status = await ApiService.getFriendStatus(targetUserId);
      return Result.success(_parseFriendStatus(status));
    } catch (e) {
      return Result.failure(
          AppFailure(message: 'Arkadaşlık durumu alınamadı: $e'));
    }
  }

  FriendStatus _parseFriendStatus(String status) {
    switch (status) {
      case 'pending_sent':
        return FriendStatus.pendingSent;
      case 'pending_received':
        return FriendStatus.pendingReceived;
      case 'friends':
        return FriendStatus.friends;
      default:
        return FriendStatus.none;
    }
  }

  @override
  Future<Result<void>> sendFriendRequest(String targetUserId) async {
    try {
      final result = await ApiService.sendFriendRequest(targetUserId);
      if (result != null && result['error'] != null) {
        return Result.failure(
            AppFailure(message: result['error']?.toString() ?? 'Hata'));
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
          AppFailure(message: 'Arkadaşlık isteği gönderilemedi: $e'));
    }
  }

  @override
  Future<Result<void>> removeFriend(String targetUserId) async {
    try {
      await ApiService.removeFriend(targetUserId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
          AppFailure(message: 'Arkadaşlık kaldırılamadı: $e'));
    }
  }

  @override
  Future<Result<void>> unmatchUser(String targetUserId) async {
    try {
      await ApiService.unmatchUser(targetUserId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
          AppFailure(message: 'Eşleşme sonlandırılamadı: $e'));
    }
  }

  @override
  Future<Result<void>> blockUser(String targetUserId) async {
    try {
      await ApiService.blockUser(targetUserId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppFailure(message: 'Kullanıcı engellenemedi: $e'));
    }
  }
}
