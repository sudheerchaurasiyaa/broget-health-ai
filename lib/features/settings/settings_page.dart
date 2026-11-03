import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/app_error.dart';
import '../../core/config/app_config.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../services/ai/broget_ai_service.dart';
import '../../widgets/common.dart';
import 'personalization_panel.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool busy = false;
  Future<void> run(Future<void> Function() action, String success) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) notify(context, success);
    } catch (e) {
      if (mounted) notify(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setPreferences(AppSettings settings) async => run(() async {
    await ref
        .read(userRepositoryProvider)
        .saveSettings(
          ref.read(sessionProvider).value!.uid,
          AppSettings(
            analytics: !AppConfig.emulators && settings.analytics,
            notifications: settings.notifications,
          ),
        );
    if (AppConfig.emulators) return;
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
      settings.analytics,
    );
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        settings.analytics,
      );
    }
  }, 'Preferences saved');
  Future<void> deleteAccount() async {
    final password = TextEditingController(),
        confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account permanently?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your profile, meals and chat will be permanently removed. Enter your password and type DELETE to confirm.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                decoration: const InputDecoration(labelText: 'Type DELETE'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (confirmation.text == 'DELETE' && password.text.isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    final enteredPassword = password.text;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    password.dispose();
    confirmation.dispose();
    if (accepted != true || !mounted) return;
    await run(() async {
      await ref.read(authRepositoryProvider).reauthenticate(enteredPassword);
      await ref.read(apiProvider).deleteAccount();
      await FirebaseAuth.instance.signOut();
    }, 'Your account and associated data were deleted');
  }

  @override
  Widget build(BuildContext context) => PageBody(
    title: 'Make this space yours.',
    subtitle: 'Account, privacy and the details that matter.',
    children: [
      if (busy) const LoadingPanel(message: 'Saving changes…'),
      Panel(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile & nutrition preferences'),
              subtitle: Text(ref.watch(sessionProvider).value?.email ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/app/profile'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_reset),
              title: const Text('Reset password'),
              onTap: busy
                  ? null
                  : () => run(
                      () => ref
                          .read(authRepositoryProvider)
                          .reset(ref.read(sessionProvider).value!.email!),
                      'Password reset email requested',
                    ),
            ),
          ],
        ),
      ),
      AsyncPanel(
        value: ref.watch(settingsProvider),
        retry: () => ref.invalidate(settingsProvider),
        builder: (settings) => Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy & preferences',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.photo_library_outlined),
                title: Text('Photo storage — coming soon'),
                subtitle: Text(
                  'Food photos are processed for analysis without being saved. Your meal records are saved in your private journal.',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: !AppConfig.emulators && settings.analytics,
                onChanged: busy || AppConfig.emulators
                    ? null
                    : (v) => setPreferences(
                        AppSettings(
                          analytics: v,
                          notifications: settings.notifications,
                        ),
                      ),
                title: const Text('Share optional usage & crash diagnostics'),
                subtitle: const Text(
                  AppConfig.emulators
                      ? 'Diagnostics are disabled in the local emulator environment.'
                      : 'No meal names, health measurements or chat text are added to analytics.',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.notifications,
                onChanged: busy
                    ? null
                    : (v) => setPreferences(
                        AppSettings(
                          analytics: settings.analytics,
                          notifications: v,
                        ),
                      ),
                title: const Text('Allow personalized reminders'),
                subtitle: const Text(
                  'Allow private inbox reminders based on the routine you choose below. FCM push delivery is not connected yet.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Clear chat history'),
                onTap: busy
                    ? null
                    : () async {
                        if (await confirmAction(
                          context,
                          'Clear stored chat?',
                          'All stored assistant conversations will be removed.',
                          label: 'Clear chat',
                        )) {
                          run(
                            () => ref.read(apiProvider).clearChat(),
                            'Chat history cleared',
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ),
      const PersonalizationPanel(),
      Panel(
        child: Column(
          children: [
            ...[
              (
                Icons.notifications_outlined,
                'Reminder inbox',
                '/app/notifications',
              ),
              (Icons.shield_outlined, 'Privacy policy', '/privacy'),
              (Icons.description_outlined, 'Terms of service', '/terms'),
              (Icons.info_outline, 'About Broget AI', '/about'),
              (Icons.android, 'Android application', '/download'),
            ].map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.$1),
                title: Text(item.$2),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => context.push(item.$3),
              ),
            ),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, s) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Broget AI'),
                subtitle: Text('Version ${s.data?.version ?? '1.0.0'}'),
              ),
            ),
          ],
        ),
      ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => run(
                      () => ref.read(authRepositoryProvider).signOut(),
                      'Signed out',
                    ),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: busy ? null : deleteAccount,
              icon: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.red,
              ),
              label: const Text(
                'Delete account & all data',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
