import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/grammar/presentation/grammar_screen.dart';
import '../features/word_quiz/presentation/word_quiz_home_screen.dart';
import '../features/word_quiz/presentation/word_quiz_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import 'scaffold_with_nav.dart';

part 'app_router.g.dart';

enum AppRoute { login, register, home, grammar, practice, profile, chat, quiz }

@riverpod
GoRouter goRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: AppRoute.login.name,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: AppRoute.register.name,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RegisterScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: AppRoute.home.name,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/grammar',
            name: AppRoute.grammar.name,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GrammarScreen(),
            ),
          ),
          GoRoute(
            path: '/practice',
            name: AppRoute.practice.name,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WordQuizHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            name: AppRoute.profile.name,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/chat',
        name: AppRoute.chat.name,
        pageBuilder: (context, state) {
          final prompt = state.extra as String?;
          return MaterialPage(
            child: ChatScreen(initialPrompt: prompt),
          );
        },
      ),
      GoRoute(
        path: '/quiz',
        name: AppRoute.quiz.name,
        pageBuilder: (context, state) => const MaterialPage(
          child: WordQuizScreen(),
        ),
      ),
    ],
  );
}
