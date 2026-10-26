import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/app.dart';
import 'package:focus_quest/providers/core_providers.dart';

import 'fake_session_repository.dart';
import 'fake_task_repository.dart';

/// Fixed "now" for widget tests: Sunday 25 October 2026, 18:00.
final testNow = DateTime(2026, 10, 25, 18);

/// Pumps the whole app with fake repositories and a fixed clock.
///
/// Returns the container so tests can inspect or drive providers.
Future<ProviderContainer> pumpTestApp(
  WidgetTester tester, {
  FakeTaskRepository? tasks,
  FakeSessionRepository? sessions,
  DateTime? now,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      taskRepositoryProvider.overrideWithValue(tasks ?? FakeTaskRepository()),
      sessionRepositoryProvider
          .overrideWithValue(sessions ?? FakeSessionRepository()),
      clockProvider.overrideWithValue(() => now ?? testNow),
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
