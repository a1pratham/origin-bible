import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_bible/app.dart';
import 'package:origin_bible/core/auth/auth_providers.dart';
import 'package:origin_bible/core/auth/auth_service.dart';
import 'package:origin_bible/core/sync/sync_controller.dart';

import 'support/fakes.dart';

Future<void> _openProfile(WidgetTester tester, {FakeAuth? auth}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (auth != null) authServiceProvider.overrideWithValue(auth),
        syncRemoteProvider.overrideWithValue(FakeRemote()),
      ],
      child: const OriginBibleApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Profile').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without a backend the app explains accounts are unavailable',
      (tester) async {
    await _openProfile(tester);
    expect(find.textContaining('Accounts are not available'), findsOneWidget);
    expect(find.text('Sign in or create account'), findsNothing);
  });

  testWidgets('signing in with email calls the account service',
      (tester) async {
    final auth = FakeAuth();
    await _openProfile(tester, auth: auth);

    await tester.tap(find.text('Sign in or create account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'reader@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'longenough1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    // The sign-in screen closes and the account card shows the user.
    expect(find.text('reader@example.com'), findsOneWidget);
  });

  testWidgets('a short password is rejected before contacting the server',
      (tester) async {
    final auth = FakeAuth();
    await _openProfile(tester, auth: auth);

    await tester.tap(find.text('Sign in or create account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'reader@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 0);
    expect(find.textContaining('at least 8 characters'), findsWidgets);
  });

  testWidgets('signed-in users can sync and sign out', (tester) async {
    final auth =
        FakeAuth(user: const AuthUser(id: 'u1', email: 'me@example.com'));
    await _openProfile(tester, auth: auth);

    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(auth.signedOut, isTrue);
    expect(find.text('Sign in or create account'), findsOneWidget);
  });

  testWidgets('deleting the account asks for confirmation first',
      (tester) async {
    final auth =
        FakeAuth(user: const AuthUser(id: 'u1', email: 'me@example.com'));
    await _openProfile(tester, auth: auth);

    await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(auth.deleted, isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(auth.deleted, isTrue);
  });
}
