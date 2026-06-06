import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';

class StatusFilterBar extends StatelessWidget {
  const StatusFilterBar({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final String? activeFilter;
  final ValueChanged<String?> onFilterChanged;

  static const _filters = [
    (value: null, label: 'Все'),
    (value: 'published', label: 'Опубликованные'),
    (value: 'draft', label: 'Черновики'),
    (value: 'archived', label: 'Архив'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Sizes.p16),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = activeFilter == filter.value;
          return Padding(
            padding: const EdgeInsets.only(right: Sizes.p8),
            child: FilterChip(
              selected: isSelected,
              label: Text(filter.label),
              onSelected: (_) => onFilterChanged(filter.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}
