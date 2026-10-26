import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/history.dart';
import 'package:focus_quest/domain/models/session_record.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/validation/validation.dart';

SessionRecord _record(int minutes) => SessionRecord(
      session: StudySession(
        taskId: 1,
        startedAt: DateTime(2026, 10, 20, 9),
        durationMinutes: minutes,
        status: SessionStatus.completed,
      ),
      taskTitle: 'Lab 3 report',
      subject: 'Physics',
    );

void main() {
  final now = DateTime(2026, 10, 22, 15, 30); // Thursday

  test('date ranges start where History expects', () {
    expect(HistoryRange.today.startAt(now), DateTime(2026, 10, 22));
    expect(HistoryRange.thisWeek.startAt(now), DateTime(2026, 10, 19));
    expect(HistoryRange.thisMonth.startAt(now), DateTime(2026, 10));
    expect(HistoryRange.allTime.startAt(now), isNull);
  });

  test('summary totals minutes and counts sessions', () {
    expect(summarizeHistory([]), HistorySummary.empty);
    expect(summarizeHistory([_record(50), _record(30), _record(25)]),
        const HistorySummary(totalMinutes: 105, sessions: 3));
  });

  test('the summary gives the same result in a background isolate', () async {
    final records = [for (var i = 1; i <= 500; i++) _record(i % 120 + 1)];
    expect(await compute(summarizeHistory, records), summarizeHistory(records));
  });

  test('a manual session may not end in the future', () {
    final start = now.subtract(const Duration(minutes: 20));
    expect(validateSessionEnd(start, 20, now), isNull);
    expect(validateSessionEnd(start, 21, now),
        'This session would end in the future');
  });
}
