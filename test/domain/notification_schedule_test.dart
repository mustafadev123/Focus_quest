import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/focus/focus_session.dart';
import 'package:focus_quest/domain/models/app_settings.dart';
import 'package:focus_quest/domain/services/notification_service.dart';

void main() {
  group('nextReminderAt', () {
    const sevenPm = ReminderTime(19, 0);

    test('is later today when the time has not passed', () {
      expect(nextReminderAt(sevenPm, DateTime(2026, 10, 25, 18, 30)),
          DateTime(2026, 10, 25, 19));
    });

    test('is tomorrow when the time has passed or is now', () {
      expect(nextReminderAt(sevenPm, DateTime(2026, 10, 25, 19, 1)),
          DateTime(2026, 10, 26, 19));
      expect(nextReminderAt(sevenPm, DateTime(2026, 10, 25, 19)),
          DateTime(2026, 10, 26, 19));
    });

    test('rolls over the end of a month', () {
      expect(nextReminderAt(sevenPm, DateTime(2026, 10, 31, 20)),
          DateTime(2026, 11, 1, 19));
    });
  });

  group('targetReachedAt', () {
    final t0 = DateTime(2026, 10, 25, 18);
    const ready = FocusSession.ready(taskId: 1, target: Duration(minutes: 25));

    test('is the start plus the target for a fresh session', () {
      expect(
          ready.start(t0).targetReachedAt, t0.add(const Duration(minutes: 25)));
    });

    test('moves later by the time spent paused', () {
      final resumed = ready
          .start(t0)
          .pause(t0.add(const Duration(minutes: 10)))
          .resume(t0.add(const Duration(minutes: 30)));
      // 15 active minutes left from the resume at 18:30.
      expect(resumed.targetReachedAt, t0.add(const Duration(minutes: 45)));
    });

    test('is null unless the session is running', () {
      expect(ready.targetReachedAt, isNull);
      expect(
          ready
              .start(t0)
              .pause(t0.add(const Duration(minutes: 1)))
              .targetReachedAt,
          isNull);
    });
  });
}
