class Verse {
  const Verse({
    required this.bookCode,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  final String bookCode;
  final int chapter;

  /// 0 means an unnumbered psalm title.
  final int verse;
  final String text;
}
