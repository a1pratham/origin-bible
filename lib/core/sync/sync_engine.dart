import 'sync_remote.dart';
import 'sync_store.dart';

/// The device database belongs to a different account than the one that is
/// signed in. Nothing is synced until the user removes the local data.
class SyncOwnerMismatch implements Exception {
  const SyncOwnerMismatch();
}

class SyncRunResult {
  const SyncRunResult({
    required this.requests,
    required this.pushed,
    required this.pulled,
    required this.changedLocal,
    required this.hasMore,
  });

  /// Network requests made (counted against the daily device budget).
  final int requests;
  final int pushed;
  final int pulled;
  final bool changedLocal;

  /// More data is waiting; another run should follow soon.
  final bool hasMore;
}

/// One sync pass: pull, merge, then push.
///
/// Pull comes first so a note edited on two devices can be merged locally
/// before anything is uploaded. Every loop is bounded, so a bug or a huge
/// backlog can never produce an endless stream of requests.
class SyncEngine {
  SyncEngine({
    required this.store,
    required this.remote,
    this.pushBatch = 100,
    this.pullBatch = 200,
    this.maxBatchesPerRun = 5,
  });

  final SyncStore store;
  final SyncRemote remote;
  final int pushBatch;
  final int pullBatch;
  final int maxBatchesPerRun;

  Future<SyncRunResult> run({required String userId}) async {
    final owner = await store.getState(kSyncOwnerKey);
    if (owner != null && owner != userId) throw const SyncOwnerMismatch();
    if (owner == null) await store.setState(kSyncOwnerKey, userId);

    var requests = 0;
    var pulled = 0;
    var changed = 0;
    var hasMore = false;

    // ---- pull ----
    var cursor = await store.getState(kSyncCursorKey);
    for (var i = 0; i < maxBatchesPerRun; i++) {
      final page = await remote.pull(cursor: cursor, limit: pullBatch);
      requests++;
      if (page.records.isNotEmpty) {
        changed += await store.applyRemote(page.records);
        pulled += page.records.length;
      }
      final next = page.nextCursor ?? cursor;
      final advanced = next != cursor;
      cursor = next;
      if (advanced && cursor != null) {
        await store.setState(kSyncCursorKey, cursor);
      }
      if (page.records.length < pullBatch || !advanced) break;
      if (i == maxBatchesPerRun - 1) hasMore = true;
    }

    // ---- push ----
    var pushed = 0;
    for (var i = 0; i < maxBatchesPerRun; i++) {
      final batch = await store.dirtyRecords(limit: pushBatch);
      if (batch.isEmpty) break;
      await remote.push(userId, batch);
      requests++;
      await store.markPushed(batch);
      pushed += batch.length;
      if (i == maxBatchesPerRun - 1 && await store.dirtyCount() > 0) {
        hasMore = true;
      }
    }

    await store.setState(
      kLastSyncedKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    return SyncRunResult(
      requests: requests,
      pushed: pushed,
      pulled: pulled,
      changedLocal: changed > 0,
      hasMore: hasMore,
    );
  }
}
