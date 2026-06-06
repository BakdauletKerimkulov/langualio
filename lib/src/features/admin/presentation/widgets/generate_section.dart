import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class GenerateSection extends StatelessWidget {
  const GenerateSection({
    super.key,
    required this.controller,
    required this.isGenerating,
    required this.onGenerate,
    required this.onManualEntry,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Введите слово на английском',
            hintText: 'serendipity',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => onGenerate(),
        ),
        gapH12,
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: isGenerating ? null : onGenerate,
                icon: isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(isGenerating ? 'Генерация...' : 'Сгенерировать'),
              ),
            ),
            gapW12,
            OutlinedButton(
              onPressed: onManualEntry,
              child: const Text('Вручную'),
            ),
          ],
        ),
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sizes.p12),
      decoration: BoxDecoration(
        color: AppColors.errorShadow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Sizes.p8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          gapW8,
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
