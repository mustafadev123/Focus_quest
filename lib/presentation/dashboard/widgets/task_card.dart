import 'package:flutter/material.dart';

import '../../../domain/models/study_task.dart';

/// One row of "My tasks": title, "Subject · Priority · Status", Focus and a
/// menu. Tap selects, long press edits; the menu offers both Edit and Delete
/// so no action depends on a gesture.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onFocus,
    this.selected = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final StudyTask task;

  /// Null disables Focus, as for completed tasks.
  final VoidCallback? onFocus;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Implicit animation for the selected task.
    return AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? scheme.surfaceContainerHigh : scheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          onLongPress: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    selected: selected,
                    onLongPressHint: 'Edit task',
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
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
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
                PopupMenuButton<_CardAction>(
                  tooltip: 'More actions for ${task.title}',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) => switch (action) {
                    _CardAction.edit => onEdit?.call(),
                    _CardAction.delete => onDelete?.call(),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _CardAction.edit, child: Text('Edit')),
                    PopupMenuItem(
                        value: _CardAction.delete, child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _CardAction { edit, delete }
