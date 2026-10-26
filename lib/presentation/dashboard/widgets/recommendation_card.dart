import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/focus/focus_session.dart';
import '../../../domain/helper/smart_helper.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/focus_providers.dart';
import '../../../providers/helper_providers.dart';
import '../../shell/home_shell.dart';
import '../../task_form/task_form_screen.dart';

/// "Not now" hides the suggestion until the student asks for it again. It
/// is screen state only and never changes saved data.
class _DismissedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool dismissed) => state = dismissed;
}

final recommendationDismissedProvider =
    NotifierProvider<_DismissedNotifier, bool>(_DismissedNotifier.new);

/// Choices for "Available time"; the current value is added if missing.
const _availableChoices = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120];

/// "Suggested next task" from the Dashboard wireframe.
class RecommendationCard extends ConsumerWidget {
  const RecommendationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(recommendationDismissedProvider)) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: () =>
              ref.read(recommendationDismissedProvider.notifier).set(false),
          child: const Text('Show suggested task'),
        ),
      );
    }

    final result = ref.watch(recommendationProvider);
    return _Frame(
      child: switch (result) {
        AsyncValue(value: final Recommendation r) => _Suggestion(result: r),
        AsyncValue(value: NoEligibleTask()) => const _NothingToSuggest(),
        AsyncError() => Row(
            children: [
              const Expanded(child: Text("Couldn't prepare a suggestion.")),
              TextButton(
                onPressed: () => ref.invalidate(recommendationProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Finding a suggestion…'),
          ),
      },
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Suggested next task',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _Suggestion extends ConsumerStatefulWidget {
  const _Suggestion({required this.result});

  final Recommendation result;

  @override
  ConsumerState<_Suggestion> createState() => _SuggestionState();
}

class _SuggestionState extends ConsumerState<_Suggestion> {
  bool _showWhy = false;

  /// Accepting only selects the task with the chosen time; the student
  /// still presses Start on the Focus screen.
  void _useTask() {
    final r = widget.result;
    final session = ref.read(focusControllerProvider).value;
    if (session != null && session.isInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Finish or reset your current focus session to use this task.')));
      return;
    }
    ref.read(sessionLengthProvider.notifier).set(r.availableMinutes);
    ref.read(selectedTaskIdProvider.notifier).select(r.task.id);
    if (session?.phase == FocusPhase.ready) {
      ref
          .read(focusControllerProvider.notifier)
          .setSessionLength(r.availableMinutes);
    }
    ref.read(selectedTabProvider.notifier).select(AppTab.focus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.result;
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final available = ref.watch(availableMinutesProvider);
    final choices = {..._availableChoices, available}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.task.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(r.summary, style: muted),
        TextButton(
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          onPressed: () => setState(() => _showWhy = !_showWhy),
          child: Text(_showWhy ? 'Hide reasons' : 'Why this task?'),
        ),
        if (_showWhy) ...[
          for (final reason in r.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• $reason'),
            ),
          const SizedBox(height: 4),
          Text(r.scoreBreakdown, style: muted),
          Text(
              'Rule-based suggestion from priority, time fit and recent '
              'study. It is not a trained AI model.',
              style: muted),
          const SizedBox(height: 8),
        ],
        Text('Available time', style: muted),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              label: 'Available time',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(6),
                ),
                // Sized to its label, shrinking with an ellipsis instead of
                // overflowing at large text sizes.
                child: IntrinsicWidth(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: available,
                      isExpanded: true,
                      items: [
                        for (final m in choices)
                          DropdownMenuItem(
                            value: m,
                            child: Text('$m min',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (m) {
                        if (m != null) {
                          ref.read(availableMinutesProvider.notifier).set(m);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () =>
                  ref.read(recommendationDismissedProvider.notifier).set(true),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: _useTask,
              child:
                  Text('Use task', semanticsLabel: 'Use task ${r.task.title}'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shown when tasks exist but none can be suggested, e.g. all completed.
class _NothingToSuggest extends StatelessWidget {
  const _NothingToSuggest();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nothing to suggest: every task is completed.'),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => TaskFormScreen.open(context),
          child: const Text('Create a task'),
        ),
      ],
    );
  }
}
