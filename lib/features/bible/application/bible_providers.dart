import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_database.dart';
import '../data/bible_repository.dart';
import '../data/verse.dart';

const int kSearchLimit = 100;

final bibleDatabaseProvider = Provider<BibleDatabase>((ref) {
  final db = BibleDatabase();
  ref.onDispose(db.close);
  return db;
});

final bibleRepositoryProvider = Provider<BibleRepository>(
  (ref) => SqliteBibleRepository(ref.watch(bibleDatabaseProvider)),
);

/// Id of the selected translation. Persisted in Phase 3.
final selectedTranslationProvider = StateProvider<String>((ref) => 'web');

/// (translationId, bookCode, chapter)
typedef ChapterKey = (String, String, int);

final chapterVersesProvider =
    FutureProvider.autoDispose.family<List<Verse>, ChapterKey>((ref, key) {
  return ref.watch(bibleRepositoryProvider).chapter(
        translationId: key.$1,
        bookCode: key.$2,
        chapter: key.$3,
      );
});

/// (translationId, query)
final searchResultsProvider =
    FutureProvider.autoDispose.family<List<Verse>, (String, String)>(
  (ref, key) {
    return ref.watch(bibleRepositoryProvider).search(
          translationId: key.$1,
          query: key.$2,
          limit: kSearchLimit,
        );
  },
);
