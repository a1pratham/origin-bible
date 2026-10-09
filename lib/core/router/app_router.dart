import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/new_password_screen.dart';
import '../../features/account/presentation/sign_in_screen.dart';
import '../../features/bible/presentation/bible_screen.dart';
import '../../features/bible/presentation/book_screen.dart';
import '../../features/bible/presentation/reader_screen.dart';
import '../../features/bible/presentation/search_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/saved/presentation/saved_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../auth/auth_constants.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/feed',
    // Sign-in, email-confirmation and reset links come back as
    // com.originbible.app://login-callback/... The auth library handles the
    // contents; the router just must not show an "unknown page" error.
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.scheme == kAuthScheme || uri.host == 'login-callback') {
        return '/profile';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bible',
                builder: (_, __) => const BibleScreen(),
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (_, __) => const SearchScreen(),
                  ),
                  GoRoute(
                    path: 'book/:code',
                    builder: (_, state) =>
                        BookScreen(code: state.pathParameters['code']!),
                  ),
                  GoRoute(
                    path: 'read/:code/:chapter',
                    builder: (_, state) => ReaderScreen(
                      code: state.pathParameters['code']!,
                      chapter:
                          int.tryParse(state.pathParameters['chapter']!) ?? 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/saved', builder: (_, __) => const SavedScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'sign-in',
                    builder: (_, __) => const SignInScreen(),
                  ),
                  GoRoute(
                    path: 'new-password',
                    builder: (_, __) => const NewPasswordScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
