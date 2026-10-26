import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/data/database/app_database.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/domain/repositories/task_repository.dart';
import 'package:focus_quest/providers/core_providers.dart';
import 'package:focus_quest/providers/task_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_task_repository.dart';
import '../support/test_database.dart';

ProviderContainer _container(List overrides) {
  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [...overrides],
  );
  addTearDown(container.dispose);
  return container;
}

Future<StudyTask> _create(ProviderContainer c, String title, String subject) =>
    c.read(tasksProvider.notifier).create(
          title: title,
          subject: subject,
          priority: TaskPriority.medium,
          estimatedMinutes: 30,
        );

void main() {
  group('with the real SQLite repositories', () {
    late Database db;
    late ProviderContainer container;

    setUp(() async {
      db = await openTestDatabase();
      container = _container([
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 20, 9)),
      ]);
    });
    tearDown(() async => db.close());

    test('creating a task refreshes the task list and subjects', () async {
      container.listen(tasksProvider, (_, __) {});
      container.listen(subjectsProvider, (_, __) {});
      expect(await container.read(tasksProvider.future), isEmpty);

      await _create(container, 'Lab 3 report', 'Physics');

      final tasks = await container.read(tasksProvider.future);
      expect(tasks.map((t) => t.title), ['Lab 3 report']);
      expect(await container.read(subjectsProvider.future), ['Physics']);
    });

    test('deleting a task returns the removed session count and refreshes',
        () async {
      container.listen(tasksProvider, (_, __) {});
      final task = await _create(container, 'Lab 3 report', 'Physics');
      await db.insert(AppDatabase.sessionsTable, {
        'task_id': task.id,
        'started_at': 0,
        'duration_minutes': 20,
        'status': 'completed',
      });

      final notifier = container.read(tasksProvider.notifier);
      expect(await notifier.countSessions(task.id!), 1);
      expect(await notifier.delete(task.id!), 1);
      expect(await container.read(tasksProvider.future), isEmpty);
    });
  });

  group('with a fake repository swapped in', () {
    late FakeTaskRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = FakeTaskRepository();
      container = _container([taskRepositoryProvider.overrideWithValue(repo)]);
    });

    test('a failed load is reported as an error and can be retried',
        () async {
      repo.failNextRead = StateError('disk busy');
      container.listen(tasksProvider, (_, __) {});

      await expectLater(
          container.read(tasksProvider.future), throwsA(isA<StateError>()));
      expect(container.read(tasksProvider).hasError, isTrue);

      container.invalidate(tasksProvider);
      expect(await container.read(tasksProvider.future), isEmpty);
    });

    test('a failed save propagates and leaves the list unchanged', () async {
      container.listen(tasksProvider, (_, __) {});
      await _create(container, 'Lab 3 report', 'Physics');
      final before = container.read(dataRevisionProvider);

      repo.failNextWrite = StateError('disk full');
      await expectLater(_create(container, 'Calculus practice', 'Calculus'),
          throwsA(isA<StateError>()));

      expect(container.read(dataRevisionProvider), before);
      final tasks = await container.read(tasksProvider.future);
      expect(tasks.map((t) => t.title), ['Lab 3 report']);
    });

    test('deleting the active task is refused and nothing refreshes',
        () async {
      container.listen(tasksProvider, (_, __) {});
      final task = await _create(container, 'Lab 3 report', 'Physics');
      repo.activeTaskIds.add(task.id!);
      final before = container.read(dataRevisionProvider);

      await expectLater(container.read(tasksProvider.notifier).delete(task.id!),
          throwsA(isA<ActiveTaskDeletionException>()));
      expect(container.read(dataRevisionProvider), before);
    });
  });
}
