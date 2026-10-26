import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/session_record.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/report/study_report.dart';

SessionRecord _record(String task, String subject, DateTime start, int minutes,
        [SessionStatus status = SessionStatus.completed]) =>
    SessionRecord(
      session: StudySession(
        taskId: 1,
        startedAt: start,
        durationMinutes: minutes,
        status: status,
      ),
      taskTitle: task,
      subject: subject,
    );

StudyReportInput _input(List<SessionRecord> records) => StudyReportInput(
      generatedAt: DateTime(2026, 10, 25, 18),
      periodLabel: 'This week',
      taskLabel: 'All tasks',
      subjectLabel: 'All subjects',
      records: records,
    );

final _records = [
  _record('Calculus practice', 'Calculus', DateTime(2026, 10, 24, 14), 30),
  _record('Lab 3 report', 'Physics', DateTime(2026, 10, 24, 9), 50),
  _record('Lab 3 report', 'Physics', DateTime(2026, 10, 23, 10), 25,
      SessionStatus.endedEarly),
];

void main() {
  test('summarises totals, subjects, tasks and each session', () {
    expect(buildStudyReport(_input(_records)), '''
FocusQuest study summary
Generated Oct 25, 2026 6:00 PM
Period: This week
Filters: All tasks, All subjects

Total: 1h 45m across 3 sessions

By subject
  Physics: 1h 15m (2 sessions)
  Calculus: 30m (1 session)

By task
  Lab 3 report (Physics): 1h 15m (2 sessions)
  Calculus practice (Calculus): 30m (1 session)

Sessions
  Oct 24, 2:00 PM  Calculus practice  30 min  Completed
  Oct 24, 9:00 AM  Lab 3 report  50 min  Completed
  Oct 23, 10:00 AM  Lab 3 report  25 min  Ended early
''');
  });

  test('says so when there are no sessions', () {
    final report = buildStudyReport(_input(const []));
    expect(report, contains('Period: This week'));
    expect(report, endsWith('No sessions in this period.\n'));
    expect(report, isNot(contains('Total')));
  });

  test('gives the same text when built in a background isolate', () async {
    final input = _input(_records);
    expect(await compute(buildStudyReport, input), buildStudyReport(input));
  });
}
