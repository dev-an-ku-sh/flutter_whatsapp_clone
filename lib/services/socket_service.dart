import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants.dart';

class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineController = StreamController<Map<String, dynamic>>.broadcast();
  final _readController = StreamController<Map<String, dynamic>>.broadcast();
  final _conversationController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onMessageStatus => _statusController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onUserOnline => _onlineController.stream;
  Stream<Map<String, dynamic>> get onMessagesRead => _readController.stream;
  Stream<Map<String, dynamic>> get onConversationUpdate => _conversationController.stream;

  bool get isConnected => _isConnected;

  void connect(String token) {
    _socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableForceNew()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      if (kDebugMode) print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      if (kDebugMode) print('Socket disconnected');
    });

    _socket!.onConnectError((data) {
      _isConnected = false;
      if (kDebugMode) print('Socket connection error: $data');
    });

    // Listen for events
    _socket!.on('new_message', (data) {
      _messageController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message_sent', (data) {
      _messageController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message_status_update', (data) {
      _statusController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('typing_start', (data) {
      _typingController.add({'isTyping': true, ...Map<String, dynamic>.from(data)});
    });

    _socket!.on('typing_stop', (data) {
      _typingController.add({'isTyping': false, ...Map<String, dynamic>.from(data)});
    });

    _socket!.on('user_online', (data) {
      _onlineController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('messages_read', (data) {
      _readController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('conversation_update', (data) {
      _conversationController.add(Map<String, dynamic>.from(data));
    });
  }

  void sendMessage({
    required String receiverId,
    required String content,
    String messageType = 'text',
    String imageUrl = '',
    String? replyToId,
  }) {
    _socket?.emit('send_message', {
      'receiverId': receiverId,
      'content': content,
      'messageType': messageType,
      'imageUrl': imageUrl,
      'replyToId': replyToId,
    });
  }

  void sendTypingStart(String receiverId) {
    _socket?.emit('typing_start', {'receiverId': receiverId});
  }

  void sendTypingStop(String receiverId) {
    _socket?.emit('typing_stop', {'receiverId': receiverId});
  }

  void markAsRead(String senderId) {
    _socket?.emit('mark_read', {'senderId': senderId});
  }

  void sendGroupMessage({
    required String groupId,
    required String content,
    String messageType = 'text',
    String imageUrl = '',
  }) {
    _socket?.emit('send_group_message', {
      'groupId': groupId,
      'content': content,
      'messageType': messageType,
      'imageUrl': imageUrl,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
    _typingController.close();
    _onlineController.close();
    _readController.close();
    _conversationController.close();
  }
}
