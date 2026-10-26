import 'package:focus_quest/domain/services/report_file_service.dart';

/// In-memory report file that can be told to fail.
class FakeReportFileService implements ReportFileService {
  String? saved;
  int writes = 0;
  Object? failNextWrite;
  Object? failNextRead;

  @override
  Future<String> write(String content) async {
    final error = failNextWrite;
    if (error != null) {
      failNextWrite = null;
      throw error;
    }
    writes++;
    saved = content;
    return '/fake/focusquest_study_summary.txt';
  }

  @override
  Future<String> read() async {
    final error = failNextRead;
    if (error != null) {
      failNextRead = null;
      throw error;
    }
    final content = saved;
    if (content == null) throw StateError('No report saved');
    return content;
  }
}
