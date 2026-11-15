class Note {
  final String path;
  final String title;
  final String firstLine;
  final String body;

  const Note({
    required this.path,
    required this.title,
    required this.firstLine,
    required this.body,
  });
}

final _dailyName = RegExp(r'^\d{4}-\d{2}-\d{2}\.md$');
final _wikilink = RegExp(r'\[\[([^\]|]*)(?:\|([^\]]*))?\]\]');

bool isNotePath(String path) {
  if (!path.endsWith('.md') || path.endsWith('.excalidraw.md')) return false;
  final parts = path.split('/');
  final name = parts.last;
  if (parts
      .take(parts.length - 1)
      .any((d) => d == '.obsidian' || d == '.git' || d == 'Excalidraw')) {
    return false;
  }
  return name != 'KANBAN.md' &&
      name != 'Untitled.md' &&
      !_dailyName.hasMatch(name);
}

Note? parseNote(String path, String content) {
  if (!isNotePath(path) || content.trim().isEmpty) return null;

  var lines = content.split('\n');
  if (lines.first.trim() == '---') {
    final end = lines.indexWhere((l) => l.trim() == '---', 1);
    if (end != -1) lines = lines.sublist(end + 1);
  }
  final body = lines.join('\n').trim();

  String? title;
  var firstLine = '';
  var inFence = false;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.startsWith('```') || line.startsWith('~~~')) {
      inFence = !inFence;
      continue;
    }
    if (inFence || line.isEmpty) continue;
    if (line.startsWith('#')) {
      if (title == null && line.startsWith('# ')) {
        title = line.substring(2).trim();
      }
      continue;
    }
    if (firstLine.isEmpty) firstLine = line;
  }

  firstLine = firstLine.replaceAllMapped(
    _wikilink,
    (m) => (m[2] ?? '').isNotEmpty ? m[2]! : m[1]!,
  );
  if (firstLine.length > 140) firstLine = '${firstLine.substring(0, 139)}…';

  final fileName = path.split('/').last;
  return Note(
    path: path,
    title: title ?? fileName.substring(0, fileName.length - 3),
    firstLine: firstLine,
    body: body,
  );
}
