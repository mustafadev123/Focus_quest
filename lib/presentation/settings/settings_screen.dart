import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/validation/validation.dart';
import '../../providers/settings_providers.dart';
import '../widgets/state_views.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: switch (settings) {
        AsyncValue(:final value?) => _SettingsForm(saved: value),
        AsyncError() => ErrorView(
            message: "Couldn't load your settings.",
            onRetry: () => ref.invalidate(settingsProvider),
          ),
        _ => const LoadingView(label: 'Loading settings…'),
      },
    );
  }
}

/// Edits a draft; nothing is stored until Save settings.
class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.saved});

  final AppSettings saved;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late AppSettings _draft = widget.saved;
  bool _saving = false;
  bool _failed = false;

  void _edit(AppSettings next) => setState(() {
        _draft = next;
        _failed = false;
      });

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: _draft.reminderTime.hour, minute: _draft.reminderTime.minute),
    );
    if (picked == null || !mounted) return;
    _edit(_draft.copyWith(
        reminderTime: ReminderTime(picked.hour, picked.minute)));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(settingsProvider.notifier).save(_draft);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          Icon(Icons.check, color: Colors.white),
          SizedBox(width: 12),
          Text('Settings saved'),
        ]),
      ));
    } catch (_) {
      // The draft stays on screen so Save can be retried.
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
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final bold =
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final reminder = TimeOfDay(
        hour: _draft.reminderTime.hour, minute: _draft.reminderTime.minute);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Section(
          children: [
            Row(
              children: [
                Expanded(child: Text('Focus duration', style: bold)),
                Text('${_draft.sessionMinutes} min', style: bold),
              ],
            ),
            Slider(
              value: _draft.sessionMinutes.toDouble(),
              min: Limits.minEstimatedMinutes.toDouble(),
              max: Limits.maxEstimatedMinutes.toDouble(),
              divisions:
                  Limits.maxEstimatedMinutes - Limits.minEstimatedMinutes,
              label: '${_draft.sessionMinutes} min',
              semanticFormatterCallback: (v) =>
                  'Focus duration ${v.round()} minutes',
              onChanged: _saving
                  ? null
                  : (v) => _edit(_draft.copyWith(sessionMinutes: v.round())),
            ),
            ExcludeSemantics(
              child: Row(
                children: [
                  Text('${Limits.minEstimatedMinutes} min', style: muted),
                  const Spacer(),
                  Text('${Limits.maxEstimatedMinutes} min', style: muted),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          children: [
            _SwitchRow(
              label: 'Daily reminder',
              value: _draft.remindersEnabled,
              onChanged: _saving
                  ? null
                  : (on) => _edit(_draft.copyWith(remindersEnabled: on)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Reminder time', style: muted)),
                OutlinedButton.icon(
                  onPressed: _draft.remindersEnabled && !_saving
                      ? _pickReminderTime
                      : null,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text(
                    reminder.format(context),
                    semanticsLabel: 'Reminder time ${reminder.format(context)}',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          children: [
            _SwitchRow(
              label: 'Reduced motion',
              value: _draft.reducedMotion,
              onChanged: _saving
                  ? null
                  : (on) => _edit(_draft.copyWith(reducedMotion: on)),
            ),
          ],
        ),
        if (_failed) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              "Couldn't save your settings. Your changes are kept, "
              'so try again.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Saving settings',
                    ),
                  )
                : const Text('Save settings'),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    // The whole row toggles, not only the switch, for a larger target.
    final toggle = onChanged;
    return MergeSemantics(
      child: InkWell(
        onTap: toggle == null ? null : () => toggle(!value),
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
