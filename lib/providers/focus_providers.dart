import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/focus/focus_session.dart';
import '../domain/models/study_session.dart';
import '../domain/repositories/focus_checkpoint_repository.dart';
import '../domain/validation/validation.dart';
import 'core_providers.dart';
import 'dashboard_providers.dart';
import 'settings_providers.dart';

/// Runs the focus session.
///
/// Every transition is written to the checkpoint before the state changes,
/// so a session restored after a restart is exactly the one on screen. When
/// no checkpoint exists, the session is Ready for the task selected on the
/// Dashboard, with the focus duration from Settings as its target; a session
/// in progress keeps the target it started with.
class FocusController extends AsyncNotifier<FocusSession> {
  bool _saving = false;

  @override
  Future<FocusSession> build() async {
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    // Read, not watched: setSessionLength updates the state itself, and
    // clearing the choice after Save must not reset the Saved session.
    final minutes = ref.read(sessionLengthProvider) ??
        ref.watch(effectiveSettingsProvider).sessionMinutes;
    final checkpoint =
        await ref.watch(focusCheckpointRepositoryProvider).load();
    return checkpoint ??
        FocusSession.ready(
          taskId: selectedTaskId,
          target: Duration(minutes: minutes),
        );
  }

  FocusCheckpointRepository get _checkpoints =>
      ref.read(focusCheckpointRepositoryProvider);

  DateTime _now() => ref.read(clockProvider)();

  FocusSession get _current => state.requireValue;

  Future<void> _apply(FocusSession next) async {
    await _checkpoints.save(next);
    if (ref.mounted) state = AsyncData(next);
  }

  /// Chooses the task for the next session; ignored while one is running.
  void selectTask(int? taskId) {
    if (!_current.canChangeTask) return;
    ref.read(selectedTaskIdProvider.notifier).select(taskId);
  }

  /// Sets the length of the next session only (5–120 minutes); Settings
  /// keeps the default. Ignored once a session has started.
  void setSessionLength(int minutes) {
    if (validateEstimatedMinutes(minutes) != null) {
      throw ArgumentError.value(minutes, 'minutes', 'Must be 5–120');
    }
    final current = _current;
    if (current.phase != FocusPhase.ready) return;
    ref.read(sessionLengthProvider.notifier).set(minutes);
    state = AsyncData(current.changeTarget(Duration(minutes: minutes)));
  }

  Future<void> start() => _apply(_current.start(_now()));

  Future<void> pause() => _apply(_current.pause(_now()));

  Future<void> resume() => _apply(_current.resume(_now()));

  Future<void> finish() => _apply(_current.finish(_now()));

  /// Opens the review when a running session has used its whole target.
  /// Returns whether it did.
  Future<bool> finishIfTargetReached() async {
    final current = state.value;
    if (current == null || !current.reachedTargetAt(_now())) return false;
    await finish();
    return true;
  }

  /// Creates exactly one history record. Repeated or concurrent calls are
  /// ignored; a retry after a failure is safe because the record and the
  /// checkpoint change in one transaction.
  Future<StudySession?> save() async {
    final current = _current;
    if (_saving || !current.canSave) return null;
    _saving = true;
    try {
      final record = await _checkpoints.saveRecord(current);
      if (ref.mounted) {
        state = AsyncData(current.markSaved());
        ref.read(sessionLengthProvider.notifier).set(null);
        ref.read(dataRevisionProvider.notifier).bump();
      }
      return record;
    } on SessionAlreadySavedException {
      if (ref.mounted) state = AsyncData(current.markSaved());
      return null;
    } finally {
      _saving = false;
    }
  }

  /// Re-writes the checkpoint of an in-progress session, for example when
  /// the app goes to the background. Timing comes from the stored
  /// timestamps, so this only guards against a lost earlier write.
  Future<void> checkpoint() async {
    final current = state.value;
    if (current != null && current.isInProgress) {
      await _checkpoints.save(current);
    }
  }

  /// Reset discards unsaved progress and keeps the task and length, so the
  /// same session can be tried again. After a save it starts a new session
  /// with the Settings default length.
  Future<void> reset() async {
    await _checkpoints.clear();
    if (!ref.mounted) return;
    final current = _current;
    if (current.phase == FocusPhase.saved) {
      final minutes = ref.read(effectiveSettingsProvider).sessionMinutes;
      state =
          AsyncData(current.reset().changeTarget(Duration(minutes: minutes)));
    } else {
      state = AsyncData(current.reset());
    }
  }
}

/// A length chosen for the next session only, on the Focus screen or from
/// the Suggested-task card; null means the Settings default.
class SessionLengthNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? minutes) => state = minutes;
}

final sessionLengthProvider =
    NotifierProvider<SessionLengthNotifier, int?>(SessionLengthNotifier.new);

final focusControllerProvider =
    AsyncNotifierProvider<FocusController, FocusSession>(FocusController.new);
