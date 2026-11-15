/// Vault name as Obsidian shows it on the phone (folder under Documents/Obsidian).
const obsidianVault = 'knmn2000';

/// Deep link that opens [notePath] (e.g. `CSE stuff/foo.md`) in the Obsidian app.
/// Obsidian wants the path without `.md`; encodeComponent gives `%20`, not `+`.
Uri obsidianLink(String notePath, {String vault = obsidianVault}) {
  final file = notePath.endsWith('.md')
      ? notePath.substring(0, notePath.length - 3)
      : notePath;
  return Uri.parse(
    'obsidian://open?vault=${Uri.encodeComponent(vault)}'
    '&file=${Uri.encodeComponent(file)}',
  );
}
