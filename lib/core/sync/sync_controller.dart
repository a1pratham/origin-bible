import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/annotations/application/annotations_provider.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_service.dart';
import '../storage/user_data_providers.dart';
import 'sync_engine.dart';
import 'sync_remote.dart';
import 'sync_store.dart';

// ---- limits (see docs/SYNC_DESIGN.md "Quota safety") ----
const Duration kSyncDebounce = Duration(seconds: 30);
const Duration kMinAutoInterval = Duration(seconds: 60);
const List<Duration> kRetryDelays = [
  Duration(seconds: 30),
  Duration(minutes: 2),
  Duration(minutes: 10),
];

/// Network requests one device may make per UTC day. A runaway-protection
/// cap; global quota tracking arrives with the Phase 5 UsageGuard.
const int kDailyRequestCap = 300;

enum SyncStatus { signedOut, idle, syncing, retrying, needsReset, paused }

@immutable
class SyncState {
  const SyncState({
    this.status = SyncStatus.signedOut,
    this.lastSyncedAt,
    this.pending = 0,
  });

  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final int pending;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    int? pending,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pending: pending ?? this.pending,
    );
  }
}

/// Defaults are inert; main.dart overrides them with the real implementations.
final syncStoreProvider = Provider<SyncStore>((ref) => InMemorySyncStore());
final syncRemoteProvider = Provider<SyncRemote>((ref) => NoBackendSyncRemote());

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    store: ref.watch(syncStoreProvider),
    remote: ref.watch(syncRemoteProvider),
  ),
);

final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);

/// Decides WHEN to sync. Rules: sign-in, app resume, 30 s after a local
/// change and manual "Sync now", never more than once a minute automatically,
/// at most 3 retries with growing delays, and a daily request cap.
class SyncController extends Notifier<SyncState> {
  Timer? _timer;
  int _failures = 0;
  bool _running = false;
  bool _disposed = false;
  DateTime? _lastRun;
  DateTime _suppressUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  SyncState build() {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });

    ref.listen<AsyncValue<AuthUser?>>(authUserProvider, (previous, next) {
      final user = next.valueOrNull;
      final before = previous?.valueOrNull;
      if (user == null) {
        _timer?.cancel();
        _failures = 0;
        state = const SyncState();
      } else if (before?.id != user.id) {
        state = state.copyWith(status: SyncStatus.idle);
        unawaited(requestSync(manual: true));
      }
    });

    ref.listen(annotationsProvider, (_, __) {
      if (DateTime.now().isBefore(_suppressUntil)) return;
      if (ref.read(authServiceProvider).currentUser == null) return;
      _schedule(kSyncDebounce);
    });

    Future<void>.microtask(_loadLastSynced);
    return const SyncState();
  }

  Future<void> _loadLastSynced() async {
    final saved = await ref.read(syncStoreProvider).getState(kLastSyncedKey);
    if (_disposed || saved == null) return;
    final parsed = DateTime.tryParse(saved)?.toLocal();
    if (parsed != null && state.lastSyncedAt == null) {
      state = state.copyWith(lastSyncedAt: parsed);
    }
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(requestSync()));
  }

  /// Manual "Sync now".
  Future<void> syncNow() => requestSync(manual: true);

  Future<void> requestSync({bool manual = false}) async {
    final auth = ref.read(authServiceProvider);
    final user = auth.currentUser;
    if (!auth.isConfigured || user == null || _running) return;
    if (state.status == SyncStatus.needsReset) return;

    if (!manual) {
      final last = _lastRun;
      if (last != null) {
        final wait = kMinAutoInterval - DateTime.now().difference(last);
        if (wait > Duration.zero) {
          _schedule(wait);
          return;
        }
      }
    }
    await _run(user.id);
  }

  Future<void> _run(String userId) async {
    _running = true;
    _timer?.cancel();
    final store = ref.read(syncStoreProvider);
    state = state.copyWith(status: SyncStatus.syncing);
    try {
      if (!await _withinBudget(store)) {
        state = state.copyWith(status: SyncStatus.paused);
        return;
      }
      final result = await ref.read(syncEngineProvider).run(userId: userId);
      await _addRequests(store, result.requests);
      _failures = 0;

      if (result.changedLocal) {
        _suppressUntil = DateTime.now().add(const Duration(seconds: 3));
        await ref.read(annotationsProvider.notifier).reload();
      }
      if (_disposed) return;
      state = SyncState(
        status: SyncStatus.idle,
        lastSyncedAt: DateTime.now(),
        pending: await store.dirtyCount(),
      );
      if (result.hasMore) _schedule(const Duration(seconds: 10));
    } on SyncOwnerMismatch {
      if (!_disposed) state = state.copyWith(status: SyncStatus.needsReset);
    } catch (e) {
      debugPrint('Sync failed: $e');
      await _addRequests(store, 1);
      _failures++;
      if (_disposed) return;
      state = state.copyWith(status: SyncStatus.retrying);
      if (_failures <= kRetryDelays.length) {
        _schedule(kRetryDelays[_failures - 1]);
      }
    } finally {
      _running = false;
      _lastRun = DateTime.now();
    }
  }

  /// Removes bookmarks, highlights, notes and progress from this device (not
  /// from the cloud) and forgets which account owned them.
  Future<void> removeLocalData() async {
    _timer?.cancel();
    await ref.read(userDataStoreProvider).clearAnnotations();
    await ref.read(syncStoreProvider).resetSyncState();
    _suppressUntil = DateTime.now().add(const Duration(seconds: 3));
    await ref.read(annotationsProvider.notifier).reload();
    if (_disposed) return;
    final signedIn = ref.read(authServiceProvider).currentUser != null;
    state =
        SyncState(status: signedIn ? SyncStatus.idle : SyncStatus.signedOut);
  }

  /// After the account is deleted: local data stays on the device but no
  /// longer belongs to anyone.
  Future<void> forgetOwner() => ref.read(syncStoreProvider).resetSyncState();

  // ---- daily budget ----

  static String _utcDay() =>
      DateTime.now().toUtc().toIso8601String().substring(0, 10);

  Future<bool> _withinBudget(SyncStore store) async {
    final today = _utcDay();
    if (await store.getState(kBudgetDayKey) != today) {
      await store.setState(kBudgetDayKey, today);
      await store.setState(kBudgetRequestsKey, '0');
      return true;
    }
    final used =
        int.tryParse(await store.getState(kBudgetRequestsKey) ?? '') ?? 0;
    return used < kDailyRequestCap;
  }

  Future<void> _addRequests(SyncStore store, int count) async {
    final used =
        int.tryParse(await store.getState(kBudgetRequestsKey) ?? '') ?? 0;
    await store.setState(kBudgetRequestsKey, '${used + count}');
  }
}
