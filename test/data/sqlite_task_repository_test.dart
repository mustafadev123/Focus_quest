import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/data/database/app_database.dart';
import 'package:focus_quest/data/repositories/sqlite_task_repository.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/domain/repositories/task_repository.dart';
import 'package:focus_quest/domain/validation/validation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_database.dart';

void main() {
  late Database db;
  late DateTime now;
  late SqliteTaskRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    now = DateTime(2026, 10, 20, 9);
    repo = SqliteTaskRepository(db, clock: () => now);
  });
  tearDown(() async => db.close());

  Future<StudyTask> create({
    String title = 'Review recursion notes',
    String subject = 'Data Structures',
  }) =>
      repo.create(
        title: title,
        subject: subject,
        priority: TaskPriority.high,
        estimatedMinutes: 25,
      );

  Future<void> addSession(int taskId) => db.insert(AppDatabase.sessionsTable, {
        'task_id': taskId,
        'started_at': now.millisecondsSinceEpoch,
        'duration_minutes': 25,
        'status': 'completed',
      });

  test('create trims text, sets timestamps and defaults to pending', () async {
    final task = await create(title: '  Lab 3 report  ', subject: ' Physics ');

    expect(task.id, isNotNull);
    expect(task.title, 'Lab 3 report');
    expect(task.subject, 'Physics');
    expect(task.status, TaskStatus.pending);
    expect(task.createdAt, now);
    expect(task.updatedAt, now);
    expect(await repo.getById(task.id!), task);
  });

  test('create refuses invalid input without writing anything', () async {
    await expectLater(
      repo.create(
        title: ' ',
        subject: 'Physics',
        priority: TaskPriority.low,
        estimatedMinutes: 200,
      ),
      throwsA(isA<ValidationException>().having(
          (e) => e.errors.keys, 'fields', ['title', 'estimatedMinutes'])),
    );
    expect(await repo.getAll(), isEmpty);
  });

  test('getAll lists tasks oldest first', () async {
    await create(title: 'First');
    now = now.add(const Duration(minutes: 5));
    await create(title: 'Second');

    expect((await repo.getAll()).map((t) => t.title), ['First', 'Second']);
  });

  test('update saves changes and refreshes updatedAt only', () async {
    final task = await create();
    now = now.add(const Duration(hours: 2));

    final updated = await repo.update(
        task.copyWith(title: 'Recursion quiz', status: TaskStatus.completed));

    expect(updated.createdAt, task.createdAt);
    expect(updated.updatedAt, now);
    expect(await repo.getById(task.id!), updated);
  });

  test('update keeps updatedAt valid if the clock moved backwards', () async {
    final task = await create();
    now = now.subtract(const Duration(days: 1));

    final updated = await repo.update(task.copyWith(title: 'Edited'));
    expect(updated.updatedAt, task.createdAt);
  });

  test('update of a deleted task reports it is missing', () async {
    final task = await create();
    await repo.delete(task.id!);

    expect(() => repo.update(task),
        throwsA(isA<RecordNotFoundException>()));
  });

  test('delete removes the task with its sessions and reports the count',
      () async {
    final task = await create();
    final other = await create(title: 'Calculus practice');
    await addSession(task.id!);
    await addSession(task.id!);
    await addSession(other.id!);

    expect(await repo.countSessions(task.id!), 2);
    expect(await repo.delete(task.id!), 2);

    expect(await repo.getById(task.id!), isNull);
    expect(await repo.countSessions(other.id!), 1);
  });

  test('delete is blocked while the task has an unsaved focus session',
      () async {
    final task = await create();
    await addSession(task.id!);
    await db.insert(AppDatabase.activeSessionTable, {
      'id': 1,
      'task_id': task.id,
      'state': 'running',
      'started_at': now.millisecondsSinceEpoch,
      'elapsed_active_ms': 0,
      'target_minutes': 25,
      'last_resumed_at': now.millisecondsSinceEpoch,
    });

    await expectLater(repo.delete(task.id!),
        throwsA(isA<ActiveTaskDeletionException>()));
    expect(await repo.getById(task.id!), isNotNull);
    expect(await repo.countSessions(task.id!), 1);
  });

  test('deleting an unknown id reports it is missing', () {
    expect(() => repo.delete(404), throwsA(isA<RecordNotFoundException>()));
  });

  test('getSubjects returns each subject once, case-insensitively sorted',
      () async {
    await create(subject: 'physics');
    await create(subject: 'Calculus');
    await create(subject: 'Calculus');

    expect(await repo.getSubjects(), ['Calculus', 'physics']);
  });
}
