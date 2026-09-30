import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/settings/display_settings.dart';
import 'core/theme/app_theme.dart';

class OriginBibleApp extends ConsumerWidget {
  const OriginBibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final userScale = kTextScaleSteps[ref.watch(textScaleIndexProvider)];

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
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
