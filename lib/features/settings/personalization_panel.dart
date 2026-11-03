import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai/broget_ai_service.dart';
import '../../core/errors/app_error.dart';
import '../../widgets/common.dart';

class PersonalizationPanel extends ConsumerStatefulWidget {
  const PersonalizationPanel({super.key});
  @override
  ConsumerState<PersonalizationPanel> createState() =>
      _PersonalizationPanelState();
}

class _PersonalizationPanelState extends ConsumerState<PersonalizationPanel> {
  final notes = TextEditingController();
  Map<String, dynamic>? preferences;
  Object? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      error = null;
      preferences = null;
    });
    try {
      final api = ref.read(apiProvider);
      final results = await Future.wait([
        api.request('GET', '/assistant-memory'),
        api.request('GET', '/reminders/preferences'),
      ]);
      if (mounted) {
        setState(() {
          notes.text = results[0]['notes'];
          preferences = results[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final api = ref.read(apiProvider);
      await api.request('PUT', '/assistant-memory', {
        'notes': notes.text.trim(),
      });
      await api.request('PUT', '/reminders/preferences', preferences);
      if (mounted) {
        notify(context, 'Assistant notes and reminder preferences saved');
      }
    } catch (e) {
      if (mounted) notify(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget hour(String key, String label) => DropdownButtonFormField<int>(
    initialValue: preferences![key],
    decoration: InputDecoration(labelText: label),
    items: List.generate(
      24,
      (h) => DropdownMenuItem(
        value: h,
        child: Text('${h.toString().padLeft(2, '0')}:00'),
      ),
    ),
    onChanged: busy ? null : (v) => setState(() => preferences![key] = v),
  );
  @override
  Widget build(BuildContext context) {
    if (error != null) return ErrorPanel(error: error!, retry: load);
    if (preferences == null) return const LoadingPanel();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What would you like your assistant to remember?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Save facts and preferences you choose to share. These notes are separate from your chat history; the assistant never silently turns a conversation into a diagnosis or a permanent fact.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: notes,
            maxLength: 1000,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Your confirmed notes',
              hintText:
                  'For example: I prefer simple vegetarian dinners and eat lunch at work.',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your reminder routine',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Enable personalized reminders above, then choose the kinds you want. Times use your fixed reporting timezone. FCM push delivery is not connected yet; reminders appear in your private inbox.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: preferences!['mealReminders'],
            onChanged: busy
                ? null
                : (v) => setState(() => preferences!['mealReminders'] = v),
            title: const Text('Remind me about an unrecorded dinner'),
            subtitle: const Text(
              'An absent log does not mean you have not eaten.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: preferences!['movementReminders'],
            onChanged: busy
                ? null
                : (v) => setState(() => preferences!['movementReminders'] = v),
            title: const Text('Offer an optional movement break'),
            subtitle: const Text(
              'Not based on calories or measured activity. Disabled for minors and special care profiles.',
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children:
                  [
                        hour('mealHour', 'Meal log reminder'),
                        hour('movementHour', 'Movement reminder'),
                        hour('quietStart', 'Quiet hours start'),
                        hour('quietEnd', 'Quiet hours end'),
                      ]
                      .map(
                        (w) => SizedBox(
                          width: c.maxWidth >= 600
                              ? (c.maxWidth - 16) / 2
                              : c.maxWidth,
                          child: w,
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Saving…' : 'Save personalization'),
          ),
        ],
      ),
    );
  }
}
