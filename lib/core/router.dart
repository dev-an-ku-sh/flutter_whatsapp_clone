import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/chat/chat_bloc.dart';
import '../core/di.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    initialLocation: '/splash',
    redirect: (context, state) {
      final authState = authBloc.state;
      final isOnLogin = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (authState is AuthLoading || authState is AuthInitial) {
        return isSplash ? null : '/splash';
      }
      if (authState is AuthAuthenticated) {
        return (isOnLogin || isSplash) ? '/' : null;
      }
      return isOnLogin ? null : '/login';
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final authState = authBloc.state;
          if (authState is AuthAuthenticated) {
            return BlocProvider(
              create: (_) => ChatBloc(
                apiService: sl<ApiService>(),
                socketService: sl<SocketService>(),
                currentUserId: authState.user.id,
              ),
              child: const HomeScreen(),
            );
          }
          return const LoginScreen();
        },
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Converts a Bloc stream into a Listenable for GoRouter refresh
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
