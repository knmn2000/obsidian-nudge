import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_nudge/notes/note.dart';
import 'package:obsidian_nudge/review/scheduler.dart';

Note n(String p) => Note(path: p, title: p, firstLine: '', body: p);
final now = DateTime.utc(2026, 1, 10, 12);
final epoch = DateTime.fromMillisecondsSinceEpoch(0);

void main() {
  group('rate', () {
    test('exact dueAt per rating', () {
      expect(
        rate(Rating.didntGetIt, now).dueAt,
        now.add(const Duration(hours: 4)),
      );
      expect(rate(Rating.forgot, now).dueAt, now.add(const Duration(days: 1)));
      expect(rate(Rating.meh, now).dueAt, now.add(const Duration(days: 3)));
      expect(rate(Rating.knowIt, now).dueAt, now.add(const Duration(days: 21)));
      expect(rate(Rating.knowIt, now).snoozedUntil, isNull);
    });
  });

  group('snooze', () {
    test('keeps dueAt, sets +1d', () {
      final due = now.subtract(const Duration(days: 2));
      final s = snooze(ReviewState(dueAt: due), now);
      expect(s.dueAt, due);
      expect(s.snoozedUntil, now.add(const Duration(days: 1)));
    });
    test('null state uses epoch', () {
      expect(snooze(null, now).dueAt, epoch);
    });
  });

  group('ReviewState json', () {
    test('round trips with and without snooze', () {
      final a = ReviewState(
        dueAt: now,
        snoozedUntil: now.add(const Duration(days: 1)),
      );
      final b = ReviewState.fromJson(a.toJson());
      expect(b.dueAt, a.dueAt);
      expect(b.snoozedUntil, a.snoozedUntil);
      final c = ReviewState(dueAt: now);
      expect(c.toJson()['snoozedUntil'], isNull);
      expect(ReviewState.fromJson(c.toJson()).snoozedUntil, isNull);
    });
  });

  group('pickNext', () {
    final rng = Random(1);
    test('most overdue wins', () {
      final notes = [n('a'), n('b')];
      final states = {
        'a': ReviewState(dueAt: now.subtract(const Duration(days: 1))),
        'b': ReviewState(dueAt: now.subtract(const Duration(days: 5))),
      };
      expect(pickNext(notes, states, now, rng)!.path, 'b');
    });
    test('skips snoozed and not-yet-due', () {
      final notes = [n('a'), n('b'), n('c')];
      final states = {
        'a': ReviewState(
          dueAt: now.subtract(const Duration(days: 9)),
          snoozedUntil: now.add(const Duration(hours: 1)),
        ),
        'b': ReviewState(dueAt: now.add(const Duration(hours: 1))),
        'c': ReviewState(
          dueAt: now.subtract(const Duration(days: 1)),
          snoozedUntil: now.subtract(const Duration(hours: 1)),
        ),
      };
      expect(pickNext(notes, states, now, rng)!.path, 'c');
    });
    test('ignores stale state path', () {
      final states = {
        'gone': ReviewState(dueAt: now.subtract(const Duration(days: 9))),
        'a': ReviewState(dueAt: now.subtract(const Duration(days: 1))),
      };
      expect(pickNext([n('a')], states, now, rng)!.path, 'a');
    });
    test('null on empty and when none eligible', () {
      expect(pickNext([], {}, now, rng), isNull);
      final states = {
        'a': ReviewState(dueAt: now.add(const Duration(days: 1))),
      };
      expect(pickNext([n('a')], states, now, rng), isNull);
    });
    test('never-seen beats seen-overdue', () {
      final states = {
        'a': ReviewState(dueAt: now.subtract(const Duration(days: 1))),
      };
      expect(pickNext([n('a'), n('new')], states, now, rng)!.path, 'new');
    });
    test('tie-break deterministic with Random(1)', () {
      final notes = [n('x'), n('y'), n('z')];
      final idx = Random(1).nextInt(3);
      expect(pickNext(notes, {}, now, Random(1))!.path, notes[idx].path);
      expect(pickNext(notes, {}, now, Random(1))!.path, notes[idx].path);
    });
  });

  group('inQuietHours', () {
    DateTime at(int h, [int m = 0]) => DateTime(2026, 1, 10, h, m);
    test('default 23-8', () {
      expect(inQuietHours(at(23)), isTrue);
      expect(inQuietHours(at(7, 59)), isTrue);
      expect(inQuietHours(at(0)), isTrue);
      expect(inQuietHours(at(8)), isFalse);
      expect(inQuietHours(at(22, 59)), isFalse);
    });
    test('non-wrapping window', () {
      expect(inQuietHours(at(0), startHour: 1, endHour: 5), isFalse);
      expect(inQuietHours(at(1), startHour: 1, endHour: 5), isTrue);
      expect(inQuietHours(at(4, 59), startHour: 1, endHour: 5), isTrue);
      expect(inQuietHours(at(5), startHour: 1, endHour: 5), isFalse);
    });
  });
}
