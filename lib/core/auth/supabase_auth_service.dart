import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'auth_constants.dart';
import 'auth_service.dart';

/// The only file (with supabase_sync_remote.dart and main.dart) that knows
/// about Supabase.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  static AuthUser? _map(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges =>
      _client.auth.onAuthStateChange.map((s) => _map(s.session?.user));

  @override
  Stream<void> get passwordRecoveryEvents => _client.auth.onAuthStateChange
      .where((s) => s.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (_) {
      throw const AuthFailure(
        'Could not reach the server. Check your internet connection.',
      );
    }
  }

  @override
  Future<SignUpOutcome> signUpWithEmail(String email, String password) {
    return _guard(() async {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kAuthRedirectUrl,
      );
      // Supabase hides whether an email is registered by returning a user
      // with no identities.
      if (res.user?.identities?.isEmpty ?? false) {
        throw const AuthFailure(
          'An account with this email may already exist. Try signing in.',
        );
      }
      return res.session == null
          ? SignUpOutcome.confirmationRequired
          : SignUpOutcome.signedIn;
    });
  }

  @override
  Future<void> signInWithEmail(String email, String password) {
    return _guard(() async {
      await _client.auth.signInWithPassword(email: email, password: password);
    });
  }

  @override
  Future<void> signInWithGoogle() {
    return _guard(() async {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kAuthRedirectUrl,
      );
    });
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _guard(() async {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: kAuthRedirectUrl,
      );
    });
  }

  @override
  Future<void> updatePassword(String newPassword) {
    return _guard(() async {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    });
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Signing out must always succeed locally, even when offline.
    }
  }

  @override
  Future<void> deleteAccount() {
    return _guard(() async {
      await _client.rpc<void>('delete_my_account');
      await signOut();
    });
  }
}
