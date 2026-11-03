import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/brand_logo.dart';

class PublicPage extends StatelessWidget {
  const PublicPage({super.key, required this.path});
  final String path;
  @override
  Widget build(BuildContext context) {
    final home = path == '/';
    final pages = <String, (String, String, List<String>)>{
      '/features': (
        'A little clarity. Every day.',
        'Everything you need to understand your plate.',
        [
          'Scan a food photo, review the AI estimate, match it to a nutrition source and confirm your portion.',
          'Log meals by breakfast, lunch, dinner and snacks. Correct or delete any entry.',
          'Explore daily, weekly and monthly reports calculated from your own records.',
          'Ask Broget AI Health Assistant about your logged food and meal ideas.',
        ],
      ),
      '/how-it-works': (
        'From plate to perspective.',
        'Four small steps. A more informed routine.',
        [
          '1. Create your private account and complete your nutrition profile.',
          '2. Take a clear photo or upload one. A standard-size reference object can help with portion estimates.',
          '3. Review the suggested foods, choose a matching nutrition entry and correct the quantity.',
          '4. Confirm your meal. Track your intake and explore patterns over time.',
        ],
      ),
      '/about': (
        'Food awareness, without the noise.',
        'Meet BROGET AI · Version 1.0.0',
        [
          'BROGET AI combines a food journal, photo-assisted recognition, deterministic nutrition tracking and a helpful nutrition assistant.',
          'A photograph cannot reveal exact ingredients, cooking oils or portion weights. All food recognition and nutrition values are estimates.',
          'Targets use the Mifflin–St Jeor equation and activity factors. They are general estimates, not medical advice. Children and people with special care needs should consult a qualified professional.',
          'Your records are private to your account. Photo storage is coming soon; photos used for analysis are not saved. You can delete your account in settings.',
        ],
      ),
      '/privacy': (
        'Your food journal is personal.',
        'Privacy policy · Effective 28 October 2026',
        [
          'We process account email and name, your nutrition profile, meal records, assistant conversations, user-confirmed assistant notes and reminder preferences/history to operate your account. Optional analytics is off by default.',
          'When you choose to scan a photo or use the assistant, relevant image content and bounded nutrition context are sent to an external AI processor. The app does not claim that processing stays on your device. Do not upload people, documents or private information unrelated to food.',
          'Food photos are resized and sent for analysis but are not saved by the app. Photo storage is coming soon. Structured scan results are cached for up to one hour. Assistant requests use limited recent messages, your confirmed notes and relevant nutrition summaries instead of your entire history. You can clear chat, edit remembered notes or delete meals.',
          'Records remain until you delete them or your account. Account deletion removes the account, meal data, chat and cached analysis. Operational quotas expire. Offline device caches may persist until application data is cleared.',
          'Before a public launch, the service operator must publish its legal identity, contact address, processing region, processor agreement, retention schedule and applicable privacy rights in the deployed policy. This policy must match that actual configuration.',
        ],
      ),
      '/terms': (
        'A companion for your routine.',
        'Terms of service · Effective 28 October 2026',
        [
          'BROGET AI offers general food tracking and nutrition education. It does not diagnose, treat, prescribe medication or replace a healthcare professional.',
          'Photo recognition, nutrient databases, portion estimates and suggested targets can be inaccurate. Review and correct entries before relying on them. Do not use this service for emergency decisions.',
          'You are responsible for the content you upload and your account security. Do not upload unlawful content, attempt to access another account or abuse automated features.',
          'The service requires users to be at least 13. Users under 18 must use the service with appropriate guardian consent and should obtain professional nutrition advice.',
          'Availability depends on configured external services and internet access. No weight change or health outcome is guaranteed. Local law and mandatory consumer rights continue to apply.',
          'The operator must add its legal identity, support contact, jurisdiction and applicable commercial terms before public distribution.',
        ],
      ),
      '/unauthorized': (
        'This space is private.',
        'Sign in to access your own nutrition journal.',
        ['Your records are accessible only through your account.'],
      ),
    };
    return Scaffold(
      appBar: AppBar(
        title: TextButton(
          onPressed: () => context.go('/'),
          child: const BrandLogo(width: 150),
        ),
        actions: [
          if (MediaQuery.sizeOf(context).width > 700)
            TextButton(
              onPressed: () => context.go('/features'),
              child: const Text('Features'),
            ),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 24 : 48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (home) ...[
                    const Chip(
                      avatar: Icon(Icons.spa_outlined, size: 18),
                      label: Text('A healthier relationship with your plate'),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Eat with curiosity.\nLive with balance.',
                      style: MediaQuery.sizeOf(context).width < 600
                          ? Theme.of(context).textTheme.headlineLarge
                          : Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 600),
                      child: Text(
                        'Turn everyday meals into everyday understanding. Photo-assisted food logging, thoughtful nutrition tracking and a companion for your questions.',
                        style: TextStyle(fontSize: 20, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.go('/register'),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Get Started'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go('/download'),
                          child: const Text('Download App'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Panel(
                      color: AppTheme.ink,
                      padding: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.restaurant_outlined,
                            color: AppTheme.lime,
                            size: 54,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Small habits.\nA bigger picture.',
                            style: TextStyle(
                              fontSize: 36,
                              height: 1.2,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'SCAN → REVIEW → LOG → UNDERSTAND',
                            style: TextStyle(
                              color: AppTheme.lime,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 24,
                            runSpacing: 16,
                            children:
                                [
                                      'Photo-assisted logging',
                                      'Indian & global food search',
                                      'Private meal journal',
                                      'Weekly & monthly insights',
                                    ]
                                    .map(
                                      (s) => Text(
                                        '✓  $s',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    LayoutBuilder(
                      builder: (context, c) => Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children:
                            [
                                  (
                                    '01',
                                    'See your plate',
                                    'Take a photo, get food suggestions and review each estimate.',
                                  ),
                                  (
                                    '02',
                                    'Know your nourishment',
                                    'Track calories, protein, carbs, fats and available fiber.',
                                  ),
                                  (
                                    '03',
                                    'Find your rhythm',
                                    'Look at your trends and ask your nutrition assistant for ideas.',
                                  ),
                                ]
                                .map(
                                  (item) => SizedBox(
                                    width: c.maxWidth > 800
                                        ? (c.maxWidth - 32) / 3
                                        : c.maxWidth,
                                    child: Panel(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.$1,
                                            style: const TextStyle(
                                              color: AppTheme.green,
                                              fontSize: 24,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            item.$2,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(item.$3),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Built for Android and your browser. Photo analysis and nutrition targets are approximate, and are not medical advice.',
                    ),
                  ] else if (path == '/download') ...[
                    Text(
                      'Use Broget AI on Android',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your nutrition journal, wherever your day takes you.',
                    ),
                    const SizedBox(height: 32),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.android,
                            size: 56,
                            color: AppTheme.green,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Android application',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (AppConfig.downloadUrl.isEmpty)
                            const Text(
                              'Android app download will be available soon.',
                            )
                          else ...[
                            const Text(
                              'Download the APK only from this official link. Android may ask you to allow installs from your browser; review the source and turn that permission off after installation.',
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () async {
                                final uri = Uri.tryParse(AppConfig.downloadUrl);
                                if (uri == null ||
                                    uri.scheme != 'https' ||
                                    !await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    )) {
                                  if (context.mounted) {
                                    notify(
                                      context,
                                      'The download is unavailable. Please try again later.',
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Download Android APK'),
                            ),
                          ],
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Use the full web app'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      pages[path]?.$1 ?? 'We couldn’t find that page.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      pages[path]?.$2 ??
                          'The address may have changed. Return home to find your way.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    ...?pages[path]?.$3.map(
                      (text) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Panel(
                          child: Text(
                            text,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Back to home'),
                    ),
                  ],
                  const SizedBox(height: 52),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                              ('/about', 'About'),
                              ('/features', 'Features'),
                              ('/how-it-works', 'How it works'),
                              ('/privacy', 'Privacy'),
                              ('/terms', 'Terms'),
                              ('/download', 'Android app'),
                            ]
                            .map(
                              (link) => TextButton(
                                onPressed: () => context.push(link.$1),
                                child: Text(link.$2),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '© 2026 BROGET AI · Make every meal a little more mindful.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
