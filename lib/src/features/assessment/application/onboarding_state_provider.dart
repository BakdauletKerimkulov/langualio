import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/logger.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/assessment_question.dart';

part 'onboarding_state_provider.g.dart';

class OnboardingState {
  const OnboardingState({
    this.isLoading = true,
    this.assessmentCompleted = false,
    this.cefrLevel,
  });

  final bool isLoading;
  final bool assessmentCompleted;
  final CefrLevel? cefrLevel;

  OnboardingState copyWith({
    bool? isLoading,
    bool? assessmentCompleted,
    CefrLevel? cefrLevel,
  }) {
    return OnboardingState(
      isLoading: isLoading ?? this.isLoading,
      assessmentCompleted: assessmentCompleted ?? this.assessmentCompleted,
      cefrLevel: cefrLevel ?? this.cefrLevel,
    );
  }
}

@Riverpod(keepAlive: true)
class OnboardingStateNotifier extends _$OnboardingStateNotifier {
  @override
  OnboardingState build() {
    final authRepo = ref.watch(authRepositoryProvider);

    // Re-fetch profile when auth state changes (login/logout)
    final subscription = authRepo.authStateChanges().listen((data) {
      if (data.session != null) {
        refresh();
      } else {
        state = const OnboardingState(isLoading: false);
      }
    });
    ref.onDispose(subscription.cancel);

    _loadProfile();
    return const OnboardingState();
  }

  Future<void> _loadProfile() async {
    final authRepo = ref.read(authRepositoryProvider);
    if (authRepo.currentUser == null) {
      state = const OnboardingState(isLoading: false);
      return;
    }

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final result = await profileRepo.fetchOnboardingState();

      CefrLevel? cefrLevel;
      if (result.cefrLevel != null) {
        cefrLevel = CefrLevel.values
            .where((l) => l.dbValue == result.cefrLevel)
            .firstOrNull;
      }

      state = OnboardingState(
        isLoading: false,
        assessmentCompleted: result.assessmentCompleted,
        cefrLevel: cefrLevel,
      );
    } catch (e) {
      log('Failed to load onboarding state: $e', name: 'OnboardingState');
      // On error, don't block the user — assume completed
      state = const OnboardingState(
        isLoading: false,
        assessmentCompleted: true,
      );
    }
  }

  /// Called after assessment is completed to update cached state.
  void markCompleted(CefrLevel level) {
    state = state.copyWith(assessmentCompleted: true, cefrLevel: level);
  }

  /// Re-fetch profile from Supabase (e.g. after login).
  Future<void> refresh() async {
    state = const OnboardingState();
    await _loadProfile();
  }
}
