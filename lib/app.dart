import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/router/app_router.dart';
import 'core/settings/display_settings.dart';
import 'core/storage/user_data.dart';
import 'core/storage/user_data_providers.dart';
import 'core/sync/sync_host.dart';
import 'core/theme/app_theme.dart';
import 'features/bible/application/bible_providers.dart';

class OriginBibleApp extends ConsumerWidget {
  const OriginBibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final userScale = kTextScaleSteps[ref.watch(textScaleIndexProvider)];

    // Save settings in the background whenever one changes.
    void persist() {
      unawaited(
        ref.read(userDataStoreProvider).savePreferences(
              UserPreferences(
                themeMode: ref.read(themeModeProvider),
                textScaleIndex: ref.read(textScaleIndexProvider),
                translationId: ref.read(selectedTranslationProvider),
              ),
            ),
      );
    }

    ref
      ..listen(themeModeProvider, (_, __) => persist())
      ..listen(textScaleIndexProvider, (_, __) => persist())
      ..listen(selectedTranslationProvider, (_, __) => persist())
      // Opening a password-reset link leads to the "new password" screen.
      ..listen(passwordRecoveryProvider, (_, next) {
        if (next.hasValue) {
          ref.read(appRouterProvider).go('/profile/new-password');
        }
      });

    return MaterialApp.router(
      title: 'Origin Bible',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = effectiveTextScale(
          system: media.textScaler.scale(1),
          user: userScale,
        );
        return SyncHost(
          child: MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(scale)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
