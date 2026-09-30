import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_bible/app.dart';
import 'package:origin_bible/core/settings/display_settings.dart';
import 'package:origin_bible/core/theme/app_theme.dart';
import 'package:origin_bible/core/theme/app_typography.dart';

void main() {
  test('effective text scale is clamped to safe bounds', () {
    expect(effectiveTextScale(system: 1, user: 1), 1);
    expect(effectiveTextScale(system: 2, user: 1.5), 2.4);
    expect(effectiveTextScale(system: 0.5, user: 0.85), 0.8);
  });

  test('both themes expose reading styles', () {
    expect(AppTheme.light.extension<ReadingStyles>(), isNotNull);
    expect(AppTheme.dark.extension<ReadingStyles>(), isNotNull);
  });

  testWidgets('theme mode can be changed from Profile', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OriginBibleApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
