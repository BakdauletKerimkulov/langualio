import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:langualio/src/app_bootstrap.dart';
import 'package:langualio/src/app_bootstrap_supabase.dart';
import 'package:langualio/src/features/word_quiz/data/local/asset_word_repository.dart';

import 'src/core/supabase/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initSupabase();

  usePathUrlStrategy();
  final appBootstrap = AppBootstrap();
  final container = await appBootstrap.createSupabaseContainerProvider();

  // Eagerly preload asset words so quiz has zero delay on first open
  container.read(assetWordsProvider);

  final rootWidget = appBootstrap.createRootWidget(container: container);
  runApp(rootWidget);
}
