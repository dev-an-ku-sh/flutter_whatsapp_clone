class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final String content;
  final String messageType;
  final String imageUrl;
  final String? replyToId;
  final String? replyToContent;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  final String senderName;
  final String senderAvatar;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.conversationId,
    required this.content,
    this.messageType = 'text',
    this.imageUrl = '',
    this.replyToId,
    this.replyToContent,
    this.status = 'sent',
    required this.createdAt,
    this.readAt,
    this.deliveredAt,
    this.senderName = '',
    this.senderAvatar = '',
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    String senderId = '';
    String senderName = '';
    String senderAvatar = '';
    String receiverId = '';

    if (json['sender'] is Map) {
      senderId = json['sender']['_id'] ?? json['sender']['id'] ?? '';
      senderName = json['sender']['name'] ?? '';
      senderAvatar = json['sender']['avatar'] ?? '';
    } else {
      senderId = json['sender'] ?? '';
    }

    if (json['receiver'] is Map) {
      receiverId = json['receiver']['_id'] ?? json['receiver']['id'] ?? '';
    } else {
      receiverId = json['receiver'] ?? '';
    }

    String? replyToContent;
    String? replyToId;
    if (json['replyTo'] is Map) {
      replyToId = json['replyTo']['_id'] ?? json['replyTo']['id'];
      replyToContent = json['replyTo']['content'];
    }

    return MessageModel(
      id: json['_id'] ?? json['id'] ?? '',
      senderId: senderId,
      receiverId: receiverId,
      conversationId: json['conversationId'] ?? '',
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? 'text',
      imageUrl: json['imageUrl'] ?? '',
      replyToId: replyToId,
      replyToContent: replyToContent,
      status: json['status'] ?? 'sent',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt']) : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'])
          : null,
      senderName: senderName,
      senderAvatar: senderAvatar,
    );
  }

  MessageModel copyWith({
    String? status,
    DateTime? readAt,
    DateTime? deliveredAt,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      conversationId: conversationId,
      content: content,
      messageType: messageType,
      imageUrl: imageUrl,
      replyToId: replyToId,
      replyToContent: replyToContent,
      status: status ?? this.status,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      senderName: senderName,
      senderAvatar: senderAvatar,
    );
  }

  bool get isSent => status == 'sent';
  bool get isDelivered => status == 'delivered';
  bool get isRead => status == 'read';
}
