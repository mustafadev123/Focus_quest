import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/app.dart';
import 'package:focus_quest/providers/core_providers.dart';

import 'fake_focus_checkpoint_repository.dart';
import 'fake_session_repository.dart';
import 'fake_task_repository.dart';

/// Fixed "now" for widget tests: Sunday 25 October 2026, 18:00.
final testNow = DateTime(2026, 10, 25, 18);

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
