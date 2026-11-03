import 'models.dart';

(DateTime, DateTime) reportBounds(DateTime anchor, String period) {
  if (period == 'year') {
    return (DateTime(anchor.year), DateTime(anchor.year + 1));
  }
  if (period == 'month') {
    return (
      DateTime(anchor.year, anchor.month),
      DateTime(anchor.year, anchor.month + 1),
    );
  }
  if (period == 'day') {
    return (
      dayStart(anchor),
      DateTime(anchor.year, anchor.month, anchor.day + 1),
    );
  }
  final start = DateTime(
    anchor.year,
    anchor.month,
    anchor.day - anchor.weekday + 1,
  );
  return (start, DateTime(start.year, start.month, start.day + 7));
}

class ReportDay {
  const ReportDay({
    required this.date,
    required this.mealCount,
    required this.nutrition,
  });
  final DateTime date;
  final int mealCount;
  final Nutrients nutrition;
  factory ReportDay.fromJson(Map<String, dynamic> j) => ReportDay(
    date: DateTime.parse(j['date']),
    mealCount: (j['mealCount'] as num).toInt(),
    nutrition: Nutrients(
      calories: number(j['calories']),
      protein: number(j['protein']),
      carbs: number(j['carbs']),
      fat: number(j['fat']),
      fiber: j['unknownFiberCount'] == 0 ? number(j['fiber']) : null,
    ),
  );
}

class ReportBucket {
  ReportBucket(this.start, this.days);
  final DateTime start;
  final List<ReportDay> days;
  int get loggedDays => days.where((d) => d.mealCount > 0).length;
  Nutrients get total => Nutrients.sum(days.map((d) => d.nutrition));
  double get averageCalories =>
      loggedDays == 0 ? 0 : total.calories / loggedDays;
}

class NutritionReport {
  NutritionReport({
    required this.start,
    required this.end,
    required this.timeZone,
    required this.days,
  });
  final DateTime start, end;
  final String timeZone;
  final List<ReportDay> days;
  factory NutritionReport.fromJson(Map<String, dynamic> j) => NutritionReport(
    start: DateTime.parse(j['startDate']),
    end: DateTime.parse(j['endDate']),
    timeZone: j['timeZone'],
    days: (j['days'] as List)
        .map((d) => ReportDay.fromJson(Map<String, dynamic>.from(d)))
        .toList(),
  );
  int get mealCount => days.fold(0, (sum, d) => sum + d.mealCount);
  int get loggedDays => days.where((d) => d.mealCount > 0).length;
  Nutrients get totals => Nutrients.sum(days.map((d) => d.nutrition));
  Nutrients get average => totals.scale(loggedDays == 0 ? 0 : 1 / loggedDays);
  double adherence(double target) => loggedDays == 0 || target <= 0
      ? 0
      : days
                .where(
                  (d) =>
                      d.mealCount > 0 &&
                      (d.nutrition.calories - target).abs() <= target * .1,
                )
                .length /
            loggedDays;
  List<ReportBucket> buckets(bool yearly) {
    if (!yearly) return days.map((d) => ReportBucket(d.date, [d])).toList();
    final grouped = <String, List<ReportDay>>{};
    for (final day in days) {
      grouped
          .putIfAbsent('${day.date.year}-${day.date.month}', () => [])
          .add(day);
    }
    return grouped.values
        .map(
          (d) =>
              ReportBucket(DateTime(d.first.date.year, d.first.date.month), d),
        )
        .toList();
  }
}
