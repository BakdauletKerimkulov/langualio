import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:langualio/src/core/language/string_hardcoded.dart';

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
        child: Text(
          'Settings screen is upcoming'.hardcoded,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
