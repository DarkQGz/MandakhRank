import 'dart:async';

import 'package:flutter/material.dart';

import 'data.dart';
import 'auth_screen.dart';

class PracticeScreen extends StatefulWidget {
  final Map<String, dynamic> problem;
  const PracticeScreen({super.key, required this.problem});
  @override
  State<PracticeScreen> createState() => _PracticeState();
}

class _PracticeState extends State<PracticeScreen> {
  final code = TextEditingController(
    text: '# Python 3\n# input() ашиглан оролтоо уншина уу.\n',
  );
  final name = TextEditingController(), password = TextEditingController();
  List<dynamic> history = [];
  bool busy = false, register = false, polling = false;
  String message = '';
  Timer? timer;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    name.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (PracticeApi.token == null || polling) return;
    polling = true;
    try {
      final r = await PracticeApi.request('submissions/');
      if (mounted)
        setState(
          () => history = (r['results'] as List)
              .where((s) => s['problem_id'] == widget.problem['id'])
              .toList(),
        );
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      polling = false;
    }
  }

  Future<void> action(Future<void> Function() run) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await run();
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;
    final completed =
        PracticeApi.token != null &&
        (widget.problem['completed'] == true ||
            history.any((s) => s['status'] == 'Accepted'));
    return Scaffold(
      appBar: AppBar(title: Text(p['title'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (completed)
                  const Chip(
                    label: Text('✓ Амжилттай бодсон'),
                    avatar: Icon(Icons.check_circle, color: Colors.green),
                  ),
                SelectableText(
                  p['description'],
                  style: const TextStyle(fontSize: 17, height: 1.6),
                ),
                const SizedBox(height: 20),
                const Text('Жишээ оролт'),
                SelectableText(p['input']),
                const SizedBox(height: 10),
                const Text('Жишээ гаралт'),
                SelectableText(p['output']),
                const SizedBox(height: 24),
                if (PracticeApi.token == null) ...[
                  FilledButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<bool>(
                          builder: (_) => const AuthScreen(),
                        ),
                      );
                      await refresh();
                      if (mounted) setState(() {});
                    },
                    child: const Text('Нэвтрэх / Бүртгүүлэх'),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text('Нэвтэрсэн: ${PracticeApi.username}'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => action(() async {
                                await PracticeApi.request(
                                  'auth/logout/',
                                  body: {},
                                );
                                PracticeApi.token = null;
                                PracticeApi.username = null;
                                widget.problem['completed'] = false;
                                if (mounted) setState(() => history = []);
                              }),
                        child: const Text('Гарах'),
                      ),
                    ],
                  ),
                  const Text('Python 3 • 2 секунд / тест • 128 MB'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    minLines: 12,
                    maxLines: 24,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(labelText: 'Код'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            await PracticeApi.request(
                              'submissions/',
                              body: {'problem_id': p['id'], 'code': code.text},
                            );
                            await refresh();
                          }),
                    icon: const Icon(Icons.send),
                    label: const Text('Илгээж шалгуулах'),
                  ),
                ],
                if (busy) const LinearProgressIndicator(),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text('Миний илгээлтүүд', style: TextStyle(fontSize: 22)),
                const Text(
                  'Бүх тест зөв бол Accepted болж, бодсон төлөв хадгалагдана. Дүн 3 секунд тутам шинэчлэгдэнэ.',
                ),
                ...history.map(
                  (s) => ListTile(
                    leading: Icon(
                      s['status'] == 'Accepted'
                          ? Icons.check_circle
                          : Icons.code,
                      color: s['status'] == 'Accepted' ? Colors.green : null,
                    ),
                    title: Text('#${s['id']} • ${s['status']}'),
                    subtitle: Text(
                      '${s['passed']}/${s['total']} тест • ${s['created_at']}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
