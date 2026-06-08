import '../../../word_quiz/domain/part_of_speech.dart';
import '../../../word_quiz/domain/word_entry.dart';
import '../../../word_quiz/domain/word_meaning.dart';
import 'word_form_fields.dart';

/// Collects a [WordEntry] from the current form controller state.
WordEntry collectFormEntry({
  required String? wordId,
  required String word,
  required String ipa,
  required String level,
  required String topic,
  required String tags,
  required List<MeaningControllers> meaningControllers,
}) {
  final meanings = meaningControllers.map((mc) {
    return WordMeaning(
      partOfSpeech: PartOfSpeech.values
              .where((e) => e.name == mc.partOfSpeech)
              .firstOrNull ??
          PartOfSpeech.noun,
      translation: mc.translation.text.trim(),
      alternativeTranslations: mc.alternativeTranslations.text.trim().isEmpty
          ? <String>[]
          : mc.alternativeTranslations.text
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
      definitionEn:
          mc.definitionEn.text.trim().isEmpty ? null : mc.definitionEn.text.trim(),
      definitionRu:
          mc.definitionRu.text.trim().isEmpty ? null : mc.definitionRu.text.trim(),
      exampleEn: mc.exampleEn.text.trim(),
      exampleRu: mc.exampleRu.text.trim(),
    );
  }).toList();

  return WordEntry(
    id: wordId ?? '',
    word: word.trim(),
    ipa: ipa.trim().isEmpty ? null : ipa.trim(),
    level: DifficultyLevel.values.where((e) => e.name == level).firstOrNull ??
        DifficultyLevel.a1,
    meanings: meanings,
    topic: topic.trim().isEmpty ? null : topic.trim(),
    tags: tags.trim().isEmpty
        ? <String>[]
        : tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
    createdAt: DateTime.now(),
  );
}

/// Validates that all required fields are filled.
bool validateRequired({
  required String word,
  required List<MeaningControllers> meaningControllers,
}) {
  if (word.trim().isEmpty) return false;
  for (final mc in meaningControllers) {
    if (mc.translation.text.trim().isEmpty) return false;
    if (mc.exampleEn.text.trim().isEmpty) return false;
    if (mc.exampleRu.text.trim().isEmpty) return false;
  }
  return true;
}
