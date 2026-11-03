import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../widgets/common.dart';
import '../dashboard/dashboard_page.dart';
import 'meal_editor.dart';
import '../food_scanner/scanner_page.dart';

class MealsPage extends ConsumerStatefulWidget {
  const MealsPage({super.key});
  @override
  ConsumerState<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends ConsumerState<MealsPage> {
  final List<Meal> meals = [];
  MealPage? page;
  bool busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => load(reset: true));
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        meals.clear();
        page = null;
      }
    });
    try {
      final result = await ref
          .read(mealRepositoryProvider)
          .page(ref.read(sessionProvider).value!.uid, cursor: page?.cursor);
      if (mounted) {
        setState(() {
          meals.addAll(result.meals);
          page = result;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    title: 'Your meal journal',
    subtitle:
        'The meals that make up your days. Tap any entry to review or correct it.',
    action: Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Scan a meal')),
                        body: const ScannerPage(returnAfterSave: true),
                      ),
                    ),
                  );
                  if (saved == true && mounted) load(reset: true);
                },
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Scan meal photo'),
        ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  if (await openMealEditor(context) == true) load(reset: true);
                },
          icon: const Icon(Icons.add),
          label: const Text('Add manually'),
        ),
      ],
    ),
    children: [
      if (error != null) ErrorPanel(error: error!, retry: () => load()),
      if (!busy && meals.isEmpty && error == null)
        const EmptyPanel(
          title: 'A journal starts with one meal.',
          message: 'Add a meal manually or scan a food photo to get started.',
        ),
      if (meals.isNotEmpty)
        Panel(
          child: Column(
            children: meals
                .map(
                  (m) => MealTile(
                    key: ValueKey(m.id),
                    meal: m,
                    onChange: () => load(reset: true),
                  ),
                )
                .toList(),
          ),
        ),
      if (busy) const LoadingPanel(),
      if (page?.hasMore == true && !busy)
        OutlinedButton(onPressed: load, child: const Text('Load more meals')),
      if (!busy && meals.isNotEmpty)
        TextButton.icon(
          onPressed: () => load(reset: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh journal'),
        ),
    ],
  );
}
