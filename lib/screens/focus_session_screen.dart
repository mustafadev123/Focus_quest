
import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/task_repository.dart';
import '../services/focus_timer_service.dart';
import 'session_review_screen.dart';

class FocusSessionScreen extends StatefulWidget {
  const FocusSessionScreen({super.key});

  @override
  State<FocusSessionScreen> createState() =>
      _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  final FocusTimerService _timer = FocusTimerService();
  final TaskRepository _taskRepository = TaskRepository();

  Timer? _refreshTimer;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreTimer();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _restoreTimer() async {
    await _timer.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes =
        (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  Future<void> _finishSession() async {
    final elapsed = await _timer.finish();

    try {
      final tasks = await _taskRepository.getAllTasks();

      if (!mounted) return;

      if (tasks.isEmpty || tasks.first.id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Create a study task before reviewing a session.',
            ),
          ),
        );
        setState(() {});
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionReviewScreen(
            elapsed: elapsed,
            taskId: tasks.first.id!,
          ),
        ),
      );

      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load study tasks: $error')),
      );
      setState(() {});
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _timer.elapsed;

    return Scaffold(
      appBar: AppBar(title: const Text('Focus Session')),
      body: _restoring
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      _formatDuration(elapsed),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton(
                          onPressed: _timer.isRunning ||
                                  _timer.isFinished
                              ? null
                              : () async {
                                  await _timer.start();
                                  if (mounted) setState(() {});
                                },
                          child: const Text('Start'),
                        ),
                        FilledButton(
                          onPressed: _timer.isRunning
                              ? () async {
                                  await _timer.pause();
                                  if (mounted) setState(() {});
                                }
                              : null,
                          child: const Text('Pause'),
                        ),
                        FilledButton(
                          onPressed: !_timer.isRunning &&
                                  !_timer.isFinished &&
                                  elapsed > Duration.zero
                              ? () async {
                                  await _timer.resume();
                                  if (mounted) setState(() {});
                                }
                              : null,
                          child: const Text('Resume'),
                        ),
                        FilledButton(
                          onPressed: _timer.isRunning ||
                                  elapsed > Duration.zero
                              ? _finishSession
                              : null,
                          child: const Text('Finish'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            await _timer.reset();
                            if (mounted) setState(() {});
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
