import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

/// A problem with a friendly, user-facing message.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

enum SignUpOutcome { signedIn, confirmationRequired }

/// Everything the app needs from an account system. The rest of the app never
/// sees Supabase types, so the backend can be swapped and tests use fakes.
abstract class AuthService {
  /// False when the build has no backend configured (accounts unavailable).
  bool get isConfigured;
  AuthUser? get currentUser;
  Stream<AuthUser?> get userChanges;
  Stream<void> get passwordRecoveryEvents;

  Future<SignUpOutcome> signUpWithEmail(String email, String password);
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> signOut();

  /// Deletes the account and all of its cloud data.
  Future<void> deleteAccount();
}

/// Used when SUPABASE_URL / SUPABASE_ANON_KEY are not set. The app works
/// fully offline without it.
class NoBackendAuthService implements AuthService {
  static const String _message = 'Accounts are not available in this build.';

  @override
  bool get isConfigured => false;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get userChanges => const Stream.empty();

  @override
  Stream<void> get passwordRecoveryEvents => const Stream.empty();

  @override
  Future<SignUpOutcome> signUpWithEmail(String email, String password) =>
      throw const AuthFailure(_message);

  @override
  Future<void> signInWithEmail(String email, String password) =>
      throw const AuthFailure(_message);

  @override
  Future<void> signInWithGoogle() => throw const AuthFailure(_message);

  @override
  Future<void> sendPasswordReset(String email) =>
      throw const AuthFailure(_message);

  @override
  Future<void> updatePassword(String newPassword) =>
      throw const AuthFailure(_message);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() => throw const AuthFailure(_message);
}
