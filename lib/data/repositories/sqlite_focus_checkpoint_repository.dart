import 'package:sqflite/sqflite.dart';

import '../../domain/clock.dart';
import '../../domain/focus/focus_session.dart';
import '../../domain/models/study_session.dart';
import '../../domain/repositories/focus_checkpoint_repository.dart';
import '../../domain/validation/validation.dart';
import '../database/app_database.dart';
import '../database/row_mappers.dart';

class SqliteFocusCheckpointRepository implements FocusCheckpointRepository {
  SqliteFocusCheckpointRepository(this._db, {Clock clock = systemClock})
      : _clock = clock;

  final Database _db;
  final Clock _clock;

  static const _table = AppDatabase.activeSessionTable;

  static const _phaseToState = {
    FocusPhase.running: 'running',
    FocusPhase.paused: 'paused',
    FocusPhase.awaitingSave: 'awaiting_save',
  };

  @override
  Future<FocusSession?> load() async {
    final rows = await _db.query(_table, where: 'id = 1');
    if (rows.isEmpty) return null;
    final row = rows.single;

    final phase = _phaseToState.entries
        .where((e) => e.value == row['state'])
        .map((e) => e.key)
        .firstOrNull;
    if (phase == null) throw FormatException('Invalid checkpoint', row);

    return FocusSession.restore(
      phase: phase,
      taskId: row['task_id'] as int,
      target: Duration(minutes: row['target_minutes'] as int),
      startedAt: _date(row['started_at'])!,
      activeBeforeResume:
          Duration(milliseconds: row['elapsed_active_ms'] as int),
      lastResumedAt: _date(row['last_resumed_at']),
      finishedAt: _date(row['finished_at']),
    );
  }

  @override
  Future<void> save(FocusSession session) async {
    final state = _phaseToState[session.phase];
    if (state == null) {
      throw ArgumentError('Only an in-progress session can be checkpointed');
    }
    await _db.insert(
      _table,
      {
        'id': 1,
        'task_id': session.taskId,
        'state': state,
        'started_at': session.startedAt!.millisecondsSinceEpoch,
        'elapsed_active_ms': session.activeBeforeResume.inMilliseconds,
        'target_minutes': session.target.inMinutes,
        'last_resumed_at': session.lastResumedAt?.millisecondsSinceEpoch,
        'finished_at': session.finishedAt?.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear() => _db.delete(_table);

  @override
  Future<StudySession> saveRecord(FocusSession session) {
    final record = session.toRecord();
    ensureValidSession(record, now: _clock());

    return _db.transaction((txn) async {
      // The checkpoint for this exact session must still exist; if it is
      // gone, this session was already recorded.
      final removed = await txn.delete(_table,
          where: 'id = 1 AND started_at = ?',
          whereArgs: [session.startedAt!.millisecondsSinceEpoch]);
      if (removed == 0) throw const SessionAlreadySavedException();

      final id = await txn.insert(
          AppDatabase.sessionsTable, sessionToRow(record)..remove('id'));
      return record.copyWith(id: id);
    });
  }

  static DateTime? _date(Object? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis as int);
}
