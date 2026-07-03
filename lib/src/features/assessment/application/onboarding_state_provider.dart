import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/logger.dart';
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
    final client = ref.watch(supabaseClientProvider);

    // Re-fetch profile when auth state changes (login/logout)
    final subscription = client.auth.onAuthStateChange.listen((data) {
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
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      state = const OnboardingState(isLoading: false);
      return;
    }

    try {
      final response = await ref.read(supabaseClientProvider)
          .from('profiles')
          .select('assessment_completed, cefr_level')
          .eq('id', user.id)
          .single();

      final completed = response['assessment_completed'] as bool? ?? false;
      final cefrLevelValue = response['cefr_level'] as int?;

      CefrLevel? cefrLevel;
      if (cefrLevelValue != null) {
        cefrLevel = CefrLevel.values.where(
          (l) => l.dbValue == cefrLevelValue,
        ).firstOrNull;
      }

      state = OnboardingState(
        isLoading: false,
        assessmentCompleted: completed,
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
    state = state.copyWith(
      assessmentCompleted: true,
      cefrLevel: level,
    );
  }

  /// Re-fetch profile from Supabase (e.g. after login).
  Future<void> refresh() async {
    state = const OnboardingState();
    await _loadProfile();
  }
}
