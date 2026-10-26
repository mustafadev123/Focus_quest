import 'package:flutter/material.dart';

import '../../../domain/validation/validation.dart';
import '../../task_form/widgets/minutes_field.dart';

/// Chooses the length of the next focus session (5–120 minutes) with the
/// same slider and number box as the task form. Returns null on Cancel.
Future<int?> showSessionLengthDialog(BuildContext context, int current) {
  return showDialog<int>(
    context: context,
    builder: (_) => _SessionLengthDialog(current: current),
  );
}

class _SessionLengthDialog extends StatefulWidget {
  const _SessionLengthDialog({required this.current});

  final int current;

  @override
  State<_SessionLengthDialog> createState() => _SessionLengthDialogState();
}

class _SessionLengthDialogState extends State<_SessionLengthDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _minutes = TextEditingController(text: '${widget.current}');

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _set() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(parseMinutes(_minutes.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session length'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('For this session only. Settings keeps the default.'),
            const SizedBox(height: 12),
            MinutesField(controller: _minutes),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _set, child: const Text('Set')),
      ],
    );
  }
}
