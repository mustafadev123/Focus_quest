import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/domain/repositories/task_repository.dart';
import 'package:focus_quest/domain/validation/validation.dart';

/// In-memory [TaskRepository] that can be told to fail, for testing error
/// and Retry paths without a database.
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({List<StudyTask> tasks = const [], DateTime? now})
      : _now = now ?? DateTime(2026, 10, 20, 9) {
    for (final task in tasks) {
      final id = task.id ?? ++_lastId;
      if (id > _lastId) _lastId = id;
      _tasks[id] = task.copyWith(id: id);
    }
  }

  final Map<int, StudyTask> _tasks = {};
  final Map<int, int> sessionCounts = {};
  final Set<int> activeTaskIds = {};
  final DateTime _now;
  int _lastId = 0;

  /// When set, the next read throws this and clears it.
  Object? failNextRead;

  /// When set, the next write throws this and clears it.
  Object? failNextWrite;

  /// When true, every call throws until reset.
  bool failAlways = false;

  void _maybeFail({bool write = false}) {
    if (failAlways) throw StateError('storage unavailable');
    final error = write ? failNextWrite : failNextRead;
    if (error == null) return;
    if (write) {
      failNextWrite = null;
    } else {
      failNextRead = null;
    }
    throw error;
  }

  @override
  Future<List<StudyTask>> getAll() async {
    _maybeFail();
    return _tasks.values.toList()
      ..sort((a, b) {
        final byDate = a.createdAt.compareTo(b.createdAt);
        return byDate != 0 ? byDate : a.id!.compareTo(b.id!);
      });
  }

  @override
  Future<StudyTask?> getById(int id) async {
    _maybeFail();
    return _tasks[id];
  }

  @override
  Future<List<String>> getSubjects() async {
    _maybeFail();
    return {for (final t in _tasks.values) t.subject}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  Future<StudyTask> create({
    required String title,
    required String subject,
    required TaskPriority priority,
    required int estimatedMinutes,
    TaskStatus status = TaskStatus.pending,
  }) async {
    _maybeFail(write: true);
    final task = StudyTask(
      id: ++_lastId,
      title: title.trim(),
      subject: subject.trim(),
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      status: status,
      createdAt: _now,
      updatedAt: _now,
    );
    ensureValidTask(task);
    return _tasks[task.id!] = task;
  }

  @override
  Future<StudyTask> update(StudyTask task) async {
    _maybeFail(write: true);
    if (!_tasks.containsKey(task.id)) throw RecordNotFoundException(task.id!);
    ensureValidTask(task);
    return _tasks[task.id!] = task;
  }

  @override
  Future<int> countSessions(int taskId) async {
    _maybeFail();
    return sessionCounts[taskId] ?? 0;
  }

  @override
  Future<int> delete(int taskId) async {
    _maybeFail(write: true);
    if (activeTaskIds.contains(taskId)) {
      throw ActiveTaskDeletionException(taskId);
    }
    if (_tasks.remove(taskId) == null) throw RecordNotFoundException(taskId);
    return sessionCounts.remove(taskId) ?? 0;
  }
}
