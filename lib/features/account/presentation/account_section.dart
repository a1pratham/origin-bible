import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';

enum _SignOutChoice { cancel, keepData, removeData }

/// "Account" block on the Profile tab. Everything here is optional: the app
/// works fully without an account.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authServiceProvider);
    final user = ref.watch(authUserProvider).valueOrNull;
    final sync = ref.watch(syncControllerProvider);

    Widget card(List<Widget> children) => AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );

    if (!auth.isConfigured) {
      return card([
        Text(
          'Accounts are not available in this build. Your notes, highlights '
          'and bookmarks are saved on this device.',
          style: theme.textTheme.bodyMedium,
        ),
      ]);
    }

    if (user == null) {
      return card([
        Text(
          'Sign in to back up your notes, highlights and bookmarks and keep '
          'them in sync. Reading never needs an account.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Sign in or create account',
          onPressed: () => context.push('/profile/sign-in'),
        ),
      ]);
    }

    final syncing = sync.status == SyncStatus.syncing;
    return card([
      Text(user.email ?? 'Signed in', style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      Semantics(
        liveRegion: true,
        child: Text(_statusText(sync), style: theme.textTheme.bodyMedium),
      ),
      const SizedBox(height: AppSpacing.md),
      if (sync.status == SyncStatus.needsReset) ...[
        Text(
          'This device holds saved items from a different account. Remove '
          'them from this device to sync this account.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Remove local data and sync',
          onPressed: () async {
            final notifier = ref.read(syncControllerProvider.notifier);
            await notifier.removeLocalData();
            await notifier.syncNow();
          },
        ),
      ] else
        AppButton(
          label: 'Sync now',
          icon: Icons.sync,
          onPressed: syncing
              ? null
              : () => ref.read(syncControllerProvider.notifier).syncNow(),
        ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        children: [
          AppButton(
            label: 'Sign out',
            style: AppButtonStyle.secondary,
            onPressed: () => _signOut(context, ref),
          ),
          AppButton(
            label: 'Delete account',
            style: AppButtonStyle.text,
            onPressed: () => _deleteAccount(context, ref),
          ),
        ],
      ),
    ]);
  }

  static String _statusText(SyncState s) {
    switch (s.status) {
      case SyncStatus.syncing:
        return 'Syncing…';
      case SyncStatus.retrying:
        return 'Can\'t reach the server. Your changes are safe on this '
            'device and will sync later.';
      case SyncStatus.paused:
        return 'Sync is paused for today to save data. It resumes tomorrow.';
      case SyncStatus.needsReset:
        return 'Sync is waiting for you.';
      case SyncStatus.signedOut:
      case SyncStatus.idle:
        final last = s.lastSyncedAt;
        final base = last == null ? 'Not synced yet' : 'Synced ${_ago(last)}';
        return s.pending > 0 ? '$base · ${s.pending} waiting' : base;
    }
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<_SignOutChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your saved items stay in the cloud. You can also remove them from '
          'this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_SignOutChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_SignOutChoice.removeData),
            child: const Text('Sign out and remove data'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_SignOutChoice.keepData),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (choice == null || choice == _SignOutChoice.cancel) return;
    await ref.read(authServiceProvider).signOut();
    if (choice == _SignOutChoice.removeData) {
      await ref.read(syncControllerProvider.notifier).removeLocalData();
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and everything backed up in '
          'the cloud. Items on this device are kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authServiceProvider).deleteAccount();
      await ref.read(syncControllerProvider.notifier).forgetOwner();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted')),
        );
      }
    } on AuthFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}
