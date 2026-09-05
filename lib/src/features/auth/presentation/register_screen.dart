import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/common_widgets/primary_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../routing/app_router.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;
  String? _nicknameError;

  static final _nicknameRegExp = RegExp(r'^[a-zA-Zа-яА-ЯёЁ0-9]+$');

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateNickname(String value) {
    if (value.isEmpty) return 'Введи никнейм';
    if (value.length > 20) return 'Максимум 20 символов';
    if (!_nicknameRegExp.hasMatch(value)) {
      return 'Только буквы и цифры';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final nicknameError = _validateNickname(nickname);
    if (nicknameError != null) {
      setState(() => _nicknameError = nicknameError);
      return;
    }
    setState(() => _nicknameError = null);

    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password, name: nickname);
      // Navigation handled by GoRouter redirect
    } on AuthException catch (e) {
      setState(() => _error = _mapAuthError(e));
    } catch (e) {
      setState(() => _error = 'Не удалось создать аккаунт. Попробуй ещё раз.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('email already registered') ||
        msg.contains('already registered')) {
      return 'Этот email уже зарегистрирован.';
    }
    if (msg.contains('password') &&
        (msg.contains('short') || msg.contains('least'))) {
      return 'Пароль должен быть не менее 6 символов.';
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return 'Проверь формат email.';
    }
    return 'Ошибка: ${e.message}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              gapH48,
              const Text(
                'Создать аккаунт',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              gapH8,
              Text(
                'Начни изучать английский прямо сейчас',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              gapH48,
              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      gapW8,
                      Expanded(
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                gapH16,
              ],
              // Nickname
              TextField(
                controller: _nicknameController,
                textInputAction: TextInputAction.next,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: 'Никнейм',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: _nicknameError,
                  counterText: '',
                ),
                onChanged: (_) {
                  if (_nicknameError != null) {
                    setState(() => _nicknameError = null);
                  }
                },
              ),
              gapH16,
              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              gapH16,
              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleRegister(),
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              gapH32,
              // Register button
              PrimaryButton(
                text: _isLoading ? 'Создаю...' : 'Создать аккаунт',
                isExpanded: true,
                onPressed: _isLoading ? () {} : _handleRegister,
              ),
              gapH16,
              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Уже есть аккаунт? ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.goNamed(AppRoute.login.name),
                    child: const Text(
                      'Войти',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
