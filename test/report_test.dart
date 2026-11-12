import 'package:flutter_test/flutter_test.dart';
import 'package:health_broget/data/models/nutrition_report.dart';
import 'package:health_broget/data/models/models.dart';

void main() {
  test(
    'calendar report ranges include a complete month, year and leap day',
    () {
      final year = reportBounds(DateTime(2024, 8, 15), 'year');
      expect(year.$1, DateTime(2024));
      expect(year.$2, DateTime(2025));
      final month = reportBounds(DateTime(2024, 2, 20), 'month');
      expect(month.$1, DateTime(2024, 2));
      expect(month.$2, DateTime(2024, 3));
    },
  );
  test(
    'year chart groups daily totals into twelve months and excludes missing logs from averages',
    () {
      final days = <ReportDay>[];
      for (
        var day = DateTime(2024);
        day.isBefore(DateTime(2025));
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        days.add(
          ReportDay(
            date: day,
            mealCount: day.day == 1 ? 1 : 0,
            nutrition: Nutrients(calories: day.day == 1 ? 2000 : 0, fiber: 0),
          ),
        );
      }
      final report = NutritionReport(
        start: DateTime(2024),
        end: DateTime(2025),
        timeZone: 'Asia/Calcutta',
        days: days,
      );
      expect(report.days.length, 366);
      expect(report.buckets(true).length, 12);
      expect(report.mealCount, 12);
      expect(report.loggedDays, 12);
      expect(report.totals.calories, 24000);
      expect(report.average.calories, 2000);
      expect(report.buckets(true)[1].days.length, 29);
      expect(report.adherence(2000), 1);
    },
  );
}
