import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/word_entry.dart';

part 'asset_word_repository.g.dart';

class AssetWordRepository {
  static const _assetPath = 'assets/data/b1_words.json';

  /// Loads and deserializes B1 words from the bundled JSON asset.
  Future<List<WordEntry>> loadWords() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final list = jsonDecode(jsonString) as List;
    return list
        .map((item) => WordEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

@Riverpod(keepAlive: true)
Future<List<WordEntry>> assetWords(Ref ref) async {
  final repository = AssetWordRepository();
  return repository.loadWords();
}
