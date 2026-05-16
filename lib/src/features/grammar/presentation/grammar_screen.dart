import 'package:flutter/material.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_sizes.dart';
import '../../../shared/common_widgets/filter_chip_bar.dart';
import '../domain/grammar_item.dart';
import 'grammar_card.dart';

const _filters = ['All', 'Tenses', 'Modals', 'Conditionals', 'Articles'];

const _grammarItems = GrammarItem.mockItems;

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  String _activeFilter = 'All';
  int? _expandedId = 2;

  @override
  Widget build(BuildContext context) {
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
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              gapH16,
            ],
          ),
        ),
        // Filter chips
        FilterChipBar(
          labels: _filters,
          selected: _activeFilter,
          onSelected: (v) => setState(() => _activeFilter = v),
        ),
        gapH8,
        // Grammar cards
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
            itemCount: _grammarItems.length,
            separatorBuilder: (_, __) => gapH16,
            itemBuilder: (context, index) {
              final item = _grammarItems[index];
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
          ),
        ),
      ],
    );
  }
}
