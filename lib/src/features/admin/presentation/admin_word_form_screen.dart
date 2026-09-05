import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../word_quiz/domain/word_entry.dart';
import '../application/admin_word_form_notifier.dart';
import '../data/admin_repository.dart';
import 'widgets/archive_confirm_dialog.dart';
import 'widgets/generate_section.dart';
import 'widgets/save_buttons.dart';
import 'widgets/word_form_collector.dart';
import 'widgets/word_form_fields.dart';

class AdminWordFormScreen extends ConsumerStatefulWidget {
  const AdminWordFormScreen({super.key, this.wordId});

  final String? wordId;

  @override
  ConsumerState<AdminWordFormScreen> createState() =>
      _AdminWordFormScreenState();
}

class _AdminWordFormScreenState extends ConsumerState<AdminWordFormScreen> {
  final _inputController = TextEditingController();
  final _wordController = TextEditingController();
  final _ipaController = TextEditingController();
  final _topicController = TextEditingController();
  final _tagsController = TextEditingController();

  final List<MeaningControllers> _meaningControllers = [];

  String _level = 'a1';
  bool _formVisible = false;
  String _currentStatus = 'draft';
  bool _editDataLoaded = false;

  bool get isEditing => widget.wordId != null;

  @override
  void initState() {
    super.initState();
    // Start with one empty meaning section
    _meaningControllers.add(MeaningControllers());
    if (isEditing) _loadExistingWord();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _wordController.dispose();
    _ipaController.dispose();
    _topicController.dispose();
    _tagsController.dispose();
    for (final mc in _meaningControllers) {
      mc.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingWord() async {
    try {
      final entry = await ref
          .read(adminRepositoryProvider)
          .fetchWordById(widget.wordId!);
      if (!mounted) return;
      _populateFromEntry(entry);
      _currentStatus = entry.status ?? 'draft';
      _editDataLoaded = true;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    }
  }

  void _populateFromEntry(WordEntry entry) {
    _wordController.text = entry.word;
    _ipaController.text = entry.ipa ?? '';
    _topicController.text = entry.topic ?? '';
    _tagsController.text = entry.tags.join(', ');

    setState(() {
      _level = entry.level.name;

      // Dispose existing controllers and replace with entry's meanings
      for (final mc in _meaningControllers) {
        mc.dispose();
      }
      _meaningControllers.clear();

      for (final meaning in entry.meanings) {
        final mc = MeaningControllers();
        mc.partOfSpeech = meaning.partOfSpeech.name;
        mc.translation.text = meaning.translation;
        mc.alternativeTranslations.text = meaning.alternativeTranslations.join(
          ', ',
        );
        mc.definitionEn.text = meaning.definitionEn ?? '';
        mc.definitionRu.text = meaning.definitionRu ?? '';
        mc.exampleEn.text = meaning.exampleEn;
        mc.exampleRu.text = meaning.exampleRu;
        _meaningControllers.add(mc);
      }

      _formVisible = true;
    });
  }

  WordEntry _collectFormEntry() {
    return collectFormEntry(
      wordId: widget.wordId,
      word: _wordController.text,
      ipa: _ipaController.text,
      level: _level,
      topic: _topicController.text,
      tags: _tagsController.text,
      meaningControllers: _meaningControllers,
    );
  }

  Future<void> _onGenerate() async {
    final word = _inputController.text.trim();
    if (word.isEmpty) return;
    FocusScope.of(context).unfocus();
    await ref.read(adminWordFormNotifierProvider.notifier).generate(word);
    if (!mounted) return;
    final entry = ref.read(adminWordFormNotifierProvider).generatedData;
    if (entry != null) _populateFromEntry(entry);
  }

  Future<void> _onSave(String status) async {
    if (!validateRequired(
      word: _wordController.text,
      meaningControllers: _meaningControllers,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните обязательные поля (помечены *)'),
        ),
      );
      return;
    }
    final entry = _collectFormEntry();
    final notifier = ref.read(adminWordFormNotifierProvider.notifier);
    final success = isEditing
        ? await notifier.update(
            wordId: widget.wordId!,
            entry: entry,
            status: status,
          )
        : await notifier.save(entry: entry, status: status);
    if (!mounted) return;
    if (success) {
      final msg = isEditing
          ? 'Слово обновлено'
          : (status == 'published'
                ? 'Слово опубликовано'
                : 'Черновик сохранён');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      context.pop();
    }
  }

  Future<void> _onStatusChange(String newStatus) async {
    if (_currentStatus == 'published' && newStatus == 'archived') {
      final confirmed = await showArchiveConfirmDialog(context);
      if (confirmed != true) return;
    }
    await _onSave(newStatus);
  }

  void _addMeaning() {
    setState(() {
      _meaningControllers.add(MeaningControllers());
    });
  }

  void _removeMeaning(int index) {
    if (_meaningControllers.length <= 1) return;
    setState(() {
      _meaningControllers[index].dispose();
      _meaningControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(adminWordFormNotifierProvider);

    ref.listen(adminWordFormNotifierProvider, (prev, next) {
      if (next.duplicateWarning && prev?.duplicateWarning != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Такое слово уже существует в базе'),
            backgroundColor: AppColors.warning,
            action: SnackBarAction(
              label: 'OK',
              textColor: AppColors.surface,
              onPressed: () => ref
                  .read(adminWordFormNotifierProvider.notifier)
                  .clearDuplicateWarning(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Редактировать слово' : 'Новое слово'),
      ),
      body: isEditing && !_editDataLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(Sizes.p16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isEditing) ...[
                    GenerateSection(
                      controller: _inputController,
                      isGenerating: formState.isGenerating,
                      onGenerate: _onGenerate,
                      onManualEntry: () => setState(() => _formVisible = true),
                    ),
                    gapH16,
                  ],
                  if (formState.error != null) ...[
                    ErrorBanner(
                      message: formState.error!,
                      onRetry: _onGenerate,
                    ),
                    gapH16,
                  ],
                  if (_formVisible) ...[
                    WordFormFields(
                      wordController: _wordController,
                      ipaController: _ipaController,
                      level: _level,
                      topicController: _topicController,
                      tagsController: _tagsController,
                      meaningControllers: _meaningControllers,
                      onLevelChanged: (v) => setState(() => _level = v),
                      onPartOfSpeechChanged: (index, v) {
                        setState(() {
                          _meaningControllers[index].partOfSpeech = v;
                        });
                      },
                      onAddMeaning: _addMeaning,
                      onRemoveMeaning: _removeMeaning,
                    ),
                    gapH24,
                    if (isEditing)
                      EditButtons(
                        isSaving: formState.isSaving,
                        currentStatus: _currentStatus,
                        onSave: () => _onSave(_currentStatus),
                        onStatusChange: _onStatusChange,
                      )
                    else
                      CreateButtons(
                        isSaving: formState.isSaving,
                        onSaveDraft: () => _onSave('draft'),
                        onPublish: () => _onSave('published'),
                      ),
                    gapH32,
                  ],
                ],
              ),
            ),
    );
  }
}
