import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth/auth_providers.dart';
import 'core/auth/supabase_auth_service.dart';
import 'core/config/app_config.dart';
import 'core/storage/sqlite_user_data_store.dart';
import 'core/storage/user_data_providers.dart';
import 'core/sync/supabase_sync_remote.dart';
import 'core/sync/sync_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local reads only. The store never throws and gives up after 2 seconds per
  // read, falling back to defaults, so startup cannot hang.
  final store = SqliteUserDataStore();
  final preferences = await store.loadPreferences();
  final recents = await store.loadRecents();
  final annotations = await store.loadAnnotations();

  // Accounts are optional. Without SUPABASE_URL / SUPABASE_ANON_KEY (or if
  // setup fails or is slow) the app simply runs without accounts.
  SupabaseClient? client;
  final config = AppConfig.fromEnvironment();
  if (config.hasBackend) {
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        anonKey: config.supabaseAnonKey,
      ).timeout(const Duration(seconds: 5));
      client = Supabase.instance.client;
    } catch (e) {
      debugPrint('Supabase unavailable, continuing without accounts: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        userDataStoreProvider.overrideWithValue(store),
        initialPreferencesProvider.overrideWithValue(preferences),
        initialRecentsProvider.overrideWithValue(recents),
        initialAnnotationsProvider.overrideWithValue(annotations),
        syncStoreProvider.overrideWithValue(store),
        if (client != null) ...[
          authServiceProvider.overrideWithValue(SupabaseAuthService(client)),
          syncRemoteProvider.overrideWithValue(SupabaseSyncRemote(client)),
        ],
      ],
      child: const OriginBibleApp(),
    ),
  );
}
