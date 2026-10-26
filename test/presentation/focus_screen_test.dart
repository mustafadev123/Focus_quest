import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/focus/focus_session.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';
import 'package:focus_quest/providers/dashboard_providers.dart';

import '../support/fake_focus_checkpoint_repository.dart';
import '../support/fake_session_repository.dart';
import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

StudyTask _task(int id, String title,
        {TaskStatus status = TaskStatus.pending}) =>
    StudyTask(
      id: id,
      title: title,
      subject: 'Data Structures',
      priority: TaskPriority.high,
      estimatedMinutes: 25,
      status: status,
      createdAt: DateTime(2026, 10, 19, 9, id),
      updatedAt: DateTime(2026, 10, 19, 9, id),
    );

final _tasks = [
  _task(1, 'Review recursion notes'),
  _task(2, 'Calculus practice'),
];

/// Any Filled/Outlined/Text button showing [label].
Finder _button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(_button(label)).onPressed != null;

/// Opens the Focus tab with task 1 chosen from the Dashboard.
Future<
        ({
          TestClock clock,
          FakeSessionRepository sessions,
          FakeFocusCheckpointRepository checkpoints
        })>
    _focusOnTask(WidgetTester tester,
        {FakeFocusCheckpointRepository? checkpoints}) async {
  final clock = TestClock();
  final sessions = FakeSessionRepository()
    ..taskInfo[1] = ('Review recursion notes', 'Data Structures');
  final cps = checkpoints ?? FakeFocusCheckpointRepository(sessions: sessions);
  final container = await pumpTestApp(tester,
      tasks: FakeTaskRepository(tasks: _tasks),
      sessions: sessions,
      checkpoints: cps,
      clock: clock);
  container.read(selectedTaskIdProvider.notifier).select(1);
  container.read(selectedTabProvider.notifier).select(AppTab.focus);
  await tester.pumpAndSettle();
  return (clock: clock, sessions: sessions, checkpoints: cps);
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(_button(label));
  await tester.pumpAndSettle();
}

