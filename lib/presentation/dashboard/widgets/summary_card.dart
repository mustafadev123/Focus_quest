import 'package:flutter/material.dart';

import '../../format.dart';

/// "This week · 3 of 8 tasks done | 4h 20m studied" from the wireframe.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.completedTasks,
    required this.totalTasks,
    required this.studiedMinutes,
  });

  final int completedTasks;
  final int totalTasks;

  /// Null while the weekly total is still loading.
  final int? studiedMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final strong =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final minutes = studiedMinutes;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This week', style: muted),
                    const SizedBox(height: 2),
                    Text('$completedTasks of $totalTasks tasks done',
                        style: strong),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 32),
            Expanded(
              child: Semantics(
                label: minutes == null
                    ? 'Study time loading'
                    : '${describeStudyTime(minutes)} studied this week',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(minutes == null ? '—' : formatStudyTime(minutes),
                        style: strong),
                    Text('studied', style: muted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
