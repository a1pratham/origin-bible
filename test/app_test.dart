import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_bible/app.dart';
import 'package:origin_bible/core/config/app_config.dart';

void main() {
  testWidgets('shows four tabs and switches between them', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OriginBibleApp()));
    await tester.pumpAndSettle();

    for (final label in ['Feed', 'Bible', 'Saved', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('Bible').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Phase 2'), findsOneWidget);
  });

  test('generation is disabled by default (fail-closed)', () {
    final config = AppConfig.fromEnvironment();
    expect(config.generationEnabled, isFalse);
    expect(config.hasBackend, isFalse);
  });
}
