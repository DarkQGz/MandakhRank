import 'dart:async';

import 'package:flutter/material.dart';

import 'data.dart';
import 'theme_settings.dart';
import 'auth_screen.dart';

class PracticeScreen extends StatefulWidget {
  final Map<String, dynamic> problem;
  const PracticeScreen({super.key, required this.problem});
  @override
  State<PracticeScreen> createState() => _PracticeState();
}

class _PracticeState extends State<PracticeScreen> {
  final code = _PythonController(
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

  Widget _panel(Widget child) {
    final p = MandakhPalette.of(context);
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.outline)), child: child);
  }

  String _verdict(dynamic value) => const {
    'Accepted': 'Зөв хариу', 'Wrong Answer': 'Буруу хариу', 'Queued': 'Хүлээгдэж байна', 'Running': 'Шалгаж байна',
    'Time Limit Exceeded': 'Хугацаа хэтэрсэн', 'Memory Limit Exceeded': 'Санах ой хэтэрсэн', 'Runtime Error': 'Ажиллуулах алдаа',
    'Compilation Error': 'Хөрвүүлэх алдаа', 'Judge Error': 'Шүүгчийн алдаа', 'Output Limit Exceeded': 'Гаралтын хэмжээ хэтэрсэн',
  }[value] ?? value.toString();

  Widget _example(String label, dynamic value) {
    final palette = MandakhPalette.of(context);
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: palette.background, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8), SelectableText('$value', style: const TextStyle(fontFamily: 'monospace', height: 1.5)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;
    final palette = MandakhPalette.of(context);
    final completed = PracticeApi.token != null && (p['completed'] == true || history.any((s) => s['status'] == 'Accepted'));
    final statement = _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (p['difficulty'] != null) Chip(label: Text('${p['difficulty']}')),
        if (p['points'] != null) Chip(label: Text('${p['points']} оноо')),
        if (completed) Chip(avatar: Icon(Icons.check_circle_outline, color: palette.positive, size: 18), label: const Text('Амжилттай бодсон')),
      ]),
      const SizedBox(height: 12),
      Text('Бодлогын нөхцөл', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      SelectableText('${p['description']}', style: const TextStyle(fontSize: 15, height: 1.65)),
      const SizedBox(height: 20),
      LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth >= 360 ? (c.maxWidth - 12) / 2 : c.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, children: [SizedBox(width: w, child: _example('Жишээ оролт', p['input'])), SizedBox(width: w, child: _example('Жишээ гаралт', p['output']))]);
      }),
    ]));
    final editor = _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Icon(Icons.code_rounded, color: palette.accentInk, size: 20), const SizedBox(width: 8), const Expanded(child: Text('Кодын талбар', style: TextStyle(fontWeight: FontWeight.w700))), Text('Python 3', style: TextStyle(color: palette.muted, fontSize: 12))]),
      const SizedBox(height: 8),
      Text('2 секунд / тест · 128 MB', style: TextStyle(color: palette.muted, fontSize: 12)),
      const SizedBox(height: 16),
      if (PracticeApi.token == null)
        FilledButton(onPressed: () async {
          await Navigator.push(context, MaterialPageRoute<bool>(builder: (_) => const AuthScreen()));
          await refresh();
          if (mounted) setState(() {});
        }, child: const Text('Нэвтрэх / Бүртгүүлэх'))
      else ...[
        Row(children: [Expanded(child: Text('Нэвтэрсэн: ${PracticeApi.username ?? ''}', overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 12))), TextButton(onPressed: busy ? null : () => action(() async {
          await PracticeApi.request('auth/logout/', body: {});
          await PracticeApi.signOut();
          widget.problem['completed'] = false;
          if (mounted) setState(() => history = []);
        }), child: const Text('Гарах'))]),
        Container(decoration: BoxDecoration(color: palette.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: palette.outline)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [Icon(Icons.description_outlined, size: 16, color: palette.muted), const SizedBox(width: 6), const Expanded(child: Text('solution.py', style: TextStyle(fontSize: 12, fontFamily: 'monospace'))), ValueListenableBuilder<TextEditingValue>(valueListenable: code, builder: (_, v, __) => Text('${v.text.split('\n').length} мөр', style: TextStyle(color: palette.muted, fontSize: 12)))])),
          Divider(height: 1, color: palette.outline),
          TextField(controller: code, minLines: 12, maxLines: 24, keyboardType: TextInputType.multiline, autocorrect: false, enableSuggestions: false, style: TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.5, color: palette.text), decoration: InputDecoration(hintText: 'Кодоо бичнэ үү', fillColor: palette.background, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: const EdgeInsets.all(12))),
        ])),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: busy ? null : () => action(() async {
          await PracticeApi.request('submissions/', body: {'problem_id': p['id'], 'code': code.text});
          await refresh();
        }), icon: const Icon(Icons.send_rounded), label: const Text('Илгээж шалгуулах')),
      ],
      if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message, style: TextStyle(color: palette.negative))),
    ]));
    final submissions = _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Миний илгээлтүүд', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Дүн 3 секунд тутам шинэчлэгдэнэ.', style: TextStyle(color: palette.muted, fontSize: 12)),
      const SizedBox(height: 8),
      if (history.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Илгээлт хараахан алга.', style: TextStyle(color: palette.muted))),
      for (var i = 0; i < history.length; i++) ...[
        if (i > 0) const Divider(),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(history[i]['status'] == 'Accepted' ? Icons.check_circle_outline : Icons.code, color: history[i]['status'] == 'Accepted' ? palette.positive : history[i]['status'] == 'Wrong Answer' ? palette.negative : palette.accentInk), title: Text('#${history[i]['id']} · ${_verdict(history[i]['status'])}'), subtitle: Text('${history[i]['passed']}/${history[i]['total']} тест · ${history[i]['created_at']}')),
      ],
    ]));
    return Scaffold(appBar: AppBar(title: Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis)), body: SafeArea(child: LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000;
      return SingleChildScrollView(padding: EdgeInsets.all(wide ? 24 : 16), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1280), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (wide) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: statement), const SizedBox(width: 16), Expanded(flex: 2, child: editor)]) else ...[statement, const SizedBox(height: 16), editor],
        const SizedBox(height: 16), submissions,
      ]))));
    })));
  }
}

// Lightweight lexical highlighting; code is still submitted verbatim.
class _PythonController extends TextEditingController {
  _PythonController({super.text});
  static final _tokens = RegExp(r'''#[^\n]*|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\b(?:False|True|None|and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|print|input|range|len|map|int|str)\b|\b\d+(?:\.\d+)?\b''');
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (withComposing && value.isComposingRangeValid && !value.composing.isCollapsed) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final p = MandakhPalette.of(context);
    final spans = <TextSpan>[];
    var start = 0;
    for (final m in _tokens.allMatches(text)) {
      if (m.start > start) spans.add(TextSpan(text: text.substring(start, m.start)));
      final token = m.group(0)!;
      final color = token.startsWith('#') ? p.muted : token.startsWith("'") || token.startsWith('"') ? p.positive : RegExp(r'^\d').hasMatch(token) ? p.readable(const Color(0xFFFFC66B)) : p.accentInk;
      spans.add(TextSpan(text: token, style: TextStyle(color: color)));
      start = m.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return TextSpan(style: style, children: spans);
  }
}
