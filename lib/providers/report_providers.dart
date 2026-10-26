import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/local_report_file_service.dart';
import '../domain/report/study_report.dart';
import '../domain/services/report_file_service.dart';

final reportFileServiceProvider =
    Provider<ReportFileService>((ref) => LocalReportFileService());

typedef ReportBuilder = Future<String> Function(StudyReportInput input);

/// The report text is prepared in a background isolate so a long history
/// never blocks the UI. Tests replace this with a synchronous version.
final reportBuilderProvider = Provider<ReportBuilder>(
  (ref) => (input) => compute(buildStudyReport, input),
);
