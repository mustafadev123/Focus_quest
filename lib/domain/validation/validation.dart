import '../models/study_session.dart';
import '../models/study_task.dart';

/// Field limits from proposal Section 8.
abstract final class Limits {
  static const titleMaxLength = 60;
  static const subjectMaxLength = 40;
  static const minEstimatedMinutes = 5;
  static const maxEstimatedMinutes = 120;
  static const minAvailableMinutes = 5;
  static const maxAvailableMinutes = 120;
  static const minSessionMinutes = 1;
  static const maxSessionMinutes = 120;
}

/// Thrown when a record fails validation before it is written.
class ValidationException implements Exception {
  const ValidationException(this.errors);

  /// Field name to user-facing message.
  final Map<String, String> errors;

  @override
  String toString() => 'ValidationException($errors)';
}

/// Validators return a user-facing message, or null when the value is valid,
/// so they can be used directly as form-field validators.
String? validateTitle(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Title is required';
  if (text.length > Limits.titleMaxLength) {
    return 'Title must be ${Limits.titleMaxLength} characters or fewer';
  }
  return null;
}

String? validateSubject(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Subject is required';
  if (text.length > Limits.subjectMaxLength) {
    return 'Subject must be ${Limits.subjectMaxLength} characters or fewer';
  }
  return null;
}

String? validateEstimatedMinutes(int? minutes) => _validateRange(
      minutes,
      Limits.minEstimatedMinutes,
      Limits.maxEstimatedMinutes,
      'Estimated time',
    );

String? validateAvailableMinutes(int? minutes) => _validateRange(
      minutes,
      Limits.minAvailableMinutes,
      Limits.maxAvailableMinutes,
      'Available time',
    );

String? validateSessionMinutes(int? minutes) => _validateRange(
      minutes,
      Limits.minSessionMinutes,
      Limits.maxSessionMinutes,
      'Duration',
    );

/// A manually recorded session cannot start in the future, so it never
/// counts towards totals before it happened.
String? validateSessionStart(DateTime? startedAt, DateTime now) {
  if (startedAt == null) return 'Start time is required';
  if (startedAt.isAfter(now)) return 'Start time cannot be in the future';
  return null;
}

/// Parses a numeric text field; returns null for blank or non-numeric input.
int? parseMinutes(String? text) => int.tryParse(text?.trim() ?? '');

String? _validateRange(int? value, int min, int max, String label) {
  if (value == null) return '$label must be a whole number';
  if (value < min || value > max) {
    return '$label must be between $min and $max minutes';
  }
  return null;
}

/// Checks every field of [task]; throws [ValidationException] if any fail.
void ensureValidTask(StudyTask task) {
  final errors = <String, String>{
    if (validateTitle(task.title) case final e?) 'title': e,
    if (validateSubject(task.subject) case final e?) 'subject': e,
    if (validateEstimatedMinutes(task.estimatedMinutes) case final e?)
      'estimatedMinutes': e,
    if (task.updatedAt.isBefore(task.createdAt))
      'updatedAt': 'Last update cannot be before creation',
  };
  if (errors.isNotEmpty) throw ValidationException(errors);
}

/// Checks every field of [session]; throws [ValidationException] if any fail.
void ensureValidSession(StudySession session, {required DateTime now}) {
  final endedAt = session.endedAt;
  final errors = <String, String>{
    if (validateSessionMinutes(session.durationMinutes) case final e?)
      'durationMinutes': e,
    if (validateSessionStart(session.startedAt, now) case final e?)
      'startedAt': e,
    if (endedAt != null && endedAt.isBefore(session.startedAt))
      'endedAt': 'End time cannot be before start time',
  };
  if (errors.isNotEmpty) throw ValidationException(errors);
}
