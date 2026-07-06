import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/assessment_question.dart';

part 'assessment_repository.g.dart';

class AssessmentRepository {
  const AssessmentRepository({required this.client});

  final SupabaseClient client;

  /// Saves assessment result to user profile.
  Future<void> saveResult(CefrLevel level) async {
    final userId = client.auth.currentUser!.id;
    await client.from('profiles').update({
      'cefr_level': level.dbValue,
      'assessment_completed': true,
    }).eq('id', userId);
  }
}

@Riverpod(keepAlive: true)
AssessmentRepository assessmentRepository(Ref ref) {
  return AssessmentRepository(client: ref.watch(supabaseClientProvider));
}
