import 'package:cloud_firestore/cloud_firestore.dart';

double number(dynamic value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Invalid number');
  }
  return value.toDouble();
}

DateTime dateValue(dynamic value) => value is Timestamp
    ? value.toDate().toUtc()
    : DateTime.parse(value as String).toUtc();
const mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

class Nutrients {
  const Nutrients({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber,
  });
  final double calories, protein, carbs, fat;
  final double? fiber;
  factory Nutrients.fromJson(Map<String, dynamic> j) {
    final n = Nutrients(
      calories: number(j['calories']),
      protein: number(j['protein']),
      carbs: number(j['carbs']),
      fat: number(j['fat']),
      fiber: j['fiber'] == null ? null : number(j['fiber']),
    );
    if (n.calories < 0 ||
        n.calories > 1000 ||
        [
          n.protein,
          n.carbs,
          n.fat,
          if (n.fiber != null) n.fiber!,
        ].any((v) => v < 0 || v > 100)) {
      throw const FormatException('Invalid nutrients');
    }
    return n;
  }
  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
  };
  Nutrients scale(double factor) => Nutrients(
    calories: calories * factor,
    protein: protein * factor,
    carbs: carbs * factor,
    fat: fat * factor,
    fiber: fiber == null ? null : fiber! * factor,
  );
  Nutrients operator +(Nutrients other) => Nutrients(
    calories: calories + other.calories,
    protein: protein + other.protein,
    carbs: carbs + other.carbs,
    fat: fat + other.fat,
    fiber: fiber == null || other.fiber == null ? null : fiber! + other.fiber!,
  );
  static Nutrients sum(Iterable<Nutrients> values) =>
      values.fold(const Nutrients(fiber: 0), (a, b) => a + b);
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    this.health,
    this.deleting = false,
  });
  final String userId, name;
  final HealthProfile? health;
  final bool deleting;
  factory UserProfile.fromJson(String uid, Map<String, dynamic> j) =>
      UserProfile(
        userId: uid,
        name: j['name'] as String? ?? '',
        health: j['health'] == null
            ? null
            : HealthProfile.fromJson(Map<String, dynamic>.from(j['health'])),
        deleting: j['deleting'] == true,
      );
}

class HealthProfile {
  const HealthProfile({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    required this.goal,
    this.diet = '',
    this.allergies = '',
    this.restrictions = '',
    this.specialCare = false,
  });
  final int age;
  final String gender, activity, goal, diet, allergies, restrictions;
  final double heightCm, weightKg;
  final bool specialCare;
  factory HealthProfile.fromJson(Map<String, dynamic> j) => HealthProfile(
    age: (j['age'] as num).toInt(),
    gender: j['gender'],
    heightCm: number(j['heightCm']),
    weightKg: number(j['weightKg']),
    activity: j['activity'],
    goal: j['goal'],
    diet: j['diet'] ?? '',
    allergies: j['allergies'] ?? '',
    restrictions: j['restrictions'] ?? '',
    specialCare: j['specialCare'] == true,
  );
  Map<String, dynamic> toJson() => {
    'age': age,
    'gender': gender,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'activity': activity,
    'goal': goal,
    'diet': diet,
    'allergies': allergies,
    'restrictions': restrictions,
    'specialCare': specialCare,
  };
  bool get valid =>
      age >= 13 &&
      age <= 100 &&
      heightCm >= 100 &&
      heightCm <= 250 &&
      weightKg >= 30 &&
      weightKg <= 350 &&
      ['female', 'male', 'unspecified'].contains(gender) &&
      ['sedentary', 'light', 'moderate', 'active'].contains(activity) &&
      ['maintain', 'lose', 'gain', 'track'].contains(goal);
}

class NutritionTarget {
  const NutritionTarget(this.bmr, this.energy, this.values);
  final double bmr, energy;
  final Nutrients values;
  static NutritionTarget? calculate(HealthProfile? p) {
    if (p == null ||
        !p.valid ||
        p.age < 18 ||
        p.specialCare ||
        p.gender == 'unspecified') {
      return null;
    }
    final bmr =
        10 * p.weightKg +
        6.25 * p.heightCm -
        5 * p.age +
        (p.gender == 'male' ? 5 : -161);
    final energy =
        bmr *
        {
          'sedentary': 1.2,
          'light': 1.375,
          'moderate': 1.55,
          'active': 1.725,
        }[p.activity]!;
    final calories =
        (energy +
                (p.goal == 'lose'
                    ? -300
                    : p.goal == 'gain'
                    ? 300
                    : 0))
            .clamp(p.gender == 'male' ? 1500 : 1200, double.infinity)
            .roundToDouble();
    final protein = (p.weightKg * (p.goal == 'gain' ? 1.6 : 1.2))
        .roundToDouble();
    final fat = (calories * .3 / 9).roundToDouble();
    return NutritionTarget(
      bmr.roundToDouble(),
      energy.roundToDouble(),
      Nutrients(
        calories: calories,
        protein: protein,
        fat: fat,
        carbs: ((calories - protein * 4 - fat * 9) / 4)
            .clamp(0, double.infinity)
            .roundToDouble(),
        fiber: 30,
      ),
    );
  }
}

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.per100g,
    required this.attribution,
  });
  final String id, name, attribution;
  final Nutrients per100g;
  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
    id: j['id'],
    name: j['name'],
    per100g: Nutrients.fromJson(Map<String, dynamic>.from(j['per100g'])),
    attribution: j['attribution'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'per100g': per100g.toJson(),
    'attribution': attribution,
  };
}

