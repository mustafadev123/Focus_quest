class StudyTask {
  final int? id;
  final String title;
  final int priority;
  final int estimatedMinutes;
  final bool isCompleted;
  final DateTime createdAt;

  const StudyTask({
    this.id,
    required this.title,
    required this.priority,
    required this.estimatedMinutes,
    this.isCompleted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'priority': priority,
      'estimated_minutes': estimatedMinutes,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StudyTask.fromMap(Map<String, dynamic> map) {
    return StudyTask(
      id: map['id'] as int?,
      title: map['title'] as String,
      priority: map['priority'] as int,
      estimatedMinutes: map['estimated_minutes'] as int,
      isCompleted: map['is_completed'] == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}