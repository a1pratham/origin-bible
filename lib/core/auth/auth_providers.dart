import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

/// Defaults to "no backend". main.dart overrides it when Supabase is set up.
final authServiceProvider = Provider<AuthService>(
  (ref) => NoBackendAuthService(),
);

/// The signed-in user (null when signed out). Emits the current user first.
final authUserProvider = StreamProvider<AuthUser?>((ref) async* {
  final auth = ref.watch(authServiceProvider);
  yield auth.currentUser;
  yield* auth.userChanges;
});

/// Fires when the user opens a password-reset link.
final passwordRecoveryProvider = StreamProvider<void>(
  (ref) => ref.watch(authServiceProvider).passwordRecoveryEvents,
);
