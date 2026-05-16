import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/grammar_item.dart';

part 'grammar_provider.g.dart';

@riverpod
class GrammarItemsNotifier extends _$GrammarItemsNotifier {
  @override
  List<GrammarItem> build() => GrammarItem.mockItems;

  void setItems(List<GrammarItem> items) {
    state = items;
  }
}
