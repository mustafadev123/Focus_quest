import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/focus/focus_session.dart';
import '../../../providers/focus_providers.dart';
import '../../format.dart';

/// "Review session": shows the time studied and saves only on Save session.
///
/// Returns true once the session is saved; Back returns false and keeps the
/// session awaiting save.
Future<bool> showReviewDialog(BuildContext context) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ReviewDialog(),
  );
  return saved ?? false;
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog();

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(focusControllerProvider.notifier).save();
      if (!mounted) return;
      final saved =
          ref.read(focusControllerProvider).value?.phase == FocusPhase.saved;
      if (saved) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _saving = false);
      }
    } catch (_) {
      // The checkpoint is untouched, so Save can be retried safely.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(focusControllerProvider).value;
    final studied = session?.finishedAt == null
        ? Duration.zero
        : session!.activeAt(session.finishedAt!);
    final canSave = session?.canSave ?? false;

    return AlertDialog(
      title: const Text('Review session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: '${describeClock(studied)} studied',
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  formatClock(studied),
                  style: theme.textTheme.displayMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text('studied', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          if (!canSave && session?.phase == FocusPhase.awaitingSave) ...[
            const SizedBox(height: 12),
            const Text(
              'Sessions shorter than a minute cannot be saved. '
              'Use Reset to discard it.',
              textAlign: TextAlign.center,
            ),
          ],
          if (_failed) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                "Couldn't save the session. Try again.",
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSave && !_saving ? _save : null,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Saving session',
                    ),
                  )
                : const Text('Save session'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
        ),
      ],
    );
  }
}
