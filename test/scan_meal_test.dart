import 'dart:typed_data';
import 'package:health_broget/data/models/models.dart';
import 'package:health_broget/features/food_scanner/scanner_page.dart';
import 'package:health_broget/features/meal_tracking/meal_editor.dart';
import 'package:health_broget/services/ai/health_broget_service.dart';
import 'package:health_broget/services/images/food_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class TestImages extends FoodImageService {
  @override
  Future<Uint8List?> recover() async =>
      Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));
}

class TestScanAi implements HealthBrogetService {
  @override
  Future<AIAnalysis> analyzeFoodImage(
    Uint8List image, {
    bool reference = false,
    String referenceDescription = '',
  }) async => AIAnalysis('breakfast', [
    RecognizedFood(
      'Rice',
      150,
      .7,
      [],
      nutrition: FoodItem(
        id: 'ai:${'a' * 64}:0',
        name: 'Rice',
        attribution: 'AI photo estimate · user reviewed',
        per100g: const Nutrients(
          calories: 130,
          protein: 2.7,
          carbs: 28,
          fat: .3,
        ),
      ),
    ),
  ], 'Approximate photo estimate.');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('photo scan prefills an editable meal without food matching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodImageServiceProvider.overrideWithValue(TestImages()),
          aiServiceProvider.overrideWithValue(TestScanAi()),
        ],
        child: const MaterialApp(home: Scaffold(body: ScannerPage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final consent = find.byType(CheckboxListTile);
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pump(const Duration(milliseconds: 400));
    final analyze = find.widgetWithText(FilledButton, 'Analyze food');
    await tester.ensureVisible(analyze);
    await tester.tap(analyze);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MealEditor), findsOneWidget);
    expect(find.textContaining('150 g · ~195 kcal'), findsOneWidget);
    final type = find.byType(DropdownButtonFormField<String>);
    expect(
      tester.widget<DropdownButtonFormField<String>>(type).initialValue,
      'breakfast',
    );
    await tester.tap(type);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Dinner').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Dinner'), findsOneWidget);
    await tester.tap(find.text('Rice').last);
    await tester.pump(const Duration(milliseconds: 400));
    final edit = find.widgetWithText(
      SwitchListTile,
      'Enter or edit nutrition values',
    );
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pump(const Duration(milliseconds: 400));
    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    expect(
      tester.widget<TextField>(field('Calories (kcal)')).controller!.text,
      '130.0',
    );
    await tester.enterText(field('Calories (kcal)'), '140');
    await tester.ensureVisible(field('Portion (grams)'));
    await tester.enterText(field('Portion (grams)'), '175');
    final confirm = find.widgetWithText(FilledButton, 'Confirm food');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('This field is required'), findsNothing);
    expect(find.textContaining('Enter 0–'), findsNothing);
    expect(find.byType(FoodPicker), findsNothing);
    expect(find.textContaining('175 g · ~245 kcal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
