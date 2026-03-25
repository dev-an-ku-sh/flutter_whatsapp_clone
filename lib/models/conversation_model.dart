import '../models/user_model.dart';

class ConversationModel {
  final String conversationId;
  final UserModel otherUser;
  final String lastMessage;
  final String lastMessageType;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String lastMessageSenderId;

  const ConversationModel({
    required this.conversationId,
    required this.otherUser,
    required this.lastMessage,
    this.lastMessageType = 'text',
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.lastMessageSenderId = '',
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json, String currentUserId) {
    final lastMsg = json['lastMessage'] ?? {};
    
    // Determine the other user
    Map<String, dynamic> otherUserData;
    String senderId = '';
    
    if (lastMsg['sender'] is Map) {
      senderId = lastMsg['sender']['_id'] ?? '';
    } else {
      senderId = lastMsg['sender'] ?? '';
    }

    if (senderId == currentUserId) {
      otherUserData = lastMsg['receiver'] is Map ? lastMsg['receiver'] : {};
    } else {
      otherUserData = lastMsg['sender'] is Map ? lastMsg['sender'] : {};
    }

    return ConversationModel(
      conversationId: json['_id'] ?? '',
      otherUser: UserModel.fromJson(otherUserData),
      lastMessage: lastMsg['content'] ?? '',
      lastMessageType: lastMsg['messageType'] ?? 'text',
      lastMessageTime: lastMsg['createdAt'] != null
          ? DateTime.parse(lastMsg['createdAt'])
          : DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
      lastMessageSenderId: senderId,
    );
  }
}
