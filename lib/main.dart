import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/sqlite_user_data_store.dart';
import 'core/storage/user_data_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local reads only (no network). The store never throws and gives up after
  // 2 seconds, falling back to defaults, so startup cannot hang.
  final store = SqliteUserDataStore();
  final preferences = await store.loadPreferences();
  final recents = await store.loadRecents();

  runApp(
    ProviderScope(
      overrides: [
        userDataStoreProvider.overrideWithValue(store),
        initialPreferencesProvider.overrideWithValue(preferences),
        initialRecentsProvider.overrideWithValue(recents),
      ],
      child: const OriginBibleApp(),
    ),
  );
}
