import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/insights.dart';
import '../../format.dart';

/// "Last 7 days" bar chart of study minutes, oldest day on the left and
/// today on the right. Days without study keep an empty column.
class DailyMinutesChart extends StatelessWidget {
  const DailyMinutesChart({
    super.key,
    required this.days,
    required this.scope,
  });

  /// Seven days, oldest first, as from [dailyMinutes].
  final List<DayTotal> days;

  /// Which filters apply, e.g. "All tasks · All subjects".
  final String scope;

  static const barAreaHeight = 96.0;

  /// One sentence for screen readers instead of 21 separate labels.
  String _describe() {
    final weekday = DateFormat.EEEE();
    final total = days.fold(0, (s, d) => s + d.minutes);
    if (total == 0) return 'Last 7 days, $scope: no study recorded.';
    final best = days.reduce((a, b) => b.minutes > a.minutes ? b : a);
    final perDay = [
      for (final d in days) '${weekday.format(d.day)} ${d.minutes} minutes',
    ].join(', ');
    return 'Last 7 days, $scope. Total ${describeStudyTime(total)}. '
        'Most on ${weekday.format(best.day)}, ${best.minutes} minutes. '
        '$perDay.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final maxMinutes = days.fold(0, (m, d) => d.minutes > m ? d.minutes : m);
    final empty = maxMinutes == 0;
    final weekday = DateFormat.E();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 days',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(scope, style: muted),
          Text('Uses the task and subject filters, not the date filter.',
              style: muted),
          const SizedBox(height: 12),
          // Its own focus stop for screen readers, separate from the title.
          Semantics(
            container: true,
            label: _describe(),
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: _DayColumn(
                      minutes: days[i].minutes,
                      fraction: empty ? 0 : days[i].minutes / maxMinutes,
                      label: i == days.length - 1
                          ? 'Today'
                          : weekday.format(days[i].day),
                      isToday: i == days.length - 1,
                    ),
                  ),
              ],
            ),
          ),
          if (empty) ...[
            const SizedBox(height: 8),
            Text('No study in the last 7 days.', style: muted),
          ],
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.minutes,
    required this.fraction,
    required this.label,
    required this.isToday,
  });

  final int minutes;

  /// Bar height relative to the busiest day, 0–1.
  final double fraction;
  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall;
    // Zero-minute days keep a thin baseline so every day stays visible.
    final barHeight = minutes == 0
        ? 2.0
        : (DailyMinutesChart.barAreaHeight * fraction).clamp(4.0, 96.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Labels shrink rather than overflow at large text sizes.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$minutes', style: small),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: DailyMinutesChart.barAreaHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: minutes == 0 ? scheme.outlineVariant : scheme.primary,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: small?.copyWith(
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}
