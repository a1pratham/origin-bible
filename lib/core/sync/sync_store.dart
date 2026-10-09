import 'sync_models.dart';

const String kSyncOwnerKey = 'sync_owner';
const String kSyncCursorKey = 'sync_cursor';
const String kLastSyncedKey = 'last_synced_at';
const String kBudgetDayKey = 'budget_day';
const String kBudgetRequestsKey = 'budget_requests';

/// The sync engine's view of the device database.
abstract class SyncStore {
  /// Items with unsent changes (including soft-deleted ones).
  Future<List<SyncRecord>> dirtyRecords({int limit = 100});

  Future<int> dirtyCount();

  /// Clears the unsent flag for items that were uploaded, but only if they
  /// were not edited again in the meantime.
  Future<void> markPushed(List<SyncRecord> pushed);

  /// Merges server items into the device database. Returns how many local
  /// rows changed.
  Future<int> applyRemote(List<SyncRecord> remote);

  Future<String?> getState(String key);
  Future<void> setState(String key, String? value);

  /// Forgets which account owns the local data and where syncing stopped.
  Future<void> resetSyncState();
}

/// Test double and safe default. Uses the same conflict rules as the real
/// store.
class InMemorySyncStore implements SyncStore {
  final Map<String, SyncRecord> records = {};
  final Map<String, String> _state = {};

  void put(SyncRecord record) => records[record.key] = record;

  @override
  Future<List<SyncRecord>> dirtyRecords({int limit = 100}) async =>
      records.values.where((r) => r.dirty).take(limit).toList();

  @override
  Future<int> dirtyCount() async => records.values.where((r) => r.dirty).length;

  @override
  Future<void> markPushed(List<SyncRecord> pushed) async {
    for (final p in pushed) {
      final current = records[p.key];
      if (current != null && current.updatedAt == p.updatedAt) {
        records[p.key] = current.copyWith(dirty: false);
      }
    }
  }

  @override
  Future<int> applyRemote(List<SyncRecord> remote) async {
    var changed = 0;
    final now = DateTime.now().toUtc();
    for (final r in remote) {
      final result = resolveConflict(records[r.key], r, now);
      if (result == null) continue;
      records[r.key] = result;
      changed++;
    }
    return changed;
  }

  @override
  Future<String?> getState(String key) async => _state[key];

  @override
  Future<void> setState(String key, String? value) async {
    if (value == null) {
      _state.remove(key);
    } else {
      _state[key] = value;
    }
  }

  @override
  Future<void> resetSyncState() async {
    _state
      ..remove(kSyncOwnerKey)
      ..remove(kSyncCursorKey)
      ..remove(kLastSyncedKey);
  }
}
