import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/assessment_question.dart';
import '../domain/assessment_result.dart';

part 'assessment_repository.g.dart';

class AssessmentRepository {
  const AssessmentRepository({required this.client});

  final SupabaseClient client;

  /// Submits answers to server-side RPC which validates, computes level,
  /// and updates the profile atomically.
  /// Returns the server-determined [AssessmentResult].
  Future<AssessmentResult> completeAssessment({
    required List<AssessmentQuestion> questions,
    required Map<int, String> answers,
  }) async {
    // Build the answers payload: [{question_id, answer}, ...]
    final answersPayload = <Map<String, String>>[];
    for (var i = 0; i < questions.length; i++) {
      final userAnswer = answers[i];
      if (userAnswer != null) {
        answersPayload.add({
          'question_id': questions[i].id,
          'answer': userAnswer,
        });
      }
    }

    final response = await client.rpc(
      'complete_assessment',
      params: {'p_answers': answersPayload},
    );

    final data = response as Map<String, dynamic>;
    final cefrLevelValue = data['cefr_level'] as int;
    final cefrLevel = CefrLevel.values.firstWhere(
      (l) => l.dbValue == cefrLevelValue,
      orElse: () => CefrLevel.a1,
    );

    return AssessmentResult(
      level: cefrLevel,
      correctAnswers: data['correct_answers'] as int,
      totalQuestions: data['total_questions'] as int,
      correctByLevel: const {},
    );
  }
}

@Riverpod(keepAlive: true)
AssessmentRepository assessmentRepository(Ref ref) {
  return AssessmentRepository(client: ref.watch(supabaseClientProvider));
}
