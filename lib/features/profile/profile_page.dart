import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../core/errors/app_error.dart';
import '../../widgets/common.dart';
import '../../widgets/brand_logo.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, this.onboarding = false});
  final bool onboarding;
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      age = TextEditingController(),
      height = TextEditingController(),
      weight = TextEditingController(),
      diet = TextEditingController(),
      allergies = TextEditingController(),
      restrictions = TextEditingController();
  String gender = 'unspecified', activity = 'sedentary', goal = 'track';
  bool care = false, busy = false, initialized = false, nameEdited = false;
  String? error;
  @override
  void dispose() {
    for (final c in [
      name,
      age,
      height,
      weight,
      diet,
      allergies,
      restrictions,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void initialize(UserProfile? profile, String? accountName) {
    final profileName = profile?.name.trim() ?? '';
    final suggestedName = profileName.isNotEmpty
        ? profileName
        : accountName?.trim() ?? '';
    // Registration publishes the session before updateDisplayName completes.
    // Keep listening for a name, but never replace what the user has edited.
    if (!nameEdited && suggestedName.isNotEmpty && name.text != suggestedName) {
      name.text = suggestedName;
    }
    if (initialized || profile == null) return;
    initialized = true;
    final h = profile.health;
    if (h != null) {
      age.text = '${h.age}';
      height.text = '${h.heightCm}';
      weight.text = '${h.weightKg}';
      gender = h.gender;
      activity = h.activity;
      goal = h.goal;
      diet.text = h.diet;
      allergies.text = h.allergies;
      restrictions.text = h.restrictions;
      care = h.specialCare;
    }
  }

  HealthProfile get health => HealthProfile(
    age: int.parse(age.text),
    gender: gender,
    heightCm: double.parse(height.text),
    weightKg: double.parse(weight.text),
    activity: activity,
    goal: goal,
    diet: diet.text.trim(),
    allergies: allergies.text.trim(),
    restrictions: restrictions.text.trim(),
    specialCare: care,
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final user = ref.read(sessionProvider).value!;
      final repo = ref.read(userRepositoryProvider);
      await repo.ensureAccount(user);
      await repo.save(user.uid, name.text, health);
      if (mounted) {
        notify(context, 'Nutrition profile saved');
        if (widget.onboarding) context.go('/app');
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget numeric(
    TextEditingController c,
    String label,
    double min,
    double max, {
    bool integer = false,
  }) => TextFormField(
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      final n = double.tryParse(v ?? '');
      return n == null ||
              !n.isFinite ||
              n < min ||
              n > max ||
              integer && n != n.roundToDouble()
          ? 'Enter ${integer ? 'a whole number' : 'a value'} from $min to $max'
          : null;
    },
  );
  Widget dropdown(
    String label,
    String value,
    Map<String, String> options,
    void Function(String) change,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList(),
    onChanged: busy ? null : (v) => setState(() => change(v!)),
  );
  @override
  Widget build(BuildContext context) {
    initialize(
      ref.watch(profileProvider).value,
      ref.watch(sessionProvider).value?.displayName,
    );
    final content = PageBody(
      title: widget.onboarding
          ? 'A plan that starts with you.'
          : 'Your nutrition profile',
      subtitle:
          'These details help estimate your needs. Your account and nutrition details are kept separately.',
      children: [
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Account information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  onChanged: (_) => nameEdited = true,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: requiredText,
                ),
                Text(ref.watch(sessionProvider).value?.email ?? ''),
                const SizedBox(height: 28),
                Text(
                  'Health & nutrition',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) => Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children:
                        [
                              numeric(
                                age,
                                'Age (years)',
                                13,
                                100,
                                integer: true,
                              ),
                              numeric(height, 'Height (cm)', 100, 250),
                              numeric(weight, 'Weight (kg)', 30, 350),
                              dropdown('Sex used for energy estimate', gender, {
                                'unspecified': 'Prefer not to specify',
                                'female': 'Female',
                                'male': 'Male',
                              }, (v) => gender = v),
                              dropdown('Activity level', activity, {
                                'sedentary': 'Mostly seated',
                                'light': 'Lightly active',
                                'moderate': 'Moderately active',
                                'active': 'Very active',
                              }, (v) => activity = v),
                              dropdown('Primary goal', goal, {
                                'track': 'General nutrition tracking',
                                'maintain': 'Maintain weight',
                                'lose': 'Lose weight',
                                'gain': 'Gain weight',
                              }, (v) => goal = v),
                            ]
                            .map(
                              (w) => SizedBox(
                                width: c.maxWidth > 650
                                    ? (c.maxWidth - 16) / 2
                                    : c.maxWidth,
                                child: w,
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: diet,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Diet preference (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: allergies,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Food allergies (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: restrictions,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Dietary restrictions (optional)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: care,
                  onChanged: (v) => setState(() => care = v),
                  title: const Text('I need individual nutrition guidance'),
                  subtitle: const Text(
                    'For pregnancy, an eating disorder or a serious medical condition. Generic calorie targets will be disabled.',
                  ),
                ),
                const Text(
                  'Targets are estimates using Mifflin–St Jeor and activity factors. No automatic target is given for minors, special care needs or unspecified sex. A qualified professional can help establish appropriate needs.',
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(error!),
                  ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(
                    busy
                        ? 'Saving…'
                        : widget.onboarding
                        ? 'Start my nutrition journal'
                        : 'Save profile',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!widget.onboarding) const TargetPanel(),
      ],
    );
    return widget.onboarding
        ? Scaffold(
            appBar: AppBar(
              title: const BrandLogo(width: 150),
              actions: [
                TextButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
            body: content,
          )
        : content;
  }
}

class TargetPanel extends ConsumerWidget {
  const TargetPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = NutritionTarget.calculate(
      ref.watch(profileProvider).value?.health,
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your estimated daily targets',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            target == null
                ? 'A generic target is not appropriate with the current profile. You can continue tracking your meals and seek individual professional guidance.'
                : 'BMR ~${target.bmr.round()} kcal · Daily energy ~${target.energy.round()} kcal\nTarget ~${target.values.calories.round()} kcal · Protein ${target.values.protein.round()} g · Carbs ${target.values.carbs.round()} g · Fat ${target.values.fat.round()} g\nActivity factor applied to BMR; weight goals adjust by 300 kcal. General adult floors: 1,200 kcal (female), 1,500 kcal (male). These are safeguards, not a personalized prescription.',
          ),
        ],
      ),
    );
  }
}
