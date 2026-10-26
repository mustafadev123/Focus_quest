import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/data/repositories/sqlite_session_repository.dart';
import 'package:focus_quest/data/repositories/sqlite_task_repository.dart';
import 'package:focus_quest/domain/helper/smart_helper.dart';
import 'package:focus_quest/domain/models/app_settings.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/providers/core_providers.dart';
import 'package:focus_quest/providers/helper_providers.dart';
import 'package:focus_quest/providers/settings_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_settings_repository.dart';
import '../support/test_database.dart';

void main() {
  late Database db;
  final now = DateTime(2026, 10, 25, 18);
  late ProviderContainer container;

  setUp(() async {
    db = await openTestDatabase();
    container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(const AppSettings(sessionMinutes: 30))),
      ],
    );
    container.listen(recommendationProvider, (_, __) {});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> addTask(int priority, int minutes, String title) async {
    final task = await SqliteTaskRepository(db, clock: () => now).create(
      title: title,
      subject: 'Subject',
      priority: TaskPriority.fromValue(priority)!,
      estimatedMinutes: minutes,
    );
    return task.id!;
  }

  Future<void> addSession(int taskId, Duration ago, int minutes) =>
      SqliteSessionRepository(db, clock: () => now).create(StudySession.manual(
        taskId: taskId,
        startedAt: now.subtract(ago),
        durationMinutes: minutes,
      ));

  test('available time starts at the Settings focus duration', () async {
    await container.read(settingsProvider.future);
    expect(container.read(availableMinutesProvider), 30);
  });

  test('only sessions from the last 7 days count as recent activity', () async {
    final a = await addTask(2, 30, 'A');
    final b = await addTask(2, 30, 'B');
    // A: one session 6 days ago (counts). B: one 8 days ago (does not).
    await addSession(a, const Duration(days: 6), 100);
    await addSession(b, const Duration(days: 8), 100);
    container.read(dataRevisionProvider.notifier).bump();

    final result =
        await container.read(recommendationProvider.future) as Recommendation;
    final byId = {for (final s in result.ranked) s.task.id: s};
    expect(byId[a]!.recentMinutes, 100);
    expect(byId[b]!.recentMinutes, 0);
    expect(result.task.id, b);
    expect(result.usedHistory, isTrue);
  });

  test('recomputes when the available time changes', () async {
    await addTask(3, 120, 'Long, high priority');
    await addTask(2, 30, 'Short, medium priority');
    container.read(dataRevisionProvider.notifier).bump();

    container.read(availableMinutesProvider.notifier).set(120);
    var result =
        await container.read(recommendationProvider.future) as Recommendation;
    expect(result.task.title, 'Long, high priority');

    // 5 minutes: long task fit 0.04 → 0.5+0.0125+0.2 = 0.71; short:
    // 0.25+0.05+0.2 = 0.50, so the long one still wins on priority.
    container.read(availableMinutesProvider.notifier).set(5);
    result =
        await container.read(recommendationProvider.future) as Recommendation;
    expect(result.availableMinutes, 5);
    expect(result.task.title, 'Long, high priority');
  });

  test('with no tasks there is nothing to recommend', () async {
    expect(await container.read(recommendationProvider.future),
        isA<NoEligibleTask>());
  });
}
