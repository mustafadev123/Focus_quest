import '../models/study_task.dart';
import '../validation/validation.dart';

/// Rule-based scoring heuristic from proposal Section 5. It is not a trained
/// machine-learning model, and it never changes any saved data.
abstract final class SmartHelper {
  static const priorityWeight = 0.50;
  static const fitWeight = 0.30;
  static const recentWeight = 0.20;

  /// Recent minutes that halve the recent-activity part.
  static const recentScale = 25;

  /// Only sessions started within this window count as recent activity.
  static const recentWindow = Duration(days: 7);

  /// Scores below this difference are treated as a tie.
  static const _tieTolerance = 1e-9;

  /// Tasks the helper may recommend: saved, not completed, and with an
  /// estimate in 5–120 minutes. Anything else is skipped, not guessed at.
  static List<StudyTask> eligible(Iterable<StudyTask> tasks) => [
        for (final t in tasks)
          if (t.id != null &&
              !t.isCompleted &&
              validateEstimatedMinutes(t.estimatedMinutes) == null)
            t,
      ];

  /// Scores one eligible task.
  static TaskScore score(
    StudyTask task, {
    required int availableMinutes,
    required int recentMinutes,
  }) {
    final p = (task.priority.value - 1) / 2;
    final f = (availableMinutes / task.estimatedMinutes).clamp(0.0, 1.0);
    final r = 1 / (1 + recentMinutes.clamp(0, 1 << 30) / recentScale);
    return TaskScore(
      task: task,
      priority: p,
      timeFit: f,
      recentActivity: r,
      recentMinutes: recentMinutes,
      total: priorityWeight * p + fitWeight * f + recentWeight * r,
    );
  }

  /// Recommends one task.
  ///
  /// [recentMinutesByTask] holds minutes studied per task in the last
  /// [recentWindow]; tasks without recent study are absent. Throws
  /// [ValidationException] when [availableMinutes] is outside 5–120.
  static HelperResult recommend({
    required List<StudyTask> tasks,
    required int availableMinutes,
    required Map<int, int> recentMinutesByTask,
  }) {
    if (validateAvailableMinutes(availableMinutes) case final error?) {
      throw ValidationException({'availableMinutes': error});
    }
    final candidates = eligible(tasks);
    if (candidates.isEmpty) return const NoEligibleTask();

    final ranked = [
      for (final t in candidates)
        score(t,
            availableMinutes: availableMinutes,
            recentMinutes: recentMinutesByTask[t.id] ?? 0),
    ]..sort(_compare);

    return Recommendation(
      best: ranked.first,
      ranked: ranked,
      availableMinutes: availableMinutes,
      usedHistory: recentMinutesByTask.values.any((m) => m > 0),
    );
  }

  /// Highest score first; ties go to the oldest task, then the lowest id.
  static int _compare(TaskScore a, TaskScore b) {
    final diff = b.total - a.total;
    if (diff.abs() > _tieTolerance) return diff > 0 ? 1 : -1;
    return _olderFirst(a.task, b.task);
  }

  static int _olderFirst(StudyTask a, StudyTask b) {
    final byDate = a.createdAt.compareTo(b.createdAt);
    return byDate != 0 ? byDate : a.id!.compareTo(b.id!);
  }

  /// The comparison baseline from proposal Section 9: the highest-priority
  /// eligible task, then the oldest, then the lowest id. Null when no task
  /// is eligible.
  static StudyTask? baseline(List<StudyTask> tasks) {
    final candidates = eligible(tasks)
      ..sort((a, b) {
        final byPriority = b.priority.value.compareTo(a.priority.value);
        return byPriority != 0 ? byPriority : _olderFirst(a, b);
      });
    return candidates.isEmpty ? null : candidates.first;
  }
}

/// The three parts of a task's score and the weighted total.
class TaskScore {
  const TaskScore({
    required this.task,
    required this.priority,
    required this.timeFit,
    required this.recentActivity,
    required this.recentMinutes,
    required this.total,
  });

  final StudyTask task;

  /// P, F and R, each between 0 and 1.
  final double priority;
  final double timeFit;
  final double recentActivity;
  final int recentMinutes;
  final double total;
}

sealed class HelperResult {
  const HelperResult();
}

/// No task can be recommended: there are none, or all are completed.
class NoEligibleTask extends HelperResult {
  const NoEligibleTask();
}

class Recommendation extends HelperResult {
  const Recommendation({
    required this.best,
    required this.ranked,
    required this.availableMinutes,
    required this.usedHistory,
  });

  final TaskScore best;

  /// Every eligible task, best first.
  final List<TaskScore> ranked;
  final int availableMinutes;

  /// False when no study was recorded in the last seven days, so only
  /// priority and time fit decided; the explanation says so.
  final bool usedHistory;

  StudyTask get task => best.task;

  /// One short phrase for the card, as in the Dashboard wireframe.
  String get summary {
    final fits = best.timeFit >= 1;
    return '${task.priority.label} priority · '
        '${fits ? 'fits your time' : 'longer than your time'}';
  }

  /// Why this task was chosen, one sentence per scoring part.
  List<String> get reasons {
    final s = best;
    final est = task.estimatedMinutes;
    return [
      '${task.priority.label} priority.',
      s.timeFit >= 1
          ? 'Its estimate of $est min fits in your $availableMinutes min.'
          : 'Its estimate of $est min is longer than your '
              '$availableMinutes min, so it fits '
              '${(s.timeFit * 100).round()}%.',
      if (!usedHistory)
        'No study history from the last 7 days was used, so only priority '
            'and time fit decided.'
      else if (s.recentMinutes == 0)
        'You have not studied it in the last 7 days.'
      else
        'You studied it for ${s.recentMinutes} min in the last 7 days.',
    ];
  }

  /// "Score 0.90 = priority 0.50 + time fit 0.20 + recent activity 0.20".
  String get scoreBreakdown {
    String f(double v) => v.toStringAsFixed(2);
    final s = best;
    return 'Score ${f(s.total)} = priority '
        '${f(SmartHelper.priorityWeight * s.priority)} + time fit '
        '${f(SmartHelper.fitWeight * s.timeFit)} + recent activity '
        '${f(SmartHelper.recentWeight * s.recentActivity)}';
  }
}
