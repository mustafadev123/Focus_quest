// Turns coverage/lcov.info into COVERAGE.md.
//
//   flutter test --coverage
//   dart run tool/coverage_report.dart
import 'dart:io';

void main() {
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr
        .writeln('coverage/lcov.info not found. Run: flutter test --coverage');
    exitCode = 1;
    return;
  }

  // Lines found and hit per source file.
  final files = <String, (int, int)>{};
  String? current;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll(r'\', '/');
    } else if (line.startsWith('DA:') && current != null) {
      final hits = int.parse(line.substring(3).split(',')[1]);
      final (found, hit) = files[current] ?? (0, 0);
      files[current] = (found + 1, hit + (hits > 0 ? 1 : 0));
    }
  }

  String pct(int hit, int found) =>
      found == 0 ? '—' : '${(hit * 100 / found).toStringAsFixed(1)}%';

  final totalFound = files.values.fold(0, (s, f) => s + f.$1);
  final totalHit = files.values.fold(0, (s, f) => s + f.$2);

  // Group by layer: lib/domain, lib/data, lib/providers, lib/presentation.
  String layerOf(String path) {
    final parts = path.split('/');
    final i = parts.indexOf('lib');
    return i >= 0 && i + 2 < parts.length ? parts[i + 1] : '(root)';
  }

  final layers = <String, (int, int)>{};
  for (final MapEntry(:key, :value) in files.entries) {
    final layer = layerOf(key);
    final (f, h) = layers[layer] ?? (0, 0);
    layers[layer] = (f + value.$1, h + value.$2);
  }

  final out = StringBuffer()
    ..writeln('# Test coverage')
    ..writeln()
    ..writeln('Generated ${DateTime.now().toIso8601String().substring(0, 16)} '
        'from `flutter test --coverage` (unit and widget tests). The '
        'integration tests in `integration_test/` run on a device and are '
        'not included in these numbers.')
    ..writeln()
    ..writeln('Regenerate with:')
    ..writeln()
    ..writeln('```')
    ..writeln('flutter test --coverage')
    ..writeln('dart run tool/coverage_report.dart')
    ..writeln('```')
    ..writeln()
    ..writeln('**Total: ${pct(totalHit, totalFound)}** '
        '($totalHit of $totalFound lines)')
    ..writeln()
    ..writeln('## By layer')
    ..writeln()
    ..writeln('| Layer | Lines hit | Coverage |')
    ..writeln('|---|---|---|');
  for (final layer in layers.keys.toList()..sort()) {
    final (f, h) = layers[layer]!;
    out.writeln('| `$layer` | $h / $f | ${pct(h, f)} |');
  }
  out
    ..writeln()
    ..writeln('## By file')
    ..writeln()
    ..writeln('| File | Lines hit | Coverage |')
    ..writeln('|---|---|---|');
  final paths = files.keys.toList()..sort();
  for (final path in paths) {
    final (f, h) = files[path]!;
    final shown =
        path.contains('lib/') ? path.substring(path.indexOf('lib/')) : path;
    out.writeln('| `$shown` | $h / $f | ${pct(h, f)} |');
  }

  // Files no unit or widget test loads are absent from lcov.info, so they
  // are not in the percentages above. List them so the total is not
  // mistaken for whole-app coverage.
  final measured = {
    for (final path in files.keys)
      if (path.contains('lib/')) path.substring(path.indexOf('lib/')),
  };
  final unmeasured = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((path) => path.endsWith('.dart') && !measured.contains(path))
      .toList()
    ..sort();
  if (unmeasured.isNotEmpty) {
    out
      ..writeln()
      ..writeln('## Not measured')
      ..writeln()
      ..writeln('No unit or widget test loads these files, so they are not '
          'in the totals. Interfaces have no executable lines. `main.dart` '
          'and the notification plugin wrapper need a real device; the '
          'integration tests replace notifications with a fake and do not '
          'call `main`, so these are checked manually on the phone.')
      ..writeln();
    for (final path in unmeasured) {
      out.writeln('- `$path`');
    }
  }

  File('COVERAGE.md').writeAsStringSync(out.toString());
  stdout.writeln('Total ${pct(totalHit, totalFound)}; wrote COVERAGE.md');
}
