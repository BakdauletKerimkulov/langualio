import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../application/admin_word_list_notifier.dart';
import 'widgets/status_filter_bar.dart';
import 'widgets/word_list_tile.dart';

class AdminWordListScreen extends ConsumerWidget {
  const AdminWordListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(adminWordListNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Управление словами')),
      body: Column(
        children: [
          gapH8,
          StatusFilterBar(
            activeFilter: listState.activeFilter,
            onFilterChanged: (filter) => ref
                .read(adminWordListNotifierProvider.notifier)
                .setFilter(filter),
          ),
          gapH8,
          Expanded(child: _buildBody(context, ref, listState)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/admin/create');
          ref.read(adminWordListNotifierProvider.notifier).refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AdminWordListState listState,
  ) {
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
            FilledButton(
              onPressed: () =>
                  ref.read(adminWordListNotifierProvider.notifier).refresh(),
              child: const Text('Повторить'),
            ),
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
      onRefresh: () =>
          ref.read(adminWordListNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: Sizes.p64),
        itemCount: listState.words.length,
        itemBuilder: (context, index) {
          final word = listState.words[index];
          return WordListTile(
            entry: word,
            onTap: () async {
              await context.push('/admin/edit/${word.id}');
              ref.read(adminWordListNotifierProvider.notifier).refresh();
            },
          );
        },
      ),
    );
  }
}
