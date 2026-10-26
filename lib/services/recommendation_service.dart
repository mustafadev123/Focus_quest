
import '../models/study_task.dart';
import '../repositories/task_repository.dart';

class TaskRecommendation {
  final StudyTask task;
  final double score;
  final String explanation;

  const TaskRecommendation({
    required this.task,
    required this.score,
    required this.explanation,
  });
}

class RecommendationService {
  final TaskRepository _taskRepository;

  RecommendationService({
    TaskRepository? taskRepository,
  }) : _taskRepository = taskRepository ?? TaskRepository();

  Future<List<TaskRecommendation>> recommendTasks({
    required int availableMinutes,
  }) async {
    if (availableMinutes < 5 || availableMinutes > 120) {
      throw ArgumentError(
        'Available study time must be between 5 and 120 minutes.',
      );
    }

    final tasks = await _taskRepository.getAllTasks();

    final eligibleTasks = tasks.where((task) {
      return !task.isCompleted &&
          task.id != null &&
          task.priority >= 1 &&
          task.priority <= 3 &&
          task.estimatedMinutes >= 5 &&
          task.estimatedMinutes <= 120;
    }).toList();

    final recommendations = <TaskRecommendation>[];

    for (final task in eligibleTasks) {
      final recentMinutes =
          await _taskRepository.getTotalStudyMinutes(task.id!);

      final priorityScore = (task.priority - 1) / 2;
      final fitScore =
          (availableMinutes / task.estimatedMinutes).clamp(0.0, 1.0);
      final recencyScore = 1 / (1 + recentMinutes / 25);

      final score = 0.50 * priorityScore +
          0.30 * fitScore +
          0.20 * recencyScore;

      final explanation =
          'Priority: ${task.priority}/3. '
          'Estimated time: ${task.estimatedMinutes} minutes. '
          'Available time: $availableMinutes minutes. '
          'Study time recorded: $recentMinutes minutes.';

      recommendations.add(
        TaskRecommendation(
          task: task,
          score: score,
          explanation: explanation,
        ),
      );
    }

    recommendations.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) return scoreComparison;

      final dateComparison =
          a.task.createdAt.compareTo(b.task.createdAt);
      if (dateComparison != 0) return dateComparison;

      return a.task.id!.compareTo(b.task.id!);
    });

    return recommendations;
  }
}
