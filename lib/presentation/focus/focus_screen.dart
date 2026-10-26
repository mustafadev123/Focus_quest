import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/focus/focus_session.dart';
import '../../domain/models/study_task.dart';
import '../../providers/core_providers.dart';
import '../../providers/focus_providers.dart';
import '../../providers/task_providers.dart';
import '../format.dart';
import '../shell/home_shell.dart';
import '../widgets/state_views.dart';
import 'widgets/completion_overlay.dart';
import 'widgets/review_dialog.dart';
import 'widgets/session_length_dialog.dart';

class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(focusControllerProvider);
    final tasks = ref.watch(tasksProvider);

    // Keep showing the current data while either provider refreshes, so a
    // reload after a save does not replace the screen with a spinner.
    return Scaffold(
      appBar: AppBar(title: const Text('Focus Session')),
      body: switch ((session, tasks)) {
        (AsyncValue(value: final s?), AsyncValue(value: final t?)) =>
          _FocusBody(session: s, tasks: t),
        (AsyncError(), _) => ErrorView(
            message: "Couldn't restore your focus session.",
            onRetry: () => ref.invalidate(focusControllerProvider),
          ),
        (_, AsyncError()) => ErrorView(
            message: "Couldn't load your tasks.",
            onRetry: () => ref.invalidate(tasksProvider),
          ),
        _ => const LoadingView(label: 'Restoring session…'),
      },
    );
  }
}

class _FocusBody extends ConsumerStatefulWidget {
  const _FocusBody({required this.session, required this.tasks});

  final FocusSession session;
  final List<StudyTask> tasks;

  @override
  ConsumerState<_FocusBody> createState() => _FocusBodyState();
}

class _FocusBodyState extends ConsumerState<_FocusBody> {
  Timer? _ticker;
  bool _reviewOpen = false;
  late final AppLifecycleListener _lifecycle;

  /// Minutes just saved while the completion moment is showing.
  int? _celebratingMinutes;

  @override
  void initState() {
    super.initState();
    _syncTicker();
    _lifecycle = AppLifecycleListener(
      // Leaving the app re-saves the checkpoint.
      onHide: () => _controller.checkpoint().catchError((_) {}),
      // Coming back refreshes the countdown and opens the review if the
      // target was reached while the app was in the background.
      onResume: _tick,
    );
  }

  @override
  void didUpdateWidget(_FocusBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Refreshes the countdown once a second, only while running. The time
  /// itself always comes from the session's timestamps.
  void _syncTicker() {
    final running = widget.session.phase == FocusPhase.running;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      // A session restored past its target opens the review straight away.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _tick() async {
    if (!mounted) return;
    setState(() {});
    final controller = ref.read(focusControllerProvider.notifier);
    if (await _guard(controller.finishIfTargetReached) == true) {
      await _openReview();
    }
  }

  FocusController get _controller => ref.read(focusControllerProvider.notifier);

  /// Runs a checkpointed action; a failed write leaves the session as it was
  /// and says so.
  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't save your progress. Try again.")));
      }
      return null;
    }
  }

  Future<void> _finish() async {
    await _guard(_controller.finish);
    await _openReview();
  }

  Future<void> _openReview() async {
    if (_reviewOpen || !mounted) return;
    if (ref.read(focusControllerProvider).value?.phase !=
        FocusPhase.awaitingSave) {
      return;
    }
    _reviewOpen = true;
    final saved = await showReviewDialog(context);
    _reviewOpen = false;
    if (!saved || !mounted) return;

    final session = ref.read(focusControllerProvider).value;
    final finished = session?.finishedAt;
    setState(() => _celebratingMinutes =
        finished == null ? 0 : session!.recordedMinutesAt(finished));
  }

  Future<void> _changeLength(FocusSession session) async {
    final minutes =
        await showSessionLengthDialog(context, session.target.inMinutes);
    if (minutes != null && mounted) _controller.setSessionLength(minutes);
  }

  /// After the completion moment, Save opens History (navigation map).
  void _completionDone() {
    setState(() => _celebratingMinutes = null);
    ref.read(selectedTabProvider.notifier).select(AppTab.history);
  }

  Future<void> _reset() async {
    final phase = widget.session.phase;
    if (phase != FocusPhase.saved) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this session?'),
          content: const Text('Your unsaved progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    await _guard(_controller.reset);
  }

  @override
  Widget build(BuildContext context) {
    final celebrating = _celebratingMinutes;
    if (celebrating != null) {
      return CompletionOverlay(minutes: celebrating, onDone: _completionDone);
    }

    final session = widget.session;
    final now = ref.watch(clockProvider)();
    final pending = widget.tasks.where((t) => !t.isCompleted).toList();

    if (pending.isEmpty && session.taskId == null) {
      return _NoTasks(
        onAddTask: () =>
            ref.read(selectedTabProvider.notifier).select(AppTab.tasks),
      );
    }

    final timer = _TimerDisplay(
      session: session,
      now: now,
      onChangeLength: session.phase == FocusPhase.ready
          ? () => _changeLength(session)
          : null,
    );
    final controls = _Controls(
      session: session,
      onStart: () => _guard(_controller.start),
      onPause: () => _guard(_controller.pause),
      onResume: () => _guard(_controller.resume),
      onFinish: _finish,
      onReview: _openReview,
      onReset: _reset,
    );
    final picker = _TaskPicker(
      session: session,
      tasks: widget.tasks,
      onChanged: _controller.selectTask,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: wide
              ? [
                  picker,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: timer),
                      const SizedBox(width: 24),
                      Expanded(child: controls),
                    ],
                  ),
                ]
              : [
                  picker,
                  const SizedBox(height: 24),
                  timer,
                  const SizedBox(height: 24),
                  controls,
                ],
        );
      },
    );
  }
}

