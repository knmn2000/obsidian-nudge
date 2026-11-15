import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../data/store.dart';
import '../notes/note.dart';
import '../review/scheduler.dart';
import '../sync/github_sync.dart';

class NoteScreen extends StatefulWidget {
  final String path;
  final Store store;
  final Directory cacheDir;
  final DateTime Function() now;

  const NoteScreen({
    super.key,
    required this.path,
    required this.store,
    required this.cacheDir,
    this.now = DateTime.now,
  });

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  late final Future<Note?> _note = _load();

  Future<Note?> _load() async {
    await widget.store.reload();
    for (final n in await loadCachedNotes(widget.cacheDir)) {
      if (n.path == widget.path) return n;
    }
    return null;
  }

  Future<void> _rate(Rating r) async {
    await widget.store.reload();
    final states = await widget.store.loadStates();
    states[widget.path] = rate(r, widget.now());
    await widget.store.saveStates(states);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Note?>(
      future: _note,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final note = snap.data;
        if (note == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This note no longer exists')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(note.title)),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(data: note.body),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (label, r) in [
                        ('Didn\'t get it', Rating.didntGetIt),
                        ('Forgot', Rating.forgot),
                        ('Meh', Rating.meh),
                        ('Know it', Rating.knowIt),
                      ])
                        FilledButton(
                          onPressed: () => _rate(r),
                          child: Text(label),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
