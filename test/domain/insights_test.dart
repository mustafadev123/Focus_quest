import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/insights.dart';
import 'package:focus_quest/domain/models/session_record.dart';
import 'package:focus_quest/domain/models/study_session.dart';

SessionRecord _at(DateTime start, int minutes,
        [SessionStatus status = SessionStatus.completed]) =>
    SessionRecord(
      session: StudySession(
        taskId: 1,
        startedAt: start,
        durationMinutes: minutes,
        status: status,
      ),
      taskTitle: 'Task',
      subject: 'Subject',
    );

void main() {
  final now = DateTime(2026, 10, 25, 18); // Sunday

  test('seven local days ending today, oldest first, zero days kept', () {
    final days = dailyMinutes(const [], now);
    expect(days.map((d) => d.day), [
      for (var d = 19; d <= 25; d++) DateTime(2026, 10, d),
    ]);
    expect(days.every((d) => d.minutes == 0), isTrue);
    expect(chartStart(now), DateTime(2026, 10, 19));
  });

  test('sums sessions per day and counts every session status', () {
    final days = dailyMinutes([
      _at(DateTime(2026, 10, 24, 9), 50),
      _at(DateTime(2026, 10, 24, 14), 30, SessionStatus.endedEarly),
      _at(DateTime(2026, 10, 24, 20), 10, SessionStatus.manual),
      _at(DateTime(2026, 10, 21, 8), 25),
    ], now);
    expect(days.map((d) => d.minutes), [0, 0, 25, 0, 0, 90, 0]);
  });

  test('a session crossing midnight counts wholly on its start day', () {
    final days = dailyMinutes([_at(DateTime(2026, 10, 23, 23, 50), 40)], now);
    expect(days[4], DayTotal(DateTime(2026, 10, 23), 40));
    expect(days[5].minutes, 0);
  });

  test('window boundaries: first midnight counts; earlier and later do not',
      () {
    final days = dailyMinutes([
      _at(DateTime(2026, 10, 19), 15), // first second of the window
      _at(DateTime(2026, 10, 18, 23, 59, 59), 60), // just before it
      _at(DateTime(2026, 10, 26, 0, 1), 60), // tomorrow
      _at(DateTime(2026, 10, 25, 17, 59), 5), // today, before now
    ], now);
    expect(days.first, DayTotal(DateTime(2026, 10, 19), 15));
    expect(days.last, DayTotal(DateTime(2026, 10, 25), 5));
    expect(days.fold(0, (s, d) => s + d.minutes), 20);
  });

  test('a daylight-saving change neither skips nor repeats a day', () {
    // 1 November 2026 is the US fall-back date; built from calendar fields,
    // the window is seven distinct consecutive dates in any time zone.
    final days = dailyMinutes(const [], DateTime(2026, 11, 3, 12));
    expect(days.map((d) => d.day.day), [28, 29, 30, 31, 1, 2, 3]);
    expect(days.map((d) => d.day.hour).toSet(), {0});
  });

  test('crosses a month boundary', () {
    final days = dailyMinutes(const [], DateTime(2026, 11, 2, 9));
    expect(days.first.day, DateTime(2026, 10, 27));
    expect(days.last.day, DateTime(2026, 11, 2));
  });
}
