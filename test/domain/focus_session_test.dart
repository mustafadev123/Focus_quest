import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/focus/focus_session.dart';
import 'package:focus_quest/domain/models/study_session.dart';

final _t0 = DateTime(2026, 10, 25, 18);
DateTime _at(int minutes, [int seconds = 0]) =>
    _t0.add(Duration(minutes: minutes, seconds: seconds));

const _target = Duration(minutes: 25);
const _ready = FocusSession.ready(taskId: 1, target: _target);

void main() {
  group('allowed actions per phase', () {
    test('Ready allows only Start, and only with a task', () {
      expect(_ready.canStart, isTrue);
      expect(_ready.canPause, isFalse);
      expect(_ready.canFinish, isFalse);
      expect(_ready.canReset, isFalse);

      const noTask = FocusSession.ready(target: _target);
      expect(noTask.canStart, isFalse);
      expect(() => noTask.start(_t0), throwsA(isA<FocusTransitionException>()));
    });

    test('Running allows Pause, Finish and Reset but not Start', () {
      final running = _ready.start(_t0);
      expect(running.phase, FocusPhase.running);
      expect(running.canPause, isTrue);
      expect(running.canFinish, isTrue);
      expect(running.canReset, isTrue);
      expect(running.canStart, isFalse);
      expect(() => running.start(_at(1)),
          throwsA(isA<FocusTransitionException>()));
    });

    test('Paused allows Resume and Finish', () {
      final paused = _ready.start(_t0).pause(_at(5));
      expect(paused.canResume, isTrue);
      expect(paused.canFinish, isTrue);
      expect(paused.canPause, isFalse);
    });

    test('Awaiting save allows only Save or Reset', () {
      final review = _ready.start(_t0).finish(_at(10));
      expect(review.phase, FocusPhase.awaitingSave);
      expect(review.canFinish, isFalse);
      expect(review.canResume, isFalse);
      expect(review.canReset, isTrue);
      expect(() => review.finish(_at(11)),
          throwsA(isA<FocusTransitionException>()));
    });

    test('the task cannot change while a session is in progress', () {
      final running = _ready.start(_t0);
      expect(running.canChangeTask, isFalse);
      expect(() => running.selectTask(2),
          throwsA(isA<FocusTransitionException>()));
      expect(_ready.selectTask(2).taskId, 2);
    });
  });

  group('active time', () {
    test('counts running time from timestamps', () {
      final running = _ready.start(_t0);
      expect(running.activeAt(_at(6, 18)),
          const Duration(minutes: 6, seconds: 18));
      expect(running.remainingAt(_at(6, 18)),
          const Duration(minutes: 18, seconds: 42));
    });

    test('excludes paused time', () {
      final session = _ready
          .start(_t0)
          .pause(_at(5)) // 5 min active
          .resume(_at(15)) // 10 min paused
          .pause(_at(18)); // 3 more active

      expect(session.activeAt(_at(60)), const Duration(minutes: 8));
    });

    test('never exceeds the target', () {
      final running = _ready.start(_t0);
      expect(running.activeAt(_at(90)), _target);
      expect(running.remainingAt(_at(90)), Duration.zero);
      expect(running.reachedTargetAt(_at(25)), isTrue);
      expect(running.reachedTargetAt(_at(24, 59)), isFalse);
    });

    test('ignores a clock that moved backwards', () {
      final running = _ready.start(_t0).pause(_at(5)).resume(_at(10));
      expect(running.activeAt(_at(8)), const Duration(minutes: 5));
    });
  });

  group('finishing and the saved record', () {
    test('finishing early records an "ended early" session', () {
      final review = _ready
          .start(_t0)
          .pause(_at(4))
          .resume(_at(10))
          .finish(_at(12, 20)); // 4 + 2:20 active

      final record = review.toRecord();
      expect(record.taskId, 1);
      expect(record.startedAt, _t0);
      expect(record.endedAt, _at(12, 20));
      expect(record.durationMinutes, 6);
      expect(record.status, SessionStatus.endedEarly);
    });

    test('reaching the target records a completed session', () {
      final review = _ready.start(_t0).finish(_at(25));
      final record = review.toRecord();
      expect(record.durationMinutes, 25);
      expect(record.status, SessionStatus.completed);
    });

    test('finishing long after the target ends the record at the target', () {
      // E.g. the app was closed while running and reopened an hour later.
      final review =
          _ready.start(_t0).pause(_at(5)).resume(_at(10)).finish(_at(70));
      final record = review.toRecord();
      expect(record.durationMinutes, 25);
      expect(record.endedAt, _at(30)); // 5 active + resumed at 10 + 20
      expect(record.status, SessionStatus.completed);
    });

    test('rounds to the nearest minute and refuses under half a minute', () {
      expect(_ready.start(_t0).finish(_at(0, 29)).canSave, isFalse);
      expect(_ready.start(_t0).finish(_at(0, 30)).canSave, isTrue);
      expect(
          _ready.start(_t0).finish(_at(6, 31)).toRecord().durationMinutes, 7);
    });

    test('a 120-minute target records at most 120 minutes', () {
      const long =
          FocusSession.ready(taskId: 1, target: Duration(minutes: 120));
      final record = long.start(_t0).finish(_at(500)).toRecord();
      expect(record.durationMinutes, 120);
    });

    test('a record can be built only while awaiting save', () {
      expect(() => _ready.start(_t0).toRecord(),
          throwsA(isA<FocusTransitionException>()));
    });

    test('after saving, a second save is impossible', () {
      final saved = _ready.start(_t0).finish(_at(10)).markSaved();
      expect(saved.phase, FocusPhase.saved);
      expect(saved.canSave, isFalse);
      expect(() => saved.markSaved(), throwsA(isA<FocusTransitionException>()));
      expect(() => saved.toRecord(), throwsA(isA<FocusTransitionException>()));
    });
  });

  test('Reset discards progress but keeps the task and target', () {
    final reset = _ready.start(_t0).pause(_at(7)).reset();
    expect(reset.phase, FocusPhase.ready);
    expect(reset.taskId, 1);
    expect(reset.target, _target);
    expect(reset.activeAt(_at(20)), Duration.zero);
  });

  test('a restored checkpoint continues counting from its timestamps', () {
    final restored = FocusSession.restore(
      phase: FocusPhase.running,
      taskId: 1,
      target: _target,
      startedAt: _t0,
      activeBeforeResume: const Duration(minutes: 5),
      lastResumedAt: _at(10),
    );
    expect(restored.activeAt(_at(12)), const Duration(minutes: 7));
  });
}
