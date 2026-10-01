import 'bible_database.dart';
import 'verse.dart';

abstract class BibleRepository {
  Future<List<Verse>> chapter({
    required String translationId,
    required String bookCode,
    required int chapter,
  });

  Future<List<Verse>> search({
    required String translationId,
    required String query,
    int limit = 100,
  });
}

class SqliteBibleRepository implements BibleRepository {
  SqliteBibleRepository(this._database);

  final BibleDatabase _database;

  @override
  Future<List<Verse>> chapter({
    required String translationId,
    required String bookCode,
    required int chapter,
  }) async {
    final db = await _database.open();
    final rows = await db.query(
      'verses',
      columns: ['book_code', 'chapter', 'verse', 'text'],
      where: 'translation_id = ? AND book_code = ? AND chapter = ?',
      whereArgs: [translationId, bookCode, chapter],
      orderBy: 'verse',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Verse>> search({
    required String translationId,
    required String query,
    int limit = 100,
  }) async {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .take(6)
        .toList();
    if (terms.isEmpty) return const [];

    final where = StringBuffer('v.translation_id = ? AND v.verse > 0');
    final args = <Object?>[translationId];
    for (final term in terms) {
      where.write(r" AND v.text LIKE ? ESCAPE '\'");
      args.add('%${_escapeLike(term)}%');
    }
    args.add(limit);

    final db = await _database.open();
    final rows = await db.rawQuery(
      'SELECT v.book_code, v.chapter, v.verse, v.text '
      'FROM verses v JOIN books b ON b.code = v.book_code '
      'WHERE $where '
      'ORDER BY b.ord, v.chapter, v.verse LIMIT ?',
      args,
    );
    return rows.map(_fromRow).toList();
  }

  static String _escapeLike(String term) {
    return term
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  static Verse _fromRow(Map<String, Object?> row) {
    return Verse(
      bookCode: row['book_code']! as String,
      chapter: row['chapter']! as int,
      verse: row['verse']! as int,
      text: row['text']! as String,
    );
  }
}
