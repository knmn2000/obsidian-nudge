import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_nudge/notes/obsidian_link.dart';

void main() {
  test('strips .md and percent-encodes spaces and slashes', () {
    expect(
      obsidianLink('CSE stuff/Big O & friends.md').toString(),
      'obsidian://open?vault=knmn2000&file=CSE%20stuff%2FBig%20O%20%26%20friends',
    );
  });

  test('leaves a path without .md alone', () {
    expect(obsidianLink('a/b').toString(), contains('file=a%2Fb'));
  });
}
