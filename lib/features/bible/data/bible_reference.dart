import 'bible_books.dart';

class BibleReference {
  const BibleReference(this.bookCode, {this.chapter, this.verse});

  final String bookCode;
  final int? chapter;
  final int? verse;
}

String _key(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// All lookup keys for a book: its name, USFM code and aliases.
List<String> aliasKeysFor(BibleBook book) {
  return [
    for (final a in [book.name, book.code, ...book.aliases]) _key(a),
  ];
}

final Map<String, String> _aliasToCode = {
  for (final b in kBibleBooks)
    for (final k in aliasKeysFor(b)) k: b.code,
};

final RegExp _refPattern = RegExp(
  r'^([1-3]?\s*[a-z][a-z\s.]*?)\s*(?:(\d+)(?:\s*[:.]\s*(\d+))?)?$',
);

/// Parses "John 3:16", "1 cor 13", "ps 23", "gen. 1.1" or just "romans".
/// Returns null when the text is not a valid reference (so callers can fall
/// back to keyword search).
BibleReference? parseReference(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;
  final match = _refPattern.firstMatch(text);
  if (match == null) return null;

  final code = _aliasToCode[_key(match.group(1)!)];
  if (code == null) return null;
  final book = bookByCode(code)!;

  final chapterText = match.group(2);
  if (chapterText == null) return BibleReference(code);

  final chapter = int.tryParse(chapterText);
  if (chapter == null || chapter < 1 || chapter > book.chapters) return null;

  final verseText = match.group(3);
  final verse = verseText == null ? null : int.tryParse(verseText);
  if (verseText != null && (verse == null || verse < 1)) return null;

  return BibleReference(code, chapter: chapter, verse: verse);
}
