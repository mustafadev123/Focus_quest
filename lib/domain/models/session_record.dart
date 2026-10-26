import 'study_session.dart';

/// A saved session joined with the task it belongs to, as listed in History.
class SessionRecord {
  const SessionRecord({
    required this.session,
    required this.taskTitle,
    required this.subject,
  });

  final StudySession session;
  final String taskTitle;
  final String subject;

  @override
  bool operator ==(Object other) =>
      other is SessionRecord &&
      other.session == session &&
      other.taskTitle == taskTitle &&
      other.subject == subject;

  @override
  int get hashCode => Object.hash(session, taskTitle, subject);
}
