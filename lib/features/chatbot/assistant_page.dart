import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../services/ai/broget_ai_service.dart';
import '../../widgets/common.dart';
import '../meal_tracking/meal_editor.dart';

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});
  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final message = TextEditingController();
  bool busy = false;
  String? error;
  Map<String, dynamic>? proposal;
  String? pendingId, pendingText;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> send([String? suggestion]) async {
    final text = (suggestion ?? message.text).trim();
    if (text.isEmpty || text.length > 2000 || busy) return;
    setState(() {
      busy = true;
      error = null;
      proposal = null;
    });
    try {
      if (pendingText != text) {
        pendingId = const Uuid().v4();
        pendingText = text;
      }
      final reply = await ref
          .read(aiServiceProvider)
          .chat(text, DateTime.now(), requestId: pendingId);
      message.clear();
      pendingId = null;
      pendingText = null;
      if (mounted) setState(() => proposal = reply.proposal);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reviewProposal() async {
    final p = proposal;
    if (p == null) return;
    if (p['action'] == 'addMeal') {
      try {
        final j = p['meal'] as Map;
        final foods = (j['foods'] as List)
            .map((f) => MealFood.fromJson(Map<String, dynamic>.from(f)))
            .toList();
        await openMealEditor(context, foods: foods, mealType: j['mealType']);
      } catch (_) {
        if (mounted) {
          notify(
            context,
            'Please enter this meal in your journal and confirm the nutrition details.',
          );
        }
      }
    } else {
      context.go('/app/meals');
    }
    if (mounted) setState(() => proposal = null);
  }

  @override
  Widget build(BuildContext context) => PageBody(
    title: 'A little guidance, on your terms.',
    subtitle:
        'Broget AI Health Assistant · Nutrition education and ideas, informed by your own records.',
    children: [
      Panel(
        color: AppTheme.lime,
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Ask about your meals, daily balance or dinner ideas. I use your recorded information, which may be incomplete. I can’t diagnose conditions or replace professional medical advice.',
              ),
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            [
                  'What have I eaten today?',
                  'How much protein did I eat yesterday?',
                  'Suggest a dinner',
                  'Summarize my week',
                ]
                .map(
                  (s) => ActionChip(
                    label: Text(s),
                    onPressed: busy ? null : () => send(s),
                  ),
                )
                .toList(),
      ),
      AsyncPanel(
        value: ref.watch(chatProvider),
        retry: () => ref.invalidate(chatProvider),
        builder: (messages) => messages.isEmpty
            ? const EmptyPanel(
                title: 'Hello, I’m Broget AI Health Assistant.',
                message:
                    'What would you like to understand about your nutrition today?',
              )
            : Column(
                children: messages
                    .map(
                      (m) => Align(
                        alignment: m.role == 'user'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 780),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Panel(
                              color: m.role == 'user'
                                  ? const Color(0xFFE8EDDE)
                                  : Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.role == 'user'
                                        ? 'You'
                                        : 'Broget AI Health Assistant',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.green,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(m.text),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
      if (proposal != null)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A journal change needs your confirmation. Nothing has been saved.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: reviewProposal,
                child: const Text('Review in meal journal'),
              ),
            ],
          ),
        ),
      if (error != null) Panel(child: Text(error!)),
      if (busy) const LoadingPanel(message: 'Thinking…'),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: message,
              maxLength: 2000,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Ask your nutrition assistant',
                hintText: 'How does my day look so far?',
              ),
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: busy ? null : send,
                icon: const Icon(Icons.arrow_upward),
                label: const Text('Send message'),
              ),
            ),
          ],
        ),
      ),
      const Text(
        'Replies use your confirmed notes, a limited recent conversation window and relevant nutrition summaries. Older date-specific records can be retrieved when needed. Clear chat or edit remembered notes in settings.',
      ),
    ],
  );
}
