import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:health_broget/core/theme/app_theme.dart';
import 'package:health_broget/features/public/public_page.dart';
import 'package:health_broget/features/dashboard/dashboard_page.dart';
import 'package:health_broget/data/models/models.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('HealthBrogetSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('Public website and dashboard cards fit $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const PublicPage(path: '/'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/branding/health_broget_wordmark.png'),
          tester.element(find.byType(PublicPage)),
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/public-${width.toInt()}.png'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  EnergyCard(totals: Nutrients(), target: null),
                  MacroCard(totals: Nutrients(), target: null),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Download page never advertises an unavailable APK', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/download',
      routes: [
        GoRoute(
          path: '/download',
          builder: (_, _) => const PublicPage(path: '/download'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Android app download will be available soon.'),
      findsOneWidget,
    );
    expect(find.text('Download Android APK'), findsNothing);
  });
}