class _TaskPicker extends StatelessWidget {
  const _TaskPicker({
    required this.session,
    required this.tasks,
    required this.onChanged,
  });

  final FocusSession session;
  final List<StudyTask> tasks;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Pending tasks, plus the session's own task if it was completed since.
    final options = [
      for (final t in tasks)
        if (!t.isCompleted || t.id == session.taskId) t,
    ];
    final selected =
        options.any((t) => t.id == session.taskId) ? session.taskId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Task', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          hint: const Text('Select a task first'),
          decoration: InputDecoration(
            helperText: session.canChangeTask
                ? null
                : 'Finish or reset this session to change task.',
          ),
          items: [
            for (final t in options)
              DropdownMenuItem(
                value: t.id,
                child: Text(t.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: session.canChangeTask ? onChanged : null,
        ),
      ],
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({
    required this.session,
    required this.now,
    this.onChangeLength,
  });

  final FocusSession session;
  final DateTime now;

  /// Set while Ready; makes "of 25 minutes" a button.
  final VoidCallback? onChangeLength;

  static String _label(FocusPhase phase) => switch (phase) {
        FocusPhase.ready => 'Ready',
        FocusPhase.running => 'Running',
        FocusPhase.paused => 'Paused',
        FocusPhase.awaitingSave => 'Awaiting save',
        FocusPhase.saved => 'Saved',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = session.remainingAt(session.finishedAt ?? now);
    final minutes = session.target.inMinutes;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              Text(_label(session.phase), style: theme.textTheme.labelMedium),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: '${describeClock(remaining)} remaining of $minutes minutes',
          excludeSemantics: true,
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatClock(remaining),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (onChangeLength == null)
                Text('of $minutes minutes', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        // While Ready, the length can be changed for this session only.
        if (onChangeLength case final change?)
          TextButton.icon(
            onPressed: change,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.expand_more, size: 18),
            label: Text(
              'of $minutes minutes',
              semanticsLabel: 'Session length $minutes minutes, change',
            ),
          ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.session,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onReview,
    required this.onReset,
  });

  final FocusSession session;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onReview;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final awaiting = session.phase == FocusPhase.awaitingSave;
    final saved = session.phase == FocusPhase.saved;

    final buttons = awaiting
        ? [
            Expanded(
              child: FilledButton(
                onPressed: onReview,
                child: const Text('Review and save'),
              ),
            ),
          ]
        : [
            Expanded(
              child: OutlinedButton(
                onPressed: session.canStart ? onStart : null,
                child: const Text('Start'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: session.canResume
                  ? FilledButton(
                      onPressed: onResume, child: const Text('Resume'))
                  : FilledButton(
                      onPressed: session.canPause ? onPause : null,
                      child: const Text('Pause'),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: session.canFinish ? onFinish : null,
                child: const Text('Finish'),
              ),
            ),
          ];

    return Column(
      children: [
        Row(children: buttons),
        const SizedBox(height: 8),
        TextButton(
          onPressed: session.canReset ? onReset : null,
          child: Text(saved ? 'New session' : 'Reset'),
        ),
      ],
    );
  }
}

class _NoTasks extends StatelessWidget {
  const _NoTasks({required this.onAddTask});

  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a task first',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('You have no tasks to focus on yet.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: onAddTask, child: const Text('Go to Tasks')),
          ],
        ),
      ),
    );
  }
}
