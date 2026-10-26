
import 'package:flutter/material.dart';

import '../models/study_session.dart';
import '../repositories/session_repository.dart';
import '../repositories/task_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final SessionRepository _sessions = SessionRepository();
  final TaskRepository _tasks = TaskRepository();

  List<StudySession> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final result = await _sessions.getAllSessions();
      if (!mounted) return;
      setState(() {
        _items = result;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load sessions: $e';
      });
    }
  }

  Future<void> _editSession([StudySession? existing]) async {
    final tasks = await _tasks.getAllTasks();
    if (!mounted) return;

    if (tasks.isEmpty || tasks.any((task) => task.id == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a study task before adding a session.'),
        ),
      );
      return;
    }

    int taskId = existing?.taskId ?? tasks.first.id!;
    DateTime start = existing?.startTime ??
        DateTime.now().subtract(const Duration(minutes: 25));
    DateTime end = existing?.endTime ?? DateTime.now();

    final formKey = GlobalKey<FormState>();
    final durationController = TextEditingController(
      text: existing?.durationMinutes.toString() ?? '25',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Session' : 'Edit Session'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: taskId,
                    decoration: const InputDecoration(labelText: 'Task'),
                    items: tasks.map((task) {
                      return DropdownMenuItem(
                        value: task.id!,
                        child: Text(task.title),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => taskId = value);
                      }
                    },
                  ),
                  TextFormField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final duration = int.tryParse(value ?? '');
                      if (duration == null || duration <= 0) {
                        return 'Enter a positive whole number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start time'),
                    subtitle: Text(start.toLocal().toString()),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: start,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                      );
                      if (date == null || !context.mounted) return;

                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(start),
                      );
                      if (time == null) return;

                      setDialogState(() {
                        start = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End time'),
                    subtitle: Text(end.toLocal().toString()),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: end,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                      );
                      if (date == null || !context.mounted) return;

                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(end),
                      );
                      if (time == null) return;

                      setDialogState(() {
                        end = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      durationController.dispose();
      return;
    }

    final duration = int.parse(durationController.text);
    durationController.dispose();

    if (!end.isAfter(start) || end.isAfter(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start and not in the future.'),
        ),
      );
      return;
    }

    final session = StudySession(
      id: existing?.id,
      taskId: taskId,
      startTime: start,
      endTime: end,
      durationMinutes: duration,
    );

    try {
      if (existing == null) {
        await _sessions.addSession(session);
      } else {
        await _sessions.updateSession(session);
      }
      await _loadSessions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save session: $e')),
      );
    }
  }

  Future<void> _deleteSession(StudySession session) async {
    if (session.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _sessions.deleteSession(session.id!);
      await _loadSessions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete session: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study History'),
        actions: [
          IconButton(
            onPressed: _loadSessions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editSession(),
        icon: const Icon(Icons.add),
        label: const Text('Add Session'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('No study sessions yet.'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final session = _items[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(
                              '${session.durationMinutes} minutes',
                            ),
                            subtitle: Text(
                              'Task ID: ${session.taskId}\n'
                              '${session.startTime.toLocal()}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  tooltip: 'Edit session',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editSession(session),
                                ),
                                IconButton(
                                  tooltip: 'Delete session',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteSession(session),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
