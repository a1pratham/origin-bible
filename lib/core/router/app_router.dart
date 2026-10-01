import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/bible/presentation/bible_screen.dart';
import '../../features/bible/presentation/book_screen.dart';
import '../../features/bible/presentation/reader_screen.dart';
import '../../features/bible/presentation/search_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/saved/presentation/saved_screen.dart';
import '../../shared/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/feed',
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
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