/// Moves the clock and lets the once-a-second ticker run.
Future<void> _elapse(WidgetTester tester, TestClock clock, Duration by) async {
  clock.advance(by);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with no tasks it asks for one and links to Tasks',
      (tester) async {
    final container = await pumpTestApp(tester);
    container.read(selectedTabProvider.notifier).select(AppTab.focus);
    await tester.pumpAndSettle();

    expect(find.text('Select a task first'), findsOneWidget);
    await tester.tap(find.text('Go to Tasks'));
    await tester.pumpAndSettle();
    expect(container.read(selectedTabProvider), AppTab.tasks);
  });

  testWidgets('Start is disabled until a task is chosen', (tester) async {
    final container =
        await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: _tasks));
    container.read(selectedTabProvider.notifier).select(AppTab.focus);
    await tester.pumpAndSettle();

    expect(find.text('Select a task first'), findsOneWidget);
    expect(_enabled(tester, 'Start'), isFalse);

    await tester.tap(find.text('Select a task first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculus practice').last);
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'Start'), isTrue);
  });

  testWidgets('shows the chosen task Ready with the full target',
      (tester) async {
    await _focusOnTask(tester);

    expect(find.text('Review recursion notes'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('of 25 minutes'), findsOneWidget);
    expect(_enabled(tester, 'Start'), isTrue);
    expect(_enabled(tester, 'Pause'), isFalse);
    expect(_enabled(tester, 'Finish'), isFalse);
  });

  testWidgets('counts down while running and stops while paused',
      (tester) async {
    final env = await _focusOnTask(tester);

    await _tap(tester, 'Start');
    expect(find.text('Running'), findsOneWidget);
    expect(_enabled(tester, 'Start'), isFalse);

    await _elapse(tester, env.clock, const Duration(minutes: 6, seconds: 18));
    expect(find.text('18:42'), findsOneWidget);

    await _tap(tester, 'Pause');
    expect(find.text('Paused'), findsOneWidget);
    expect(_button('Resume'), findsOneWidget);

    await _elapse(tester, env.clock, const Duration(minutes: 10));
    expect(find.text('18:42'), findsOneWidget);

    await _tap(tester, 'Resume');
    await _elapse(tester, env.clock, const Duration(seconds: 60));
    expect(find.text('17:42'), findsOneWidget);
  });

  testWidgets('the task cannot be changed while a session runs',
      (tester) async {
    await _focusOnTask(tester);
    await _tap(tester, 'Start');

    final dropdown =
        tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>));
    expect(dropdown.onChanged, isNull);
    expect(find.text('Finish or reset this session to change task.'),
        findsOneWidget);
  });

  testWidgets(
      'Finish opens the review; Back keeps it unsaved; Save records '
      'one session', (tester) async {
    final env = await _focusOnTask(tester);
    await _tap(tester, 'Start');
    await _elapse(tester, env.clock, const Duration(minutes: 6, seconds: 18));

    await _tap(tester, 'Finish');
    expect(find.text('Review session'), findsOneWidget);
    expect(find.text('06:18'), findsOneWidget);
    expect(find.text('studied'), findsOneWidget);

    await _tap(tester, 'Back');
    expect(find.text('Awaiting save'), findsOneWidget);
    expect(env.sessions.taskInfo, isNotEmpty);
    expect(await env.sessions.getRecords(), isEmpty);

    await _tap(tester, 'Review and save');
    await _tap(tester, 'Save session');

    expect(find.text('Session saved'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    final records = await env.sessions.getRecords();
    expect(records.single.session.durationMinutes, 6);
    expect(records.single.session.status, SessionStatus.endedEarly);
    expect(records.single.session.taskId, 1);
  });

  testWidgets('a failed save shows an error and Retry saves exactly once',
      (tester) async {
    final env = await _focusOnTask(tester);
    await _tap(tester, 'Start');
    await _elapse(tester, env.clock, const Duration(minutes: 3));
    env.checkpoints.failNextSave = StateError('disk full');

    await _tap(tester, 'Finish');
    await _tap(tester, 'Save session');
    expect(find.text("Couldn't save the session. Try again."), findsOneWidget);
    expect(await env.sessions.getRecords(), isEmpty);

    await _tap(tester, 'Save session');
    expect(await env.sessions.getRecords(), hasLength(1));
  });

  testWidgets('reaching 00:00 opens the review without saving', (tester) async {
    final env = await _focusOnTask(tester);
    await _tap(tester, 'Start');

    await _elapse(tester, env.clock, const Duration(minutes: 25));

    expect(find.text('Review session'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(await env.sessions.getRecords(), isEmpty);
  });

  testWidgets('Reset asks first and discards progress on confirm',
      (tester) async {
    final env = await _focusOnTask(tester);
    await _tap(tester, 'Start');
    await _elapse(tester, env.clock, const Duration(minutes: 5));

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this session?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Running'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(env.checkpoints.checkpoint, isNull);
  });

  testWidgets('a session under half a minute cannot be saved', (tester) async {
    final env = await _focusOnTask(tester);
    await _tap(tester, 'Start');
    await _elapse(tester, env.clock, const Duration(seconds: 10));

    await _tap(tester, 'Finish');
    expect(find.textContaining('shorter than a minute'), findsOneWidget);
    expect(_enabled(tester, 'Save session'), isFalse);
  });

  testWidgets('a restored running session continues where it left off',
      (tester) async {
    final checkpoint = FocusSession.restore(
      phase: FocusPhase.running,
      taskId: 1,
      target: const Duration(minutes: 25),
      startedAt: testNow.subtract(const Duration(minutes: 10)),
      activeBeforeResume: const Duration(minutes: 4),
      lastResumedAt: testNow.subtract(const Duration(minutes: 2)),
    );
    await _focusOnTask(tester,
        checkpoints: FakeFocusCheckpointRepository(checkpoint: checkpoint));

    expect(find.text('Running'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
  });

  testWidgets('lays out in landscape at 2x text scale', (tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _focusOnTask(tester);
    expect(tester.takeException(), isNull);
  });
}
