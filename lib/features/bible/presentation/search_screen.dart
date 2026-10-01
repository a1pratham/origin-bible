import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/state_views.dart';
import '../application/bible_providers.dart';
import '../data/bible_books.dart';
import '../data/bible_reference.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String input) {
    final text = input.trim();
    if (text.isEmpty) return;

    final parsed = parseReference(text);
    if (parsed != null) {
      final book = bookByCode(parsed.bookCode)!;
      if (parsed.chapter != null) {
        context.push('/bible/read/${book.code}/${parsed.chapter}');
      } else if (book.chapters == 1) {
        context.push('/bible/read/${book.code}/1');
      } else {
        context.push('/bible/book/${book.code}');
      }
      return;
    }
    setState(() => _query = text);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
          decoration: const InputDecoration(
            hintText: 'Search words or a reference (John 3:16)',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => _submit(_controller.text),
          ),
        ],
      ),
      body: query == null
          ? const EmptyState(
              icon: Icons.search,
              title: 'Search the Bible',
              message: 'Type a word, or a reference like Psalm 23.',
            )
          : _Results(query: query),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationId = ref.watch(selectedTranslationProvider);
    return ref.watch(searchResultsProvider((translationId, query))).when(
          loading: () => const LoadingView(label: 'Searching'),
          error: (e, _) => ErrorState(
            title: 'Search unavailable',
            message: 'The Bible data could not be opened on this device.',
            onRetry: () =>
                ref.invalidate(searchResultsProvider((translationId, query))),
          ),
          data: (hits) {
            if (hits.isEmpty) {
              return EmptyState(
                icon: Icons.search_off,
                title: 'No results',
                message: 'Nothing found for "$query".',
              );
            }
            return ListView.separated(
              itemCount: hits.length + (hits.length >= kSearchLimit ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == hits.length) {
                  return const ListTile(
                    title:
                        Text('Showing the first results. Refine your search.'),
                  );
                }
                final v = hits[i];
                final book = bookByCode(v.bookCode)!;
                return ListTile(
                  title: Text('${book.name} ${v.chapter}:${v.verse}'),
                  subtitle: Text(
                    v.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () =>
                      context.push('/bible/read/${book.code}/${v.chapter}'),
                );
              },
            );
          },
        );
  }
}
