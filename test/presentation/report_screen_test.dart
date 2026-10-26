import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/session_record.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';

import '../support/fake_report_file_service.dart';
import '../support/fake_session_repository.dart';
import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

final _task = StudyTask(
  id: 1,
  title: 'Lab 3 report',
  subject: 'Physics',
  priority: TaskPriority.high,
  estimatedMinutes: 50,
  status: TaskStatus.pending,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

FakeSessionRepository _sessions() => FakeSessionRepository(records: [
      SessionRecord(
        session: StudySession(
          taskId: 1,
          startedAt: DateTime(2026, 10, 24, 9),
          durationMinutes: 50,
          status: SessionStatus.completed,
        ),
        taskTitle: 'Lab 3 report',
        subject: 'Physics',
      ),
    ]);

Future<void> _openReport(WidgetTester tester, FakeReportFileService reports,
    {FakeSessionRepository? sessions}) async {
  useTallScreen(tester);
  final container = await pumpTestApp(tester,
      tasks: FakeTaskRepository(tasks: [_task]),
      sessions: sessions ?? _sessions(),
      reports: reports);
  container.read(selectedTabProvider.notifier).select(AppTab.history);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Text report'));
  await tester.tap(find.text('Text report'));
  await tester.pumpAndSettle();
}

Finder _report(String text) => find.descendant(
    of: find.byType(SelectableText), matching: find.textContaining(text));

void main() {
  testWidgets('saves the report file and previews what was saved',
      (tester) async {
    final reports = FakeReportFileService();
    await _openReport(tester, reports);

    expect(find.text('Study summary'), findsOneWidget);
    expect(find.text('Saved on this phone as focusquest_study_summary.txt'),
        findsOneWidget);
    expect(reports.writes, 1);
    expect(reports.saved, contains('Total: 50m across 1 session'));
    expect(_report('FocusQuest study summary'), findsOneWidget);
    expect(_report('Period: This week'), findsOneWidget);
    expect(_report('Physics: 50m (1 session)'), findsOneWidget);
  });

  testWidgets('a failed write explains it and Retry saves', (tester) async {
    final reports = FakeReportFileService()
      ..failNextWrite = const FileSystemFailure();
    await _openReport(tester, reports);

    expect(find.textContaining("Couldn't save the report"), findsOneWidget);
    expect(reports.saved, isNull);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(_report('FocusQuest study summary'), findsOneWidget);
  });

  testWidgets('a failed read after saving says so and Retry recovers',
      (tester) async {
    final reports = FakeReportFileService()
      ..failNextRead = const FileSystemFailure();
    await _openReport(tester, reports);

    expect(find.textContaining("couldn't be opened"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(_report('FocusQuest study summary'), findsOneWidget);
  });

  testWidgets('with no sessions the report says so', (tester) async {
    await _openReport(tester, FakeReportFileService(),
        sessions: FakeSessionRepository());
    expect(_report('No sessions in this period.'), findsOneWidget);
  });

  testWidgets('the report follows the History filters', (tester) async {
    final reports = FakeReportFileService();
    useTallScreen(tester);
    final container = await pumpTestApp(tester,
        tasks: FakeTaskRepository(tasks: [_task]),
        sessions: _sessions(),
        reports: reports);
    container.read(selectedTabProvider.notifier).select(AppTab.history);
    await tester.pumpAndSettle();

    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Text report'));
    await tester.tap(find.text('Text report'));
    await tester.pumpAndSettle();

    expect(reports.saved, contains('Period: Today'));
    expect(reports.saved, contains('No sessions in this period.'));
  });
}

class FileSystemFailure implements Exception {
  const FileSystemFailure();
}
