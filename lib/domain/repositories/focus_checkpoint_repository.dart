import '../focus/focus_session.dart';
import '../models/study_session.dart';

/// Thrown when Save is repeated after the session was already recorded.
class SessionAlreadySavedException implements Exception {
  const SessionAlreadySavedException();

  @override
  String toString() => 'SessionAlreadySavedException';
}

/// Persists the in-progress focus session so it survives a restart.
abstract interface class FocusCheckpointRepository {
  /// The saved in-progress session, or null if there is none.
  Future<FocusSession?> load();

  /// Replaces the checkpoint with [session], which must be in progress.
  Future<void> save(FocusSession session);

  /// Removes the checkpoint, for example after Reset.
  Future<void> clear();

  /// Writes the history record for [session] and removes its checkpoint in
  /// one transaction, so a retried or repeated Save can never create a
  /// second record.
  ///
  /// Throws [SessionAlreadySavedException] if the checkpoint for this
  /// session no longer exists.
  Future<StudySession> saveRecord(FocusSession session);
}
