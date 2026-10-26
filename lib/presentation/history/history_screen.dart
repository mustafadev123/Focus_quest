import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/history.dart';
import '../../domain/models/session_record.dart';
import '../../domain/models/study_task.dart';
import '../../domain/report/study_report.dart';
import '../../domain/repositories/session_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/history_providers.dart';
import '../../providers/task_providers.dart';
import '../format.dart';
import '../shell/home_shell.dart';
import '../widgets/state_views.dart';
import 'report_screen.dart';
import 'widgets/session_dialog.dart';

/// Whether any session exists at all, to tell "No sessions yet" apart from
/// "nothing matches these filters".
final _hasAnySessionProvider = FutureProvider<bool>((ref) async {
  ref.watch(dataRevisionProvider);
  final records =
      await ref.watch(sessionRepositoryProvider).getRecords(SessionFilter.none);
  return records.isNotEmpty;
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(historyRecordsProvider);
    final tasks = ref.watch(tasksProvider).value ?? const <StudyTask>[];

    return Scaffold(
      appBar: AppBar(title: const Text('History and Insights')),
      body: switch (records) {
        AsyncValue(:final value?) => _HistoryList(records: value, tasks: tasks),
        AsyncError() => ErrorView(
            message: "Couldn't load your sessions.",
            onRetry: () => ref.invalidate(historyRecordsProvider),
          ),
        _ => const LoadingView(label: 'Loading sessions…'),
      },
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.records, required this.tasks});

  final List<SessionRecord> records;
  final List<StudyTask> tasks;

  Future<void> _add(BuildContext context) async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a task first, then record a session for it.')));
      return;
    }
    await showSessionDialog(context, tasks: tasks);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAny = ref.watch(_hasAnySessionProvider).value ?? true;
    final summary = ref.watch(historySummaryProvider).value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Filters(tasks: tasks),
        const SizedBox(height: 16),
        _SummaryRow(summary: summary),
        const Divider(height: 24),
        if (!hasAny)
          _NoSessions(
            onStart: () =>
                ref.read(selectedTabProvider.notifier).select(AppTab.focus),
          )
        else if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No sessions match these filters.',
                textAlign: TextAlign.center),
          )
        else
          for (final record in records) ...[
            _SessionRow(
              key: ValueKey(record.session.id),
              record: record,
              onEdit: () =>
                  showSessionDialog(context, tasks: tasks, existing: record),
              onDelete: () => _confirmDelete(context, ref, record),
            ),
            const Divider(height: 1),
          ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _add(context),
            child: const Text('Add session'),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () => _openReport(context, ref),
            child: const Text(
              'Text report',
              semanticsLabel: 'Save and view a text report of these sessions',
              style: TextStyle(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ],
    );
  }

  /// Reports exactly what History is showing, with its filters.
  void _openReport(BuildContext context, WidgetRef ref) {
    final filter = ref.read(historyFilterProvider);
    final task = tasks.where((t) => t.id == filter.taskId).firstOrNull;
    ReportScreen.open(
      context,
      StudyReportInput(
        generatedAt: ref.read(clockProvider)(),
        periodLabel: filter.range.label,
        taskLabel: task?.title ?? 'All tasks',
        subjectLabel: filter.subject ?? 'All subjects',
        records: records,
      ),
    );
  }
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, SessionRecord record) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this session?'),
      content: Text('${record.taskTitle}, '
          '${record.session.durationMinutes} min on '
          '${DateFormat.MMMd().format(record.session.startedAt)}. '
          "This can't be undone."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(sessionActionsProvider).delete(record.session.id!);
    messenger.showSnackBar(const SnackBar(content: Text('Session deleted')));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't delete the session. Try again.")));
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.tasks});

  final List<StudyTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterProvider);
    final notifier = ref.read(historyFilterProvider.notifier);
    final subjects = ref.watch(subjectsProvider).value ?? const <String>[];

    // A filter pointing at a deleted task or subject falls back to "All".
    final taskId =
        tasks.any((t) => t.id == filter.taskId) ? filter.taskId : null;
    final subject = subjects.contains(filter.subject) ? filter.subject : null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterDropdown<int?>(
          semanticLabel: 'Filter sessions by task',
          value: taskId,
          options: [null, for (final t in tasks) t.id],
          labelOf: (id) => id == null
              ? 'All tasks'
              : tasks.firstWhere((t) => t.id == id).title,
          onChanged: notifier.setTask,
        ),
        _FilterDropdown<String?>(
          semanticLabel: 'Filter sessions by subject',
          value: subject,
          options: [null, ...subjects],
          labelOf: (s) => s ?? 'All subjects',
          onChanged: notifier.setSubject,
        ),
        _FilterDropdown<HistoryRange>(
          semanticLabel: 'Filter sessions by date',
          value: filter.range,
          options: HistoryRange.values,
          labelOf: (r) => r.label,
          onChanged: (r) => notifier.setRange(r ?? filter.range),
        ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.semanticLabel,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String semanticLabel;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        // Shrinks with an ellipsis when a long task title would not fit.
        child: IntrinsicWidth(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              selectedItemBuilder: (_) => [
                for (final option in options)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(labelOf(option),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option,
                    child: Text(labelOf(option),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

/// "1h 45m studied · 3 sessions" for the filtered list.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  /// Null while the totals are being prepared.
  final HistorySummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;
    final count = s?.sessions;
    return Semantics(
      label: s == null
          ? 'Totals loading'
          : '${describeStudyTime(s.totalMinutes)} studied in '
              '${s.sessions} ${s.sessions == 1 ? 'session' : 'sessions'}',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 8,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(
              text: s == null ? '—' : formatStudyTime(s.totalMinutes),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: ' studied', style: theme.textTheme.bodyMedium),
          ])),
          Text(
            count == null
                ? ''
                : '$count ${count == 1 ? 'session' : 'sessions'}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final SessionRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final date = DateFormat.MMMd().format(record.session.startedAt);
    final description = '${record.taskTitle} on $date';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.taskTitle,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(date, style: muted),
                  Text('${record.session.durationMinutes} min', style: muted),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(minimumSize: const Size(56, 40)),
            child: Text('Edit', semanticsLabel: 'Edit session, $description'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(minimumSize: const Size(56, 40)),
            child:
                Text('Delete', semanticsLabel: 'Delete session, $description'),
          ),
        ],
      ),
    );
  }
}

class _NoSessions extends StatelessWidget {
  const _NoSessions({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          const ExcludeSemantics(child: Icon(Icons.bar_chart, size: 32)),
          const SizedBox(height: 8),
          Text('No sessions yet',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Start a focus session to see your history here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: onStart, child: const Text('Start a focus session')),
        ],
      ),
    );
  }
}
