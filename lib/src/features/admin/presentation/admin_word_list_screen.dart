import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../application/admin_word_list.dart';
import 'widgets/status_filter_bar.dart';
import 'widgets/word_list_tile.dart';

class AdminWordListScreen extends ConsumerWidget {
  const AdminWordListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(adminWordListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Управление словами')),
      body: Column(
        children: [
          gapH8,
          StatusFilterBar(
            activeFilter: listState.activeFilter,
            onFilterChanged: (filter) =>
                ref.read(adminWordListProvider.notifier).setFilter(filter),
          ),
          gapH8,
          Expanded(
            child: _AdminWordListBody(
              listState: listState,
              onRefresh: () =>
                  ref.read(adminWordListProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/admin/create');
          ref.read(adminWordListProvider.notifier).refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AdminWordListBody extends StatelessWidget {
  const _AdminWordListBody({required this.listState, required this.onRefresh});

  final AdminWordListState listState;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (listState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (listState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              listState.error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            gapH16,
            FilledButton(onPressed: onRefresh, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (listState.words.isEmpty) {
      return Center(
        child: Text(
          listState.activeFilter != null
              ? 'Нет слов с таким статусом'
              : 'Нет слов',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: Sizes.p64),
        itemCount: listState.words.length,
        itemBuilder: (context, index) {
          final word = listState.words[index];
          return WordListTile(
            entry: word,
            onTap: () async {
              await context.push('/admin/edit/${word.id}');
              await onRefresh();
            },
          );
        },
      ),
    );
  }
}
