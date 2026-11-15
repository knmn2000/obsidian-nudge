import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_nudge/data/store.dart';
import 'package:obsidian_nudge/sync/github_sync.dart';
import 'package:obsidian_nudge/ui/setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(Store, MemoryTokenStore)> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final tokens = MemoryTokenStore();
  return (Store(await SharedPreferences.getInstance(), tokens), tokens);
}

Future<void> _pump(
  WidgetTester tester,
  Store store,
  Future<void> Function() syncNow,
  VoidCallback onDone,
) => tester.pumpWidget(
  MaterialApp(
    home: SetupScreen(store: store, syncNow: syncNow, onDone: onDone),
  ),
);

void main() {
  testWidgets('prefills repo and branch', (tester) async {
    final (store, _) = await _setup();
    await _pump(tester, store, () async {}, () {});
    await tester.pumpAndSettle();
    expect(find.text('knmn2000/obsidian-notes'), findsOneWidget);
    expect(find.text('main'), findsOneWidget);
  });

  testWidgets('Save stores trimmed token and settings, syncs, calls onDone', (
    tester,
  ) async {
    final (store, tokens) = await _setup();
    var synced = 0;
    var done = 0;
    await _pump(tester, store, () async => synced++, () => done++);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('token')), '  ghp_abc  ');
    await tester.enterText(find.byKey(const Key('repo')), 'a/b');
    await tester.enterText(find.byKey(const Key('branch')), 'dev');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await tokens.read(), 'ghp_abc');
    final s = await store.settings();
    expect(s.repo, 'a/b');
    expect(s.branch, 'dev');
    expect(synced, 1);
    expect(done, 1);
  });

  testWidgets('sync failure shows error, no token leak, no onDone', (
    tester,
  ) async {
    final (store, _) = await _setup();
    var done = 0;
    await _pump(
      tester,
      store,
      () async => throw const SyncException('Bad credentials'),
      () => done++,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('token')), 'ghp_secret');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Bad credentials'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('ghp_secret'),
      ),
      findsNothing,
    );
    expect(done, 0);
  });

  testWidgets('empty token shows validation and does not save', (tester) async {
    final (store, tokens) = await _setup();
    var synced = 0;
    await _pump(tester, store, () async => synced++, () {});
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('token')), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Token is required'), findsOneWidget);
    expect(await tokens.read(), isNull);
    expect(synced, 0);
  });
}
