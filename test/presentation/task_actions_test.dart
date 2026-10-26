import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/focus/focus_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/dashboard/widgets/task_card.dart';
import 'package:focus_quest/providers/dashboard_providers.dart';

import '../support/fake_focus_checkpoint_repository.dart';
import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

StudyTask _task(int id, String title) => StudyTask(
      id: id,
      title: title,
      subject: 'Data Structures',
      priority: TaskPriority.high,
      estimatedMinutes: 25,
      status: TaskStatus.pending,
      createdAt: DateTime(2026, 10, 19, 9, id),
      updatedAt: DateTime(2026, 10, 19, 9, id),
    );

FakeTaskRepository _repo() => FakeTaskRepository(tasks: [
      _task(1, 'Review recursion notes'),
      _task(2, 'Calculus practice'),
    ])
      ..sessionCounts[1] = 2;

Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(TaskCard));

Future<void> _openMenu(WidgetTester tester, String title, String item) async {
  await tester.tap(find.byTooltip('More actions for $title'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a card selects and highlights it', (tester) async {
    final container = await pumpTestApp(tester, tasks: _repo());

    await tester.tap(find.text('Calculus practice'));
    await tester.pumpAndSettle();

    expect(container.read(selectedTaskIdProvider), 2);
    expect(
        tester.widget<TaskCard>(_card('Calculus practice')).selected, isTrue);
    expect(tester.widget<TaskCard>(_card('Review recursion notes')).selected,
        isFalse);
    final box = tester.widget<AnimatedContainer>(find.descendant(
        of: _card('Calculus practice'),
        matching: find.byType(AnimatedContainer)));
    expect((box.decoration! as BoxDecoration).border!.top.width, 2);
  });

  testWidgets('long press and the menu both open Edit Task', (tester) async {
    await pumpTestApp(tester, tasks: _repo());

    await tester.longPress(find.text('Calculus practice'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Calculus practice'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await _openMenu(tester, 'Review recursion notes', 'Edit');
    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Review recursion notes'), findsOneWidget);
  });

  testWidgets('delete confirms with the session count; Cancel keeps the task',
      (tester) async {
    final repo = _repo();
    await pumpTestApp(tester, tasks: repo);

    await _openMenu(tester, 'Review recursion notes', 'Delete');
    expect(find.text('Delete this task?'), findsOneWidget);
    expect(
        find.text("This also deletes 2 saved sessions. This can't be undone."),
        findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await repo.getById(1), isNotNull);

    await _openMenu(tester, 'Review recursion notes', 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repo.getById(1), isNull);
    expect(find.text('Review recursion notes'), findsNothing);
    expect(find.text('Task deleted'), findsOneWidget);
    expect(find.text('My tasks (1)'), findsOneWidget);
  });

  testWidgets('a task without sessions just warns it cannot be undone',
      (tester) async {
    await pumpTestApp(tester, tasks: _repo());
    await _openMenu(tester, 'Calculus practice', 'Delete');
    expect(find.text("This can't be undone."), findsOneWidget);
  });

  testWidgets('swiping left asks, then deletes on confirm', (tester) async {
    final repo = _repo();
    await pumpTestApp(tester, tasks: repo);

    await tester.drag(_card('Calculus practice'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete this task?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repo.getById(2), isNull);
    expect(find.text('Calculus practice'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancelled swipe leaves the card in place', (tester) async {
    await pumpTestApp(tester, tasks: _repo());

    await tester.drag(_card('Calculus practice'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Calculus practice'), findsOneWidget);
  });

  testWidgets('the task of an unsaved focus session cannot be deleted',
      (tester) async {
    final repo = _repo();
    final running =
        const FocusSession.ready(taskId: 1, target: Duration(minutes: 25))
            .start(testNow.subtract(const Duration(minutes: 5)));
    await pumpTestApp(tester,
        tasks: repo,
        checkpoints: FakeFocusCheckpointRepository(checkpoint: running));

    await _openMenu(tester, 'Review recursion notes', 'Delete');

    expect(find.text('Delete this task?'), findsNothing);
    expect(
        find.text('Finish or reset the focus session for this task before '
            'deleting it.'),
        findsOneWidget);
    expect(await repo.getById(1), isNotNull);
  });

  testWidgets('Delete task on the Edit screen returns to the Dashboard',
      (tester) async {
    final repo = _repo();
    await pumpTestApp(tester, tasks: repo);

    await tester.longPress(find.text('Calculus practice'));
    await tester.pumpAndSettle();
    // The form list builds lazily, so scroll the button into existence.
    await tester.scrollUntilVisible(find.text('Delete task'), 200,
        scrollable: find
            .descendant(
                of: find.byType(Form), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('FocusQuest'), findsOneWidget);
    expect(find.text('Calculus practice'), findsNothing);
    expect(await repo.getById(2), isNull);
  });

  testWidgets('Add Task has no Delete button', (tester) async {
    await pumpTestApp(tester, tasks: _repo());
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Save task'), 200,
        scrollable: find
            .descendant(
                of: find.byType(Form), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Delete task'), findsNothing);
  });

  testWidgets('a failed delete says so and keeps the task', (tester) async {
    final repo = _repo();
    await pumpTestApp(tester, tasks: repo);
    repo.failNextWrite = StateError('disk full');

    await _openMenu(tester, 'Calculus practice', 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't delete the task. Try again."), findsOneWidget);
    expect(find.text('Calculus practice'), findsOneWidget);
  });

  testWidgets('deleting the selected task clears the selection',
      (tester) async {
    final container = await pumpTestApp(tester, tasks: _repo());
    await tester.tap(find.text('Calculus practice'));
    await tester.pumpAndSettle();

    await _openMenu(tester, 'Calculus practice', 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(container.read(selectedTaskIdProvider), isNull);
  });

  testWidgets('the selection highlight is instant with reduced motion',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpTestApp(tester, tasks: _repo());

    final box = tester.widget<AnimatedContainer>(find.descendant(
        of: _card('Calculus practice'),
        matching: find.byType(AnimatedContainer)));
    expect(box.duration, Duration.zero);
  });
}
