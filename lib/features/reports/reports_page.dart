import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/errors/app_error.dart';
import '../../data/models/models.dart';
import '../../data/models/nutrition_report.dart';
import '../../data/repositories/repositories.dart';
import '../../services/ai/broget_ai_service.dart';
import '../../widgets/common.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String period = 'week';
  DateTime anchor = dayStart(DateTime.now());
  Future<NutritionReport>? future;
  bool summarizing = false;
  String? explanation;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    reload();
  }

  (DateTime, DateTime) get bounds => reportBounds(anchor, period);
  void reload() {
    revision++;
    final range = bounds;
    future = ref.read(apiProvider).nutritionReport(range.$1, range.$2);
    explanation = null;
  }

  Future<void> summarize() async {
    final version = revision, range = bounds;
    setState(() => summarizing = true);
    try {
      final text = await ref
          .read(aiServiceProvider)
          .generateNutritionSummary(range.$1, range.$2);
      if (mounted && version == revision) setState(() => explanation = text);
    } catch (e) {
      if (mounted) notify(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => summarizing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    title: 'See the bigger picture.',
    subtitle:
        'Daily, weekly, monthly and yearly patterns from your own recorded meals.',
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButtonFormField<String>(
            initialValue: period,
            decoration: const InputDecoration(
              labelText: 'Report period',
              constraints: BoxConstraints(maxWidth: 210),
            ),
            items: const [
              DropdownMenuItem(value: 'day', child: Text('Daily')),
              DropdownMenuItem(value: 'week', child: Text('Weekly')),
              DropdownMenuItem(value: 'month', child: Text('Monthly')),
              DropdownMenuItem(value: 'year', child: Text('Yearly')),
            ],
            onChanged: (v) => setState(() {
              period = v!;
              reload();
            }),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: anchor.isAfter(DateTime.now())
                    ? DateTime.now()
                    : anchor,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  anchor = date;
                  reload();
                });
              }
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              period == 'year'
                  ? '${anchor.year}'
                  : period == 'month'
                  ? DateFormat('MMMM yyyy').format(anchor)
                  : DateFormat('d MMM yyyy').format(anchor),
            ),
          ),
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: () => setState(reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      FutureBuilder<NutritionReport>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorPanel(
              error: snapshot.error!,
              retry: () => setState(reload),
            );
          }
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData) {
            return const LoadingPanel();
          }
          final report = snapshot.data!;
          final target = NutritionTarget.calculate(
            ref.watch(profileProvider).value?.health,
          );
          if (report.mealCount == 0) {
            return const EmptyPanel(
              title: 'Your patterns will grow with you.',
              message:
                  'No meals are recorded in this period. Log meals to build your nutrition report.',
            );
          }
          final yearly = period == 'year', average = report.average;
          final buckets = report.buckets(yearly);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${DateFormat('d MMM yyyy').format(report.start)} – ${DateFormat('d MMM yyyy').format(report.end.subtract(const Duration(days: 1)))}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Reporting timezone: ${report.timeZone}. This fixed journal timezone keeps historical dates consistent.',
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      [
                            (
                              'Average energy',
                              '~${average.calories.round()} kcal',
                            ),
                            (
                              'Average protein',
                              '~${average.protein.round()} g',
                            ),
                            ('Meals logged', '${report.mealCount}'),
                            (
                              'Days logged',
                              '${report.loggedDays} / ${report.days.length}',
                            ),
                          ]
                          .map(
                            (v) => SizedBox(
                              width: c.maxWidth < 500
                                  ? (c.maxWidth - 12) / 2
                                  : (c.maxWidth - 36) / 4,
                              child: Panel(
                                padding: 18,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.$1),
                                    const SizedBox(height: 12),
                                    Text(
                                      v.$2,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 20),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      yearly
                          ? 'Monthly average energy · estimated kcal per logged day'
                          : 'Daily energy · estimated kcal',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: ReportChart(
                        buckets: buckets,
                        yearly: yearly,
                        target: target?.values.calories,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Blank days mean no recorded meals. Averages include logged days only; partial logs may understate intake.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total energy: ~${report.totals.calories.round()} kcal\nAverage carbs: ~${average.carbs.round()} g · fat: ~${average.fat.round()} g\nAverage fiber: ${average.fiber == null ? 'not fully available' : '~${average.fiber!.round()} g'}',
                    ),
                    if (target != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '${(report.adherence(target.values.calories) * 100).round()}% of logged days were within 10% of your current estimated calorie target. Historical targets may have differed.',
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: summarizing ? null : summarize,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(
                        summarizing
                            ? 'Preparing explanation…'
                            : 'Explain my report',
                      ),
                    ),
                    if (explanation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SelectableText(explanation!),
                      ),
                  ],
                ),
              ),
              if (yearly) ...[
                const SizedBox(height: 20),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Month by month',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ...buckets.map(
                        (bucket) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            DateFormat('MMMM yyyy').format(bucket.start),
                          ),
                          subtitle: Text(
                            '${bucket.loggedDays} days logged · ~${bucket.total.calories.round()} kcal total · ~${bucket.averageCalories.round()} kcal per logged day',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => setState(() {
                            anchor = bucket.start;
                            period = 'month';
                            reload();
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class ReportChart extends StatelessWidget {
  const ReportChart({
    super.key,
    required this.buckets,
    required this.yearly,
    this.target,
  });
  final List<ReportBucket> buckets;
  final bool yearly;
  final double? target;
  @override
  Widget build(BuildContext context) {
    final values = buckets
        .map((b) => yearly ? b.averageCalories : b.total.calories)
        .toList();
    final maximum =
        math.max(1, math.max(target ?? 0, values.fold<double>(0, math.max))) *
        1.15;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: buckets.asMap().entries.map((entry) {
        final bucket = entry.value, value = values[entry.key];
        return Expanded(
          child: Tooltip(
            message:
                '${DateFormat(yearly ? 'MMM yyyy' : 'd MMM').format(bucket.start)}: ${bucket.loggedDays == 0 ? 'No logs' : '~${value.round()} kcal'}',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Container(
                      height: bucket.loggedDays == 0
                          ? 3
                          : math.max(5, value / maximum * 175),
                      decoration: BoxDecoration(
                        color: bucket.loggedDays == 0
                            ? const Color(0xFFDBE0D5)
                            : AppTheme.green,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (yearly ||
                      buckets.length <= 7 ||
                      bucket.start.day % 5 == 0)
                    Text(
                      yearly ? '${bucket.start.month}' : '${bucket.start.day}',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
