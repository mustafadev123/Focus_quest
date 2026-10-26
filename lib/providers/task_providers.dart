import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/study_task.dart';
import 'core_providers.dart';

/// Saved tasks plus the write operations screens use.
///
/// Write methods let errors propagate so forms can keep the user's input and
/// offer Retry; on success they bump [dataRevisionProvider] so every screen
/// reloads.
class TaskListNotifier extends AsyncNotifier<List<StudyTask>> {
  @override
  Future<List<StudyTask>> build() {
    ref.watch(dataRevisionProvider);
    return ref.watch(taskRepositoryProvider).getAll();
  }

  Future<StudyTask> create({
    required String title,
    required String subject,
    required TaskPriority priority,
    required int estimatedMinutes,
    TaskStatus status = TaskStatus.pending,
  }) async {
    final task = await ref.read(taskRepositoryProvider).create(
          title: title,
          subject: subject,
          priority: priority,
          estimatedMinutes: estimatedMinutes,
          status: status,
        );
    _changed();
    return task;
  }

  Future<StudyTask> save(StudyTask task) async {
    final saved = await ref.read(taskRepositoryProvider).update(task);
    _changed();
    return saved;
  }

  /// Returns the number of sessions removed with the task.
  Future<int> delete(int taskId) async {
    final removed = await ref.read(taskRepositoryProvider).delete(taskId);
    _changed();
    return removed;
  }

  Future<int> countSessions(int taskId) =>
      ref.read(taskRepositoryProvider).countSessions(taskId);

  void _changed() {
    if (ref.mounted) ref.read(dataRevisionProvider.notifier).bump();
  }
}

final tasksProvider =
    AsyncNotifierProvider<TaskListNotifier, List<StudyTask>>(
        TaskListNotifier.new);

final subjectsProvider = FutureProvider<List<String>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(taskRepositoryProvider).getSubjects();
});
