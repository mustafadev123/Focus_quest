import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/local_report_file_service.dart';
import '../../domain/report/study_report.dart';
import '../../providers/report_providers.dart';
import '../widgets/state_views.dart';

enum _Stage { preparing, writeFailed, readFailed, done }

/// Builds the study summary, saves it as a text file and previews the
/// file read back from storage.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.input});

  final StudyReportInput input;

  static Future<void> open(BuildContext context, StudyReportInput input) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReportScreen(input: input)),
    );
  }

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  _Stage _stage = _Stage.preparing;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _stage = _Stage.preparing);
    final files = ref.read(reportFileServiceProvider);

    try {
      final text = await ref.read(reportBuilderProvider)(widget.input);
      await files.write(text);
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.writeFailed);
      return;
    }

    try {
      // Preview what is actually on disk, not the text in memory.
      final saved = await files.read();
      if (!mounted) return;
      setState(() {
        _content = saved;
        _stage = _Stage.done;
      });
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.readFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Study summary')),
      body: switch (_stage) {
        _Stage.preparing => const LoadingView(label: 'Preparing your report…'),
        _Stage.writeFailed => ErrorView(
            message: "Couldn't save the report. Check that your phone has "
                'free storage, then try again.',
            onRetry: _run,
          ),
        _Stage.readFailed => ErrorView(
            message: "The report was saved but couldn't be opened. "
                'Try again.',
            onRetry: _run,
          ),
        _Stage.done => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Saved on this phone as '
                '${LocalReportFileService.fileName}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  _content,
                  style: const TextStyle(fontFamily: 'monospace', height: 1.4),
                ),
              ),
            ],
          ),
      },
    );
  }
}
