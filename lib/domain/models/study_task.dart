/// Task priority stored as 1 (low), 2 (medium) or 3 (high).
enum TaskPriority {
  low(1, 'Low'),
  medium(2, 'Medium'),
  high(3, 'High');

  const TaskPriority(this.value, this.label);

  final int value;
  final String label;

  static TaskPriority? fromValue(int value) {
    for (final priority in values) {
      if (priority.value == value) return priority;
    }
    return null;
  }
}

/// Stored as `pending` or `completed`; shown as "To do" or "Completed".
enum TaskStatus {
  pending('pending', 'To do'),
  completed('completed', 'Completed');

  const TaskStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static TaskStatus? fromStorage(String value) {
    for (final status in values) {
      if (status.storageValue == value) return status;
    }
    return null;
  }
}

class StudyTask {
  const StudyTask({
    this.id,
    required this.title,
    required this.subject,
    required this.priority,
    required this.estimatedMinutes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Null until the database assigns one.
  final int? id;
  final String title;
  final String subject;
  final TaskPriority priority;
  final int estimatedMinutes;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == TaskStatus.completed;

  StudyTask copyWith({
    int? id,
    String? title,
    String? subject,
    TaskPriority? priority,
    int? estimatedMinutes,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyTask(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      priority: priority ?? this.priority,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StudyTask &&
      other.id == id &&
      other.title == title &&
      other.subject == subject &&
      other.priority == priority &&
      other.estimatedMinutes == estimatedMinutes &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, title, subject, priority,
      estimatedMinutes, status, createdAt, updatedAt);

  @override
  String toString() => 'StudyTask($id, $title, ${priority.label}, '
      '$estimatedMinutes min, ${status.storageValue})';
}
