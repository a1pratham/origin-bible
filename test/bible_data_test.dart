import 'package:flutter_test/flutter_test.dart';
import 'package:origin_bible/features/bible/data/bible_books.dart';
import 'package:origin_bible/features/bible/data/bible_reference.dart';

void main() {
  group('catalog', () {
    test('has 66 books with the standard chapter totals', () {
      expect(kBibleBooks.length, 66);
      int total(Testament t) => kBibleBooks
          .where((b) => b.testament == t)
          .fold(0, (sum, b) => sum + b.chapters);
      expect(
        kBibleBooks.where((b) => b.testament == Testament.oldTestament).length,
        39,
      );
      expect(total(Testament.oldTestament), 929);
      expect(total(Testament.newTestament), 260);
    });

    test('book codes are unique', () {
      final codes = kBibleBooks.map((b) => b.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('no search alias points at two different books', () {
      final all = [
        for (final b in kBibleBooks) ...aliasKeysFor(b).toSet(),
      ];
      expect(all.length, all.toSet().length);
    });
  });

  group('parseReference', () {
    test('book, chapter and verse', () {
      final r = parseReference('John 3:16')!;
      expect(r.bookCode, 'JHN');
      expect(r.chapter, 3);
      expect(r.verse, 16);
    });

    test('numbered books with and without spaces', () {
      expect(parseReference('1 John 2')!.bookCode, '1JN');
      expect(parseReference('1john 2:3')!.bookCode, '1JN');
      expect(parseReference('2 cor 5:17')!.bookCode, '2CO');
    });

    test('abbreviations and separators', () {
      expect(parseReference('ps 23')!.bookCode, 'PSA');
      expect(parseReference('Psalm 119:105')!.chapter, 119);
      expect(parseReference('gen. 1.1')!.verse, 1);
      expect(parseReference('Song of Solomon 2:1')!.bookCode, 'SNG');
    });

    test('book name alone', () {
      final r = parseReference('romans')!;
      expect(r.bookCode, 'ROM');
      expect(r.chapter, isNull);
      expect(parseReference('1 john')!.bookCode, '1JN');
    });

    test('invalid input falls back to keyword search', () {
      expect(parseReference('john 99'), isNull);
      expect(parseReference('forgiveness'), isNull);
      expect(parseReference('love one another'), isNull);
      expect(parseReference(''), isNull);
      expect(parseReference('john 3:'), isNull);
    });
  });
}
