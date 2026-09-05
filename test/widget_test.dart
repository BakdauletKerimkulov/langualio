import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:langualio/src/app.dart';
import 'package:langualio/src/routing/app_router.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    // Override goRouter to avoid Supabase dependency in tests
    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Test'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [goRouterProvider.overrideWithValue(testRouter)],
        child: const LangualioApp(),
      ),
    );
    expect(find.byType(LangualioApp), findsOneWidget);
  });
}
