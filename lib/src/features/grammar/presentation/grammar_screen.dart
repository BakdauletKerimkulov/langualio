import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/common_widgets/filter_chip_bar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../application/grammar_provider.dart';
import 'grammar_card.dart';

const _filters = ['All', 'Tenses', 'Modals', 'Conditionals', 'Articles'];

class GrammarScreen extends ConsumerStatefulWidget {
  const GrammarScreen({super.key});

  @override
  ConsumerState<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends ConsumerState<GrammarScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(grammarFilterProvider);
    final filteredAsync = ref.watch(filteredGrammarItemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sticky header
        Container(
          color: AppColors.background.withValues(alpha: 0.9),
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Grammar Rules',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              gapH16,
              // Search
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search rules...',
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.textTertiary),
                ),
              ),
              gapH16,
            ],
          ),
        ),
        // Filter chips
        FilterChipBar(
          labels: _filters,
          selected: activeFilter,
          onSelected: (v) => ref.read(grammarFilterProvider.notifier).select(v),
        ),
        gapH8,
        // Grammar cards
        Expanded(
          child: filteredAsync.when(
            data: (filtered) {
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No grammar items found',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => gapH16,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return GrammarCard(
                    item: item,
                    isExpanded: _expandedId == item.id,
                    onToggle: () {
                      setState(() {
                        _expandedId = _expandedId == item.id ? null : item.id;
                      });
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    e.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  gapH16,
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(grammarItemsNotifierProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
