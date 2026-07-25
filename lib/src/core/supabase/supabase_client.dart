import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_client.g.dart';

/// ── Supabase environment config ──
/// Comment/uncomment to switch between dev and prod.

// --- DEV (local Supabase) ---
//const _supabaseUrl = 'http://127.0.0.1:54321';
//const _supabaseAnonKey =
//  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

// --- PROD ---
const _supabaseUrl = 'https://nuysaiqhhyvfqccgxpte.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im51eXNhaXFoaHl2ZnFjY2d4cHRlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc5MTQ0NDQsImV4cCI6MjA5MzQ5MDQ0NH0.qxZyugfloNJD-cb9k2GS8KL1PqjeZfNDeG7WWvKopCE';

Future<void> initSupabase() async {
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
}

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}
