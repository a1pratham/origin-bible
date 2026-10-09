import 'sync_models.dart';

class SyncPage {
  const SyncPage(this.records, this.nextCursor);

  final List<SyncRecord> records;

  /// Pass back to pull() to continue after this page.
  final String? nextCursor;
}

abstract class SyncRemote {
  Future<void> push(String userId, List<SyncRecord> records);

  /// Items changed on the server at or after [cursor], oldest first.
  Future<SyncPage> pull({String? cursor, required int limit});
}

class NoBackendSyncRemote implements SyncRemote {
  @override
  Future<void> push(String userId, List<SyncRecord> records) =>
      throw StateError('Sync is not configured.');

  @override
  Future<SyncPage> pull({String? cursor, required int limit}) =>
      throw StateError('Sync is not configured.');
}
