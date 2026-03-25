import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:chatapp/blocs/auth/auth_bloc.dart';
import 'package:chatapp/services/api_service.dart';
import 'package:chatapp/services/socket_service.dart';
import 'package:chatapp/models/user_model.dart';

import 'auth_bloc_test.mocks.dart';

@GenerateMocks([ApiService, SocketService])
void main() {
  late MockApiService mockApiService;
  late MockSocketService mockSocketService;

  setUp(() {
    mockApiService = MockApiService();
    mockSocketService = MockSocketService();
  });

  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      final bloc = AuthBloc(
        apiService: mockApiService,
        socketService: mockSocketService,
      );
      expect(bloc.state, isA<AuthInitial>());
      bloc.close();
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when AuthCheckRequested and no stored token',
      build: () {
        // No stored token simulated by throwing
        return AuthBloc(
          apiService: mockApiService,
          socketService: mockSocketService,
        );
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthUnauthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure] on login with wrong credentials',
      build: () {
        when(mockApiService.post('/auth/login', any))
            .thenThrow(Exception('Invalid credentials'));
        return AuthBloc(
          apiService: mockApiService,
          socketService: mockSocketService,
        );
      },
      act: (bloc) => bloc.add(
        AuthLoginRequested(email: 'wrong@test.com', password: 'bad'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful login',
      build: () {
        when(mockApiService.post('/auth/login', any)).thenAnswer((_) async => {
          'token': 'test_token_123',
          'user': {
            '_id': 'user1',
            'name': 'Alice',
            'email': 'alice@test.com',
            'avatar': '',
            'about': 'Hey there!',
            'isOnline': true,
            'lastSeen': null,
          },
        });
        when(mockApiService.setToken(any)).thenReturn(null);
        when(mockSocketService.connect(any)).thenReturn(null);
        return AuthBloc(
          apiService: mockApiService,
          socketService: mockSocketService,
        );
      },
      act: (bloc) => bloc.add(
        AuthLoginRequested(email: 'alice@test.com', password: 'password123'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
      verify: (bloc) {
        final state = bloc.state as AuthAuthenticated;
        expect(state.user.name, 'Alice');
        expect(state.user.email, 'alice@test.com');
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthUnauthenticated] on logout',
      build: () {
        when(mockApiService.clearToken()).thenReturn(null);
        when(mockSocketService.disconnect()).thenReturn(null);
        return AuthBloc(
          apiService: mockApiService,
          socketService: mockSocketService,
        );
      },
      // Start from authenticated state by seeding
      seed: () => AuthAuthenticated(
        user: const UserModel(id: 'u1', name: 'Alice', email: 'alice@test.com'),
        token: 'tok',
      ),
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
    );
  });
}
