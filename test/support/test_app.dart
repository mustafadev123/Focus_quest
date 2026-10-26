import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/app.dart';
import 'package:focus_quest/domain/history.dart';
import 'package:focus_quest/providers/core_providers.dart';
import 'package:focus_quest/providers/history_providers.dart';
import 'package:focus_quest/domain/report/study_report.dart';
import 'package:focus_quest/providers/notification_providers.dart';
import 'package:focus_quest/providers/report_providers.dart';
import 'package:focus_quest/providers/settings_providers.dart';

import 'fake_focus_checkpoint_repository.dart';
import 'fake_notification_service.dart';
import 'fake_report_file_service.dart';
import 'fake_session_repository.dart';
import 'fake_settings_repository.dart';
import 'fake_task_repository.dart';

/// Fixed "now" for widget tests: Sunday 25 October 2026, 18:00.
final testNow = DateTime(2026, 10, 25, 18);

/// A tall test surface (800×1600) so long screens such as History build
/// their lower rows without scrolling. Reset after the test.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A clock tests can move forward.
class TestClock {
  TestClock([DateTime? start]) : now = start ?? testNow;

  DateTime now;

  void advance(Duration by) => now = now.add(by);

  DateTime call() => now;
}

/// Pumps the whole app with fake repositories and a controllable clock.
///
/// Returns the container so tests can inspect or drive providers.
Future<ProviderContainer> pumpTestApp(
  WidgetTester tester, {
  FakeTaskRepository? tasks,
  FakeSessionRepository? sessions,
  FakeFocusCheckpointRepository? checkpoints,
  FakeSettingsRepository? settings,
  FakeNotificationService? notifications,
  FakeReportFileService? reports,
  DateTime? now,
  TestClock? clock,
  bool settle = true,
}) async {
  final sessionRepo = sessions ?? FakeSessionRepository();
  final testClock = clock ?? TestClock(now);
  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      taskRepositoryProvider.overrideWithValue(tasks ?? FakeTaskRepository()),
      sessionRepositoryProvider.overrideWithValue(sessionRepo),
      focusCheckpointRepositoryProvider.overrideWithValue(
          checkpoints ?? FakeFocusCheckpointRepository(sessions: sessionRepo)),
      clockProvider.overrideWithValue(testClock.call),
      settingsRepositoryProvider
          .overrideWithValue(settings ?? FakeSettingsRepository()),
      notificationServiceProvider
          .overrideWithValue(notifications ?? FakeNotificationService()),
      reportFileServiceProvider
          .overrideWithValue(reports ?? FakeReportFileService()),
      reportBuilderProvider
          .overrideWithValue((input) async => buildStudyReport(input)),
      // Real isolates do not run inside the widget-test fake clock.
      historyAggregatorProvider
          .overrideWithValue((records) async => summarizeHistory(records)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const FocusQuestApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}
