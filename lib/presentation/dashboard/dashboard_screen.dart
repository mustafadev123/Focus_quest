import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates.dart';
import '../../domain/models/study_task.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/task_providers.dart';
import '../shell/home_shell.dart';
import '../task_actions.dart';
import '../task_form/task_form_screen.dart';
import '../widgets/state_views.dart';
import 'widgets/summary_card.dart';
import 'widgets/task_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// From this width the task list sits beside the progress summary.
  static const wideLayoutWidth = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('FocusQuest')),
      // Keep the current list visible while it refreshes after a change.
      body: switch (tasks) {
        AsyncValue(:final value?) => _Loaded(allTasks: value),
        AsyncError() => ErrorView(
            message: "Couldn't load your tasks.",
            onRetry: () => ref.invalidate(tasksProvider),
          ),
        _ => const LoadingView(label: 'Loading tasks…'),
      },
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.allTasks});

  final List<StudyTask> allTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyMinutes = ref.watch(weeklyStudyMinutesProvider).value;
    final summary = SummaryCard(
      completedTasks: completedCount(allTasks),
      totalTasks: allTasks.length,
      studiedMinutes: weeklyMinutes,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= DashboardScreen.wideLayoutWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.4,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                  children: [summary],
                ),
              ),
              Expanded(child: _TaskList(allTasks: allTasks, header: null)),
            ],
          );
        }
        return _TaskList(allTasks: allTasks, header: summary);
      },
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.allTasks, required this.header});

  final List<StudyTask> allTasks;

  /// Shown above "My tasks" in the portrait layout.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(statusFilterProvider);
    final visible = ref.watch(visibleTasksProvider).value ?? const [];
    final selectedId = ref.watch(selectedTaskIdProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (header != null) ...[header!, const SizedBox(height: 16)],
        // Wraps so the filter moves below the heading at large text sizes.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Semantics(
              header: true,
              child: Text(
                'My tasks (${visible.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _StatusFilter(value: filter),
          ],
        ),
        const SizedBox(height: 8),
        if (allTasks.isEmpty)
          const _EmptyTasks()
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No tasks match this filter.',
                textAlign: TextAlign.center),
          )
        else
          for (final task in visible) ...[
            _SwipeToDelete(
              key: ValueKey(task.id),
              task: task,
              child: TaskCard(
                task: task,
                selected: task.id == selectedId,
                onTap: () =>
                    ref.read(selectedTaskIdProvider.notifier).select(task.id),
                onFocus: task.isCompleted ? null : () => _focus(ref, task),
                onEdit: () => TaskFormScreen.open(context, taskId: task.id),
                onDelete: () => confirmAndDeleteTask(context, ref, task),
              ),
            ),
            const SizedBox(height: 8),
          ],
        if (allTasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _AddTaskButton(),
        ],
      ],
    );
  }

  void _focus(WidgetRef ref, StudyTask task) {
    ref.read(selectedTaskIdProvider.notifier).select(task.id);
    ref.read(selectedTabProvider.notifier).select(AppTab.focus);
  }
}

/// Swipe left to delete. The card always slides back; if the deletion is
/// confirmed, the refreshed list removes it.
class _SwipeToDelete extends ConsumerWidget {
  const _SwipeToDelete({super.key, required this.task, required this.child});

  final StudyTask task;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismiss-${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete', style: TextStyle(color: scheme.onPrimary)),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline, color: scheme.onPrimary),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await confirmAndDeleteTask(context, ref, task);
        return false;
      },
      child: child,
    );
  }
}

class _StatusFilter extends ConsumerWidget {
  const _StatusFilter({required this.value});

  final TaskStatus? value;

  static const _options = <TaskStatus?>[null, ...TaskStatus.values];

  static String _label(TaskStatus? status) => status?.label ?? 'All';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Filter tasks by status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        // Sized to its label, but shrinks with an ellipsis when the label
        // is wider than the screen at large text sizes.
        child: IntrinsicWidth(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TaskStatus?>(
              value: value,
              isExpanded: true,
              selectedItemBuilder: (_) => [
                for (final option in _options)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Status: ${_label(option)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              items: [
                for (final option in _options)
                  DropdownMenuItem(value: option, child: Text(_label(option))),
              ],
              onChanged: (status) =>
                  ref.read(statusFilterProvider.notifier).set(status),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text('No tasks yet',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Add your first task.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          const _AddTaskButton(expand: false),
        ],
      ),
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton({this.expand = true});

  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: () => TaskFormScreen.open(context),
      icon: const Icon(Icons.add),
      label: const Text('Add task'),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
