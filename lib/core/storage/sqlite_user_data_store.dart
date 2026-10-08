import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'user_data.dart';

/// Writable on-device database for user data. Separate from the read-only
/// Bible database so Bible updates can never touch it. Phase 4 adds
/// bookmarks, highlights and notes through migrations of this same file.
class SqliteUserDataStore implements UserDataStore {
  static const String _fileName = 'origin_user.db';
  static const int _schemaVersion = 1;
  static const Duration _timeout = Duration(seconds: 2);

  Future<Database>? _opening;

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _fileName),
      version: _schemaVersion,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE preferences('
          'key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE recent_chapters('
          'book_code TEXT NOT NULL, chapter INTEGER NOT NULL, '
          'opened_at INTEGER NOT NULL, PRIMARY KEY (book_code, chapter))',
        );
      },
    );
  }

  /// Runs [body]; on any failure (or timeout) returns [fallback] instead of
  /// throwing, so a storage problem can never break the app.
  Future<T> _guard<T>(Future<T> Function(Database db) body, T fallback) async {
    try {
      final db = await (_opening ??= _open());
      return await body(db).timeout(_timeout);
    } catch (e) {
      debugPrint('User data store error: $e');
      _opening = null;
      return fallback;
    }
  }

  @override
  Future<UserPreferences> loadPreferences() {
    return _guard<UserPreferences>(
      (db) async {
        final rows = await db.query('preferences');
        final map = {
          for (final r in rows) r['key']! as String: r['value']! as String,
        };
        return UserPreferences(
          themeMode: ThemeMode.values.asNameMap()[map['theme_mode']] ??
              ThemeMode.system,
          textScaleIndex: int.tryParse(map['text_scale_index'] ?? '') ?? 1,
          translationId: map['translation_id'] ?? 'web',
        );
      },
      const UserPreferences(),
    );
  }

  @override
  Future<void> savePreferences(UserPreferences preferences) {
    return _guard<void>(
      (db) async {
        final batch = db.batch();
        void put(String key, String value) => batch.insert(
              'preferences',
              {'key': key, 'value': value},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
        put('theme_mode', preferences.themeMode.name);
        put('text_scale_index', '${preferences.textScaleIndex}');
        put('translation_id', preferences.translationId);
        await batch.commit(noResult: true);
      },
      null,
    );
  }

  @override
  Future<List<RecentChapter>> loadRecents() {
    return _guard<List<RecentChapter>>(
      (db) async {
        final rows = await db.query(
          'recent_chapters',
          orderBy: 'opened_at DESC',
          limit: kMaxRecentChapters,
        );
        return [
          for (final r in rows)
            RecentChapter(
              bookCode: r['book_code']! as String,
              chapter: r['chapter']! as int,
              openedAt: DateTime.fromMillisecondsSinceEpoch(
                r['opened_at']! as int,
              ),
            ),
        ];
      },
      const [],
    );
  }

  @override
  Future<void> saveRecent(RecentChapter recent) {
    return _guard<void>(
      (db) async {
        await db.insert(
          'recent_chapters',
          {
            'book_code': recent.bookCode,
            'chapter': recent.chapter,
            'opened_at': recent.openedAt.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await db.delete(
          'recent_chapters',
          where: 'rowid NOT IN (SELECT rowid FROM recent_chapters '
              'ORDER BY opened_at DESC LIMIT ?)',
          whereArgs: [kMaxRecentChapters],
        );
      },
      null,
    );
  }
}
