import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';

class CreateButtons extends StatelessWidget {
  const CreateButtons({
    super.key,
    required this.isSaving,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final bool isSaving;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : onSaveDraft,
            child: const Text('Сохранить черновик'),
          ),
        ),
        gapW12,
        Expanded(
          child: FilledButton(
            onPressed: isSaving ? null : onPublish,
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Опубликовать'),
          ),
        ),
      ],
    );
  }
}

class EditButtons extends StatelessWidget {
  const EditButtons({
    super.key,
    required this.isSaving,
    required this.currentStatus,
    required this.onSave,
    required this.onStatusChange,
  });

  final bool isSaving;
  final String currentStatus;
  final VoidCallback onSave;
  final ValueChanged<String> onStatusChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: isSaving ? null : onSave,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Обновить'),
        ),
        gapH12,
        _StatusActions(
          currentStatus: currentStatus,
          isSaving: isSaving,
          onStatusChange: onStatusChange,
        ),
      ],
    );
  }
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.currentStatus,
    required this.isSaving,
    required this.onStatusChange,
  });

  final String currentStatus;
  final bool isSaving;
  final ValueChanged<String> onStatusChange;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (currentStatus == 'draft') {
      actions.add(
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : () => onStatusChange('published'),
            child: const Text('Опубликовать'),
          ),
        ),
      );
      actions.add(gapW12);
      actions.add(
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : () => onStatusChange('archived'),
            child: const Text('В архив'),
          ),
        ),
      );
    } else if (currentStatus == 'published') {
      actions.add(
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : () => onStatusChange('draft'),
            child: const Text('В черновик'),
          ),
        ),
      );
      actions.add(gapW12);
      actions.add(
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : () => onStatusChange('archived'),
            child: const Text('В архив'),
          ),
        ),
      );
    } else if (currentStatus == 'archived') {
      actions.add(
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : () => onStatusChange('draft'),
            child: const Text('В черновик'),
          ),
        ),
      );
      actions.add(gapW12);
      actions.add(
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : () => onStatusChange('published'),
            child: const Text('Опубликовать'),
          ),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(children: actions);
  }
}
