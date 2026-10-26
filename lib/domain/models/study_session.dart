/// The state a session was in when its record was saved.
enum SessionStatus {
  /// Finished after the timer reached the target time.
  completed('completed', 'Completed'),

  /// Finished before the target time.
  endedEarly('ended_early', 'Ended early'),

  /// Added or corrected manually from History.
  manual('manual', 'Manual entry');

  const SessionStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static SessionStatus? fromStorage(String value) {
    for (final status in values) {
      if (status.storageValue == value) return status;
    }
    return null;
  }
}

class StudySession {
  const StudySession({
    this.id,
    required this.taskId,
    required this.startedAt,
    this.endedAt,
    required this.durationMinutes,
    required this.status,
  });

  /// Null until the database assigns one.
  final int? id;
  final int taskId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationMinutes;
  final SessionStatus status;

  StudySession copyWith({
    int? id,
    int? taskId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationMinutes,
    SessionStatus? status,
  }) {
    return StudySession(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StudySession &&
      other.id == id &&
      other.taskId == taskId &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.durationMinutes == durationMinutes &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(id, taskId, startedAt, endedAt, durationMinutes, status);

  @override
  String toString() => 'StudySession($id, task $taskId, $durationMinutes min, '
      '${status.storageValue})';
}
