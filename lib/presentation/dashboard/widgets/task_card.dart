import 'package:flutter/material.dart';

import '../../../domain/models/study_task.dart';

/// One row of "My tasks": title, "Subject · Priority · Status" and Focus.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onFocus});

  final StudyTask task;

  /// Null disables Focus, as for completed tasks.
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.subject} · ${task.priority.label} · '
                      '${task.status.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              hint: onFocus == null
                  ? 'Completed tasks cannot be focused'
                  : 'Opens Focus Session for ${task.title}',
              child: FilledButton(
                onPressed: onFocus,
                child: const Text('Focus'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
