import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:broget_ai/core/theme/app_theme.dart';
import 'package:broget_ai/data/models/models.dart';
import 'package:broget_ai/data/models/nutrition_report.dart';
import 'package:broget_ai/data/repositories/repositories.dart';
import 'package:broget_ai/services/ai/broget_ai_service.dart';
import 'package:broget_ai/features/reports/reports_page.dart';

class _ReportApi extends BrogetApi {
  _ReportApi() : super(http.Client());
  @override
  Future<NutritionReport> nutritionReport(DateTime start, DateTime end) async {
    final days = <ReportDay>[];
    for (
      var day = start;
      day.isBefore(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      days.add(
        ReportDay(
          date: day,
          mealCount: day.day % 3 == 0 ? 2 : 0,
          nutrition: Nutrients(
            calories: day.day % 3 == 0 ? 2000 : 0,
            protein: day.day % 3 == 0 ? 90 : 0,
            fiber: 0,
          ),
        ),
      );
    }
    return NutritionReport(
      start: start,
      end: end,
      timeZone: 'Asia/Calcutta',
      days: days,
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('BrogetSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'Yearly report renders a responsive monthly chart at $width px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = _ReportApi();
        addTearDown(api.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiProvider.overrideWithValue(api),
              profileProvider.overrideWith(
                (ref) => Stream<UserProfile?>.value(null),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: const Scaffold(body: ReportsPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Weekly'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yearly').last);
        await tester.pumpAndSettle();
        expect(find.text('Month by month'), findsOneWidget);
        expect(
          find.text('Monthly average energy · estimated kcal per logged day'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/report-year-${width.toInt()}.png'),
        );
      },
    );
  }
}
