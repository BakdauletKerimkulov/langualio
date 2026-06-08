import 'package:flutter/material.dart';

/// Shows a confirmation dialog for archiving a published word.
/// Returns `true` if confirmed, `false` or `null` if cancelled.
Future<bool?> showArchiveConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Архивировать слово?'),
      content: const Text('Слово будет убрано из квизов. Продолжить?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Архивировать'),
        ),
      ],
    ),
  );
}
