import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/data/services/local_report_file_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late LocalReportFileService files;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('focus_quest_report');
    files = LocalReportFileService(directory: () async => dir);
  });
  tearDown(() => dir.delete(recursive: true));

  test('writes the report to a text file and reads it back', () async {
    final path = await files.write('FocusQuest study summary\nTotal: 2h\n');

    expect(path, p.join(dir.path, LocalReportFileService.fileName));
    expect(File(path).existsSync(), isTrue);
    expect(await files.read(), 'FocusQuest study summary\nTotal: 2h\n');
  });

  test('a new report replaces the previous one', () async {
    await files.write('first');
    await files.write('second');
    expect(await files.read(), 'second');
  });

  test('reading before anything was saved fails clearly', () {
    expect(files.read(), throwsA(isA<FileSystemException>()));
  });

  test('writing to a folder that does not exist fails', () {
    final missing = LocalReportFileService(
        directory: () async => Directory(p.join(dir.path, 'missing')));
    expect(missing.write('text'), throwsA(isA<FileSystemException>()));
  });
}
