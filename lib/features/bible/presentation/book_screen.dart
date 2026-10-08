import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/annotation_models.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../../annotations/application/annotations_provider.dart';
import '../data/bible_books.dart';

class BookScreen extends ConsumerWidget {
  const BookScreen({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = bookByCode(code);
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Book not found',
        ),
      );
    }
    final read = ref.watch(annotationsProvider.select((a) => a.readChapters));
    return Scaffold(
      appBar: AppBar(title: Text(book.name)),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 72,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
        ),
        itemCount: book.chapters,
        itemBuilder: (context, i) {
          final chapter = i + 1;
          final isRead = read.contains(chapterId(book.code, chapter));
          void open() => context.push('/bible/read/${book.code}/$chapter');
          final style = FilledButton.styleFrom(padding: EdgeInsets.zero);
          // Read chapters are solid and show a check; unread are tonal.
          return isRead
              ? FilledButton(
                  style: style,
                  onPressed: open,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$chapter'),
                      const SizedBox(width: 2),
                      const Icon(Icons.check, size: 14),
                    ],
                  ),
                )
              : FilledButton.tonal(
                  style: style,
                  onPressed: open,
                  child: Text('$chapter'),
                );
        },
      ),
    );
  }
}
