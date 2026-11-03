import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/errors/app_error.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../widgets/common.dart';
import '../meal_tracking/meal_editor.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final profile = ref.watch(profileProvider).value;
    final target = NutritionTarget.calculate(profile?.health);
    return PageBody(
      title: 'Your daily balance',
      subtitle:
          'A little awareness goes a long way, ${profile?.name.split(' ').first ?? 'you'}.',
      action: FilledButton.icon(
        onPressed: () => context.go('/app/scan'),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Scan a meal'),
      ),
      children: [
        DaySelector(
          day: day,
          onChange: (d) => ref.read(selectedDayProvider.notifier).select(d),
        ),
        if (ref.watch(sessionProvider).value?.emailVerified == false)
          Panel(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                const Text(
                  'Verify your email to unlock online nutrition tools.',
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(sessionProvider)
                          .value!
                          .sendEmailVerification();
                      if (context.mounted) {
                        notify(context, 'Verification email sent');
                      }
                    } catch (e) {
                      if (context.mounted) notify(context, friendlyError(e));
                    }
                  },
                  child: const Text('Send email'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final verified = await ref
                          .read(authRepositoryProvider)
                          .refreshVerification();
                      if (context.mounted) {
                        notify(
                          context,
                          verified
                              ? 'Email verified'
                              : 'Open the verification link in your email, then try again.',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) notify(context, friendlyError(e));
                    }
                  },
                  child: const Text('I have verified'),
                ),
              ],
            ),
          ),
        AsyncPanel<List<Meal>>(
          value: ref.watch(dailyMealsProvider),
          retry: () => ref.invalidate(dailyMealsProvider),
          builder: (meals) {
            final totals = Nutrients.sum(meals.map((m) => m.nutrients));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 800;
                    final width = wide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: EnergyCard(totals: totals, target: target),
                        ),
                        SizedBox(
                          width: width,
                          child: MacroCard(totals: totals, target: target),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'On your plate',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: () => openMealEditor(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Log manually'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (meals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: EmptyPanel(
                      title: 'Your day is a fresh page.',
                      message:
                          'Log your first meal to start understanding your daily nutrition.',
                      action: FilledButton(
                        onPressed: () => openMealEditor(context),
                        child: const Text('Add your first meal'),
                      ),
                    ),
                  ),
                for (final type in mealTypes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                type == 'breakfast'
                                    ? Icons.wb_sunny_outlined
                                    : type == 'lunch'
                                    ? Icons.restaurant_outlined
                                    : type == 'dinner'
                                    ? Icons.nightlight_outlined
                                    : Icons.local_cafe_outlined,
                                color: AppTheme.green,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  type[0].toUpperCase() + type.substring(1),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                '~${Nutrients.sum(meals.where((m) => m.mealType == type).map((m) => m.nutrients)).calories.round()} kcal',
                              ),
                              IconButton(
                                tooltip: 'Add $type',
                                onPressed: () =>
                                    openMealEditor(context, mealType: type),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          if (!meals.any((m) => m.mealType == type))
                            const Text('No meals logged yet.'),
                          ...meals
                              .where((m) => m.mealType == type)
                              .map((m) => MealTile(meal: m)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const Text(
          'All nutrition is approximate. Missing logs do not mean you ate nothing. Your journal is a tool for awareness, not a score.',
        ),
      ],
    );
  }
}

class EnergyCard extends StatelessWidget {
  const EnergyCard({super.key, required this.totals, required this.target});
  final Nutrients totals;
  final NutritionTarget? target;
  @override
  Widget build(BuildContext context) => Panel(
    color: AppTheme.ink,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR ENERGY TODAY',
          style: TextStyle(
            color: AppTheme.lime,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            height: 180,
            width: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: target == null
                        ? 0
                        : (totals.calories / target!.values.calories).clamp(
                            0,
                            1,
                          ),
                    strokeWidth: 13,
                    backgroundColor: Colors.white12,
                    color: AppTheme.lime,
                    semanticsLabel: 'Estimated calorie progress',
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '~${totals.calories.round()}',
                      style: const TextStyle(
                        fontSize: 34,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'kcal logged',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          target == null
              ? 'No generic target set for your profile.'
              : 'of ~${target!.values.calories.round()} kcal estimated target',
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          target == null
              ? 'Track your meals at your own pace.'
              : totals.calories <= target!.values.calories
              ? '~${(target!.values.calories - totals.calories).round()} kcal remaining'
              : '~${(totals.calories - target!.values.calories).round()} kcal above the estimate',
          style: const TextStyle(color: AppTheme.lime),
        ),
      ],
    ),
  );
}

class MacroCard extends StatelessWidget {
  const MacroCard({super.key, required this.totals, required this.target});
  final Nutrients totals;
  final NutritionTarget? target;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More than just calories',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        for (final n in [
          ('Protein', totals.protein, target?.values.protein, AppTheme.green),
          (
            'Carbohydrates',
            totals.carbs,
            target?.values.carbs,
            const Color(0xFF956622),
          ),
          ('Fat', totals.fat, target?.values.fat, const Color(0xFF7C6EAA)),
          (
            'Fiber',
            totals.fiber,
            target?.values.fiber,
            const Color(0xFF587D86),
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  children: [
                    Text(n.$1),
                    Text(
                      n.$2 == null
                          ? 'Not fully available'
                          : '~${n.$2!.round()}${n.$3 == null ? '' : ' / ${n.$3!.round()}'} g',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: n.$2 == null || n.$3 == null
                      ? 0
                      : (n.$2! / n.$3!).clamp(0, 1),
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                  color: n.$4,
                  backgroundColor: const Color(0xFFF0F1E9),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class DaySelector extends StatelessWidget {
  const DaySelector({super.key, required this.day, required this.onChange});
  final DateTime day;
  final ValueChanged<DateTime> onChange;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      IconButton(
        tooltip: 'Previous day',
        onPressed: () => onChange(DateTime(day.year, day.month, day.day - 1)),
        icon: const Icon(Icons.chevron_left),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: day,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (d != null) onChange(d);
        },
        icon: const Icon(Icons.calendar_today_outlined, size: 18),
        label: Text(DateFormat('EEE, d MMM yyyy').format(day)),
      ),
      IconButton(
        tooltip: 'Next day',
        onPressed: day.isBefore(dayStart(DateTime.now()))
            ? () => onChange(DateTime(day.year, day.month, day.day + 1))
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class MealTile extends ConsumerWidget {
  const MealTile({super.key, required this.meal, this.onChange});
  final Meal meal;
  final VoidCallback? onChange;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      meal.foods.map((f) => f.food.name).join(', '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      '${DateFormat('d MMM · h:mm a').format(meal.eatenAt.toLocal())} · ~${meal.nutrients.calories.round()} kcal\n${meal.foods.map((f) => '${f.grams.round()} g').join(' + ')}',
    ),
    isThreeLine: true,
    onTap: () async {
      if (await openMealEditor(context, meal: meal) == true) onChange?.call();
    },
    trailing: PopupMenuButton<String>(
      tooltip: 'Meal actions',
      onSelected: (v) async {
        if (v == 'delete') {
          if (await deleteMeal(context, ref, meal)) onChange?.call();
        } else {
          if (await openMealEditor(context, meal: meal) == true) {
            onChange?.call();
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit meal')),
        PopupMenuItem(value: 'delete', child: Text('Delete meal')),
      ],
    ),
  );
}
