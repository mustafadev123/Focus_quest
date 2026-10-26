import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/history.dart';
import '../domain/models/session_record.dart';
import '../domain/models/study_session.dart';
import '../domain/repositories/session_repository.dart';
import 'core_providers.dart';

/// History filters; null task or subject means all.
class HistoryFilter {
  const HistoryFilter({
    this.taskId,
    this.subject,
    this.range = HistoryRange.thisWeek,
  });

  final int? taskId;
  final String? subject;
  final HistoryRange range;

  HistoryFilter copyWith({
    int? Function()? taskId,
    String? Function()? subject,
    HistoryRange? range,
  }) {
    return HistoryFilter(
      taskId: taskId == null ? this.taskId : taskId(),
      subject: subject == null ? this.subject : subject(),
      range: range ?? this.range,
    );
  }
}

class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => const HistoryFilter();

  void setTask(int? taskId) => state = state.copyWith(taskId: () => taskId);

  void setSubject(String? subject) =>
      state = state.copyWith(subject: () => subject);

  void setRange(HistoryRange range) => state = state.copyWith(range: range);
}

final historyFilterProvider =
    NotifierProvider<HistoryFilterNotifier, HistoryFilter>(
        HistoryFilterNotifier.new);

/// Sessions matching the History filters, newest first.
final historyRecordsProvider = FutureProvider<List<SessionRecord>>((ref) {
  ref.watch(dataRevisionProvider);
  final filter = ref.watch(historyFilterProvider);
  final now = ref.watch(clockProvider)();
  return ref.watch(sessionRepositoryProvider).getRecords(SessionFilter(
        taskId: filter.taskId,
        subject: filter.subject,
        from: filter.range.startAt(now),
      ));
});

typedef HistoryAggregator = Future<HistorySummary> Function(
    List<SessionRecord> records);

/// Totals are prepared in a background isolate so a long history never
/// blocks the UI. Tests replace this with a synchronous version.
final historyAggregatorProvider = Provider<HistoryAggregator>(
  (ref) => (records) => compute(summarizeHistory, records),
);

final historySummaryProvider = FutureProvider<HistorySummary>((ref) async {
  final records = await ref.watch(historyRecordsProvider.future);
  return ref.watch(historyAggregatorProvider)(records);
});

/// Session writes from History. Errors propagate so dialogs can keep the
/// user's input; success refreshes every screen.
class SessionActions {
  SessionActions(this._ref);

  final Ref _ref;

  SessionRepository get _repo => _ref.read(sessionRepositoryProvider);

  Future<StudySession> add(StudySession session) async {
    final saved = await _repo.create(session);
    _changed();
    return saved;
  }

  Future<StudySession> update(StudySession session) async {
    final saved = await _repo.update(session);
    _changed();
    return saved;
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    _changed();
  }

  void _changed() => _ref.read(dataRevisionProvider.notifier).bump();
}

final sessionActionsProvider =
    Provider<SessionActions>((ref) => SessionActions(ref));
