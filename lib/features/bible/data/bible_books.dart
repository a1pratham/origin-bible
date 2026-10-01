enum Testament { oldTestament, newTestament }

class BibleBook {
  const BibleBook(
    this.code,
    this.name,
    this.chapters,
    this.testament, [
    this.aliases = const [],
  ]);

  /// USFM book code, e.g. JHN.
  final String code;
  final String name;
  final int chapters;
  final Testament testament;

  /// Extra abbreviations accepted by reference search ("jn", "1 cor").
  final List<String> aliases;
}

const Testament _ot = Testament.oldTestament;
const Testament _nt = Testament.newTestament;

/// Kept in sync with BOOKS in tools/build_bible_db.py.
const List<BibleBook> kBibleBooks = [
  BibleBook('GEN', 'Genesis', 50, _ot, ['ge', 'gn']),
  BibleBook('EXO', 'Exodus', 40, _ot, ['exod']),
  BibleBook('LEV', 'Leviticus', 27, _ot, ['le', 'lv']),
  BibleBook('NUM', 'Numbers', 36, _ot, ['nu', 'nm', 'nb']),
  BibleBook('DEU', 'Deuteronomy', 34, _ot, ['dt', 'deut']),
  BibleBook('JOS', 'Joshua', 24, _ot, ['josh']),
  BibleBook('JDG', 'Judges', 21, _ot, ['judg', 'jg']),
  BibleBook('RUT', 'Ruth', 4, _ot, ['ru']),
  BibleBook('1SA', '1 Samuel', 31, _ot, ['1sam', '1sm']),
  BibleBook('2SA', '2 Samuel', 24, _ot, ['2sam', '2sm']),
  BibleBook('1KI', '1 Kings', 22, _ot, ['1kgs', '1kg']),
  BibleBook('2KI', '2 Kings', 25, _ot, ['2kgs', '2kg']),
  BibleBook('1CH', '1 Chronicles', 29, _ot, ['1chr']),
  BibleBook('2CH', '2 Chronicles', 36, _ot, ['2chr']),
  BibleBook('EZR', 'Ezra', 10, _ot),
  BibleBook('NEH', 'Nehemiah', 13, _ot, ['ne']),
  BibleBook('EST', 'Esther', 10, _ot, ['esth']),
  BibleBook('JOB', 'Job', 42, _ot, ['jb']),
  BibleBook('PSA', 'Psalms', 150, _ot, ['ps', 'psalm', 'pslm']),
  BibleBook('PRO', 'Proverbs', 31, _ot, ['prov', 'pr', 'prv']),
  BibleBook('ECC', 'Ecclesiastes', 12, _ot, ['eccl', 'qoh']),
  BibleBook('SNG', 'Song of Solomon', 8, _ot, ['song', 'songofsongs', 'sos']),
  BibleBook('ISA', 'Isaiah', 66, _ot),
  BibleBook('JER', 'Jeremiah', 52, _ot, ['jr']),
  BibleBook('LAM', 'Lamentations', 5, _ot),
  BibleBook('EZK', 'Ezekiel', 48, _ot, ['ezek', 'eze']),
  BibleBook('DAN', 'Daniel', 12, _ot, ['dn']),
  BibleBook('HOS', 'Hosea', 14, _ot),
  BibleBook('JOL', 'Joel', 3, _ot, ['jl']),
  BibleBook('AMO', 'Amos', 9, _ot),
  BibleBook('OBA', 'Obadiah', 1, _ot, ['obad', 'ob']),
  BibleBook('JON', 'Jonah', 4, _ot, ['jnh']),
  BibleBook('MIC', 'Micah', 7, _ot, ['mc']),
  BibleBook('NAM', 'Nahum', 3, _ot, ['nah', 'na']),
  BibleBook('HAB', 'Habakkuk', 3, _ot, ['hb']),
  BibleBook('ZEP', 'Zephaniah', 3, _ot, ['zeph', 'zp']),
  BibleBook('HAG', 'Haggai', 2, _ot, ['hg']),
  BibleBook('ZEC', 'Zechariah', 14, _ot, ['zech', 'zc']),
  BibleBook('MAL', 'Malachi', 4, _ot, ['ml']),
  BibleBook('MAT', 'Matthew', 28, _nt, ['mt', 'matt']),
  BibleBook('MRK', 'Mark', 16, _nt, ['mk', 'mr']),
  BibleBook('LUK', 'Luke', 24, _nt, ['lk']),
  BibleBook('JHN', 'John', 21, _nt, ['jn', 'joh']),
  BibleBook('ACT', 'Acts', 28, _nt, ['ac']),
  BibleBook('ROM', 'Romans', 16, _nt, ['ro', 'rm']),
  BibleBook('1CO', '1 Corinthians', 16, _nt, ['1cor']),
  BibleBook('2CO', '2 Corinthians', 13, _nt, ['2cor']),
  BibleBook('GAL', 'Galatians', 6, _nt, ['ga']),
  BibleBook('EPH', 'Ephesians', 6, _nt, ['ep']),
  BibleBook('PHP', 'Philippians', 4, _nt, ['phil', 'pp']),
  BibleBook('COL', 'Colossians', 4, _nt),
  BibleBook('1TH', '1 Thessalonians', 5, _nt, ['1thess']),
  BibleBook('2TH', '2 Thessalonians', 3, _nt, ['2thess']),
  BibleBook('1TI', '1 Timothy', 6, _nt, ['1tim']),
  BibleBook('2TI', '2 Timothy', 4, _nt, ['2tim']),
  BibleBook('TIT', 'Titus', 3, _nt),
  BibleBook('PHM', 'Philemon', 1, _nt, ['philem']),
  BibleBook('HEB', 'Hebrews', 13, _nt),
  BibleBook('JAS', 'James', 5, _nt, ['jm']),
  BibleBook('1PE', '1 Peter', 5, _nt, ['1pet']),
  BibleBook('2PE', '2 Peter', 3, _nt, ['2pet']),
  BibleBook('1JN', '1 John', 5, _nt, ['1jhn', '1joh']),
  BibleBook('2JN', '2 John', 1, _nt, ['2jhn', '2joh']),
  BibleBook('3JN', '3 John', 1, _nt, ['3jhn', '3joh']),
  BibleBook('JUD', 'Jude', 1, _nt),
  BibleBook('REV', 'Revelation', 22, _nt, ['rv', 'revelations']),
];

final Map<String, BibleBook> _booksByCode = {
  for (final b in kBibleBooks) b.code: b,
};

BibleBook? bookByCode(String code) => _booksByCode[code.toUpperCase()];
