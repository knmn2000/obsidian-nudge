import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_nudge/notes/note.dart';

void main() {
  group('isNotePath', () {
    test('rejects non-notes', () {
      for (final p in [
        '.obsidian/x.md',
        'Excalidraw/d.excalidraw.md',
        'KANBAN.md',
        '2026-09-07.md',
        'a.txt',
      ]) {
        expect(isNotePath(p), isFalse, reason: p);
      }
    });

    test('accepts nested note', () {
      expect(isNotePath('CSE stuff/General terms/redis.md'), isTrue);
    });
  });

  group('parseNote', () {
    test('title and firstLine from heading', () {
      final n = parseNote('x/kafka.md', '# Kafka\n\na log of events\n- b')!;
      expect(n.path, 'x/kafka.md');
      expect(n.title, 'Kafka');
      expect(n.firstLine, 'a log of events');
    });

    test('no heading falls back to filename', () {
      final n = parseNote('x/kafka.md', 'just text')!;
      expect(n.title, 'kafka');
      expect(n.firstLine, 'just text');
    });

    test('skips frontmatter', () {
      final n = parseNote('a.md', '---\ntags: a\n---\n# T\nline')!;
      expect(n.title, 'T');
      expect(n.firstLine, 'line');
    });

    test('skips code fence, uses next prose line', () {
      final n = parseNote('a.md', '# T\n```\ncode\n```\nprose')!;
      expect(n.firstLine, 'prose');
    });

    test('only a code fence gives empty firstLine', () {
      final n = parseNote('a.md', '# T\n```\ncode\n```')!;
      expect(n.firstLine, '');
    });

    test('flattens wikilinks', () {
      expect(
        parseNote('a.md', '# T\n[[Redis|cache]] is fast')!.firstLine,
        'cache is fast',
      );
      expect(parseNote('a.md', '# T\n[[Redis]]')!.firstLine, 'Redis');
    });

    test('truncates firstLine to 140 chars with ellipsis', () {
      final n = parseNote('a.md', '# T\n${'a' * 200}')!;
      expect(n.firstLine.length, 140);
      expect(n.firstLine.endsWith('…'), isTrue);
    });

    test('blank content is null', () {
      expect(parseNote('a.md', '  \n'), isNull);
    });

    test('non-note path is null', () {
      expect(parseNote('KANBAN.md', '# K\nx'), isNull);
    });
  });
}
