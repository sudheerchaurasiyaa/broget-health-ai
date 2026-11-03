import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/models.dart';
import '../../services/ai/broget_ai_service.dart';
import '../../services/images/food_images.dart';
import '../../core/errors/app_error.dart';
import '../../widgets/common.dart';
import '../meal_tracking/meal_editor.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key, this.returnAfterSave = false});
  final bool returnAfterSave;
  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  late final images = ref.read(foodImageServiceProvider);
  final referenceText = TextEditingController();
  Uint8List? bytes;
  AIAnalysis? analysis;
  final Map<int, MealFood> confirmed = {};
  bool reference = false, consent = false, busy = false;
  String? error;
  String id = const Uuid().v4();
  DateTime photoTime = DateTime.now();
  @override
  void initState() {
    super.initState();
    recover();
  }

  Future<void> recover() async {
    try {
      final recovered = await images.recover();
      if (recovered != null && mounted) setState(() => bytes = recovered);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  @override
  void dispose() {
    referenceText.dispose();
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final image = await images.pick(source);
      if (image != null && mounted) {
        setState(() {
          bytes = image;
          photoTime = DateTime.now();
          analysis = null;
          confirmed.clear();
          id = const Uuid().v4();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> analyze() async {
    if (bytes == null || !consent) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(aiServiceProvider)
          .analyzeFoodImage(
            bytes!,
            reference: reference,
            referenceDescription: referenceText.text,
          );
      if (result.foods.isEmpty) {
        if (mounted) {
          setState(() {
            analysis = null;
            confirmed.clear();
            error =
                'No food could be identified. Try a clearer food photo or add your meal manually.';
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          analysis = result;
          confirmed.clear();
          for (var i = 0; i < result.foods.length; i++) {
            final estimate = result.foods[i].estimatedMealFood;
            if (estimate != null) confirmed[i] = estimate;
          }
        });
        if (confirmed.length == result.foods.length) await save();
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> correct(int index) async {
    final food = await showDialog<MealFood>(
      context: context,
      builder: (_) => FoodPicker(
        existing: confirmed[index],
        suggestion: confirmed[index] == null ? analysis!.foods[index] : null,
      ),
    );
    if (food != null && mounted) setState(() => confirmed[index] = food);
  }

  Future<void> save() async {
    if (analysis == null || confirmed.length != analysis!.foods.length) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!mounted) return;
      final saved = await openMealEditor(
        context,
        foods: List.generate(analysis!.foods.length, (i) => confirmed[i]!),
        mealType: analysis!.mealType,
        stableId: id,
        eatenAt: photoTime,
      );
      if (saved == true) {
        if (mounted) {
          if (widget.returnAfterSave) {
            Navigator.of(context).pop(true);
            return;
          }
          setState(() {
            bytes = null;
            analysis = null;
            confirmed.clear();
            id = const Uuid().v4();
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    title: 'A closer look at your plate.',
    subtitle:
        'Snap it. Check it. Make it yours. Every result is an estimate you control.',
    children: [
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bytes == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 72),
                    SizedBox(height: 16),
                    Text('Start with a clear photo of your meal'),
                    Text('JPEG, PNG or WebP · up to 10 MB / 16 MP'),
                  ],
                ),
              ),
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  bytes!,
                  height: 280,
                  fit: BoxFit.contain,
                  semanticLabel: 'Selected food photograph',
                ),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : () => pick(ImageSource.gallery),
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(
                    bytes == null ? 'Choose a photo' : 'Choose another photo',
                  ),
                ),
                if (!kIsWeb ||
                    defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Use camera'),
                  ),
              ],
            ),
            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'On a mobile browser, the upload picker may also offer your camera. If camera access is unavailable, upload a photo.',
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: reference,
              onChanged: busy ? null : (v) => setState(() => reference = v),
              title: const Text('Use a reference object'),
              subtitle: const Text(
                'For a better portion-size estimate, place a standard-size reference object such as a coin beside the food. It is a visual scale aid, not an exact measurement.',
              ),
            ),
            if (reference)
              TextField(
                controller: referenceText,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Reference object and known size',
                  hintText: 'For example, a coin with a 24 mm diameter',
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: consent,
              onChanged: busy ? null : (v) => setState(() => consent = v!),
              title: const Text(
                'I agree to process this food image for analysis.',
              ),
              subtitle: const Text(
                'The resized photo is sent for analysis but is not saved. Avoid people and private information. Photo storage is coming soon.',
              ),
            ),
            if (busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Working on your photo. This can take a moment…'),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(error!),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy || bytes == null || !consent ? null : analyze,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(error == null ? 'Analyze food' : 'Retry analysis'),
            ),
            TextButton(
              onPressed: busy ? null : () => openMealEditor(context),
              child: const Text('Prefer to log manually?'),
            ),
          ],
        ),
      ),
      if (analysis != null)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'AI estimate · review required',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(analysis!.notes),
              const SizedBox(height: 16),
              ...analysis!.foods.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(confirmed[e.key]?.food.name ?? e.value.name),
                    subtitle: Text(
                      '~${confirmed[e.key]?.grams.round() ?? e.value.grams.round()} g · ${e.value.confidence < .6
                          ? 'Low'
                          : e.value.confidence < .85
                          ? 'Medium'
                          : 'High'} confidence\n${confirmed.containsKey(e.key) ? '~${confirmed[e.key]!.nutrients.calories.round()} kcal · tap to edit estimate' : 'Choose a food match and confirm the portion'}',
                    ),
                    isThreeLine: true,
                    trailing: Icon(
                      confirmed.containsKey(e.key)
                          ? Icons.check_circle_outline
                          : Icons.edit_outlined,
                    ),
                    onTap: busy ? null : () => correct(e.key),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy || confirmed.length != analysis!.foods.length
                    ? null
                    : save,
                child: const Text('Review meal & save'),
              ),
            ],
          ),
        ),
    ],
  );
}
