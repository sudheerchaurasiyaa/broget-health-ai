import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/ai/broget_ai_service.dart';
import '../../widgets/common.dart';
import '../../core/errors/app_error.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final List<Map<String, dynamic>> entries = [];
  bool busy = false;
  Object? error;
  String? cursor;
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = ref.read(apiProvider);
      if (reset) {
        await api.prepareHistory();
        await api.request('POST', '/notifications/check', {});
      }
      final result = await api.request(
        'GET',
        '/notifications${!reset && cursor != null ? '?cursor=${Uri.encodeQueryComponent(cursor!)}' : ''}',
      );
      if (mounted) {
        setState(() {
          if (reset) entries.clear();
          entries.addAll(
            (result['notifications'] as List).map(
              (n) => Map<String, dynamic>.from(n),
            ),
          );
          cursor = result['nextCursor'];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(Map<String, dynamic> entry, String status) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(apiProvider).request(
        'POST',
        '/notifications/${entry['id']}/action',
        {'action': status},
      );
      if (mounted) setState(() => entry['status'] = status);
      if (status == 'opened' && mounted) context.go(entry['route']);
    } catch (e) {
      if (mounted) notify(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    title: 'A little nudge, when you want it.',
    subtitle:
        'Your private reminder history. FCM push delivery will be connected later.',
    action: IconButton(
      tooltip: 'Check reminders',
      onPressed: busy ? null : () => load(reset: true),
      icon: const Icon(Icons.refresh),
    ),
    children: [
      const Panel(
        child: Text(
          'Reminders are created from your saved preferences and recorded meal information when you open or refresh this inbox. An unrecorded meal is not treated as proof that you did not eat. Push delivery is not active yet.',
        ),
      ),
      if (error != null)
        ErrorPanel(error: error!, retry: () => load(reset: true)),
      if (busy) const LoadingPanel(),
      if (!busy && error == null && entries.isEmpty)
        EmptyPanel(
          title: 'All quiet for now.',
          message:
              'Enable personalized reminders and choose your routine in settings. Quiet hours and one reminder of each kind per day keep this inbox calm.',
          action: OutlinedButton(
            onPressed: () => context.go('/app/settings'),
            child: const Text('Reminder settings'),
          ),
        ),
      ...entries.map(
        (entry) => Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry['title'],
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(entry['body']),
              const SizedBox(height: 8),
              Text(entry['reason']),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('d MMM yyyy · h:mm a').format(DateTime.parse(entry['createdAt']).toLocal())} · ${entry['status']} · Push not connected',
              ),
              if (!['dismissed', 'completed'].contains(entry['status']))
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: busy ? null : () => action(entry, 'opened'),
                      child: const Text('Open journal'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => action(entry, 'completed'),
                      child: const Text('Mark done'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => action(entry, 'dismissed'),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      if (cursor != null && !busy)
        OutlinedButton(
          onPressed: load,
          child: const Text('Load older reminders'),
        ),
    ],
  );
}
