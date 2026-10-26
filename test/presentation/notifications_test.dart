import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/app_settings.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';
import 'package:focus_quest/providers/dashboard_providers.dart';

import '../support/fake_notification_service.dart';
import '../support/fake_settings_repository.dart';
import '../support/fake_task_repository.dart';
import '../support/test_app.dart';

final _task = StudyTask(
  id: 1,
  title: 'Lab 3 report',
  subject: 'Physics',
  priority: TaskPriority.high,
  estimatedMinutes: 50,
  status: TaskStatus.pending,
  createdAt: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 10, 20),
);

const _remindersOn = AppSettings(
  remindersEnabled: true,
  reminderTime: ReminderTime(7, 30),
);

Future<ProviderContainer> _open(
  WidgetTester tester, {
  required FakeNotificationService notifications,
  AppSettings saved = AppSettings.defaults,
  AppTab tab = AppTab.settings,
  TestClock? clock,
}) async {
  final container = await pumpTestApp(tester,
      notifications: notifications,
      settings: FakeSettingsRepository(saved),
      tasks: FakeTaskRepository(tasks: [_task]),
      clock: clock);
  container.read(selectedTaskIdProvider.notifier).select(1);
  container.read(selectedTabProvider.notifier).select(tab);
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  group('permission and the daily reminder', () {
    testWidgets('turning the reminder on asks once; granted schedules it',
        (tester) async {
      final notifications = FakeNotificationService(grantOnRequest: true);
      await _open(tester, notifications: notifications);

      await _tap(tester, 'Daily reminder');
      expect(notifications.permissionRequests, 1);
      expect(find.text('Notifications are off for FocusQuest.'), findsNothing);
      expect(notifications.dailyReminder, isNull, reason: 'not saved yet');

      await _tap(tester, 'Save settings');
      expect(notifications.dailyReminder, AppSettings.defaultReminderTime);
    });

    testWidgets('denied permission shows how to fix it; the app still works',
        (tester) async {
      final notifications = FakeNotificationService(grantOnRequest: false);
      await _open(tester, notifications: notifications);

      await _tap(tester, 'Daily reminder');
      expect(
          find.text('Notifications are off for FocusQuest.'), findsOneWidget);

      await _tap(tester, 'Open phone settings');
      expect(notifications.settingsOpened, 1);

      await _tap(tester, 'Save settings');
      expect(find.text('Settings saved'), findsOneWidget);
      expect(notifications.dailyReminder, isNull);
    });

    testWidgets('does not ask again when notifications are already allowed',
        (tester) async {
      final notifications = FakeNotificationService(allowed: true);
      await _open(tester, notifications: notifications);

      await _tap(tester, 'Daily reminder');
      expect(notifications.permissionRequests, 0);
    });

    testWidgets(
        'a saved reminder is scheduled at launch and cancelled when '
        'turned off', (tester) async {
      final notifications = FakeNotificationService(allowed: true);
      await _open(tester, notifications: notifications, saved: _remindersOn);
      expect(notifications.dailyReminder, const ReminderTime(7, 30));

      await _tap(tester, 'Daily reminder');
      await _tap(tester, 'Save settings');
      expect(notifications.dailyReminder, isNull);
    });

    testWidgets(
        'allowing notifications in phone settings takes effect on '
        'return to the app', (tester) async {
      final notifications = FakeNotificationService(allowed: false);
      await _open(tester, notifications: notifications, saved: _remindersOn);
      expect(
          find.text('Notifications are off for FocusQuest.'), findsOneWidget);
      expect(notifications.dailyReminder, isNull);

      notifications.allowed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(notifications.dailyReminder, const ReminderTime(7, 30));
      expect(find.text('Notifications are off for FocusQuest.'), findsNothing);
    });
  });

  group('session-end alert', () {
    Finder button(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

    Future<void> press(WidgetTester tester, String label) async {
      await tester.tap(button(label));
      await tester.pumpAndSettle();
    }

    testWidgets('follows the session: start, pause, resume and finish',
        (tester) async {
      final clock = TestClock();
      final notifications = FakeNotificationService(allowed: true);
      await _open(tester,
          notifications: notifications,
          saved: _remindersOn,
          tab: AppTab.focus,
          clock: clock);

      await press(tester, 'Start');
      expect(notifications.sessionEnd?.at,
          testNow.add(const Duration(minutes: 25)));
      expect(notifications.sessionEnd?.taskTitle, 'Lab 3 report');
      expect(notifications.sessionEnd?.minutes, 25);

      clock.advance(const Duration(minutes: 10));
      await press(tester, 'Pause');
      expect(notifications.sessionEnd, isNull);

      clock.advance(const Duration(minutes: 5));
      await press(tester, 'Resume');
      // 15 minutes left from the resume at 18:15.
      expect(notifications.sessionEnd?.at,
          testNow.add(const Duration(minutes: 30)));

      clock.advance(const Duration(minutes: 1));
      await press(tester, 'Finish');
      expect(notifications.sessionEnd, isNull);
    });

    testWidgets('is not scheduled unless reminders are on', (tester) async {
      final notifications = FakeNotificationService(allowed: true);
      await _open(tester, notifications: notifications, tab: AppTab.focus);

      await press(tester, 'Start');
      expect(notifications.sessionEnd, isNull);
    });

    testWidgets('is not scheduled without permission', (tester) async {
      final notifications = FakeNotificationService(allowed: false);
      await _open(tester,
          notifications: notifications, saved: _remindersOn, tab: AppTab.focus);

      await press(tester, 'Start');
      expect(notifications.sessionEnd, isNull);
    });
  });
}
