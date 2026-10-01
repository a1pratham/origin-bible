import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Read-only Bible text database, shipped inside the app as an asset.
///
/// On first launch (or when the bundled version changes) the asset is copied
/// to the device and then opened read-only. No network is ever used. User data
/// (bookmarks, notes) will live in a separate database in Phase 4, so updating
/// the Bible text can never touch it.
class BibleDatabase {
  static const String assetPath = 'assets/bible/web.db';
  static const String versionAssetPath = 'assets/bible/web.version';
  static const String _fileName = 'bible_web.db';

  Future<Database>? _opening;

  Future<Database> open() async {
    try {
      return await (_opening ??= _openInternal());
    } catch (_) {
      _opening = null; // allow a retry
      rethrow;
    }
  }

  Future<Database> _openInternal() async {
    final dir = await getDatabasesPath();
    await Directory(dir).create(recursive: true);
    final path = p.join(dir, _fileName);

    final bundledVersion =
        (await rootBundle.loadString(versionAssetPath)).trim();
    final dbFile = File(path);
    final versionFile = File('$path.version');
    final installedVersion = await versionFile.exists()
        ? (await versionFile.readAsString()).trim()
        : null;

    if (!await dbFile.exists() || installedVersion != bundledVersion) {
      final data = await rootBundle.load(assetPath);
      final tmp = File('$path.tmp');
      await tmp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await tmp.rename(path);
      await versionFile.writeAsString(bundledVersion, flush: true);
    }
    return openDatabase(path, readOnly: true);
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening == null) return;
    try {
      await (await opening).close();
    } catch (_) {
      // Nothing to close.
    }
  }
}
