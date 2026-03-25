import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../core/constants.dart';

// Events
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested({required this.email, required this.password});
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  AuthRegisterRequested({required this.name, required this.email, required this.password});
}

class AuthLogoutRequested extends AuthEvent {}

// States
abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  final String token;
  AuthAuthenticated({required this.user, required this.token});
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService apiService;
  final SocketService socketService;

  AuthBloc({required this.apiService, required this.socketService}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckAuth);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheckAuth(AuthCheckRequested event, Emitter<AuthState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      final userData = prefs.getString(AppConstants.userKey);

      if (token != null && userData != null) {
        apiService.setToken(token);
        final user = UserModel.fromJsonString(userData);
        socketService.connect(token);
        emit(AuthAuthenticated(user: user, token: token));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await apiService.post('/auth/login', {
        'email': event.email,
        'password': event.password,
      });

      final token = response['token'] as String;
      final user = UserModel.fromJson(response['user']);

      await _saveAuth(token, user);
      apiService.setToken(token);
      socketService.connect(token);

      emit(AuthAuthenticated(user: user, token: token));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onRegister(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await apiService.post('/auth/register', {
        'name': event.name,
        'email': event.email,
        'password': event.password,
      });

      final token = response['token'] as String;
      final user = UserModel.fromJson(response['user']);

      await _saveAuth(token, user);
      apiService.setToken(token);
      socketService.connect(token);

      emit(AuthAuthenticated(user: user, token: token));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    socketService.disconnect();
    apiService.clearToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);

    emit(AuthUnauthenticated());
  }

  Future<void> _saveAuth(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userKey, user.toJsonString());
  }
}
