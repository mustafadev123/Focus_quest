import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/dashboard/dashboard_screen.dart';
import 'package:focus_quest/presentation/task_form/task_form_screen.dart';
import 'package:focus_quest/presentation/task_form/widgets/minutes_field.dart';

import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

final _existing = StudyTask(
  id: 1,
  title: 'Review recursion notes',
  subject: 'Data Structures',
  priority: TaskPriority.high,
  estimatedMinutes: 25,
  status: TaskStatus.pending,
  createdAt: DateTime(2026, 10, 19, 9),
  updatedAt: DateTime(2026, 10, 19, 9),
);

Finder _field(String hint) => find.widgetWithText(TextFormField, hint);
final _minutesBox = find.descendant(
    of: find.byType(MinutesField), matching: find.byType(EditableText));

Future<void> _openAdd(WidgetTester tester) async {
  await tester.tap(find.text('Add task'));
  await tester.pumpAndSettle();
}

Future<void> _openEdit(WidgetTester tester, int id) async {
  TaskFormScreen.open(tester.element(find.byType(DashboardScreen)),
      taskId: id);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save task'));
  await tester.tap(find.text('Save task'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adding a valid task returns to the refreshed Dashboard',
      (tester) async {
    final repo = FakeTaskRepository();
    await pumpTestApp(tester, tasks: repo);

    await _openAdd(tester);
    expect(find.text('Add Task'), findsOneWidget);
    await tester.enterText(_field('e.g. Review recursion notes'), 'Lab 3 report');
    await tester.enterText(_field('e.g. Data Structures'), 'Physics');
    await tester.tap(find.text('High'));
    await _tapSave(tester);

    expect(find.text('FocusQuest'), findsOneWidget);
    expect(find.text('Lab 3 report'), findsOneWidget);
    expect(find.text('Physics · High · To do'), findsOneWidget);
    final saved = (await repo.getAll()).single;
    expect(saved.estimatedMinutes, 25);
  });

  testWidgets('blank required fields show messages and nothing is saved',
      (tester) async {
    final repo = FakeTaskRepository();
    await pumpTestApp(tester, tasks: repo);

    await _openAdd(tester);
    await _tapSave(tester);

    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Subject is required'), findsOneWidget);
    expect(find.text('Add Task'), findsOneWidget);
    expect(await repo.getAll(), isEmpty);
  });

  testWidgets('estimated time outside 5–120 is refused with a message',
      (tester) async {
    final repo = FakeTaskRepository();
    await pumpTestApp(tester, tasks: repo);
    await _openAdd(tester);
    await tester.enterText(_field('e.g. Review recursion notes'), 'Reading');
    await tester.enterText(_field('e.g. Data Structures'), 'History');

    for (final bad in ['200', '4', '']) {
      await tester.enterText(_minutesBox, bad);
      await _tapSave(tester);
      expect(find.textContaining('Estimated time must be'), findsOneWidget,
          reason: 'input "$bad"');
    }
    expect(await repo.getAll(), isEmpty);
  });

  testWidgets('the number box and slider stay in step', (tester) async {
    await pumpTestApp(tester);
    await _openAdd(tester);

    await tester.enterText(_minutesBox, '90');
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 90);

    // An invalid entry leaves the slider on the last valid value.
    await tester.enterText(_minutesBox, '300');
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 90);

    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(slider.right - 4, slider.center.dy));
    await tester.pump();
    expect(tester.widget<EditableText>(_minutesBox).controller.text, '120');
  });

  testWidgets('a failed save keeps the input and Retry saves it',
      (tester) async {
    final repo = FakeTaskRepository();
    await pumpTestApp(tester, tasks: repo);
    await _openAdd(tester);
    await tester.enterText(_field('e.g. Review recursion notes'), 'Lab 3 report');
    await tester.enterText(_field('e.g. Data Structures'), 'Physics');

    repo.failNextWrite = StateError('disk full');
    await _tapSave(tester);

    expect(find.text("Couldn't save the task."), findsOneWidget);
    expect(find.text('Your changes are kept.'), findsOneWidget);
    expect(find.text('Lab 3 report'), findsOneWidget);
    expect(await repo.getAll(), isEmpty);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('FocusQuest'), findsOneWidget);
    expect((await repo.getAll()).single.title, 'Lab 3 report');
  });

  testWidgets('tapping Save twice creates only one task', (tester) async {
    final repo = FakeTaskRepository();
    await pumpTestApp(tester, tasks: repo);
    await _openAdd(tester);
    await tester.enterText(_field('e.g. Review recursion notes'), 'Lab 3 report');
    await tester.enterText(_field('e.g. Data Structures'), 'Physics');

    await tester.ensureVisible(find.text('Save task'));
    await tester.tap(find.text('Save task'));
    await tester.tap(find.text('Save task'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(await repo.getAll(), hasLength(1));
  });

  testWidgets('editing loads the saved values and saves changes',
      (tester) async {
    final repo = FakeTaskRepository(tasks: [_existing]);
    await pumpTestApp(tester, tasks: repo);
    await _openEdit(tester, 1);

    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Review recursion notes'), findsOneWidget);
    expect(find.text('Data Structures'), findsOneWidget);

    await tester.enterText(
        _field('e.g. Review recursion notes'), 'Recursion quiz');
    await tester.ensureVisible(find.text('To do'));
    await tester.tap(find.text('To do'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed').last);
    await tester.pumpAndSettle();
    await _tapSave(tester);

    final saved = (await repo.getById(1))!;
    expect(saved.title, 'Recursion quiz');
    expect(saved.status, TaskStatus.completed);
    expect(saved.createdAt, _existing.createdAt);
    expect(find.text('Data Structures · High · Completed'), findsOneWidget);
  });

  testWidgets('editing a task that no longer exists says so', (tester) async {
    await pumpTestApp(tester);
    await _openEdit(tester, 42);
    expect(find.text('This task no longer exists.'), findsOneWidget);
  });

  testWidgets('leaving with unsaved changes asks before discarding',
      (tester) async {
    final repo = FakeTaskRepository();
    await pumpTestApp(tester, tasks: repo);
    await _openAdd(tester);
    await tester.enterText(_field('e.g. Review recursion notes'), 'Draft');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Add Task'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);

    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('FocusQuest'), findsOneWidget);
    expect(await repo.getAll(), isEmpty);
  });

  testWidgets('leaving an untouched form does not ask', (tester) async {
    await pumpTestApp(tester);
    await _openAdd(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('FocusQuest'), findsOneWidget);
  });

  testWidgets('subject suggests subjects already in use', (tester) async {
    await pumpTestApp(tester, tasks: FakeTaskRepository(tasks: [_existing]));
    await _openAdd(tester);

    await tester.enterText(_field('e.g. Data Structures'), 'data');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Data Structures'));
    await tester.pumpAndSettle();

    final subject = tester.widget<EditableText>(find.descendant(
        of: _field('e.g. Data Structures'),
        matching: find.byType(EditableText)));
    expect(subject.controller.text, 'Data Structures');
  });

  testWidgets('Cancel and Save task share the row in equal halves',
      (tester) async {
    await pumpTestApp(tester);
    await _openAdd(tester);
    await tester.ensureVisible(find.text('Save task'));
    await tester.pumpAndSettle();

    final cancel =
        tester.getRect(find.widgetWithText(OutlinedButton, 'Cancel'));
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Save task'));
    expect(cancel.width, save.width);
    expect(cancel.height, save.height);
    expect(cancel.top, save.top);
  });

  testWidgets('the form lays out at 2x text scale', (tester) async {
    tester.view.physicalSize = const Size(780, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpTestApp(tester);
    await _openAdd(tester);
    expect(tester.takeException(), isNull);
  });
}
