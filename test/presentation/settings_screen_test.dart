import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/app_settings.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';
import 'package:focus_quest/providers/dashboard_providers.dart';

import '../support/fake_settings_repository.dart';
import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

Future<ProviderContainer> _openSettings(WidgetTester tester,
    {FakeSettingsRepository? settings, FakeTaskRepository? tasks}) async {
  final container = await pumpTestApp(tester, settings: settings, tasks: tasks);
  container.read(selectedTabProvider.notifier).select(AppTab.settings);
  await tester.pumpAndSettle();
  return container;
}

Switch _switch(WidgetTester tester, String label) =>
    tester.widget<Switch>(find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Row)),
        matching: find.byType(Switch)));

Future<void> _save(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Save settings'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(find.text('Save settings'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the defaults', (tester) async {
    await _openSettings(tester);

    expect(find.text('25 min'), findsOneWidget);
    expect(_switch(tester, 'Daily reminder').value, isFalse);
    expect(_switch(tester, 'Reduced motion').value, isFalse);
    expect(find.text('7:00 PM'), findsOneWidget);
    // Reminder time is unavailable while reminders are off.
    final timeButton = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('7:00 PM'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(timeButton.onPressed, isNull);
  });

  testWidgets('changes are stored only when Save settings is pressed',
      (tester) async {
    final settings = FakeSettingsRepository();
    await _openSettings(tester, settings: settings);

    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(slider.right - 4, slider.center.dy));
    await tester.tap(find.text('Daily reminder'));
    await tester.tap(find.text('Reduced motion'));
    await tester.pumpAndSettle();

    expect(find.text('120 min'), findsNWidgets(2)); // value + range label
    expect(settings.stored, AppSettings.defaults);

    await _save(tester);
    expect(find.text('Settings saved'), findsOneWidget);
    expect(settings.stored.sessionMinutes, 120);
    expect(settings.stored.remindersEnabled, isTrue);
    expect(settings.stored.reducedMotion, isTrue);
  });

  testWidgets('loads previously saved settings', (tester) async {
    await _openSettings(tester,
        settings: FakeSettingsRepository(const AppSettings(
          sessionMinutes: 50,
          remindersEnabled: true,
          reminderTime: ReminderTime(7, 30),
        )));

    expect(find.text('50 min'), findsOneWidget);
    expect(_switch(tester, 'Daily reminder').value, isTrue);
    expect(find.text('7:30 AM'), findsOneWidget);
  });

  testWidgets('a failed save keeps the edits and can be retried',
      (tester) async {
    final settings = FakeSettingsRepository()
      ..failNextSave = StateError('storage full');
    await _openSettings(tester, settings: settings);

    await tester.tap(find.text('Reduced motion'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(find.textContaining("Couldn't save your settings"), findsOneWidget);
    expect(_switch(tester, 'Reduced motion').value, isTrue);
    expect(settings.stored.reducedMotion, isFalse);

    await _save(tester);
    expect(settings.stored.reducedMotion, isTrue);
    expect(find.textContaining("Couldn't save your settings"), findsNothing);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    final settings = FakeSettingsRepository()
      ..failNextLoad = StateError('storage unavailable');
    await _openSettings(tester, settings: settings);

    expect(find.text("Couldn't load your settings."), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Focus duration'), findsOneWidget);
  });

  testWidgets('the saved focus duration becomes the Focus target',
      (tester) async {
    final container = await _openSettings(tester,
        settings: FakeSettingsRepository(const AppSettings(sessionMinutes: 45)),
        tasks: FakeTaskRepository(tasks: [
          StudyTask(
            id: 1,
            title: 'Lab 3 report',
            subject: 'Physics',
            priority: TaskPriority.high,
            estimatedMinutes: 60,
            status: TaskStatus.pending,
            createdAt: DateTime(2026, 10, 20),
            updatedAt: DateTime(2026, 10, 20),
          ),
        ]));

    container.read(selectedTaskIdProvider.notifier).select(1);
    container.read(selectedTabProvider.notifier).select(AppTab.focus);
    await tester.pumpAndSettle();

    expect(find.text('45:00'), findsOneWidget);
    expect(find.text('of 45 minutes'), findsOneWidget);
  });

  testWidgets('Reduced motion turns animations off across the app',
      (tester) async {
    await _openSettings(tester);
    final context = tester.element(find.text('Focus duration'));
    expect(MediaQuery.disableAnimationsOf(context), isFalse);

    await tester.tap(find.text('Reduced motion'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(
        MediaQuery.disableAnimationsOf(
            tester.element(find.text('Focus duration'))),
        isTrue);
  });

  testWidgets('lays out in landscape at 2x text scale', (tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openSettings(tester);
    expect(tester.takeException(), isNull);
  });
}
