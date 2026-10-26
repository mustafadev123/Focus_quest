import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/aggregates.dart';
import 'package:focus_quest/presentation/format.dart';

void main() {
  group('startOfWeek', () {
    test('is Monday 00:00 for any day of that week', () {
      final monday = DateTime(2026, 10, 19);
      expect(startOfWeek(DateTime(2026, 10, 19, 0, 0)), monday);
      expect(startOfWeek(DateTime(2026, 10, 22, 13, 5)), monday);
      expect(startOfWeek(DateTime(2026, 10, 25, 23, 59)), monday);
    });

    test('crosses month boundaries', () {
      expect(startOfWeek(DateTime(2026, 11, 1, 12)), DateTime(2026, 10, 26));
    });
  });

  group('formatStudyTime', () {
    test('matches the wireframe style', () {
      expect(formatStudyTime(0), '0m');
      expect(formatStudyTime(45), '45m');
      expect(formatStudyTime(60), '1h');
      expect(formatStudyTime(105), '1h 45m');
      expect(formatStudyTime(260), '4h 20m');
    });

    test('has a spoken form for screen readers', () {
      expect(describeStudyTime(0), '0 minutes');
      expect(describeStudyTime(61), '1 hour 1 minute');
      expect(describeStudyTime(120), '2 hours');
    });
  });
}
