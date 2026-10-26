import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/study_task.dart';
import '../../domain/validation/validation.dart';
import '../../providers/task_providers.dart';
import '../task_actions.dart';
import '../widgets/state_views.dart';
import 'widgets/minutes_field.dart';

/// Add Task when [taskId] is null, otherwise Edit Task for that saved task.
class TaskFormScreen extends ConsumerWidget {
  const TaskFormScreen({super.key, this.taskId});

  final int? taskId;

  static Future<void> open(BuildContext context, {int? taskId}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TaskFormScreen(taskId: taskId)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = taskId;
    if (id == null) return const _TaskForm(initial: null);

    final task = ref.watch(taskByIdProvider(id));
    if (task.hasValue) {
      final value = task.value;
      if (value != null) return _TaskForm(initial: value);
      return _Message(
        child: ErrorView(
          message: 'This task no longer exists.',
          onRetry: () => ref.invalidate(taskByIdProvider(id)),
        ),
      );
    }
    if (task.hasError) {
      return _Message(
        child: ErrorView(
          message: "Couldn't load this task.",
          onRetry: () => ref.invalidate(taskByIdProvider(id)),
        ),
      );
    }
    return const _Message(child: LoadingView(label: 'Loading task…'));
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Edit Task')), body: child);
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({required this.initial});

  final StudyTask? initial;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  static const _defaultMinutes = 25;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _subject;
  late final TextEditingController _minutes;
  late TaskPriority _priority;
  late TaskStatus _status;

  bool _submitted = false;
  bool _saving = false;
  bool _saveFailed = false;

  bool get _isEdit => widget.initial != null;

  Future<void> _delete() async {
    final deleted = await confirmAndDeleteTask(context, ref, widget.initial!);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    final task = widget.initial;
    _title = TextEditingController(text: task?.title ?? '');
    _subject = TextEditingController(text: task?.subject ?? '');
    _minutes = TextEditingController(
        text: '${task?.estimatedMinutes ?? _defaultMinutes}');
    _priority = task?.priority ?? TaskPriority.medium;
    _status = task?.status ?? TaskStatus.pending;
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _minutes.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final task = widget.initial;
    return _title.text.trim() != (task?.title ?? '') ||
        _subject.text.trim() != (task?.subject ?? '') ||
        _minutes.text != '${task?.estimatedMinutes ?? _defaultMinutes}' ||
        _priority != (task?.priority ?? TaskPriority.medium) ||
        _status != (task?.status ?? TaskStatus.pending);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final notifier = ref.read(tasksProvider.notifier);
    final minutes = parseMinutes(_minutes.text)!;
    try {
      final initial = widget.initial;
      if (initial == null) {
        await notifier.create(
          title: _title.text,
          subject: _subject.text,
          priority: _priority,
          estimatedMinutes: minutes,
          status: _status,
        );
      } else {
        await notifier.save(initial.copyWith(
          title: _title.text,
          subject: _subject.text,
          priority: _priority,
          estimatedMinutes: minutes,
          status: _status,
        ));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      // Input stays in the controllers so Retry resubmits it unchanged.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _leave() async {
    if (!_isDirty || await _confirmDiscard()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this task will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = ref.watch(subjectsProvider).value ?? const <String>[];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _saving ? null : _leave),
          title: Text(_isEdit ? 'Edit Task' : 'Add Task'),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (_saveFailed) ...[
                _SaveFailedBanner(onRetry: _saving ? null : _save),
                const SizedBox(height: 16),
              ],
              const _FieldLabel('Task title *'),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    hintText: 'e.g. Review recursion notes'),
                validator: validateTitle,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Subject *'),
              _SubjectField(
                controller: _subject,
                subjects: subjects,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Priority'),
              SegmentedButton<TaskPriority>(
                segments: [
                  for (final p in TaskPriority.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {_priority},
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: theme.colorScheme.primary,
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onSelectionChanged: (s) => setState(() => _priority = s.single),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Estimated time (minutes)'),
              MinutesField(
                controller: _minutes,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Status'),
              DropdownButtonFormField<TaskStatus>(
                initialValue: _status,
                items: [
                  for (final s in TaskStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (s) => setState(() => _status = s ?? _status),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : _leave,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: 'Saving task',
                              ),
                            )
                          : const Text('Save task'),
                    ),
                  ),
                ],
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _saving ? null : _delete,
                  child: const Text('Delete task'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ExcludeSemantics(
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Free-text subject (required, up to 40 characters) that suggests the
/// subjects already in use.
class _SubjectField extends StatefulWidget {
  const _SubjectField({
    required this.controller,
    required this.subjects,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<String> subjects;
  final VoidCallback onChanged;

  @override
  State<_SubjectField> createState() => _SubjectFieldState();
}

class _SubjectFieldState extends State<_SubjectField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        return widget.subjects.where(
            (s) => s.toLowerCase().contains(query) && s.toLowerCase() != query);
      },
      onSelected: (_) => widget.onChanged(),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Data Structures',
            suffixIcon: Icon(Icons.expand_more),
          ),
          validator: validateSubject,
          onChanged: (_) => widget.onChanged(),
          onFieldSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      title: Text(option),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SaveFailedBanner extends StatelessWidget {
  const _SaveFailedBanner({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Couldn't save the task.",
                style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Your changes are kept.',
                style: TextStyle(color: scheme.onErrorContainer)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child:
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
