import '../../../../core/base/result.dart';

/// Chat odası modeli
class ChatRoomModel {
  const ChatRoomModel({
    required this.roomId,
    required this.targetUserId,
    required this.username,
    this.avatarSeed,
    this.avatarUrl,
    this.movieTitle,
    this.moviePoster,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  final String roomId;
  final String targetUserId;
  final String username;
  final String? avatarSeed;
  final String? avatarUrl;
  final String? movieTitle;
  final String? moviePoster;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;
}

/// Chat mesajı modeli
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.isMe,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  final String id;
  final String text;
  final String senderId;
  final bool isMe;
  final DateTime timestamp;
  final MessageStatus status;
}

enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

/// Arkadaşlık durumu
enum FriendStatus {
  none,
  pendingSent,
  pendingReceived,
  friends,
}

/// Repository arayüzü
abstract class ChatRepository {
  /// Tüm chat odalarını getir
  Future<Result<List<ChatRoomModel>>> getChatRooms();

  /// Belirli bir odanın mesajlarını getir
  Future<Result<List<ChatMessageModel>>> getMessages(String roomId);

  /// Mesaj gönder
  Future<Result<ChatMessageModel>> sendMessage(String roomId, String text);

  /// Sohbeti gizle
  Future<Result<void>> hideChat(String roomId);

  /// Arkadaşlık durumunu getir
  Future<Result<FriendStatus>> getFriendStatus(String targetUserId);

  /// Arkadaşlık isteği gönder
  Future<Result<void>> sendFriendRequest(String targetUserId);

  /// Arkadaşlıktan çıkar
  Future<Result<void>> removeFriend(String targetUserId);

  /// Eşlemeyi sonlandır (unmatch)
  Future<Result<void>> unmatchUser(String targetUserId);

  /// Kullanıcıyı engelle
  Future<Result<void>> blockUser(String targetUserId);
}