class MealFood {
  const MealFood({
    required this.food,
    required this.grams,
    this.source = 'user_entered',
    this.confidence,
  });
  final FoodItem food;
  final double grams;
  final String source;
  final double? confidence;
  Nutrients get nutrients => food.per100g.scale(grams / 100);
  factory MealFood.fromJson(Map<String, dynamic> j) => MealFood(
    food: FoodItem.fromJson(Map<String, dynamic>.from(j['food'])),
    grams: number(j['grams']),
    source: j['source'],
    confidence: j['confidence'] == null ? null : number(j['confidence']),
  );
  Map<String, dynamic> toJson() => {
    'food': food.toJson(),
    'grams': grams,
    'source': source,
    'confidence': confidence,
  };
}

class Meal {
  const Meal({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.eatenAt,
    required this.foods,
    this.imagePath,
    this.createdAt,
    this.updatedAt,
  });
  final String id, userId, mealType;
  final DateTime eatenAt;
  final List<MealFood> foods;
  final String? imagePath;
  final DateTime? createdAt, updatedAt;
  Nutrients get nutrients => Nutrients.sum(foods.map((f) => f.nutrients));
  factory Meal.fromJson(String id, Map<String, dynamic> j) => Meal(
    id: id,
    userId: j['userId'],
    mealType: j['mealType'],
    eatenAt: dateValue(j['eatenAt']),
    foods: (j['foods'] as List)
        .map((f) => MealFood.fromJson(Map<String, dynamic>.from(f)))
        .toList(),
    imagePath: j['imagePath'],
    createdAt: j['createdAt'] == null ? null : dateValue(j['createdAt']),
    updatedAt: j['updatedAt'] == null ? null : dateValue(j['updatedAt']),
  );
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'mealType': mealType,
    'eatenAt': Timestamp.fromDate(eatenAt.toUtc()),
    'foods': foods.map((f) => f.toJson()).toList(),
    'imagePath': imagePath,
    'analysisVersion': 1,
  };
}

class DailySummary {
  DailySummary(this.date, this.meals);
  final DateTime date;
  final List<Meal> meals;
  Nutrients get totals => Nutrients.sum(meals.map((m) => m.nutrients));
}

class PeriodSummary {
  PeriodSummary({required this.start, required this.end, required this.meals});
  final DateTime start, end;
  final List<Meal> meals;
  List<DailySummary> get days {
    final output = <DailySummary>[];
    for (
      var day = dayStart(start);
      day.isBefore(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      output.add(
        DailySummary(
          day,
          meals
              .where((m) => dayKey(m.eatenAt.toLocal()) == dayKey(day))
              .toList(),
        ),
      );
    }
    return output;
  }

  Nutrients get totals => Nutrients.sum(meals.map((m) => m.nutrients));
  int get loggedDays => days.where((d) => d.meals.isNotEmpty).length;
  Nutrients get average => totals.scale(loggedDays == 0 ? 0 : 1 / loggedDays);
  double adherence(double target) => loggedDays == 0 || target <= 0
      ? 0
      : days
                .where(
                  (d) =>
                      d.meals.isNotEmpty &&
                      (d.totals.calories - target).abs() <= target * .1,
                )
                .length /
            loggedDays;
}

class WeeklySummary extends PeriodSummary {
  WeeklySummary({
    required super.start,
    required super.end,
    required super.meals,
  });
}

class MonthlySummary extends PeriodSummary {
  MonthlySummary({
    required super.start,
    required super.end,
    required super.meals,
  });
}

class AIAnalysis {
  AIAnalysis(this.mealType, this.foods, this.notes);
  final String mealType, notes;
  final List<RecognizedFood> foods;
  factory AIAnalysis.fromJson(Map<String, dynamic> j) {
    if (!mealTypes.contains(j['mealType']) ||
        j['needsUserConfirmation'] != true ||
        j['foods'] is! List ||
        (j['foods'] as List).length > 12) {
      throw const FormatException('Invalid analysis');
    }
    return AIAnalysis(
      j['mealType'],
      (j['foods'] as List)
          .map((f) => RecognizedFood.fromJson(Map<String, dynamic>.from(f)))
          .toList(),
      j['analysisNotes'] as String,
    );
  }
}

class RecognizedFood {
  RecognizedFood(
    this.name,
    this.grams,
    this.confidence,
    this.alternatives, {
    this.nutrition,
  });
  final String name;
  final double grams, confidence;
  final List<String> alternatives;
  final FoodItem? nutrition;
  MealFood? get estimatedMealFood => nutrition == null
      ? null
      : MealFood(
          food: nutrition!,
          grams: grams,
          source: 'ai_estimate',
          confidence: confidence,
        );
  factory RecognizedFood.fromJson(Map<String, dynamic> j) {
    final grams = number(j['estimatedQuantity']),
        confidence = number(j['confidence']);
    if (j['unit'] != 'g' ||
        grams < 1 ||
        grams > 3000 ||
        confidence < 0 ||
        confidence > 1 ||
        j['name'] is! String ||
        (j['name'] as String).length > 120) {
      throw const FormatException('Invalid portion');
    }
    return RecognizedFood(
      j['name'],
      grams,
      confidence,
      List<String>.from(j['alternatives']),
      nutrition: j['nutrition'] == null
          ? null
          : FoodItem.fromJson(Map<String, dynamic>.from(j['nutrition'])),
    );
  }
}

class ChatMessage {
  ChatMessage(this.id, this.role, this.text, this.createdAt);
  final String id, role, text;
  final DateTime? createdAt;
}

class ChatSession {
  ChatSession(this.userId, this.messages);
  final String userId;
  final List<ChatMessage> messages;
}

class AppSettings {
  const AppSettings({this.analytics = false, this.notifications = false});
  final bool analytics, notifications;
  Map<String, dynamic> toJson() => {
    'analytics': analytics,
    'notifications': notifications,
  };
  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    analytics: j['analytics'] == true,
    notifications: j['notifications'] == true,
  );
}
