
import 'package:flutter/material.dart';

import '../models/study_task.dart';
import '../services/recommendation_service.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() =>
      _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final RecommendationService _service = RecommendationService();
  final TextEditingController _minutesController =
      TextEditingController(text: '25');

  List<TaskRecommendation> _recommendations = [];
  StudyTask? _acceptedTask;
  final Set<int> _dismissedTaskIds = {};

  bool _loading = false;
  String? _error;
  String? _message;

  Future<void> _getRecommendations() async {
    final minutes = int.tryParse(_minutesController.text.trim());

    if (minutes == null || minutes < 5 || minutes > 120) {
      setState(() {
        _error = 'Enter available study time from 5 to 120 minutes.';
        _recommendations = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
      _recommendations = [];
    });

    try {
      final results = await _service.recommendTasks(
        availableMinutes: minutes,
      );

      if (!mounted) return;

      setState(() {
        _recommendations = results
            .where((item) =>
                !_dismissedTaskIds.contains(item.task.id))
            .toList();
        _loading = false;

        if (_recommendations.isEmpty) {
          _message = 'No eligible tasks found. Add an active study task.';
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not generate recommendations: $error';
      });
    }
  }

  void _accept(TaskRecommendation recommendation) {
    setState(() {
      _acceptedTask = recommendation.task;
      _message = 'Accepted: ${recommendation.task.title}';
      _error = null;
    });
  }

  void _dismiss(TaskRecommendation recommendation) {
    setState(() {
      _dismissedTaskIds.add(recommendation.task.id!);
      _recommendations.removeWhere(
        (item) => item.task.id == recommendation.task.id,
      );
      _message = 'Recommendation dismissed.';
      _acceptedTask = null;

      if (_recommendations.isEmpty) {
        _message = 'No more recommendations. Generate again to refresh.';
      }
    });
  }

  Future<void> _overrideRecommendation() async {
    final candidates = _recommendations
        .map((item) => item.task)
        .where((task) => task.id != null)
        .toList();

    if (candidates.isEmpty) {
      setState(() {
        _error = 'No tasks available to override with.';
      });
      return;
    }

    StudyTask? selected = candidates.first;

    final result = await showDialog<StudyTask>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose a different task'),
          content: DropdownButton<StudyTask>(
            isExpanded: true,
            value: selected,
            items: candidates.map((task) {
              return DropdownMenuItem(
                value: task,
                child: Text(task.title),
              );
            }).toList(),
            onChanged: (task) {
              setDialogState(() => selected = task);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Override'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _acceptedTask = result;
      _message = 'Override selected: ${result.title}';
      _error = null;
    });
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Helper')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Get a study recommendation based on priority, time fit, '
            'and recorded study time.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Available study time (minutes)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _getRecommendations,
            child: Text(
              _loading ? 'Calculating...' : 'Get Recommendation',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          if (_acceptedTask != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text('Selected: ${_acceptedTask!.title}'),
                subtitle: const Text(
                  'Selection saved for this screen only. '
                  'It has not started a focus session.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < _recommendations.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recommendations[i].task.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score: ${_recommendations[i].score.toStringAsFixed(3)}',
                    ),
                    const SizedBox(height: 8),
                    Text(_recommendations[i].explanation),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () =>
                              _accept(_recommendations[i]),
                          child: const Text('Accept'),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              _dismiss(_recommendations[i]),
                          child: const Text('Dismiss'),
                        ),
                        OutlinedButton(
                          onPressed: _overrideRecommendation,
                          child: const Text('Override'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
