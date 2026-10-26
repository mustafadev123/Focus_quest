import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/session_record.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';

import '../support/fake_session_repository.dart';
import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

// testNow is Sunday 25 October 2026, 18:00; the week starts Monday 19th.

StudyTask _task(int id, String title, String subject) => StudyTask(
      id: id,
      title: title,
      subject: subject,
      priority: TaskPriority.medium,
      estimatedMinutes: 30,
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

final _tasks = [
  _task(1, 'Lab 3 report', 'Physics'),
  _task(2, 'Calculus practice', 'Calculus'),
];

SessionRecord _record(int id, int taskId, DateTime start, int minutes) =>
    SessionRecord(
      session: StudySession(
        id: id,
        taskId: taskId,
        startedAt: start,
        endedAt: start.add(Duration(minutes: minutes)),
        durationMinutes: minutes,
        status: SessionStatus.completed,
      ),
      taskTitle: _tasks[taskId - 1].title,
      subject: _tasks[taskId - 1].subject,
    );

FakeSessionRepository _sessions() => FakeSessionRepository(records: [
      _record(1, 1, DateTime(2026, 10, 24, 9), 50),
      _record(2, 2, DateTime(2026, 10, 24, 14), 30),
      _record(3, 1, DateTime(2026, 10, 23, 10), 25),
      _record(4, 2, DateTime(2026, 10, 12, 10), 40), // two weeks ago
    ])
      ..taskInfo[1] = ('Lab 3 report', 'Physics')
      ..taskInfo[2] = ('Calculus practice', 'Calculus');

Future<void> _openHistory(WidgetTester tester,
    {FakeSessionRepository? sessions, FakeTaskRepository? tasks}) async {
  final container = await pumpTestApp(tester,
      tasks: tasks ?? FakeTaskRepository(tasks: _tasks),
      sessions: sessions ?? _sessions());
  container.read(selectedTabProvider.notifier).select(AppTab.history);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String current, String option) async {
  await tester.tap(find.text(current).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Finder _rowButton(String label, int index) =>
    find.widgetWithText(OutlinedButton, label).at(index);

void main() {
  testWidgets('lists this week by default with totals', (tester) async {
    await _openHistory(tester);

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('All tasks'), findsOneWidget);
    expect(find.text('All subjects'), findsOneWidget);
    expect(find.text('1h 45m studied', findRichText: true), findsOneWidget);
    expect(find.text('3 sessions'), findsOneWidget);
    expect(find.text('Lab 3 report'), findsNWidgets(2));
    expect(find.text('Oct 24'), findsNWidgets(2));
    expect(find.text('50 min'), findsOneWidget);
    expect(find.text('40 min'), findsNothing);
  });

  testWidgets('filters by task, subject and date, and they combine',
      (tester) async {
    await _openHistory(tester);

    await _choose(tester, 'All tasks', 'Calculus practice');
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('1 session'), findsOneWidget);

    await _choose(tester, 'This week', 'All time');
    expect(find.text('2 sessions'), findsOneWidget);
    expect(find.text('1h 10m studied', findRichText: true), findsOneWidget);

    await _choose(tester, 'Calculus practice', 'All tasks');
    await _choose(tester, 'All subjects', 'Physics');
    expect(find.text('2 sessions'), findsOneWidget);
    expect(find.text('1h 15m studied', findRichText: true), findsOneWidget);

    await _choose(tester, 'All time', 'Today');
    expect(find.text('No sessions match these filters.'), findsOneWidget);
    expect(find.text('0 sessions'), findsOneWidget);
  });

  testWidgets('with no sessions at all it offers to start one', (tester) async {
    final container =
        await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: _tasks));
    container.read(selectedTabProvider.notifier).select(AppTab.history);
    await tester.pumpAndSettle();

    expect(find.text('No sessions yet'), findsOneWidget);
    await tester.tap(find.text('Start a focus session'));
    await tester.pumpAndSettle();
    expect(container.read(selectedTabProvider), AppTab.focus);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    final sessions = _sessions()..failNextRead = StateError('disk busy');
    await _openHistory(tester, sessions: sessions);

    expect(find.text("Couldn't load your sessions."), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('3 sessions'), findsOneWidget);
  });

  testWidgets('delete asks first, then the totals refresh', (tester) async {
    final sessions = _sessions();
    await _openHistory(tester, sessions: sessions);

    await tester.tap(_rowButton('Delete', 0)); // newest: Calculus, 30 min
    await tester.pumpAndSettle();
    expect(find.text('Delete this session?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('3 sessions'), findsOneWidget);

    await tester.tap(_rowButton('Delete', 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('2 sessions'), findsOneWidget);
    expect(find.text('1h 15m studied', findRichText: true), findsOneWidget);
    expect(find.text('Session deleted'), findsOneWidget);
    expect(await sessions.getById(2), isNull);
  });

  group('Add session', () {
    testWidgets('records a valid manual session and refreshes the totals',
        (tester) async {
      final sessions = _sessions();
      await _openHistory(tester, sessions: sessions);

      await tester.tap(find.text('Add session'));
      await tester.pumpAndSettle();
      expect(find.text('Add session'), findsNWidgets(2)); // title + button
      await tester.enterText(find.byType(TextFormField), '20');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('4 sessions'), findsOneWidget);
      expect(find.text('2h 5m studied', findRichText: true), findsOneWidget);
      final added = (await sessions.getRecords())
          .firstWhere((r) => r.session.status == SessionStatus.manual);
      expect(added.session.taskId, 1);
      expect(added.session.durationMinutes, 20);
      expect(added.session.endedAt,
          added.session.startedAt.add(const Duration(minutes: 20)));
    });

    testWidgets('refuses durations outside 1–120 and keeps the dialog open',
        (tester) async {
      final sessions = _sessions();
      await _openHistory(tester, sessions: sessions);
      await tester.tap(find.text('Add session'));
      await tester.pumpAndSettle();

      for (final bad in ['0', '121', '']) {
        await tester.enterText(find.byType(TextFormField), bad);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Duration must'), findsOneWidget,
            reason: 'input "$bad"');
      }
      expect(await sessions.getRecords(), hasLength(4));
    });

    testWidgets('refuses a session that would end in the future',
        (tester) async {
      await _openHistory(tester);
      await tester.tap(find.text('Add session'));
      await tester.pumpAndSettle();

      // The default start is 25 minutes ago, so 26 minutes ends in future.
      await tester.enterText(find.byType(TextFormField), '26');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('This session would end in the future'), findsOneWidget);
    });

    testWidgets('a failed save keeps the input and can be retried',
        (tester) async {
      final sessions = _sessions()..failNextWrite = StateError('disk full');
      await _openHistory(tester, sessions: sessions);
      await tester.tap(find.text('Add session'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '15');

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
          find.text("Couldn't save the session. Try again."), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('4 sessions'), findsOneWidget);
    });

    testWidgets('with no tasks it asks for a task first', (tester) async {
      final container = await pumpTestApp(tester);
      container.read(selectedTabProvider.notifier).select(AppTab.history);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add session'));
      await tester.pumpAndSettle();
      expect(find.text('Add a task first, then record a session for it.'),
          findsOneWidget);
    });
  });

  testWidgets('Edit corrects the task and minutes and the totals follow',
      (tester) async {
    final sessions = _sessions();
    await _openHistory(tester, sessions: sessions);

    await tester.tap(_rowButton('Edit', 0)); // Calculus, 30 min
    await tester.pumpAndSettle();
    expect(find.text('Edit session'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);

    await tester.tap(find.text('Calculus practice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab 3 report').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '45');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final edited = (await sessions.getById(2))!;
    expect(edited.taskId, 1);
    expect(edited.durationMinutes, 45);
    expect(edited.status, SessionStatus.manual);
    expect(find.text('2h studied', findRichText: true),
        findsOneWidget); // 50 + 45 + 25
  });

  testWidgets('lays out in landscape at 2x text scale', (tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openHistory(tester);
    expect(tester.takeException(), isNull);
  });
}
