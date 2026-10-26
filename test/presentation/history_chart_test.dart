import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/app_settings.dart';
import 'package:focus_quest/domain/models/session_record.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/history/widgets/daily_minutes_chart.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';

import '../support/fake_session_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

// testNow is Sunday 25 October 2026, 18:00: the chart shows Mon 19 – Sun 25.

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
        durationMinutes: minutes,
        status: SessionStatus.completed,
      ),
      taskTitle: _tasks[taskId - 1].title,
      subject: _tasks[taskId - 1].subject,
    );

FakeSessionRepository _sessions() => FakeSessionRepository(records: [
      _record(1, 1, DateTime(2026, 10, 24, 9), 50), // Sat
      _record(2, 2, DateTime(2026, 10, 24, 14), 30), // Sat
      _record(3, 1, DateTime(2026, 10, 22, 10), 25), // Thu
      _record(4, 2, DateTime(2026, 10, 12, 10), 40), // two weeks ago
    ])
      ..taskInfo[1] = ('Lab 3 report', 'Physics')
      ..taskInfo[2] = ('Calculus practice', 'Calculus');

Finder get _chart => find.byType(DailyMinutesChart);

Future<ProviderContainer> _open(WidgetTester tester,
    {FakeSessionRepository? sessions,
    FakeSettingsRepository? settings,
    bool tall = true}) async {
  if (tall) useTallScreen(tester);
  final container = await pumpTestApp(tester,
      tasks: FakeTaskRepository(tasks: _tasks),
      sessions: sessions ?? _sessions(),
      settings: settings);
  container.read(selectedTabProvider.notifier).select(AppTab.history);
  await tester.pumpAndSettle();
  return container;
}

/// Minutes shown above each bar, left to right.
List<String> _barValues(WidgetTester tester) {
  final semantics =
      find.descendant(of: _chart, matching: find.byType(Semantics)).first;
  return tester
      .widgetList<Text>(
          find.descendant(of: semantics, matching: find.byType(Text)))
      .map((t) => t.data!)
      .where((s) => int.tryParse(s) != null)
      .toList();
}

Future<void> _choose(WidgetTester tester, String current, String option) async {
  await tester.tap(find.text(current).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows seven days in order with zero days kept', (tester) async {
    await _open(tester);

    expect(find.descendant(of: _chart, matching: find.text('Last 7 days')),
        findsOneWidget);
    expect(_barValues(tester), ['0', '0', '0', '25', '0', '80', '0']);
    for (final label in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Today']) {
      expect(find.descendant(of: _chart, matching: find.text(label)),
          findsOneWidget,
          reason: label);
    }
  });

  testWidgets('screen readers get one summary of the whole chart',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);

    final node = tester.getSemantics(
        find.descendant(of: _chart, matching: find.byType(Semantics)).first);
    expect(
        node.label,
        'Last 7 days, All tasks · All subjects. Total 1 hour 45 minutes. '
        'Most on Saturday, 80 minutes. Monday 0 minutes, Tuesday 0 minutes, '
        'Wednesday 0 minutes, Thursday 25 minutes, Friday 0 minutes, '
        'Saturday 80 minutes, Sunday 0 minutes.');
    // The 21 individual labels are not read out separately.
    expect(node.mergeAllDescendantsIntoThisNode || node.childrenCount == 0,
        isTrue);
    handle.dispose();
  });

  testWidgets('follows the task and subject filters but not the date filter',
      (tester) async {
    await _open(tester);

    await _choose(tester, 'All tasks', 'Lab 3 report');
    expect(
        find.descendant(
            of: _chart, matching: find.text('Lab 3 report · All subjects')),
        findsOneWidget);
    expect(_barValues(tester), ['0', '0', '0', '25', '0', '50', '0']);

    // Narrowing History to Today does not shrink the 7-day chart.
    await _choose(tester, 'This week', 'Today');
    expect(_barValues(tester), ['0', '0', '0', '25', '0', '50', '0']);
    expect(
        find.descendant(
            of: _chart,
            matching: find.text(
                'Uses the task and subject filters, not the date filter.')),
        findsOneWidget);

    await _choose(tester, 'Lab 3 report', 'All tasks');
    await _choose(tester, 'All subjects', 'Calculus');
    expect(_barValues(tester), ['0', '0', '0', '0', '0', '30', '0']);
  });

  testWidgets('refreshes after a session is added, edited and deleted',
      (tester) async {
    await _open(tester);

    // Add 20 minutes ending now (today).
    await tester.tap(find.text('Add session'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '20');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(_barValues(tester).last, '20');

    // Edit the newest record (today's) to 10 minutes.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '10');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(_barValues(tester).last, '10');

    // Delete it again.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(_barValues(tester).last, '0');
  });

  testWidgets('with only older sessions it shows empty days and says so',
      (tester) async {
    await _open(tester,
        sessions: FakeSessionRepository(records: [
          _record(4, 2, DateTime(2026, 10, 12, 10), 40),
        ]));

    expect(_barValues(tester), List.filled(7, '0'));
    expect(find.text('No study in the last 7 days.'), findsOneWidget);
  });

  testWidgets('is hidden when there are no sessions at all', (tester) async {
    await _open(tester, sessions: FakeSessionRepository());
    expect(_chart, findsNothing);
    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('renders in dark mode at 2x text on a phone without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _open(tester,
        tall: false,
        settings: FakeSettingsRepository(
            const AppSettings(themeMode: AppThemeMode.dark)));

    expect(tester.takeException(), isNull);
    expect(Theme.of(tester.element(_chart)).brightness, Brightness.dark);
  });

  testWidgets('on a phone the list below the chart is reached by scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await _open(tester, tall: false);

    await tester.scrollUntilVisible(find.text('Add session'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Add session'), findsOneWidget);
    expect(find.text('50 min'), findsOneWidget);
  });
}
