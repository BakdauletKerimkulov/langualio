import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:langualio/src/core/constants/app_sizes.dart';
import 'package:langualio/src/core/language/string_hardcoded.dart';
import 'package:langualio/src/features/auth/data/auth_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Settings screen is upcoming'.hardcoded,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            gapH16,
            Consumer(
              builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () =>
                      ref.read(authRepositoryProvider).signOut(),
                  child: Text('logout'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
