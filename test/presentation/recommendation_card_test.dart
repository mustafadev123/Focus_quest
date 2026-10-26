import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/focus/focus_session.dart';
import 'package:focus_quest/domain/models/session_record.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/dashboard/widgets/recommendation_card.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';
import 'package:focus_quest/providers/dashboard_providers.dart';
import 'package:focus_quest/providers/focus_providers.dart';

import '../support/fake_focus_checkpoint_repository.dart';
import '../support/fake_session_repository.dart';
import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

StudyTask _task(int id, String title, int priority, int minutes,
        {TaskStatus status = TaskStatus.pending}) =>
    StudyTask(
      id: id,
      title: title,
      subject: 'Subject',
      priority: TaskPriority.fromValue(priority)!,
      estimatedMinutes: minutes,
      status: status,
      createdAt: DateTime(2026, 10, 19, 9, id),
      updatedAt: DateTime(2026, 10, 19, 9, id),
    );

/// The proposal's "time fit and recent study" case: with 30 minutes,
/// A (high, 90 min, 25 recent) scores 0.70 and B (medium, 30 min) 0.75.
final _a = _task(1, 'Review recursion notes', 3, 90);
final _b = _task(2, 'Calculus practice', 2, 30);

FakeSessionRepository _recentA() => FakeSessionRepository(records: [
      SessionRecord(
        session: StudySession(
          taskId: 1,
          startedAt: testNow.subtract(const Duration(days: 2)),
          durationMinutes: 25,
          status: SessionStatus.completed,
        ),
        taskTitle: _a.title,
        subject: _a.subject,
      ),
    ]);

Finder get _card => find.byType(RecommendationCard);
Finder _inCard(String text) =>
    find.descendant(of: _card, matching: find.text(text));

Future<void> _setAvailable(WidgetTester tester, int from, int to) async {
  await tester.tap(_inCard('$from min'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$to min').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('suggests the highest-scoring task for the available time',
      (tester) async {
    await pumpTestApp(tester,
        tasks: FakeTaskRepository(tasks: [_a, _b]), sessions: _recentA());

    expect(_inCard('Suggested next task'), findsOneWidget);
    expect(_inCard('25 min'), findsOneWidget); // Settings default
    await _setAvailable(tester, 25, 30);

    expect(_inCard('Calculus practice'), findsOneWidget);
    expect(_inCard('Medium priority · fits your time'), findsOneWidget);

    // More time makes the long, high-priority task fit: A wins.
    await _setAvailable(tester, 30, 90);
    expect(_inCard('Review recursion notes'), findsOneWidget);
  });

  testWidgets('"Why this task?" explains the parts of the score',
      (tester) async {
    await pumpTestApp(tester,
        tasks: FakeTaskRepository(tasks: [_a, _b]), sessions: _recentA());
    await _setAvailable(tester, 25, 30);

    await tester.tap(_inCard('Why this task?'));
    await tester.pumpAndSettle();

    expect(_inCard('• Medium priority.'), findsOneWidget);
    expect(_inCard('• Its estimate of 30 min fits in your 30 min.'),
        findsOneWidget);
    expect(_inCard('• You have not studied it in the last 7 days.'),
        findsOneWidget);
    expect(
        _inCard('Score 0.75 = priority 0.25 + time fit 0.30 + recent '
            'activity 0.20'),
        findsOneWidget);
    expect(find.textContaining('not a trained AI model'), findsOneWidget);
  });

  testWidgets('with no study history the explanation says so', (tester) async {
    await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: [_a, _b]));
    await tester.tap(_inCard('Why this task?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No study history from the last 7 days'),
        findsOneWidget);
  });

  testWidgets('Use task selects it with the chosen time but does not start',
      (tester) async {
    final container = await pumpTestApp(tester,
        tasks: FakeTaskRepository(tasks: [_a, _b]), sessions: _recentA());
    await _setAvailable(tester, 25, 30);

    await tester.tap(_inCard('Use task'));
    await tester.pumpAndSettle();

    expect(container.read(selectedTabProvider), AppTab.focus);
    expect(container.read(selectedTaskIdProvider), 2);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
    expect(find.text('of 30 minutes'), findsOneWidget);
    expect(
        container.read(focusControllerProvider).value!.phase, FocusPhase.ready);
  });

  testWidgets('Not now hides the suggestion without changing any data',
      (tester) async {
    final tasks = FakeTaskRepository(tasks: [_a, _b]);
    final container = await pumpTestApp(tester, tasks: tasks);

    await tester.tap(_inCard('Not now'));
    await tester.pumpAndSettle();
    expect(_inCard('Suggested next task'), findsNothing);
    expect(container.read(selectedTaskIdProvider), isNull);
    expect(await tasks.getAll(), [_a, _b]);

    await tester.tap(find.text('Show suggested task'));
    await tester.pumpAndSettle();
    expect(_inCard('Suggested next task'), findsOneWidget);
  });

  testWidgets('choosing another task overrides the suggestion', (tester) async {
    final container =
        await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: [_a, _b]));

    // The helper suggests A; the student picks B from the list instead.
    expect(_inCard('Review recursion notes'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Focus').last);
    await tester.pumpAndSettle();
    expect(container.read(selectedTaskIdProvider), 2);
  });

  testWidgets('with every task completed it offers Create a task',
      (tester) async {
    await pumpTestApp(tester,
        tasks: FakeTaskRepository(tasks: [
          _task(1, 'Done', 3, 30, status: TaskStatus.completed),
        ]));

    expect(_inCard('Nothing to suggest: every task is completed.'),
        findsOneWidget);
    await tester.tap(_inCard('Create a task'));
    await tester.pumpAndSettle();
    expect(find.text('Add Task'), findsOneWidget);
  });

  testWidgets('with no tasks the card is not shown', (tester) async {
    await pumpTestApp(tester);
    expect(_card, findsNothing);
    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('Use task is refused while a focus session is in progress',
      (tester) async {
    final running =
        const FocusSession.ready(taskId: 1, target: Duration(minutes: 25))
            .start(testNow.subtract(const Duration(minutes: 3)));
    final container = await pumpTestApp(tester,
        tasks: FakeTaskRepository(tasks: [_a, _b]),
        checkpoints: FakeFocusCheckpointRepository(checkpoint: running));
    await _setAvailable(tester, 25, 30);

    await tester.tap(_inCard('Use task'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Finish or reset your current focus session'),
        findsOneWidget);
    expect(container.read(selectedTabProvider), AppTab.tasks);
    expect(container.read(focusControllerProvider).value!.target,
        const Duration(minutes: 25));
  });
}
