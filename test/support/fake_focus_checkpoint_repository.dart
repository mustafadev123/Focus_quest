import 'package:focus_quest/domain/focus/focus_session.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/repositories/focus_checkpoint_repository.dart';

import 'fake_session_repository.dart';

/// In-memory checkpoint store; saved records go to [sessions] when given.
class FakeFocusCheckpointRepository implements FocusCheckpointRepository {
  FakeFocusCheckpointRepository({this.checkpoint, this.sessions});

  FocusSession? checkpoint;
  final FakeSessionRepository? sessions;
  final List<StudySession> savedRecords = [];

  /// When set, the next saveRecord throws this and clears it.
  Object? failNextSave;

  @override
  Future<FocusSession?> load() async => checkpoint;

  @override
  Future<void> save(FocusSession session) async {
    if (!session.isInProgress) {
      throw ArgumentError('Only an in-progress session can be checkpointed');
    }
    checkpoint = session;
  }

  @override
  Future<void> clear() async => checkpoint = null;

  @override
  Future<StudySession> saveRecord(FocusSession session) async {
    final error = failNextSave;
    if (error != null) {
      failNextSave = null;
      throw error;
    }
    if (checkpoint?.startedAt != session.startedAt) {
      throw const SessionAlreadySavedException();
    }
    final record = session.toRecord();
    final saved = await sessions?.create(record) ??
        record.copyWith(id: savedRecords.length + 1);
    savedRecords.add(saved);
    checkpoint = null;
    return saved;
  }
}
