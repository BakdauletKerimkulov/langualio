import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';

/// Controller group for a single meaning's fields.
class MeaningControllers {
  MeaningControllers();

  final translation = TextEditingController();
  final alternativeTranslations = TextEditingController();
  final definitionEn = TextEditingController();
  final definitionRu = TextEditingController();
  final exampleEn = TextEditingController();
  final exampleRu = TextEditingController();
  String partOfSpeech = 'noun';

  void dispose() {
    translation.dispose();
    alternativeTranslations.dispose();
    definitionEn.dispose();
    definitionRu.dispose();
    exampleEn.dispose();
    exampleRu.dispose();
  }
}

/// Top-level word fields (word, IPA, level, topic, tags) plus per-meaning sections.
class WordFormFields extends StatelessWidget {
  const WordFormFields({
    super.key,
    required this.wordController,
    required this.ipaController,
    required this.level,
    required this.topicController,
    required this.tagsController,
    required this.meaningControllers,
    required this.onLevelChanged,
    required this.onPartOfSpeechChanged,
    required this.onAddMeaning,
    required this.onRemoveMeaning,
  });

  final TextEditingController wordController;
  final TextEditingController ipaController;
  final String level;
  final TextEditingController topicController;
  final TextEditingController tagsController;
  final List<MeaningControllers> meaningControllers;
  final ValueChanged<String> onLevelChanged;
  final void Function(int index, String value) onPartOfSpeechChanged;
  final VoidCallback onAddMeaning;
  final ValueChanged<int> onRemoveMeaning;

  static const _partsOfSpeech = [
    'noun',
    'verb',
    'adjective',
    'adverb',
    'pronoun',
    'preposition',
    'conjunction',
    'interjection',
    'phrase',
  ];

  static const _levels = ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabeledTextField(controller: wordController, label: 'Слово *'),
        gapH12,
        _LabeledTextField(controller: ipaController, label: 'IPA'),
        gapH12,
        _LabeledDropdown(
          label: 'Уровень',
          value: level,
          items: _levels,
          onChanged: onLevelChanged,
        ),
        gapH12,
        _LabeledTextField(controller: topicController, label: 'Тема'),
        gapH12,
        _LabeledTextField(
          controller: tagsController,
          label: 'Теги (через запятую)',
        ),
        gapH24,

        // Meanings header
        Row(
          children: [
            Text(
              'Значения',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAddMeaning,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить'),
            ),
          ],
        ),
        gapH8,

        // Per-meaning expandable sections
        ...List.generate(meaningControllers.length, (index) {
          final mc = meaningControllers[index];
          return _MeaningSection(
            index: index,
            controllers: mc,
            canRemove: meaningControllers.length > 1,
            partsOfSpeech: _partsOfSpeech,
            onPartOfSpeechChanged: (v) => onPartOfSpeechChanged(index, v),
            onRemove: () => onRemoveMeaning(index),
          );
        }),
      ],
    );
  }
}

/// A single expandable meaning section with its own POS, translation, etc.
class _MeaningSection extends StatelessWidget {
  const _MeaningSection({
    required this.index,
    required this.controllers,
    required this.canRemove,
    required this.partsOfSpeech,
    required this.onPartOfSpeechChanged,
    required this.onRemove,
  });

  final int index;
  final MeaningControllers controllers;
  final bool canRemove;
  final List<String> partsOfSpeech;
  final ValueChanged<String> onPartOfSpeechChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Sizes.p12),
      child: Padding(
        padding: const EdgeInsets.all(Sizes.p12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Значение ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Удалить значение',
                  ),
              ],
            ),
            gapH8,
            DropdownButtonFormField<String>(
              initialValue: controllers.partOfSpeech,
              decoration: const InputDecoration(
                labelText: 'Часть речи',
                border: OutlineInputBorder(),
              ),
              items: partsOfSpeech
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onPartOfSpeechChanged(v);
              },
            ),
            gapH12,
            _LabeledTextField(
              controller: controllers.translation,
              label: 'Перевод *',
            ),
            gapH12,
            _LabeledTextField(
              controller: controllers.alternativeTranslations,
              label: 'Альт. переводы (через запятую)',
            ),
            gapH12,
            _LabeledTextField(
              controller: controllers.definitionEn,
              label: 'Определение (EN)',
            ),
            gapH12,
            _LabeledTextField(
              controller: controllers.definitionRu,
              label: 'Определение (RU)',
            ),
            gapH12,
            _LabeledTextField(
              controller: controllers.exampleEn,
              label: 'Пример (EN) *',
            ),
            gapH12,
            _LabeledTextField(
              controller: controllers.exampleRu,
              label: 'Пример (RU) *',
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (item) =>
                DropdownMenuItem(value: item, child: Text(item.toUpperCase())),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
