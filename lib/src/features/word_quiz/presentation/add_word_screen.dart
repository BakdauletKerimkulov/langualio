import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:langualio/src/core/language/string_hardcoded.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../application/add_word_notifier.dart';
import 'widgets/word_preview_card.dart';

class AddWordScreen extends ConsumerStatefulWidget {
  const AddWordScreen({super.key});

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addWordNotifierProvider);

    ref.listen(addWordNotifierProvider, (prev, next) {
      if (next.saved && !(prev?.saved ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Слово сохранено!'.hardcoded),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Добавить слово'.hardcoded),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WordInputField(
                controller: _controller,
                isLoading: state.isGenerating,
                onGenerate: () {
                  ref
                      .read(addWordNotifierProvider.notifier)
                      .generate(_controller.text);
                },
              ),
              gapH24,
              if (state.isGenerating) ...[
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ] else if (state.preview != null) ...[
                Expanded(
                  child: SingleChildScrollView(
                    child: WordPreviewCard(entry: state.preview!),
                  ),
                ),
                gapH16,
                _SaveButton(
                  isSaving: state.isSaving,
                  onSave: () {
                    ref.read(addWordNotifierProvider.notifier).save();
                  },
                ),
              ] else ...[
                const Spacer(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WordInputField extends StatelessWidget {
  const _WordInputField({
    required this.controller,
    required this.isLoading,
    required this.onGenerate,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isLoading,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onGenerate(),
            decoration: InputDecoration(
              hintText: 'Введите слово на английском'.hardcoded,
              hintStyle: TextStyle(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Sizes.p12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Sizes.p12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Sizes.p12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Sizes.p16,
                vertical: Sizes.p12,
              ),
            ),
          ),
        ),
        gapW12,
        SizedBox(
          height: Sizes.p48,
          child: FilledButton(
            onPressed: isLoading ? null : onGenerate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Sizes.p12),
              ),
            ),
            child: Text('Найти'.hardcoded),
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaving, required this.onSave});

  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSaving ? null : onSave,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: Sizes.p16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.p16),
        ),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      child: isSaving
          ? const SizedBox(
              height: Sizes.p20,
              width: Sizes.p20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text('Сохранить'.hardcoded),
    );
  }
}
