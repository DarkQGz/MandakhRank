import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'judge_languages.dart';
import 'theme_settings.dart';

List<Map<String, dynamic>> solutionRows(Object? raw) => raw is List
    ? raw.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : <Map<String, dynamic>>[];

void openSolution(BuildContext context, int userId, Map<String, dynamic> row) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
    SolutionCodeScreen(userId: userId, submissionId: row['id'] as int)));
}

class ProfileSolutionsSection extends StatelessWidget {
  const ProfileSolutionsSection({super.key, required this.userId, required this.rows,
    required this.owner, required this.onManage});
  final int userId;
  final List<Map<String, dynamic>> rows;
  final bool owner;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.outline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Icon(Icons.code_rounded, color: p.accentInk), const SizedBox(width: 10),
          Expanded(child: Text(owner ? 'Миний бодолтууд' : 'Нийтэлсэн бодолтууд', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          Text('${rows.length}', style: TextStyle(color: p.accentInk, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        Text(owner ? 'Бусдад харуулах бодолтоо өөрөө сонгоорой.' : 'Хэрэглэгчийн нийтэлсэн бодолтууд.', style: TextStyle(color: p.muted)),
        if (owner) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(key: const ValueKey('showcase-manage'), onPressed: onManage,
            icon: const Icon(Icons.visibility_outlined), label: const Text('Бодолтын харагдац тохируулах')),
        ],
        if (rows.isEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [Icon(Icons.lock_outline, color: p.muted), const SizedBox(width: 10),
            Expanded(child: Text('Нийтэлсэн бодолт алга.', style: TextStyle(color: p.muted)))])
        ] else ...[
          const SizedBox(height: 12),
          for (final row in rows.take(3)) _SolutionTile(row: row, onOpen: () => openSolution(context, userId, row)),
          if (rows.length > 3) TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _PublicSolutionsScreen(userId: userId, rows: rows))),
            icon: const Icon(Icons.arrow_forward), label: Text('Бүх ${rows.length} бодолтыг үзэх')),
        ],
      ]));
  }
}

class _SolutionTile extends StatelessWidget {
  const _SolutionTile({required this.row, required this.onOpen});
  final Map<String, dynamic> row;
  final VoidCallback onOpen;
  @override Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(
      color: p.background, borderRadius: BorderRadius.circular(12), child: ListTile(
        key: ValueKey('showcase-open-${row['id']}'), onTap: onOpen,
        leading: Icon(Icons.check_circle_outline, color: p.positive),
        title: Text('${row['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${judgeLabel(row['language'])} · ${row['difficulty'] ?? ''}'),
        trailing: Icon(Icons.chevron_right, color: p.accentInk),
      )));
  }
}

class _PublicSolutionsScreen extends StatefulWidget {
  const _PublicSolutionsScreen({required this.userId, required this.rows});
  final int userId;
  final List<Map<String, dynamic>> rows;
  @override State<_PublicSolutionsScreen> createState() => _PublicSolutionsState();
}
class _PublicSolutionsState extends State<_PublicSolutionsScreen> {
  String query = '';
  @override Widget build(BuildContext context) {
    final rows = widget.rows.where((r) => '${r['title']} ${judgeLabel(r['language'])}'.toLowerCase().contains(query.toLowerCase().trim())).toList();
    return Scaffold(appBar: AppBar(title: const Text('Нийтэлсэн бодолтууд')),
      body: SafeArea(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: rows.length + 1,
        itemBuilder: (context, i) => i == 0 ? Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
          onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Бодлого хайх')))
          : _SolutionTile(row: rows[i - 1], onOpen: () => openSolution(context, widget.userId, rows[i - 1])))));
  }
}

