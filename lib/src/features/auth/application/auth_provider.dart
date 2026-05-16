import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/logger.dart';
import '../domain/app_user.dart';

part 'auth_provider.g.dart';

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  final AppUser? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    final client = ref.watch(supabaseClientProvider);

    // Listen for auth changes
    client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        state = state.copyWith(user: _mapUser(user));
      } else {
        state = state.copyWith(clearUser: true);
      }
    });

    // Check current session
    final session = client.auth.currentSession;
    if (session != null) {
      return AuthState(user: _mapUser(session.user));
    }
    return const AuthState();
  }

  SupabaseClient get _client => ref.read(supabaseClientProvider);

  AppUser _mapUser(User user) {
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['name'] as String?,
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
    } on AuthException catch (e) {
      log('Sign up error: ${e.message}', name: 'Auth');
      state = state.copyWith(
        isLoading: false,
        error: _mapAuthError(e),
      );
      return;
    } catch (e) {
      log('Sign up error: $e', name: 'Auth');
      state = state.copyWith(
        isLoading: false,
        error: 'Не удалось создать аккаунт. Попробуй ещё раз.',
      );
      return;
    }

    // If email confirmation is enabled, session won't be set yet
    final session = _client.auth.currentSession;
    if (session == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Аккаунт создан! Проверь почту для подтверждения.',
      );
      return;
    }

    state = state.copyWith(isLoading: false);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      log('Sign in error: ${e.message}', name: 'Auth');
      state = state.copyWith(
        isLoading: false,
        error: _mapAuthError(e),
      );
      return;
    } catch (e) {
      log('Sign in error: $e', name: 'Auth');
      state = state.copyWith(
        isLoading: false,
        error: 'Не удалось войти. Проверь интернет.',
      );
      return;
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Неверный email или пароль.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email не подтверждён. Проверь почту.';
    }
    if (msg.contains('email already registered') || msg.contains('already registered')) {
      return 'Этот email уже зарегистрирован.';
    }
    if (msg.contains('password') && (msg.contains('short') || msg.contains('least'))) {
      return 'Пароль должен быть не менее 6 символов.';
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return 'Проверь формат email.';
    }
    return 'Ошибка: ${e.message}';
  }
}
