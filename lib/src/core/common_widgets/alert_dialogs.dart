import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const kDialogDefaultKey = Key('dialog-default-key');

/// Generic function to show a platform-aware Material or Cupertino dialog
Future<bool?> showAlertDialog({
  required BuildContext context,
  required String title,
  String? content,
  String? cancelActionText,
  String defaultActionText = 'OK',
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: cancelActionText != null,
    builder: (context) {
      // WEB → всегда Material
      if (kIsWeb) {
        return AlertDialog(
          constraints: BoxConstraints(maxWidth: 400.0),
          title: Text(title),
          content: content != null
              ? SingleChildScrollView(child: Text(content))
              : null,
          actions: [
            if (cancelActionText != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelActionText),
              ),
            TextButton(
              key: kDialogDefaultKey,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(defaultActionText),
            ),
          ],
        );
      }

      // iOS / macOS → Cupertino
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: content != null ? Text(content) : null,
          actions: [
            if (cancelActionText != null)
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelActionText),
              ),
            CupertinoDialogAction(
              key: kDialogDefaultKey,
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(defaultActionText),
            ),
          ],
        );
      }

      // Android / Windows / Linux → Material
      return AlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: [
          if (cancelActionText != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelActionText),
            ),
          TextButton(
            key: kDialogDefaultKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(defaultActionText),
          ),
        ],
      );
    },
  );
}

/// Generic function to show a platform-aware Material or Cupertino error dialog
Future<void> showExceptionAlertDialog({
  required BuildContext context,
  required String title,
  required dynamic exception,
}) => showAlertDialog(
  context: context,
  title: title,
  content: exception.toString(),
  defaultActionText: 'OK',
);

Future<void> showNotImplementedAlertDialog({required BuildContext context}) =>
    showAlertDialog(context: context, title: 'not implemented yet');
