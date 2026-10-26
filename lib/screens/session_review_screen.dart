
import 'package:flutter/material.dart';

import '../models/study_session.dart';
import '../repositories/session_repository.dart';

class SessionReviewScreen extends StatefulWidget {
  final Duration elapsed;
  final int taskId;

  const SessionReviewScreen({
    super.key,
    required this.elapsed,
    required this.taskId,
  });

  @override
  State<SessionReviewScreen> createState() =>
      _SessionReviewScreenState();
}

class _SessionReviewScreenState extends State<SessionReviewScreen> {
  final SessionRepository _repository = SessionRepository();

  bool _isSaving = false;
  bool _hasSaved = false;
  String? _error;

  Future<void> _saveSession() async {
    if (_isSaving || _hasSaved) return;

    final durationMinutes = widget.elapsed.inMinutes;

    if (durationMinutes < 1) {
      setState(() {
        _error = 'Study for at least one full minute before saving.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final endTime = DateTime.now();
    final startTime =
        endTime.subtract(Duration(seconds: widget.elapsed.inSeconds));

    try {
      await _repository.addSession(
        StudySession(
          taskId: widget.taskId,
          startTime: startTime,
          endTime: endTime,
          durationMinutes: durationMinutes,
        ),
      );

      if (!mounted) return;

      setState(() {
        _hasSaved = true;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study session saved.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _error = 'Could not save session: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Session')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Session Summary',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text('Task ID: ${widget.taskId}'),
            Text('Duration: ${widget.elapsed.inMinutes} minutes'),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving || _hasSaved ? null : _saveSession,
              child: Text(
                _hasSaved
                    ? 'Saved'
                    : _isSaving
                        ? 'Saving...'
                        : 'Save Session',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
