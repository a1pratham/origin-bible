import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/bible_books.dart';

class BookScreen extends StatelessWidget {
  const BookScreen({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
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
          return FilledButton.tonal(
            style: FilledButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => context.push('/bible/read/${book.code}/$chapter'),
            child: Text('$chapter'),
          );
        },
      ),
    );
  }
}