class SolutionPrivacyScreen extends StatefulWidget {
  const SolutionPrivacyScreen({super.key, required this.userId});
  final int userId;
  @override State<SolutionPrivacyScreen> createState() => _SolutionPrivacyState();
}
class _SolutionPrivacyState extends State<SolutionPrivacyScreen> {
  late final String? token;
  List<Map<String, dynamic>> rows = [];
  Set<int> selected = {}, previous = {};
  String filter = 'all', query = '';
  bool loading = true, saving = false;
  String? error;
  bool get sameAccount => token != null && token == PracticeApi.token;
  @override void initState() { super.initState(); token = PracticeApi.token; load(); }
  Future<void> load() async {
    if (!sameAccount) { setState(() { loading = false; error = 'Дахин нэвтэрнэ үү.'; }); return; }
    setState(() { loading = true; error = null; });
    try {
      final result = await PracticeApi.request('profile/solutions/');
      if (!mounted || !sameAccount) return;
      if (result['results'] is! List || result['shared_ids'] is! List) throw const FormatException('Бодолтын мэдээлэл буруу байна.');
      final data = solutionRows(result['results']);
      setState(() {
        rows = data;
        previous = (result['shared_ids'] as List).cast<int>().toSet();
        selected = data.where((r) => r['shared'] == true).map((r) => r['id'] as int).toSet();
      });
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  bool get changed => selected.length != previous.length || !selected.containsAll(previous);
  Future<void> save() async {
    if (saving || loading || !sameAccount || !changed) return;
    final newlyShared = selected.difference(previous).length;
    if (newlyShared > 0) {
      final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Бодолтоо нийтлэх үү?'),
        content: Text('$newlyShared бодолтын кодыг бусад хүн харах, хуулах боломжтой болно. Нууц мэдээлэл оруулаагүй эсэхээ шалгаарай.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Болих')),
          FilledButton(key: const ValueKey('showcase-confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Нийтлэх'))],
      ));
      if (yes != true || !mounted || !sameAccount || saving) return;
    }
    setState(() { saving = true; error = null; });
    try {
      final result = await PracticeApi.request('profile/solutions/', body: {
        'ids': selected.toList()..sort(), 'previous_ids': previous.toList()..sort(),
      });
      if (!mounted || !sameAccount) return;
      if (result['results'] is! List) throw const FormatException('Хадгалсан мэдээлэл буруу байна.');
      Navigator.pop(context, solutionRows(result['results']));
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final filtered = rows.where((r) {
      final isSelected = selected.contains(r['id']);
      return (filter == 'all' || (filter == 'shared' ? isSelected : !isSelected)) &&
        '${r['title']} ${judgeLabel(r['language'])}'.toLowerCase().contains(query.toLowerCase().trim());
    }).toList();
    final disabled = loading || saving || !sameAccount;
    return Scaffold(appBar: AppBar(title: const Text('Бодолтын харагдац')),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: FilledButton.icon(
        key: const ValueKey('showcase-save'), onPressed: disabled || !changed ? null : save,
        icon: Icon(saving ? Icons.hourglass_empty : Icons.check), label: Text(saving ? 'Хадгалж байна...' : 'Хадгалах · ${selected.length} нийтлэх')))),
      body: SafeArea(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.outline)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.shield_outlined, color: p.accentInk), const SizedBox(width: 8),
                Expanded(child: Text('${selected.length} / ${rows.length} нийтлэхээр сонгосон', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))]),
              const SizedBox(height: 8), Text('Бүх код анхдагчаар нууц. Шинээр бодсон бодлогыг автоматаар нийтлэхгүй.', style: TextStyle(color: p.muted)),
              if (previous.difference(rows.map((r) => r['id'] as int).toSet()).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Нийтлэх боломжгүй болсон бодолтын харагдацыг хадгалах үед цуцална.', style: TextStyle(color: p.muted))),
              const SizedBox(height: 12), LinearProgressIndicator(value: rows.isEmpty ? 0.0 : selected.length / rows.length),
              const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 6, children: [
                OutlinedButton(key: const ValueKey('showcase-share-all'), onPressed: disabled || rows.isEmpty ? null : () => setState(() => selected = rows.map((r) => r['id'] as int).toSet()), child: const Text('Бүгдийг харуулах')),
                TextButton(key: const ValueKey('showcase-hide-all'), onPressed: disabled || selected.isEmpty ? null : () => setState(() => selected = {}), child: const Text('Бүгдийг нуух')),
              ]),
            ])),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('showcase-search'), onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Бодлого эсвэл хэл хайх')),
            const SizedBox(height: 8), Wrap(spacing: 8, children: [for (final entry in {'all':'Бүгд', 'shared':'Харуулах', 'hidden':'Нуух'}.entries)
              ChoiceChip(key: ValueKey('showcase-filter-${entry.key}'), label: Text(entry.value), selected: filter == entry.key, onSelected: (_) => setState(() => filter = entry.key))]),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[Text(error!, style: TextStyle(color: p.negative)), TextButton(onPressed: disabled ? null : load, child: const Text('Дахин ачаалах'))],
            if (!loading && filtered.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Тохирох бодолт алга.')),
            const SizedBox(height: 12),
          ]);
          final r = filtered[i - 1], id = r['id'] as int;
          final checked = selected.contains(id);
          return Card(margin: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Expanded(child: CheckboxListTile(key: ValueKey('showcase-choice-$id'), contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              controlAffinity: ListTileControlAffinity.leading, value: checked, onChanged: disabled ? null : (v) => setState(() { if (v == true) { selected.add(id); } else { selected.remove(id); } }),
              title: Text('${r['title']}', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${judgeLabel(r['language'])} · ${checked ? 'Нийтлэх' : 'Нууц'}', style: TextStyle(color: checked ? p.positive : p.muted, fontSize: 12)))),
            IconButton(key: ValueKey('showcase-preview-$id'), tooltip: 'Код харах', onPressed: disabled ? null : () => openSolution(context, widget.userId, r), icon: const Icon(Icons.code)),
          ]));
        })));
  }
}

