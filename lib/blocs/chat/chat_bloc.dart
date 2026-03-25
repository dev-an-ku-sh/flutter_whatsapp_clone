import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/message_model.dart';
import '../../models/conversation_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';

// Events
abstract class ChatEvent {}

class ChatLoadConversations extends ChatEvent {}

class ChatSelectConversation extends ChatEvent {
  final UserModel user;
  ChatSelectConversation(this.user);
}

class ChatLoadMessages extends ChatEvent {
  final String userId;
  ChatLoadMessages(this.userId);
}

class ChatSendMessage extends ChatEvent {
  final String receiverId;
  final String content;
  final String messageType;
  final String? replyToId;
  final String? imageUrl;
  ChatSendMessage({
    required this.receiverId,
    required this.content,
    this.messageType = 'text',
    this.replyToId,
    this.imageUrl,
  });
}

class ChatNewMessageReceived extends ChatEvent {
  final MessageModel message;
  ChatNewMessageReceived(this.message);
}

class ChatMessageStatusUpdated extends ChatEvent {
  final String messageId;
  final String status;
  final String conversationId;
  ChatMessageStatusUpdated({
    required this.messageId,
    required this.status,
    required this.conversationId,
  });
}

class ChatMessagesRead extends ChatEvent {
  final String conversationId;
  ChatMessagesRead(this.conversationId);
}

class ChatTypingChanged extends ChatEvent {
  final String userId;
  final bool isTyping;
  final String? name;
  ChatTypingChanged({required this.userId, required this.isTyping, this.name});
}

class ChatUserOnlineChanged extends ChatEvent {
  final String userId;
  final bool isOnline;
  ChatUserOnlineChanged({required this.userId, required this.isOnline});
}

class ChatClearSelection extends ChatEvent {}

class ChatAppFocusChanged extends ChatEvent {
  final bool isFocused;
  ChatAppFocusChanged(this.isFocused);
}

class ChatDeleteMessage extends ChatEvent {
  final String messageId;
  ChatDeleteMessage(this.messageId);
}

// State
class ChatState {
  final List<ConversationModel> conversations;
  final List<MessageModel> messages;
  final UserModel? selectedUser;
  final bool isLoadingConversations;
  final bool isLoadingMessages;
  final Map<String, bool> typingUsers;
  final Map<String, bool> onlineUsers;
  final String? error;

  const ChatState({
    this.conversations = const [],
    this.messages = const [],
    this.selectedUser,
    this.isLoadingConversations = false,
    this.isLoadingMessages = false,
    this.typingUsers = const {},
    this.onlineUsers = const {},
    this.error,
  });

