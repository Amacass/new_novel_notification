import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/charm_tag_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/recommendation_provider.dart';
import '../providers/stamp_provider.dart';
import '../providers/triage_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/timeline/timeline_screen.dart';
import '../screens/desk/desk_screen.dart';
import '../screens/bookshelf/bookshelf_screen.dart';
import '../screens/novel_detail/novel_detail_screen.dart';
import '../screens/authors/favorite_authors_screen.dart';
import '../screens/notifications/notification_list_screen.dart';
import '../screens/recommend/recommend_screen.dart';
import '../screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isSplash = state.matchedLocation == '/';

      if (isSplash) return null;
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/timeline',
            builder: (context, state) => const TimelineScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const DeskScreen(),
          ),
          GoRoute(
            path: '/bookshelf',
            builder: (context, state) => BookshelfScreen(
              initialTier: int.tryParse(
                state.uri.queryParameters['tier'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/authors',
            builder: (context, state) => const FavoriteAuthorsScreen(),
          ),
          GoRoute(
            path: '/recommend',
            builder: (context, state) => const RecommendScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/novel/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return NovelDetailScreen(novelId: int.parse(id));
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationListScreen(),
      ),
    ],
  );

  // Listen for auth changes and refresh router
  ref.listen(authStateProvider, (prev, next) {
    if (prev?.value?.user.id != next.value?.user.id) {
      ref.invalidate(bookmarkListProvider);
      ref.invalidate(timelineProvider);
      ref.invalidate(notificationListProvider);
      ref.invalidate(triageProvider);
      ref.invalidate(allUserStampsProvider);
      ref.invalidate(userStampCountProvider);
      ref.invalidate(novelStampsProvider);
      ref.invalidate(novelTagsProvider);
      ref.invalidate(userTagCountProvider);
    }
    router.refresh();
  });

  return router;
});

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showRecommend = ref.watch(recommendSettingsProvider).maybeWhen(
          data: (s) => s.viewEnabled,
          orElse: () => false,
        );

    final routes = _buildRoutes(showRecommend);
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _selectedIndex(location, showRecommend);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(routes[i].path),
        destinations: routes.map((r) => r.destination).toList(),
      ),
    );
  }
}

class _NavRoute {
  final String path;
  final NavigationDestination destination;

  const _NavRoute({required this.path, required this.destination});
}

List<_NavRoute> _buildRoutes(bool showRecommend) {
  return [
    const _NavRoute(
      path: '/timeline',
      destination: NavigationDestination(
        icon: Icon(Icons.update_outlined),
        selectedIcon: Icon(Icons.update),
        label: 'タイムライン',
      ),
    ),
    const _NavRoute(
      path: '/home',
      destination: NavigationDestination(
        icon: Icon(Icons.inbox_outlined),
        selectedIcon: Icon(Icons.inbox),
        label: 'デスク',
      ),
    ),
    const _NavRoute(
      path: '/bookshelf',
      destination: NavigationDestination(
        icon: Icon(Icons.library_books_outlined),
        selectedIcon: Icon(Icons.library_books),
        label: '本棚',
      ),
    ),
    if (showRecommend)
      const _NavRoute(
        path: '/recommend',
        destination: NavigationDestination(
          icon: Icon(Icons.recommend_outlined),
          selectedIcon: Icon(Icons.recommend),
          label: 'おすすめ',
        ),
      ),
    const _NavRoute(
      path: '/settings',
      destination: NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: '設定',
      ),
    ),
  ];
}

int _selectedIndex(String location, bool showRecommend) {
  if (location.startsWith('/timeline')) return 0;
  if (location.startsWith('/home')) return 1;
  if (location.startsWith('/bookshelf')) return 2;
  if (showRecommend) {
    if (location.startsWith('/recommend')) return 3;
    if (location.startsWith('/settings')) return 4;
  } else {
    if (location.startsWith('/settings')) return 3;
  }
  return 0;
}
