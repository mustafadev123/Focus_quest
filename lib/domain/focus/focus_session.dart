import '../models/study_session.dart';

/// The Focus Session states from proposal Section 6, Screen 3.
enum FocusPhase { ready, running, paused, awaitingSave, saved }

/// Thrown when an action is not allowed in the current phase, for example
/// Pause while Ready.
class FocusTransitionException implements Exception {
  const FocusTransitionException(this.action, this.phase);

  final String action;
  final FocusPhase phase;

  @override
  String toString() => 'Cannot $action while ${phase.name}';
}

/// Immutable focus-session state. Every action takes the current time and
/// returns a new state, so timing is computed from timestamps rather than a
/// ticking timer and survives being saved and restored.
///
/// Active time is the time spent running: paused time is never counted, and
/// active time never exceeds the target.
class FocusSession {
  const FocusSession._({
    required this.phase,
    required this.taskId,
    required this.target,
    this.startedAt,
    this.activeBeforeResume = Duration.zero,
    this.lastResumedAt,
    this.finishedAt,
  });

  /// A session with nothing started yet.
  const FocusSession.ready({int? taskId, required Duration target})
      : this._(phase: FocusPhase.ready, taskId: taskId, target: target);

  /// Rebuilds a session from a saved checkpoint.
  const FocusSession.restore({
    required FocusPhase phase,
    required int taskId,
    required Duration target,
    required DateTime startedAt,
    required Duration activeBeforeResume,
    DateTime? lastResumedAt,
    DateTime? finishedAt,
  }) : this._(
          phase: phase,
          taskId: taskId,
          target: target,
          startedAt: startedAt,
          activeBeforeResume: activeBeforeResume,
          lastResumedAt: lastResumedAt,
          finishedAt: finishedAt,
        );

  final FocusPhase phase;
  final int? taskId;
  final Duration target;

  /// When Start was first pressed.
  final DateTime? startedAt;

  /// Active time accumulated before the current running stretch.
  final Duration activeBeforeResume;

  /// Start of the current running stretch; set only while running.
  final DateTime? lastResumedAt;

  /// When the session stopped; set from Awaiting save onwards.
  final DateTime? finishedAt;

  bool get isInProgress =>
      phase == FocusPhase.running ||
      phase == FocusPhase.paused ||
      phase == FocusPhase.awaitingSave;

  bool get canStart => phase == FocusPhase.ready && taskId != null;
  bool get canPause => phase == FocusPhase.running;
  bool get canResume => phase == FocusPhase.paused;
  bool get canFinish =>
      phase == FocusPhase.running || phase == FocusPhase.paused;
  bool get canReset => phase != FocusPhase.ready;

  /// Whether a different task may be chosen without losing progress.
  bool get canChangeTask =>
      phase == FocusPhase.ready || phase == FocusPhase.saved;

  /// Active time at [now], capped at the target.
  Duration activeAt(DateTime now) {
    var active = activeBeforeResume;
    final resumed = lastResumedAt;
    if (phase == FocusPhase.running && resumed != null) {
      final stretch = now.difference(resumed);
      // A clock moved backwards must not subtract time.
      if (!stretch.isNegative) active += stretch;
    }
    return active > target ? target : active;
  }

  Duration remainingAt(DateTime now) => target - activeAt(now);

  /// True once a running session has used its whole target; the screen then
  /// opens the review, but never saves on its own.
  bool reachedTargetAt(DateTime now) =>
      phase == FocusPhase.running && activeAt(now) >= target;

  /// Whole minutes recorded for this session, rounded to the nearest minute.
  int recordedMinutesAt(DateTime now) => (activeAt(now).inSeconds / 60).round();

  /// A session shorter than half a minute rounds to zero and cannot be saved.
  bool get canSave =>
      phase == FocusPhase.awaitingSave && recordedMinutesAt(finishedAt!) >= 1;

  FocusSession selectTask(int? taskId) {
    if (!canChangeTask) throw FocusTransitionException('change task', phase);
    return FocusSession.ready(taskId: taskId, target: target);
  }

  FocusSession changeTarget(Duration target) {
    if (phase != FocusPhase.ready && phase != FocusPhase.saved) {
      throw FocusTransitionException('change target', phase);
    }
    return FocusSession.ready(taskId: taskId, target: target);
  }

  FocusSession start(DateTime now) {
    if (!canStart) throw FocusTransitionException('start', phase);
    return FocusSession._(
      phase: FocusPhase.running,
      taskId: taskId,
      target: target,
      startedAt: now,
      lastResumedAt: now,
    );
  }

  FocusSession pause(DateTime now) {
    if (!canPause) throw FocusTransitionException('pause', phase);
    return FocusSession._(
      phase: FocusPhase.paused,
      taskId: taskId,
      target: target,
      startedAt: startedAt,
      activeBeforeResume: activeAt(now),
    );
  }

  FocusSession resume(DateTime now) {
    if (!canResume) throw FocusTransitionException('resume', phase);
    return FocusSession._(
      phase: FocusPhase.running,
      taskId: taskId,
      target: target,
      startedAt: startedAt,
      activeBeforeResume: activeBeforeResume,
      lastResumedAt: now,
    );
  }

  /// Stops the clock and waits for an explicit Save.
  ///
  /// If the target was reached earlier (for example while the app was
  /// closed), the finish time is when it was reached, not [now].
  FocusSession finish(DateTime now) {
    if (!canFinish) throw FocusTransitionException('finish', phase);
    final active = activeAt(now);
    var finishedAt = now;
    final resumed = lastResumedAt;
    if (phase == FocusPhase.running && resumed != null && active >= target) {
      final reachedAt = resumed.add(target - activeBeforeResume);
      if (reachedAt.isBefore(now)) finishedAt = reachedAt;
    }
    return FocusSession._(
      phase: FocusPhase.awaitingSave,
      taskId: taskId,
      target: target,
      startedAt: startedAt,
      activeBeforeResume: active,
      finishedAt: finishedAt,
    );
  }

  /// The history record Save will create.
  StudySession toRecord() {
    if (phase != FocusPhase.awaitingSave) {
      throw FocusTransitionException('build a record', phase);
    }
    final end = finishedAt!;
    return StudySession(
      taskId: taskId!,
      startedAt: startedAt!,
      endedAt: end,
      durationMinutes: recordedMinutesAt(end),
      status: activeBeforeResume >= target
          ? SessionStatus.completed
          : SessionStatus.endedEarly,
    );
  }

  /// After the record has been written.
  FocusSession markSaved() {
    if (phase != FocusPhase.awaitingSave) {
      throw FocusTransitionException('mark saved', phase);
    }
    return FocusSession._(
      phase: FocusPhase.saved,
      taskId: taskId,
      target: target,
      startedAt: startedAt,
      activeBeforeResume: activeBeforeResume,
      finishedAt: finishedAt,
    );
  }

  /// Discards unsaved progress and keeps the task and target.
  FocusSession reset() => FocusSession.ready(taskId: taskId, target: target);
}
