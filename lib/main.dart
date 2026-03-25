import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/theme/theme_cubit.dart';
import 'core/di.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'package:go_router/go_router.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  runApp(const ChatApp());
}

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(
      apiService: sl<ApiService>(),
      socketService: sl<SocketService>(),
    )..add(AuthCheckRequested());
    _router = createRouter(_authBloc);
  }

  @override
  void dispose() {
    _authBloc.close();
    sl<SocketService>().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiService>.value(value: sl<ApiService>()),
        RepositoryProvider<SocketService>.value(value: sl<SocketService>()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()..loadTheme()),
          BlocProvider.value(value: _authBloc),
        ],
        child: BlocBuilder<ThemeCubit, bool>(
          builder: (context, isDarkMode) {
            return MaterialApp.router(
              title: 'ChatApp',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
              routerConfig: _router,
            );
          },
        ),
      ),
    );
  }
}
