import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:chatapp/blocs/chat/chat_bloc.dart';
import 'package:chatapp/models/user_model.dart';
import 'package:chatapp/models/message_model.dart';
import 'package:chatapp/services/api_service.dart';
import 'package:chatapp/services/socket_service.dart';

import 'chat_bloc_test.mocks.dart';

@GenerateMocks([ApiService, SocketService])
void main() {
  late MockApiService mockApiService;
  late MockSocketService mockSocketService;

  // Stub all stream getters
  setUp(() {
    mockApiService = MockApiService();
    mockSocketService = MockSocketService();
    when(mockSocketService.onNewMessage)
        .thenAnswer((_) => const Stream.empty());
    when(mockSocketService.onMessageStatus)
        .thenAnswer((_) => const Stream.empty());
    when(mockSocketService.onTyping)
        .thenAnswer((_) => const Stream.empty());
    when(mockSocketService.onUserOnline)
        .thenAnswer((_) => const Stream.empty());
    when(mockSocketService.onMessagesRead)
        .thenAnswer((_) => const Stream.empty());
    when(mockSocketService.onConversationUpdate)
        .thenAnswer((_) => const Stream.empty());
  });

  group('ChatBloc', () {
    test('initial state is empty ChatState', () {
      final bloc = ChatBloc(
        apiService: mockApiService,
        socketService: mockSocketService,
        currentUserId: 'user1',
      );
      expect(bloc.state.conversations, isEmpty);
      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.selectedUser, isNull);
      bloc.close();
    });

    blocTest<ChatBloc, ChatState>(
      'emits conversations after ChatLoadConversations succeeds',
      build: () {
        when(mockApiService.get('/conversations')).thenAnswer((_) async => {
          'conversations': [
            {
              '_id': 'conv1',
              'lastMessage': {
                '_id': 'msg1',
                'sender': {'_id': 'user2', 'name': 'Bob', 'email': 'bob@test.com', 'avatar': '', 'isOnline': false},
                'receiver': {'_id': 'user1', 'name': 'Alice', 'email': 'alice@test.com', 'avatar': '', 'isOnline': true},
                'content': 'Hello!',
                'messageType': 'text',
                'status': 'read',
                'createdAt': DateTime.now().toIso8601String(),
              },
              'unreadCount': 0,
            }
          ],
        });
        return ChatBloc(
          apiService: mockApiService,
          socketService: mockSocketService,
          currentUserId: 'user1',
        );
      },
      act: (bloc) => bloc.add(ChatLoadConversations()),
      expect: () => [
        predicate<ChatState>((s) => s.isLoadingConversations),
        predicate<ChatState>((s) => s.conversations.length == 1),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'emits selectedUser when ChatSelectConversation is added',
      build: () {
        when(mockApiService.get(any)).thenAnswer((_) async => {'messages': []});
        when(mockSocketService.markAsRead(any)).thenReturn(null);
        return ChatBloc(
          apiService: mockApiService,
          socketService: mockSocketService,
          currentUserId: 'user1',
        );
      },
      act: (bloc) => bloc.add(ChatSelectConversation(
        const UserModel(id: 'user2', name: 'Bob', email: 'bob@test.com'),
      )),
      expect: () => [
        predicate<ChatState>((s) => s.selectedUser?.name == 'Bob'),
        predicate<ChatState>((s) => s.isLoadingMessages == true),
        predicate<ChatState>((s) => s.isLoadingMessages == false && s.messages.isEmpty),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'sends message via socketService on ChatSendMessage',
      build: () {
        when(mockSocketService.sendMessage(
          receiverId: anyNamed('receiverId'),
          content: anyNamed('content'),
          messageType: anyNamed('messageType'),
          replyToId: anyNamed('replyToId'),
          imageUrl: anyNamed('imageUrl'),
        )).thenReturn(null);
        return ChatBloc(
          apiService: mockApiService,
          socketService: mockSocketService,
          currentUserId: 'user1',
        );
      },
      seed: () => ChatState(
        selectedUser: const UserModel(id: 'user2', name: 'Bob', email: 'b@b.com'),
      ),
      act: (bloc) => bloc.add(ChatSendMessage(
        receiverId: 'user2', content: 'Hello!',
      )),
      verify: (_) {
        verify(mockSocketService.sendMessage(
          receiverId: 'user2',
          content: 'Hello!',
          messageType: 'text',
          replyToId: null,
          imageUrl: '',
        )).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'clears selected user on ChatClearSelection',
      build: () => ChatBloc(
        apiService: mockApiService,
        socketService: mockSocketService,
        currentUserId: 'user1',
      ),
      seed: () => ChatState(
        selectedUser: const UserModel(id: 'u2', name: 'Bob', email: 'b@b.com'),
        messages: [
          MessageModel(
            id: 'm1', senderId: 'u2', receiverId: 'u1',
            conversationId: 'conv1', content: 'hi',
            createdAt: DateTime.now(),
          ),
        ],
      ),
      act: (bloc) => bloc.add(ChatClearSelection()),
      expect: () => [
        predicate<ChatState>((s) => s.selectedUser == null && s.messages.isEmpty),
      ],
    );
  });
}
