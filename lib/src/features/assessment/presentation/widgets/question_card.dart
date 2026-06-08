import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/assessment_question.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final AssessmentQuestion question;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (question.context != null) ...[
          _ContextBlock(text: question.context!),
          gapH24,
        ],
        Text(
          question.text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        gapH24,
        if (question.type == QuestionType.multipleChoice)
          _MultipleChoiceOptions(options: question.options, onSelect: onAnswer)
        else
          _FillBlankInput(onSubmit: onAnswer),
      ],
    );
  }
}

class _ContextBlock extends StatelessWidget {
  const _ContextBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sizes.p16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(Sizes.p12),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _MultipleChoiceOptions extends StatelessWidget {
  const _MultipleChoiceOptions({required this.options, required this.onSelect});

  final List<String> options;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in options) ...[
          _OptionButton(text: option, onTap: () => onSelect(option)),
          if (option != options.last) gapH12,
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(Sizes.p16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Sizes.p16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sizes.p20,
            vertical: Sizes.p16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Sizes.p16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FillBlankInput extends StatefulWidget {
  const _FillBlankInput({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_FillBlankInput> createState() => _FillBlankInputState();
}

class _FillBlankInputState extends State<_FillBlankInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSubmit(),
          decoration: InputDecoration(
            hintText: 'Введи ответ',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Sizes.p16),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Sizes.p16),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Sizes.p16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        gapH16,
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: Sizes.p16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Sizes.p20),
              ),
              elevation: 0,
            ),
            child: Text(
              'Ответить',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
      ],
    );
  }
}
