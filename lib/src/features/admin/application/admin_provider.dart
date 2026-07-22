import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

part 'admin_provider.g.dart';

@Riverpod(keepAlive: true)
bool isAdmin(Ref ref) {
  // Watch auth state to re-evaluate when user signs in/out
  ref.watch(authRepositoryProvider);
  final user = Supabase.instance.client.auth.currentUser;
  return user?.appMetadata['role'] == 'admin';
}
