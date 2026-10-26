import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/services/report_file_service.dart';

/// Keeps one report file in the app's private documents folder.
class LocalReportFileService implements ReportFileService {
  LocalReportFileService({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;

  static const fileName = 'focusquest_study_summary.txt';

  final Future<Directory> Function() _directory;

  Future<File> _file() async =>
      File(p.join((await _directory()).path, fileName));

  @override
  Future<String> write(String content) async {
    final file = await _file();
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  @override
  Future<String> read() async => (await _file()).readAsString();
}
