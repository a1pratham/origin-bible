import '../../../core/storage/annotation_models.dart';
import '../../bible/data/bible_books.dart';

/// "John 3:16"
String verseTitle(VerseRef ref) {
  final name = bookByCode(ref.bookCode)?.name ?? ref.bookCode;
  return '$name ${ref.chapter}:${ref.verse}';
}
