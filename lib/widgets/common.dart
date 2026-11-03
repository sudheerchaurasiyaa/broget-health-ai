import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import '../core/errors/app_error.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/repositories.dart';
import 'brand_logo.dart';

class AsyncPanel<T> extends StatelessWidget {
  const AsyncPanel({
    super.key,
    required this.value,
    required this.builder,
    required this.retry,
  });
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const LoadingPanel(),
    error: (e, _) => ErrorPanel(error: e, retry: retry),
  );
}

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({super.key, this.message = 'Loading…'});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    label: message,
    liveRegion: true,
    excludeSemantics: true,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 36),
        const SizedBox(height: 12),
        Text(friendlyError(error), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        const Icon(Icons.spa_outlined, size: 40, color: AppTheme.green),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color, this.padding = 24});
  final Widget child;
  final Color? color;
  final double padding;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
  });
  final String title, subtitle;
  final List<Widget> children;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 16,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
                ?action,
              ],
            ),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 28),
            ...children.expand((w) => [w, const SizedBox(height: 20)]),
          ],
        ),
      ),
    ),
  );
}

void notify(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message, {
  String label = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label),
          ),
        ],
      ),
    ) ??
    false;
String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;
String? validEmail(String? value) =>
    value != null &&
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? null
    : 'Enter a valid email';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  static const destinations = [
    ('/app', 'Overview', Icons.space_dashboard_outlined),
    ('/app/scan', 'Scan food', Icons.document_scanner_outlined),
    ('/app/meals', 'Meals', Icons.restaurant_outlined),
    ('/app/reports', 'Reports', Icons.insights_outlined),
    ('/app/assistant', 'Assistant', Icons.auto_awesome_outlined),
    ('/app/profile', 'Profile', Icons.person_outline),
    ('/app/settings', 'Settings', Icons.settings_outlined),
    ('/app/notifications', 'Reminders', Icons.notifications_outlined),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    final tablet = MediaQuery.sizeOf(context).width >= 768;
    final index = destinations.indexWhere((d) => d.$1 == location);
    final nav = destinations
        .map(
          (d) => NavigationRailDestination(icon: Icon(d.$3), label: Text(d.$2)),
        )
        .toList();
    return Scaffold(
      appBar: desktop
          ? null
          : AppBar(
              title: const BrandLogo(width: 150),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.go('/app/settings'),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
      drawer: tablet
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BrandLogo(width: 190),
                      ),
                    ),
                    ...destinations.map(
                      (d) => ListTile(
                        leading: Icon(d.$3),
                        title: Text(d.$2),
                        selected: d.$1 == location,
                        onTap: () {
                          Navigator.pop(context);
                          context.go(d.$1);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: Row(
        children: [
          if (tablet)
            NavigationRail(
              extended: desktop,
              minExtendedWidth: 218,
              selectedIndex: index < 0 ? null : index,
              onDestinationSelected: (i) => context.go(destinations[i].$1),
              leading: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 12,
                ),
                child: desktop
                    ? const BrandLogo(width: 180)
                    : const BrandLogo(width: 40, compact: true),
              ),
              destinations: nav,
            ),
          Expanded(
            child: Column(
              children: [
                const NetworkBanner(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: tablet
          ? null
          : NavigationBar(
              selectedIndex: index >= 0 && index < 5 ? index : 0,
              onDestinationSelected: (i) => context.go(destinations[i].$1),
              destinations: destinations
                  .take(5)
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.$3),
                      label: d.$2 == 'Overview'
                          ? 'Home'
                          : d.$2 == 'Scan food'
                          ? 'Scan'
                          : d.$2,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class NetworkBanner extends StatefulWidget {
  const NetworkBanner({super.key});
  @override
  State<NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends State<NetworkBanner> {
  late final stream = Connectivity().onConnectivityChanged;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ConnectivityResult>>(
    stream: stream,
    builder: (context, snap) =>
        snap.data?.contains(ConnectivityResult.none) == true
        ? MaterialBanner(
            content: const Text(
              'You are offline. Cached records may be available; saving and analysis need a connection.',
            ),
            actions: [
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('Check again'),
              ),
            ],
          )
        : const SizedBox.shrink(),
  );
}

class SessionGate extends ConsumerWidget {
  const SessionGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session.isLoading) {
      return const Scaffold(body: Center(child: LoadingPanel()));
    }
    if (session.hasError) {
      return Scaffold(
        body: ErrorPanel(
          error: session.error!,
          retry: () => ref.invalidate(sessionProvider),
        ),
      );
    }
    final profile = ref.watch(profileProvider);
    if (session.value != null && profile.isLoading) {
      return const Scaffold(body: Center(child: LoadingPanel()));
    }
    if (profile.hasError) {
      return Scaffold(
        body: ErrorPanel(
          error: profile.error!,
          retry: () => ref.invalidate(profileProvider),
        ),
      );
    }
    return child;
  }
}
