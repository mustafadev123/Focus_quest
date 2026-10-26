import '../models/study_task.dart';

/// Thrown when an id does not match a saved record.
class RecordNotFoundException implements Exception {
  const RecordNotFoundException(this.id);

  final int id;

  @override
  String toString() => 'RecordNotFoundException($id)';
}

/// Thrown when deleting the task of a focus session that is still in
/// progress; the session must be saved or reset first.
class ActiveTaskDeletionException implements Exception {
  const ActiveTaskDeletionException(this.taskId);

  final int taskId;

  @override
  String toString() => 'ActiveTaskDeletionException($taskId)';
}

abstract interface class TaskRepository {
  /// All tasks, oldest first.
  Future<List<StudyTask>> getAll();

  Future<StudyTask?> getById(int id);

  /// Distinct subjects in use, alphabetically, for suggestions and filters.
  Future<List<String>> getSubjects();

  /// Validates and saves a new task. The repository sets the id and both
  /// timestamps.
  Future<StudyTask> create({
    required String title,
    required String subject,
    required TaskPriority priority,
    required int estimatedMinutes,
    TaskStatus status = TaskStatus.pending,
  });

  /// Validates and saves [task], refreshing `updatedAt`.
  Future<StudyTask> update(StudyTask task);

  /// Number of sessions that deleting the task would also remove.
  Future<int> countSessions(int taskId);

  /// Deletes the task and its sessions in one transaction and returns how
  /// many sessions were removed.
  ///
  /// Throws [ActiveTaskDeletionException] while the task has an unsaved
  /// focus session.
  Future<int> delete(int taskId);
}