  ChatState copyWith({
    List<ConversationModel>? conversations,
    List<MessageModel>? messages,
    UserModel? selectedUser,
    bool? isLoadingConversations,
    bool? isLoadingMessages,
    Map<String, bool>? typingUsers,
    Map<String, bool>? onlineUsers,
    String? error,
    bool clearSelectedUser = false,
    bool clearError = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      selectedUser: clearSelectedUser ? null : (selectedUser ?? this.selectedUser),
      isLoadingConversations: isLoadingConversations ?? this.isLoadingConversations,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      typingUsers: typingUsers ?? this.typingUsers,
      onlineUsers: onlineUsers ?? this.onlineUsers,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Bloc
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiService apiService;
  final SocketService socketService;
  final String currentUserId;

  bool _isWindowFocused = true;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _onlineSubscription;
  StreamSubscription? _readSubscription;
  StreamSubscription? _conversationSubscription;

  ChatBloc({
    required this.apiService,
    required this.socketService,
    required this.currentUserId,
  }) : super(const ChatState()) {
    on<ChatLoadConversations>(_onLoadConversations);
    on<ChatSelectConversation>(_onSelectConversation);
    on<ChatLoadMessages>(_onLoadMessages);
    on<ChatSendMessage>(_onSendMessage);
    on<ChatNewMessageReceived>(_onNewMessage);
    on<ChatMessageStatusUpdated>(_onMessageStatusUpdated);
    on<ChatMessagesRead>(_onMessagesRead);
    on<ChatTypingChanged>(_onTypingChanged);
    on<ChatUserOnlineChanged>(_onUserOnlineChanged);
    on<ChatClearSelection>(_onClearSelection);
    on<ChatAppFocusChanged>(_onAppFocusChanged);
    on<ChatDeleteMessage>(_onDeleteMessage);

    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _messageSubscription = socketService.onNewMessage.listen((data) {
      final message = MessageModel.fromJson(data);
      add(ChatNewMessageReceived(message));
    });

    _statusSubscription = socketService.onMessageStatus.listen((data) {
      add(ChatMessageStatusUpdated(
        messageId: data['messageId'] ?? '',
        status: data['status'] ?? '',
        conversationId: data['conversationId'] ?? '',
      ));
    });

    _typingSubscription = socketService.onTyping.listen((data) {
      add(ChatTypingChanged(
        userId: data['userId'] ?? '',
        isTyping: data['isTyping'] ?? false,
        name: data['name'],
      ));
    });

    _onlineSubscription = socketService.onUserOnline.listen((data) {
      add(ChatUserOnlineChanged(
        userId: data['userId'] ?? '',
        isOnline: data['isOnline'] ?? false,
      ));
    });

    _readSubscription = socketService.onMessagesRead.listen((data) {
      add(ChatMessagesRead(data['conversationId'] ?? ''));
    });

    _conversationSubscription = socketService.onConversationUpdate.listen((_) {
      add(ChatLoadConversations());
    });
  }

  Future<void> _onLoadConversations(ChatLoadConversations event, Emitter<ChatState> emit) async {
    emit(state.copyWith(isLoadingConversations: true, clearError: true));
    try {
      final response = await apiService.get('/messages/conversations');
      final conversations = (response['conversations'] as List)
          .map((c) => ConversationModel.fromJson(c, currentUserId))
          .toList();
      emit(state.copyWith(conversations: conversations, isLoadingConversations: false));
    } catch (e) {
      emit(state.copyWith(isLoadingConversations: false, error: e.toString()));
    }
  }

  void _onSelectConversation(ChatSelectConversation event, Emitter<ChatState> emit) {
    emit(state.copyWith(selectedUser: event.user, messages: []));
    add(ChatLoadMessages(event.user.id));
    // Only mark as read if the window is focused
    if (_isWindowFocused) {
      socketService.markAsRead(event.user.id);
    }
  }

  Future<void> _onLoadMessages(ChatLoadMessages event, Emitter<ChatState> emit) async {
    emit(state.copyWith(isLoadingMessages: true));
    try {
      final response = await apiService.get('/messages/${event.userId}');
      final messages = (response['messages'] as List)
          .map((m) => MessageModel.fromJson(m))
          .toList();
      emit(state.copyWith(messages: messages, isLoadingMessages: false));
    } catch (e) {
      emit(state.copyWith(isLoadingMessages: false, error: e.toString()));
    }
  }

  void _onSendMessage(ChatSendMessage event, Emitter<ChatState> emit) {
    socketService.sendMessage(
      receiverId: event.receiverId,
      content: event.content,
      messageType: event.messageType,
      replyToId: event.replyToId,
      imageUrl: event.imageUrl ?? '',
    );
  }

  void _onNewMessage(ChatNewMessageReceived event, Emitter<ChatState> emit) {
    final message = event.message;

    // Add to messages if this conversation is open
    if (state.selectedUser != null) {
      final isRelevant = message.senderId == state.selectedUser!.id ||
          message.receiverId == state.selectedUser!.id ||
          message.senderId == currentUserId;
      
      if (isRelevant) {
        // Avoid duplicates
        final exists = state.messages.any((m) => m.id == message.id);
        if (!exists) {
          final updatedMessages = [...state.messages, message];
          emit(state.copyWith(messages: updatedMessages));
        }
        
        // Only mark as read if from the other user AND window is focused
        if (message.senderId == state.selectedUser!.id && _isWindowFocused) {
          socketService.markAsRead(state.selectedUser!.id);
        }
      }
    }

    // Refresh conversations
    add(ChatLoadConversations());
  }

  void _onMessageStatusUpdated(ChatMessageStatusUpdated event, Emitter<ChatState> emit) {
    final updatedMessages = state.messages.map((msg) {
      if (msg.id == event.messageId) {
        return msg.copyWith(status: event.status);
      }
      return msg;
    }).toList();
    emit(state.copyWith(messages: updatedMessages));
  }

  void _onMessagesRead(ChatMessagesRead event, Emitter<ChatState> emit) {
    final updatedMessages = state.messages.map((msg) {
      if (msg.senderId == currentUserId && msg.status != 'read') {
        return msg.copyWith(status: 'read');
      }
      return msg;
    }).toList();
    emit(state.copyWith(messages: updatedMessages));
  }

  void _onTypingChanged(ChatTypingChanged event, Emitter<ChatState> emit) {
    final updated = Map<String, bool>.from(state.typingUsers);
    updated[event.userId] = event.isTyping;
    emit(state.copyWith(typingUsers: updated));
  }

  void _onUserOnlineChanged(ChatUserOnlineChanged event, Emitter<ChatState> emit) {
    final updated = Map<String, bool>.from(state.onlineUsers);
    updated[event.userId] = event.isOnline;
    emit(state.copyWith(onlineUsers: updated));
  }

  void _onClearSelection(ChatClearSelection event, Emitter<ChatState> emit) {
    emit(state.copyWith(clearSelectedUser: true, messages: []));
  }

  void _onAppFocusChanged(ChatAppFocusChanged event, Emitter<ChatState> emit) {
    _isWindowFocused = event.isFocused;
    // When window regains focus, mark messages from the current chat as read
    if (event.isFocused && state.selectedUser != null) {
      socketService.markAsRead(state.selectedUser!.id);
      add(ChatLoadConversations());
    }
  }

  Future<void> _onDeleteMessage(ChatDeleteMessage event, Emitter<ChatState> emit) async {
    try {
      await apiService.delete('/messages/${event.messageId}');
      final updatedMessages = state.messages.where((m) => m.id != event.messageId).toList();
      emit(state.copyWith(messages: updatedMessages));
      add(ChatLoadConversations());
    } catch (e) {
      // Silently fail — message might not be owned by user
    }
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    _typingSubscription?.cancel();
    _onlineSubscription?.cancel();
    _readSubscription?.cancel();
    _conversationSubscription?.cancel();
    return super.close();
  }
}
