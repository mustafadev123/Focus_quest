import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/domain/validation/validation.dart';

final _created = DateTime(2026, 10, 20, 9);

StudyTask _task({
  String title = 'Review recursion notes',
  String subject = 'Data Structures',
  int minutes = 25,
  DateTime? updatedAt,
}) =>
    StudyTask(
      title: title,
      subject: subject,
      priority: TaskPriority.high,
      estimatedMinutes: minutes,
      status: TaskStatus.pending,
      createdAt: _created,
      updatedAt: updatedAt ?? _created,
    );

void main() {
  group('title', () {
    test('is required and blank-only text counts as empty', () {
      expect(validateTitle(null), 'Title is required');
      expect(validateTitle(''), 'Title is required');
      expect(validateTitle('   '), 'Title is required');
    });

    test('accepts 60 characters and rejects 61', () {
      expect(validateTitle('a' * 60), isNull);
      expect(validateTitle('a' * 61), contains('60 characters'));
    });

    test('ignores surrounding whitespace when measuring length', () {
      expect(validateTitle('  ${'a' * 60}  '), isNull);
    });
  });

  group('subject', () {
    test('is required', () {
      expect(validateSubject('  '), 'Subject is required');
    });

    test('accepts 40 characters and rejects 41', () {
      expect(validateSubject('s' * 40), isNull);
      expect(validateSubject('s' * 41), contains('40 characters'));
    });
  });

  group('estimated minutes', () {
    test('accepts the 5 and 120 boundaries', () {
      expect(validateEstimatedMinutes(5), isNull);
      expect(validateEstimatedMinutes(120), isNull);
    });

    test('rejects values just outside the range, zero and missing input', () {
      for (final bad in [4, 121, 0, -10]) {
        expect(validateEstimatedMinutes(bad), contains('between 5 and 120'),
            reason: '$bad');
      }
      expect(validateEstimatedMinutes(null), contains('whole number'));
    });
  });

  group('available minutes for the helper', () {
    test('rejects the proposal examples of 3 and 200', () {
      expect(validateAvailableMinutes(3), isNotNull);
      expect(validateAvailableMinutes(200), isNotNull);
      expect(validateAvailableMinutes(5), isNull);
      expect(validateAvailableMinutes(120), isNull);
    });
  });

  group('session minutes', () {
    test('must be positive and at most 120', () {
      expect(validateSessionMinutes(1), isNull);
      expect(validateSessionMinutes(120), isNull);
      expect(validateSessionMinutes(0), contains('between 1 and 120'));
      expect(validateSessionMinutes(121), contains('between 1 and 120'));
    });
  });

  group('parseMinutes', () {
    test('reads whole numbers and rejects other text', () {
      expect(parseMinutes(' 25 '), 25);
      expect(parseMinutes(''), isNull);
      expect(parseMinutes('25.5'), isNull);
      expect(parseMinutes('abc'), isNull);
    });
  });

  group('ensureValidTask', () {
    test('accepts a valid task', () {
      expect(() => ensureValidTask(_task()), returnsNormally);
    });

    test('reports every invalid field at once', () {
      try {
        ensureValidTask(_task(title: ' ', subject: '', minutes: 0));
        fail('expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.errors.keys,
            unorderedEquals(['title', 'subject', 'estimatedMinutes']));
      }
    });

    test('rejects an update time earlier than creation', () {
      expect(
        () => ensureValidTask(
            _task(updatedAt: _created.subtract(const Duration(minutes: 1)))),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ensureValidSession', () {
    final now = DateTime(2026, 10, 25, 18);

    StudySession session({
      DateTime? startedAt,
      DateTime? endedAt,
      int minutes = 30,
    }) =>
        StudySession(
          taskId: 1,
          startedAt: startedAt ?? DateTime(2026, 10, 25, 17),
          endedAt: endedAt,
          durationMinutes: minutes,
          status: SessionStatus.manual,
        );

    test('accepts a past session with no end time', () {
      expect(() => ensureValidSession(session(), now: now), returnsNormally);
    });

    test('rejects a future start, an end before start and a bad duration',
        () {
      try {
        ensureValidSession(
          session(
            startedAt: now.add(const Duration(hours: 1)),
            endedAt: now,
            minutes: 0,
          ),
          now: now,
        );
        fail('expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.errors.keys,
            unorderedEquals(['startedAt', 'endedAt', 'durationMinutes']));
      }
    });
  });

  group('stored values', () {
    test('map back to the same enum and reject unknown text', () {
      for (final s in TaskStatus.values) {
        expect(TaskStatus.fromStorage(s.storageValue), s);
      }
      for (final s in SessionStatus.values) {
        expect(SessionStatus.fromStorage(s.storageValue), s);
      }
      expect(TaskStatus.fromStorage('in_progress'), isNull);
      expect(TaskPriority.fromValue(2), TaskPriority.medium);
      expect(TaskPriority.fromValue(4), isNull);
    });

    test('pending tasks are shown as "To do" to match the wireframe', () {
      expect(TaskStatus.pending.label, 'To do');
    });
  });
}
