class StudySession {
  final int? id;
  final int taskId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String status;

  const StudySession({
    this.id,
    required this.taskId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.status = 'completed',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_minutes': durationMinutes,
      'status': status,
    };
  }

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      durationMinutes: map['duration_minutes'] as int,
      status: map['status'] as String? ?? 'completed',
    );
  }
}