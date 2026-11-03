import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/repositories/repositories.dart';
import '../widgets/common.dart';
import '../features/public/public_page.dart';
import '../features/authentication/auth_page.dart';
import '../features/profile/profile_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/food_scanner/scanner_page.dart';
import '../features/meal_tracking/meals_page.dart';
import '../features/reports/reports_page.dart';
import '../features/chatbot/assistant_page.dart';
import '../features/settings/settings_page.dart';
import '../features/notifications/notifications_page.dart';

String? routeRedirect({
  required String path,
  required bool authenticated,
  required bool onboarded,
  required bool web,
  bool deleting = false,
}) {
  final private = path.startsWith('/app') || path == '/onboarding';
  final authPage = ['/login', '/register', '/forgot-password'].contains(path);
  if (!authenticated && private) return '/login';
  if (authenticated) {
    if (deleting && path != '/app/settings') return '/app/settings';
    if (!deleting && !onboarded && (private || authPage || path == '/')) {
      return path == '/onboarding' ? null : '/onboarding';
    }
    if (onboarded && (path == '/onboarding' || authPage || path == '/')) {
      return '/app';
    }
  }
  if (!web && path == '/' && !authenticated) return '/login';
  return null;
}

class RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (_, next) => refresh.refresh());
  ref.listen(profileProvider, (_, next) => refresh.refresh());
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider),
          profile = ref.read(profileProvider);
      if (session.isLoading ||
          session.hasError ||
          session.value != null && (profile.isLoading || profile.hasError)) {
        return null;
      }
      return routeRedirect(
        path: state.uri.path,
        authenticated: session.value != null,
        onboarded: profile.value?.health != null,
        web: kIsWeb,
        deleting: profile.value?.deleting ?? false,
      );
    },
    errorBuilder: (context, state) => const PublicPage(path: '/404'),
    routes: [
      ...[
        '/',
        '/about',
        '/features',
        '/how-it-works',
        '/download',
        '/privacy',
        '/terms',
        '/unauthorized',
      ].map(
        (path) => GoRoute(
          path: path,
          builder: (context, state) => PublicPage(path: path),
        ),
      ),
      ...['login', 'register', 'forgot-password'].map(
        (mode) => GoRoute(
          path: '/$mode',
          builder: (context, state) =>
              AuthPage(key: ValueKey(mode), mode: mode),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const ProfilePage(onboarding: true),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/app',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/app/scan',
            builder: (context, state) => const ScannerPage(),
          ),
          GoRoute(
            path: '/app/meals',
            builder: (context, state) => const MealsPage(),
          ),
          GoRoute(
            path: '/app/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/app/assistant',
            builder: (context, state) => const AssistantPage(),
          ),
          GoRoute(
            path: '/app/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/app/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/app/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
