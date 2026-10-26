import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/helper/smart_helper.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/domain/validation/validation.dart';

/// Builds a task as in the proposal's Section 9 examples.
StudyTask _task(
  int id,
  int priority,
  int minutes, {
  int createdMinute = 0,
  TaskStatus status = TaskStatus.pending,
}) =>
    StudyTask(
      id: id,
      title: 'Task $id',
      subject: 'Subject',
      priority: TaskPriority.fromValue(priority)!,
      estimatedMinutes: minutes,
      status: status,
      createdAt: DateTime(2026, 10, 20, 9, createdMinute),
      updatedAt: DateTime(2026, 10, 20, 9, createdMinute),
    );

Recommendation _recommend(List<StudyTask> tasks, int available,
        [Map<int, int> recent = const {}]) =>
    SmartHelper.recommend(
      tasks: tasks,
      availableMinutes: available,
      recentMinutesByTask: recent,
    ) as Recommendation;

double _scoreOf(Recommendation r, int id) =>
    r.ranked.firstWhere((s) => s.task.id == id).total;

void main() {
  group('proposal Section 9 worked examples', () {
    test('Normal: scores 0.90, 0.62 and 0.50; A is recommended', () {
      final a = _task(1, 3, 90, createdMinute: 1);
      final b = _task(2, 2, 30, createdMinute: 2);
      final c = _task(3, 1, 45, createdMinute: 3);
      final r = _recommend([a, b, c], 60, {2: 50});

      expect(_scoreOf(r, 1), closeTo(0.90, 0.005));
      expect(_scoreOf(r, 2), closeTo(0.62, 0.005));
      expect(_scoreOf(r, 3), closeTo(0.50, 0.005));
      expect(r.task, a);
      expect(SmartHelper.baseline([a, b, c]), a);
    });

    test('Time fit and recent study change the result: B 0.75 beats A 0.70',
        () {
      final a = _task(1, 3, 90, createdMinute: 1);
      final b = _task(2, 2, 30, createdMinute: 2);
      final r = _recommend([a, b], 30, {1: 25});

      expect(_scoreOf(r, 1), closeTo(0.70, 0.005));
      expect(_scoreOf(r, 2), closeTo(0.75, 0.005));
      expect(r.task, b);
      expect(SmartHelper.baseline([a, b]), a);
    });

    test('No history: A 0.85, B 0.75; the explanation says so', () {
      final a = _task(1, 3, 120, createdMinute: 1);
      final b = _task(2, 2, 30, createdMinute: 2);
      final r = _recommend([a, b], 60);

      expect(_scoreOf(r, 1), closeTo(0.85, 0.005));
      expect(_scoreOf(r, 2), closeTo(0.75, 0.005));
      expect(r.task, a);
      expect(r.usedHistory, isFalse);
      expect(r.reasons.last, contains('No study history'));
      expect(SmartHelper.baseline([a, b]), a);
    });

    test('No eligible task: none, or every task completed', () {
      expect(
          SmartHelper.recommend(
              tasks: const [], availableMinutes: 30, recentMinutesByTask: {}),
          isA<NoEligibleTask>());
      expect(
          SmartHelper.recommend(
            tasks: [_task(1, 3, 30, status: TaskStatus.completed)],
            availableMinutes: 30,
            recentMinutesByTask: const {},
          ),
          isA<NoEligibleTask>());
      expect(SmartHelper.baseline(const []), isNull);
    });

    test('Invalid input: a 0-minute task is skipped; 3 or 200 is rejected', () {
      final broken = _task(1, 3, 0);
      final ok = _task(2, 1, 30);
      expect(_recommend([broken, ok], 30).task, ok);
      expect(SmartHelper.baseline([broken, ok]), ok);

      for (final bad in [3, 200]) {
        expect(
          () => SmartHelper.recommend(
              tasks: [ok], availableMinutes: bad, recentMinutesByTask: {}),
          throwsA(isA<ValidationException>()),
          reason: '$bad minutes',
        );
      }
    });

    test('Boundary: time fit 0.04 and 1.00; 500 recent minutes gives R≈0.05',
        () {
      final long = SmartHelper.score(_task(1, 2, 120),
          availableMinutes: 5, recentMinutes: 0);
      final short = SmartHelper.score(_task(2, 2, 5),
          availableMinutes: 120, recentMinutes: 0);
      final busy = SmartHelper.score(_task(3, 2, 30),
          availableMinutes: 30, recentMinutes: 500);

      expect(long.timeFit, closeTo(0.04, 0.005));
      expect(short.timeFit, 1.0);
      expect(busy.recentActivity, closeTo(0.05, 0.005));
      expect(busy.recentActivity, greaterThan(0));
    });

    test('Tie: both 0.75; the task created first wins, then the lower id', () {
      final first = _task(2, 2, 30, createdMinute: 1);
      final second = _task(1, 2, 30, createdMinute: 2);
      final r = _recommend([second, first], 30);
      expect(_scoreOf(r, 1), _scoreOf(r, 2));
      expect(r.task, first);
      expect(SmartHelper.baseline([second, first]), first);

      final sameTimeHigh = _task(7, 2, 30);
      final sameTimeLow = _task(4, 2, 30);
      expect(_recommend([sameTimeHigh, sameTimeLow], 30).task, sameTimeLow);
    });

    test('Counterexample: X 0.53, Y 0.75; deadlines are not modelled', () {
      final x = _task(1, 2, 120, createdMinute: 1); // due tomorrow
      final y = _task(2, 2, 30, createdMinute: 2); // due in two weeks
      final r = _recommend([x, y], 30);

      // Exactly 0.525, which the proposal rounds to 0.53.
      expect(_scoreOf(r, 1), closeTo(0.525, 1e-9));
      expect(_scoreOf(r, 2), closeTo(0.75, 0.005));
      expect(r.task, y);
      expect(SmartHelper.baseline([x, y]), x); // only because X is older
    });
  });

  group('explanation', () {
    test('names priority, time fit and recent activity', () {
      final r = _recommend([_task(1, 3, 90), _task(2, 1, 20)], 60, {1: 10});
      expect(r.reasons, [
        'High priority.',
        'Its estimate of 90 min is longer than your 60 min, so it fits 67%.',
        'You studied it for 10 min in the last 7 days.',
      ]);
      expect(r.summary, 'High priority · longer than your time');
      expect(
          r.scoreBreakdown,
          // R = 1 / (1 + 10/25) = 0.714, weighted 0.14.
          'Score 0.84 = priority 0.50 + time fit 0.20 + recent activity 0.14');
    });

    test('says when a task was not studied recently but others were', () {
      final r = _recommend([_task(1, 3, 25), _task(2, 1, 20)], 30, {2: 40});
      expect(r.reasons[1], 'Its estimate of 25 min fits in your 30 min.');
      expect(r.reasons[2], 'You have not studied it in the last 7 days.');
      expect(r.summary, 'High priority · fits your time');
    });
  });

  test('ranking lists every eligible task, best first', () {
    final r =
        _recommend([_task(1, 1, 30), _task(2, 3, 30), _task(3, 2, 30)], 30);
    expect(r.ranked.map((s) => s.task.id), [2, 3, 1]);
  });
}
