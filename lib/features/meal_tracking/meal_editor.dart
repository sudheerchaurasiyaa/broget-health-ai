import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../services/ai/broget_ai_service.dart';
import '../../core/errors/app_error.dart';
import '../../widgets/common.dart';

Future<bool?> openMealEditor(
  BuildContext context, {
  Meal? meal,
  List<MealFood>? foods,
  String? mealType,
  String? imagePath,
  String? stableId,
  DateTime? eatenAt,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => MealEditor(
    meal: meal,
    initialFoods: foods,
    initialType: mealType,
    imagePath: imagePath,
    stableId: stableId,
    initialEatenAt: eatenAt,
  ),
);

class MealEditor extends ConsumerStatefulWidget {
  const MealEditor({
    super.key,
    this.meal,
    this.initialFoods,
    this.initialType,
    this.imagePath,
    this.stableId,
    this.initialEatenAt,
  });
  final Meal? meal;
  final List<MealFood>? initialFoods;
  final String? initialType, imagePath, stableId;
  final DateTime? initialEatenAt;
  @override
  ConsumerState<MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends ConsumerState<MealEditor> {
  late final id = widget.meal?.id ?? widget.stableId ?? const Uuid().v4();
  late String type = widget.meal?.mealType ?? widget.initialType ?? 'lunch';
  late DateTime eatenAt =
      widget.meal?.eatenAt.toLocal() ?? widget.initialEatenAt ?? DateTime.now();
  late List<MealFood> foods = [
    ...?widget.meal?.foods,
    if (widget.meal == null) ...?widget.initialFoods,
  ];
  bool busy = false;
  String? error;
  Future<void> save() async {
    if (foods.isEmpty) {
      setState(() => error = 'Add at least one food before saving.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final uid = ref.read(sessionProvider).value!.uid;
      await ref
          .read(mealRepositoryProvider)
          .save(
            Meal(
              id: id,
              userId: uid,
              mealType: type,
              eatenAt: eatenAt.toUtc(),
              foods: foods,
              imagePath: widget.meal?.imagePath ?? widget.imagePath,
            ),
          );
      if (mounted) {
        notify(context, 'Meal saved to your journal');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add({int? index}) async {
    final item = await showDialog<MealFood>(
      context: context,
      builder: (_) => FoodPicker(existing: index == null ? null : foods[index]),
    );
    if (item != null && mounted) {
      setState(() {
        if (index == null) {
          foods.add(item);
        } else {
          foods[index] = item;
        }
      });
    }
  }

  Future<void> chooseTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: eatenAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(eatenAt),
    );
    if (time != null && mounted) {
      setState(
        () => eatenAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.meal == null
                  ? 'Review & confirm your meal'
                  : 'Edit your meal',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nutrition values are estimates. Review every food and portion before saving.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Meal type'),
              items: mealTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t[0].toUpperCase() + t.substring(1)),
                    ),
                  )
                  .toList(),
              onChanged: busy ? null : (v) => setState(() => type = v!),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : chooseTime,
              icon: const Icon(Icons.schedule),
              label: Text(
                DateFormat('EEE, d MMM yyyy · h:mm a').format(eatenAt),
              ),
            ),
            const SizedBox(height: 16),
            ...foods.asMap().entries.map(
              (e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  isThreeLine: true,
                  title: Text(e.value.food.name),
                  subtitle: Text(
                    '${e.value.grams.round()} g · ~${e.value.nutrients.calories.round()} kcal\n'
                    'Protein ${e.value.nutrients.protein.toStringAsFixed(1)} g · Carbs ${e.value.nutrients.carbs.toStringAsFixed(1)} g · Fat ${e.value.nutrients.fat.toStringAsFixed(1)} g\n'
                    'Fiber ${e.value.nutrients.fiber?.toStringAsFixed(1) ?? 'unknown'}${e.value.nutrients.fiber == null ? '' : ' g'} · ${e.value.food.attribution}\nTap to edit food, portion or nutrition',
                  ),
                  onTap: busy ? null : () => add(index: e.key),
                  trailing: IconButton(
                    tooltip: 'Remove food',
                    onPressed: busy
                        ? null
                        : () => setState(() => foods.removeAt(e.key)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
            if (foods.length < 12)
              OutlinedButton.icon(
                onPressed: busy ? null : () => add(),
                icon: const Icon(Icons.add),
                label: const Text('Add food / choose another food'),
              ),
            if (foods.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Meal total: ~${Nutrients.sum(foods.map((f) => f.nutrients)).calories.round()} kcal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error!),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Saving…' : 'Confirm & save meal'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class FoodPicker extends ConsumerStatefulWidget {
  const FoodPicker({super.key, this.existing, this.suggestion});
  final MealFood? existing;
  final RecognizedFood? suggestion;
  @override
  ConsumerState<FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends ConsumerState<FoodPicker> {
  final form = GlobalKey<FormState>();
  late final search = TextEditingController(
    text: widget.existing?.food.name ?? widget.suggestion?.name ?? '',
  );
  late final grams = TextEditingController(
    text: '${widget.existing?.grams ?? widget.suggestion?.grams ?? 100}',
  );
  late final name = TextEditingController(
    text: widget.existing?.food.name ?? widget.suggestion?.name ?? '',
  );
  final labelSource = TextEditingController();
  final calories = TextEditingController(),
      protein = TextEditingController(),
      carbs = TextEditingController(),
      fat = TextEditingController(),
      fiber = TextEditingController();
  FoodItem? selected;
  List<FoodItem> results = [];
  bool busy = false, manual = false, searched = false;
  String? error;
  @override
  void initState() {
    super.initState();
    selected = widget.existing?.food;
    final existing = widget.existing?.food;
    if (existing != null) {
      final n = existing.per100g;
      calories.text = '${n.calories}';
      protein.text = '${n.protein}';
      carbs.text = '${n.carbs}';
      fat.text = '${n.fat}';
      fiber.text = n.fiber == null ? '' : '${n.fiber}';
      labelSource.text = existing.id.startsWith('ai:')
          ? 'Edited AI photo estimate'
          : existing.attribution.replaceFirst('User-entered label: ', '');
    }
  }

  @override
  void dispose() {
    for (final c in [
      search,
      grams,
      name,
      labelSource,
      calories,
      protein,
      carbs,
      fat,
      fiber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> lookup() async {
    if (search.text.trim().length < 2) {
      setState(() => error = 'Enter at least two letters.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final found = await ref.read(apiProvider).searchFood(search.text.trim());
      if (mounted) {
        setState(() {
          results = found;
          searched = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? bounded(String? value, double maximum, {bool optional = false}) {
    if (optional && (value ?? '').isEmpty) return null;
    final n = double.tryParse(value ?? '');
    return n == null || !n.isFinite || n < 0 || n > maximum
        ? 'Enter 0–$maximum'
        : null;
  }

  void choose() {
    if (!form.currentState!.validate()) return;
    final quantity = double.tryParse(grams.text);
    if (quantity == null ||
        !quantity.isFinite ||
        quantity < 1 ||
        quantity > 3000) {
      setState(() => error = 'Enter a portion from 1 to 3,000 grams.');
      return;
    }
    FoodItem? food = selected;
    if (manual) {
      food = FoodItem(
        id: 'label:${const Uuid().v4()}',
        name: name.text.trim(),
        attribution: 'User-entered label: ${labelSource.text.trim()}',
        per100g: Nutrients.fromJson({
          'calories': double.parse(calories.text),
          'protein': double.parse(protein.text),
          'carbs': double.parse(carbs.text),
          'fat': double.parse(fat.text),
          'fiber': fiber.text.isEmpty ? null : double.parse(fiber.text),
        }),
      );
    }
    if (food == null) {
      setState(() => error = 'Select a nutrition match or enter a food label.');
      return;
    }
    Navigator.pop(
      context,
      MealFood(
        food: food,
        grams: quantity,
        source: manual
            ? 'user_entered'
            : widget.suggestion != null
            ? 'ai_estimate'
            : widget.existing?.source ?? 'user_entered',
        confidence: manual
            ? null
            : widget.suggestion?.confidence ?? widget.existing?.confidence,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose food & portion',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              if (widget.suggestion != null) ...[
                Text(
                  'AI estimate · ${widget.suggestion!.confidence < .6
                      ? 'Low'
                      : widget.suggestion!.confidence < .85
                      ? 'Medium'
                      : 'High'} confidence · ~${widget.suggestion!.grams.round()} g',
                ),
                const Text(
                  'This food may be one of the following. Confirm a matching database entry.',
                ),
                Wrap(
                  spacing: 8,
                  children:
                      [
                            widget.suggestion!.name,
                            ...widget.suggestion!.alternatives,
                          ]
                          .map(
                            (s) => ActionChip(
                              label: Text(s),
                              onPressed: () {
                                search.text = s;
                                lookup();
                              },
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: manual,
                onChanged: (v) => setState(() => manual = v),
                title: const Text('Enter or edit nutrition values'),
              ),
              if (!manual) ...[
                TextFormField(
                  controller: search,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Search foods',
                    suffixIcon: IconButton(
                      tooltip: 'Search nutrition database',
                      onPressed: busy ? null : lookup,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onFieldSubmitted: (_) => lookup(),
                ),
                if (busy) const LinearProgressIndicator(),
                if (searched && results.isEmpty)
                  const Text(
                    'No exact matches. Try a simpler name or enter values from a reliable label.',
                  ),
                ...results.map(
                  (f) => ListTile(
                    selected: selected?.id == f.id,
                    leading: Icon(
                      selected?.id == f.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    onTap: () => setState(() => selected = f),
                    title: Text(f.name),
                    subtitle: Text(
                      '~${f.per100g.calories.round()} kcal / 100 g\n${f.attribution}',
                    ),
                  ),
                ),
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Selected: ${selected!.name}'),
                  ),
              ],
              if (manual) ...[
                const Text(
                  'Edit values per 100 g, not per serving. Use a package label or reliable source when available. Photo estimates are approximate.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Food name'),
                  validator: manual ? requiredText : null,
                ),
                TextFormField(
                  controller: labelSource,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Label or source description',
                  ),
                  validator: manual ? requiredText : null,
                ),
                ...[
                  (calories, 'Calories (kcal)', 1000.0),
                  (protein, 'Protein (g)', 100.0),
                  (carbs, 'Carbohydrates (g)', 100.0),
                  (fat, 'Fat (g)', 100.0),
                  (fiber, 'Fiber (g), optional', 100.0),
                ].map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: item.$1,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: item.$2),
                      validator: (v) =>
                          bounded(v, item.$3, optional: item.$1 == fiber),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: grams,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Portion (grams)',
                  helperText:
                      'Weigh when possible. Convert cups or pieces to grams using the label.',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(error!),
                ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : choose,
                    child: const Text('Confirm food'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> deleteMeal(BuildContext context, WidgetRef ref, Meal meal) async {
  if (!await confirmAction(
    context,
    'Delete this meal?',
    'This meal will be permanently removed from your journal.',
    label: 'Delete meal',
  )) {
    return false;
  }
  try {
    await ref.read(mealRepositoryProvider).delete(meal.userId, meal.id);
    if (context.mounted) notify(context, 'Meal deleted');
    return true;
  } catch (e) {
    if (context.mounted) notify(context, friendlyError(e));
    return false;
  }
}
