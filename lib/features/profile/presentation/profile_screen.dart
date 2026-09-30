import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/display_settings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reading = theme.extension<ReadingStyles>()!;
    final themeMode = ref.watch(themeModeProvider);
    final scaleIndex = ref.watch(textScaleIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Appearance', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).state = s.first,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Text size', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: scaleIndex.toDouble(),
                  min: 0,
                  max: (kTextScaleSteps.length - 1).toDouble(),
                  divisions: kTextScaleSteps.length - 1,
                  label: kTextScaleLabels[scaleIndex],
                  semanticFormatterCallback: (v) => kTextScaleLabels[v.round()],
                  onChanged: (v) => ref
                      .read(textScaleIndexProvider.notifier)
                      .state = v.round(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sample reading text. Adjust the size until it feels '
                  'comfortable.',
                  style: reading.verse,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