class SolutionCodeScreen extends StatefulWidget {
  const SolutionCodeScreen({super.key, required this.userId, required this.submissionId});
  final int userId, submissionId;
  @override State<SolutionCodeScreen> createState() => _SolutionCodeState();
}
class _SolutionCodeState extends State<SolutionCodeScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final token = PracticeApi.token;
    setState(() { loading = true; error = null; data = null; });
    try {
      final result = await PracticeApi.request('profile/public/${widget.userId}/solutions/${widget.submissionId}/');
      if (!mounted || token != PracticeApi.token) return;
      if (result['code'] is! String) throw const FormatException('Код олдсонгүй.');
      setState(() => data = result);
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override Widget build(BuildContext context) {
    final p = MandakhPalette.of(context), row = data;
    final raw = row?['code'] as String?;
    final language = row?['language']?.toString() ?? 'python';
    final code = raw?.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\t', '    ') ?? '';
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.55);
    return Scaffold(appBar: AppBar(title: const Text('Бодолтын код'), actions: [
      if (raw != null) IconButton(key: const ValueKey('showcase-copy'), tooltip: 'Код хуулах', icon: const Icon(Icons.copy), onPressed: () async {
        try { await Clipboard.setData(ClipboardData(text: raw)); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код хууллаа.'))); }
        catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код хуулж чадсангүй.'))); }
      }),
    ]), body: SafeArea(child: loading ? const Center(child: CircularProgressIndicator()) : row == null ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error ?? 'Код олдсонгүй.'), TextButton(onPressed: load, child: const Text('Дахин оролдох'))]))) : ListView(padding: const EdgeInsets.all(16), children: [
      Text('${row['title']}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 6, children: [Chip(avatar: Icon(Icons.check_circle_outline, color: p.positive, size: 18), label: const Text('Accepted')), Chip(label: Text(judgeLabel(language))), Chip(avatar: Icon(row['shared'] == true ? Icons.visibility_outlined : Icons.lock_outline, size: 16), label: Text(row['shared'] == true ? 'Нийтэлсэн' : 'Зөвхөн танд'))]),
      const SizedBox(height: 12), Container(decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.outline)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [Icon(Icons.description_outlined, size: 18, color: p.accentInk), const SizedBox(width: 8), Expanded(child: Text(judgeFiles[language] ?? 'solution', style: mono)), Text('${code.split('\n').length} мөр', style: TextStyle(color: p.muted, fontSize: 12))])),
        const Divider(height: 1), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(List.generate(code.split('\n').length, (i) => '${i + 1}'.padLeft(3)).join('\n'), style: mono.copyWith(color: p.muted)), const SizedBox(width: 16),
          SelectionArea(child: Text.rich(TextSpan(style: mono.copyWith(color: p.text), children: highlightSolution(code, language, p)), softWrap: false, key: const ValueKey('showcase-code'))),
        ]))),
      ])),
      const SizedBox(height: 10), Text('Энэ нь хэрэглэгчийн илгээсэн эх код юм.', style: TextStyle(color: p.muted)),
    ])));
  }
}

// Lightweight lexical highlighting only. Never execute, parse as HTML, or alter
// the original source that is returned by the API and copied to the clipboard.
List<TextSpan> highlightSolution(String code, String language, MandakhPalette p) {
  final python = language == 'python';
  final pattern = RegExp(python
    ? r'''#[^\n]*|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|\b(?:def|class|if|elif|else|for|while|return|import|from|in|not|and|or|True|False|None|print|input|range|len|int|str|try|except|break|continue|with|as)\b|\b\d+(?:\.\d+)?\b'''
    : r'''//[^\n]*|/\*[\s\S]*?\*/|#[^\n]*|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`|\b(?:int|long|double|float|char|bool|void|public|private|static|class|const|let|var|function|return|if|else|for|while|break|continue|new|import|include|using|namespace|true|false|null|String|auto|try|catch|async|await|console)\b|\b\d+(?:\.\d+)?\b''');
  final result = <TextSpan>[];
  var start = 0;
  for (final match in pattern.allMatches(code)) {
    if (match.start > start) result.add(TextSpan(text: code.substring(start, match.start)));
    final t = match.group(0)!;
    final color = t.startsWith('//') || t.startsWith('/*') || (python && t.startsWith('#')) ? p.muted
        : t.startsWith('"') || t.startsWith("'") || t.startsWith('`') ? p.positive
        : RegExp(r'^\d').hasMatch(t) ? p.readable(const Color(0xFFFFC66B)) : p.accentInk;
    result.add(TextSpan(text: t, style: TextStyle(color: color)));
    start = match.end;
  }
  if (start < code.length) result.add(TextSpan(text: code.substring(start)));
  return result;
}
