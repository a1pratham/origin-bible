import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/settings/display_settings.dart';
import '../../../core/storage/annotation_export.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../account/presentation/account_section.dart';
import '../../annotations/application/annotations_provider.dart';

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
          Text('Account', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const AccountSection(),
          const SizedBox(height: AppSpacing.lg),
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
          const SizedBox(height: AppSpacing.lg),
          Text('Your data', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Copy my data'),
                  subtitle: const Text(
                    'Bookmarks, highlights, notes and progress as text (JSON)',
                  ),
                  onTap: () => _copyData(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove saved data from this device'),
                  onTap: () => _removeLocal(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _copyData(BuildContext context, WidgetRef ref) async {
    final json = exportAnnotationsJson(ref.read(annotationsProvider));
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to the clipboard')),
      );
    }
  }

  Future<void> _removeLocal(BuildContext context, WidgetRef ref) async {
    final signedIn = ref.read(authUserProvider).valueOrNull != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove saved data?'),
        content: Text(
          signedIn
              ? 'Bookmarks, highlights, notes and reading progress will be '
                  'removed from this device. Items backed up to your account '
                  'will download again on the next sync.'
              : 'Bookmarks, highlights, notes and reading progress will be '
                  'permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(syncControllerProvider.notifier).removeLocalData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from this device')),
      );
    }
  }
}
