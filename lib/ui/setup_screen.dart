import 'package:flutter/material.dart';

import '../data/store.dart';
import '../sync/github_sync.dart';

class SetupScreen extends StatefulWidget {
  final Store store;
  final Future<void> Function() syncNow;
  final VoidCallback onDone;

  const SetupScreen({
    super.key,
    required this.store,
    required this.syncNow,
    required this.onDone,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _repo = TextEditingController();
  final _branch = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.store.settings().then((s) {
      if (!mounted) return;
      _repo.text = s.repo;
      _branch.text = s.branch;
    });
  }

  @override
  void dispose() {
    _token.dispose();
    _repo.dispose();
    _branch.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.setToken(_token.text.trim());
      final s = await widget.store.settings();
      await widget.store.saveSettings(
        s.copyWith(repo: _repo.text.trim(), branch: _branch.text.trim()),
      );
      await widget.syncNow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is SyncException ? e.message : e.toString();
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onDone();
  }

  String? _required(String? v, String msg) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect GitHub')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('token'),
                  controller: _token,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'GitHub token',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _required(v, 'Token is required'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('repo'),
                  controller: _repo,
                  decoration: const InputDecoration(
                    labelText: 'Repository (owner/name)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _required(v, 'Repository is required'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('branch'),
                  controller: _branch,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _required(v, 'Branch is required'),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Syncing…' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
