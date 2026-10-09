import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  bool _isError = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate({required bool needEmail, required bool needPassword}) {
    final email = _email.text.trim();
    if (needEmail && (!email.contains('@') || email.length < 5)) {
      return 'Enter a valid email address.';
    }
    if (needPassword && _password.text.length < 8) {
      return 'Use a password with at least 8 characters.';
    }
    return null;
  }

  /// Runs [action]; a returned string is shown as information, an
  /// [AuthFailure] as an error.
  Future<void> _run(
    Future<String?> Function() action, {
    bool needEmail = true,
    bool needPassword = false,
  }) async {
    final problem = _validate(needEmail: needEmail, needPassword: needPassword);
    if (problem != null) {
      setState(() {
        _message = problem;
        _isError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final info = await action();
      if (!mounted) return;
      setState(() {
        _message = info;
        _isError = false;
      });
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authServiceProvider);

    // Close this screen as soon as sign-in succeeds.
    ref.listen(authUserProvider, (_, next) {
      if (next.valueOrNull != null && context.canPop()) context.pop();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Back up your notes, highlights and bookmarks and keep them '
                'in sync across devices. Reading never needs an account.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 8 characters',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _message!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _isError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Sign in',
                onPressed: _busy
                    ? null
                    : () => _run(
                          () async {
                            await auth.signInWithEmail(
                              _email.text.trim(),
                              _password.text,
                            );
                            return null;
                          },
                          needPassword: true,
                        ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Create account',
                style: AppButtonStyle.secondary,
                onPressed: _busy
                    ? null
                    : () => _run(
                          () async {
                            final email = _email.text.trim();
                            final outcome = await auth.signUpWithEmail(
                              email,
                              _password.text,
                            );
                            return outcome == SignUpOutcome.confirmationRequired
                                ? 'We sent a confirmation link to $email. Open '
                                    'it on this phone, then sign in.'
                                : null;
                          },
                          needPassword: true,
                        ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Continue with Google',
                icon: Icons.account_circle_outlined,
                style: AppButtonStyle.secondary,
                onPressed: _busy
                    ? null
                    : () => _run(
                          () async {
                            await auth.signInWithGoogle();
                            return 'Finish signing in in your browser, then '
                                'come back to the app.';
                          },
                          needEmail: false,
                        ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Forgot password?',
                style: AppButtonStyle.text,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final email = _email.text.trim();
                          await auth.sendPasswordReset(email);
                          return 'If an account exists for $email, a reset '
                              'link is on its way.';
                        }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
