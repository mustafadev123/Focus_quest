import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/session_record.dart';
import '../../../domain/models/study_session.dart';
import '../../../domain/models/study_task.dart';
import '../../../domain/validation/validation.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/history_providers.dart';

/// "Add session" when [existing] is null, otherwise "Edit session".
///
/// Returns true once the record is saved. A failed save keeps the dialog
/// open with the user's input so Save can be retried.
Future<bool> showSessionDialog(
  BuildContext context, {
  required List<StudyTask> tasks,
  SessionRecord? existing,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _SessionDialog(tasks: tasks, existing: existing),
  );
  return saved ?? false;
}

class _SessionDialog extends ConsumerStatefulWidget {
  const _SessionDialog({required this.tasks, this.existing});

  final List<StudyTask> tasks;
  final SessionRecord? existing;

  @override
  ConsumerState<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends ConsumerState<_SessionDialog> {
  static const _defaultMinutes = 25;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minutes;
  late int _taskId;
  late DateTime _start;

  bool _submitted = false;
  bool _saving = false;
  bool _failed = false;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    final session = widget.existing?.session;
    final now = ref.read(clockProvider)();
    _taskId = session?.taskId ?? widget.tasks.first.id!;
    _minutes = TextEditingController(
        text: '${session?.durationMinutes ?? _defaultMinutes}');
    // A new record defaults to one that has just finished.
    _start = session?.startedAt ??
        _toMinute(now.subtract(const Duration(minutes: _defaultMinutes)));
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  static DateTime _toMinute(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final date = await showDatePicker(
      context: context,
      initialDate: _start.isAfter(now) ? now : _start,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    setState(() => _start =
        DateTime(date.year, date.month, date.day, _start.hour, _start.minute));
    _revalidateTime();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null || !mounted) return;
    setState(() => _start = DateTime(
        _start.year, _start.month, _start.day, time.hour, time.minute));
    _revalidateTime();
  }

  String? _checkTime() {
    final now = ref.read(clockProvider)();
    final minutes = parseMinutes(_minutes.text);
    return validateSessionStart(_start, now) ??
        (minutes == null || validateSessionMinutes(minutes) != null
            ? null
            : validateSessionEnd(_start, minutes, now));
  }

  void _revalidateTime() {
    if (_submitted) setState(() => _timeError = _checkTime());
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _timeError = _checkTime();
    });
    final fieldsValid = _formKey.currentState!.validate();
    if (!fieldsValid || _timeError != null) return;

    setState(() {
      _saving = true;
      _failed = false;
    });
    final minutes = parseMinutes(_minutes.text)!;
    final actions = ref.read(sessionActionsProvider);
    final existing = widget.existing?.session;
    try {
      if (existing == null) {
        await actions.add(StudySession.manual(
          taskId: _taskId,
          startedAt: _start,
          durationMinutes: minutes,
        ));
      } else {
        await actions.update(existing.corrected(
          taskId: _taskId,
          startedAt: _start,
          durationMinutes: minutes,
        ));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
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

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add session' : 'Edit session'),
      content: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Task'),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                initialValue: _taskId,
                isExpanded: true,
                items: [
                  for (final t in widget.tasks)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(t.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _taskId = id ?? _taskId),
              ),
              const SizedBox(height: 12),
              const Text('Started'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(DateFormat.yMMMd().format(_start)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(DateFormat.jm().format(_start)),
                  ),
                ],
              ),
              if (_timeError case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(error,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 12),
              const Text('Minutes'),
              const SizedBox(height: 4),
              TextFormField(
                controller: _minutes,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                validator: (text) => validateSessionMinutes(parseMinutes(text)),
                onChanged: (_) => _revalidateTime(),
              ),
              if (_failed) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    "Couldn't save the session. Try again.",
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Saving session',
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
