import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_data.dart';

/// Defaults to in-memory so tests never touch the device database.
/// main.dart overrides this with the SQLite store.
final userDataStoreProvider = Provider<UserDataStore>(
  (ref) => InMemoryUserDataStore(),
);

/// Values loaded from local storage before the first frame (no flash of
/// default theme). Overridden in main.dart.
final initialPreferencesProvider = Provider<UserPreferences>(
  (ref) => const UserPreferences(),
);

final initialRecentsProvider = Provider<List<RecentChapter>>(
  (ref) => const [],
);
