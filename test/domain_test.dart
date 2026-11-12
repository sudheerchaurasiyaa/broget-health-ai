import 'package:flutter_test/flutter_test.dart';
import 'package:health_broget/data/models/models.dart';
import 'package:health_broget/routing/app_router.dart';
import 'package:health_broget/services/images/food_images.dart';
import 'package:flutter/foundation.dart';

HealthProfile profile({
  int age = 30,
  bool care = false,
  String gender = 'male',
}) => HealthProfile(
  age: age,
  gender: gender,
  heightCm: 175,
  weightKg: 75,
  activity: 'moderate',
  goal: 'maintain',
  specialCare: care,
);
Meal meal(String id, DateTime when) => Meal(
  id: id,
  userId: 'test',
  mealType: 'lunch',
  eatenAt: when.toUtc(),
  foods: const [
    MealFood(
      food: FoodItem(
        id: 'test',
        name: 'Rice',
        attribution: 'Test',
        per100g: Nutrients(
          calories: 130,
          protein: 2,
          carbs: 28,
          fat: .3,
          fiber: 1,
        ),
      ),
      grams: 150,
    ),
  ],
);
void main() {
  test('Mifflin target is deterministic and safety exclusions suppress it', () {
    final target = NutritionTarget.calculate(profile())!;
    expect(target.bmr, 1699);
    expect(target.values.calories, 2633);
    expect(target.values.protein, 90);
    expect(NutritionTarget.calculate(profile(age: 16)), isNull);
    expect(NutritionTarget.calculate(profile(care: true)), isNull);
    expect(NutritionTarget.calculate(profile(gender: 'unspecified')), isNull);
    expect(NutritionTarget.calculate(null), isNull);
    expect(profile(age: 400).valid, false);
  });
  test('totals, missing fiber and logged-day averages are transparent', () {
    final start = DateTime(2026, 10, 26), end = DateTime(2026, 11, 2);
    final summary = WeeklySummary(
      start: start,
      end: end,
      meals: [
        meal('a', DateTime(2026, 10, 26, 12)),
        meal('b', DateTime(2026, 10, 28, 1)),
      ],
    );
    expect(summary.days.length, 7);
    expect(summary.loggedDays, 2);
    expect(summary.totals.calories, 390);
    expect(summary.average.calories, 195);
    expect(summary.days[1].meals, isEmpty);
    expect(summary.adherence(195), 1);
    expect(
      Nutrients.sum([const Nutrients(fiber: 1), const Nutrients()]).fiber,
      isNull,
    );
    expect(
      PeriodSummary(start: start, end: end, meals: []).average.calories,
      0,
    );
  });
  test('local midnight and month rollover group meals correctly', () {
    final summary = MonthlySummary(
      start: DateTime(2026, 10),
      end: DateTime(2026, 11),
      meals: [meal('late', DateTime(2026, 10, 31, 23, 59))],
    );
    expect(summary.days.length, 31);
    expect(summary.days.last.meals.single.id, 'late');
  });
  test('strict analysis rejects malformed responses and invalid units', () {
    expect(
      () => AIAnalysis.fromJson({
        'mealType': 'lunch',
        'foods': [],
        'analysisNotes': '',
        'needsUserConfirmation': false,
      }),
      throwsFormatException,
    );
    expect(
      () => RecognizedFood.fromJson({
        'name': 'Rice',
        'estimatedQuantity': -5,
        'confidence': .5,
        'unit': 'g',
        'alternatives': <String>[],
      }),
      throwsFormatException,
    );
    expect(
      () => Nutrients.fromJson({
        'calories': -1,
        'protein': 1,
        'carbs': 2,
        'fat': 3,
        'fiber': null,
      }),
      throwsFormatException,
    );
  });
  test('invalid and oversized images fail before upload', () {
    expect(
      () => compressFoodImage(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
    expect(
      () => compressFoodImage(Uint8List(10 * 1024 * 1024 + 1)),
      throwsA(anything),
    );
  });
  test(
    'authentication and onboarding guards survive deep links and refresh',
    () {
      expect(
        routeRedirect(
          path: '/app/reports',
          authenticated: false,
          onboarded: false,
          web: true,
        ),
        '/login',
      );
      expect(
        routeRedirect(
          path: '/login',
          authenticated: true,
          onboarded: true,
          web: true,
        ),
        '/app',
      );
      expect(
        routeRedirect(
          path: '/app/reports',
          authenticated: true,
          onboarded: true,
          web: true,
        ),
        isNull,
      );
      expect(
        routeRedirect(
          path: '/',
          authenticated: true,
          onboarded: true,
          web: true,
        ),
        '/app',
      );
      expect(
        routeRedirect(
          path: '/app/scan',
          authenticated: true,
          onboarded: false,
          web: true,
        ),
        '/onboarding',
      );
      expect(
        routeRedirect(
          path: '/',
          authenticated: false,
          onboarded: false,
          web: false,
        ),
        '/login',
      );
      expect(
        routeRedirect(
          path: '/app',
          authenticated: true,
          onboarded: true,
          web: true,
          deleting: true,
        ),
        '/app/settings',
      );
    },
  );
}
