import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/session_record.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/dashboard/widgets/task_card.dart';
import 'package:focus_quest/presentation/dashboard/widgets/summary_card.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';
import 'package:focus_quest/providers/dashboard_providers.dart';

import '../support/fake_session_repository.dart';
import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

StudyTask _task(int id, String title,
        {TaskStatus status = TaskStatus.pending,
        String subject = 'Data Structures'}) =>
    StudyTask(
      id: id,
      title: title,
      subject: subject,
      priority: TaskPriority.high,
      estimatedMinutes: 25,
      status: status,
      createdAt: DateTime(2026, 10, 19, 9, id),
      updatedAt: DateTime(2026, 10, 19, 9, id),
    );

SessionRecord _record(DateTime startedAt, int minutes) => SessionRecord(
      session: StudySession(
        taskId: 1,
        startedAt: startedAt,
        durationMinutes: minutes,
        status: SessionStatus.completed,
      ),
      taskTitle: 'Review recursion notes',
      subject: 'Data Structures',
    );

final _tasks = [
  _task(1, 'Review recursion notes'),
  _task(2, 'Calculus practice', subject: 'Calculus'),
  _task(3, 'Lab 3 report', status: TaskStatus.completed, subject: 'Physics'),
];

void main() {
  testWidgets('shows the empty state when there are no tasks', (tester) async {
    await pumpTestApp(tester);

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Add your first task.'), findsOneWidget);
    expect(find.text('My tasks (0)'), findsOneWidget);
    expect(find.text('0 of 0 tasks done'), findsOneWidget);
  });

  testWidgets('shows a labelled loading state before tasks arrive',
      (tester) async {
    await pumpTestApp(tester, settle: false);
    expect(find.text('Loading tasks…'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Loading tasks…'), findsNothing);
  });

  testWidgets('lists tasks with subject, priority and status', (tester) async {
    await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: _tasks));

    expect(find.text('My tasks (3)'), findsOneWidget);
    // The title also appears on the Suggested-task card.
    expect(
        find.descendant(
            of: find.byType(TaskCard),
            matching: find.text('Review recursion notes')),
        findsOneWidget);
    expect(find.text('Data Structures · High · To do'), findsOneWidget);
    expect(find.text('Physics · High · Completed'), findsOneWidget);
  });

  testWidgets('summary counts completed tasks and this week\'s minutes only',
      (tester) async {
    await pumpTestApp(
      tester,
      tasks: FakeTaskRepository(tasks: _tasks),
      sessions: FakeSessionRepository(records: [
        _record(DateTime(2026, 10, 19, 8), 50), // Monday this week
        _record(DateTime(2026, 10, 25, 9), 210), // today
        _record(DateTime(2026, 10, 18, 23), 90), // last Sunday
      ]),
    );

    final card = find.byType(SummaryCard);
    expect(find.descendant(of: card, matching: find.text('1 of 3 tasks done')),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('4h 20m')),
        findsOneWidget);
    expect(find.bySemanticsLabel('4 hours 20 minutes studied this week'),
        findsOneWidget);
  });

  testWidgets('status filter narrows the list and reports no matches',
      (tester) async {
    final repo = FakeTaskRepository(tasks: _tasks.take(2).toList());
    await pumpTestApp(tester, tasks: repo);

    await tester.tap(find.text('Status: All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed').last);
    await tester.pumpAndSettle();

    expect(find.text('Status: Completed'), findsOneWidget);
    expect(find.text('My tasks (0)'), findsOneWidget);
    expect(find.text('No tasks match this filter.'), findsOneWidget);
    expect(find.text('No tasks yet'), findsNothing);
  });

  testWidgets('a failed load shows Retry, which reloads the tasks',
      (tester) async {
    final repo = FakeTaskRepository(tasks: _tasks)
      ..failNextRead = StateError('disk busy');
    await pumpTestApp(tester, tasks: repo);

    expect(find.text("Couldn't load your tasks."), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('My tasks (3)'), findsOneWidget);
  });

  testWidgets('Focus preselects the task and opens the Focus tab',
      (tester) async {
    final container =
        await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: _tasks));

    await tester.tap(find.widgetWithText(FilledButton, 'Focus').first);
    await tester.pumpAndSettle();

    expect(container.read(selectedTaskIdProvider), 1);
    expect(container.read(selectedTabProvider), AppTab.focus);
  });

  testWidgets('Focus is disabled for a completed task', (tester) async {
    await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: _tasks));

    final buttons = tester
        .widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Focus'))
        .toList();
    expect(buttons.map((b) => b.onPressed != null), [true, true, false]);
  });

  testWidgets('landscape puts the task list beside the summary',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: _tasks));

    final summary = tester.getRect(find.byType(SummaryCard));
    final heading = tester.getRect(find.text('My tasks (3)'));
    expect(heading.left, greaterThan(summary.right));
    expect(heading.top, lessThan(summary.bottom));
  });

  testWidgets('portrait at 2x text scale lays out without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: _tasks));
    expect(tester.takeException(), isNull);
  });
}
