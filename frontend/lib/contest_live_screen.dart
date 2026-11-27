import 'dart:async';
import 'package:flutter/material.dart';
import 'data.dart';
import 'theme_settings.dart';
import 'practice_screen.dart';
import 'auth_screen.dart';

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];

class ContestLiveScreen extends StatefulWidget {
  const ContestLiveScreen({super.key, required this.contestId, required this.title});
  final int contestId;
  final String title;
  @override
  State<ContestLiveScreen> createState() => _ContestLiveState();
}

class _ContestLiveState extends State<ContestLiveScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  Timer? poll, clock;
  final elapsed = Stopwatch();
  DateTime? serverTime;
  String? loadedToken;
  int ticks = 0;

  @override
  void initState() {
    super.initState();
    load();
    poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      ticks++;
      if (data?['final'] != true || ticks % 3 == 0 || loadedToken != PracticeApi.token) load();
    });
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true && data?['final'] != true) setState(() {});
    });
  }

  @override
  void dispose() { poll?.cancel(); clock?.cancel(); elapsed.stop(); super.dispose(); }

  Future<void> load() async {
    if (busy || !mounted) return;
    busy = true;
    final token = PracticeApi.token;
    try {
      final result = await PracticeApi.request('contests/${widget.contestId}/live/');
      if (!mounted || token != PracticeApi.token) return;
      final timestamp = DateTime.tryParse('${result['server_time']}');
      if (timestamp == null || result['id'] != widget.contestId) throw const FormatException('Тэмцээний мэдээлэл буруу байна.');
      setState(() {
        data = result; error = null; loadedToken = token; serverTime = timestamp;
        elapsed..reset()..start();
      });
    } catch (e) {
      if (mounted && token == PracticeApi.token) setState(() => error = '$e');
    } finally { busy = false; }
  }

  Duration remaining(Map<String, dynamic> d) {
    final target = DateTime.tryParse('${d[d['status'] == 'Удахгүй' ? 'starts_at' : 'ends_at']}');
    if (target == null || serverTime == null) return Duration.zero;
    final left = target.difference(serverTime!.add(elapsed.elapsed));
    return left.isNegative ? Duration.zero : left;
  }

  String durationText(Duration d) {
    String two(int i) => i.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  Widget panel(Widget child) {
    final p = MandakhPalette.of(context);
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(
      color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.outline)),
      child: Material(type: MaterialType.transparency, child: child));
  }

  Future<void> openTask(Map<String, dynamic> p, {required bool review}) async {
    final token = PracticeApi.token;
    if (token == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PracticeScreen(
      problem: {...p, 'description': p['statement']}, contestId: widget.contestId, contestReview: review)));
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final d = data;
    return Scaffold(appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis), actions: [
      IconButton(onPressed: load, icon: const Icon(Icons.refresh), tooltip: 'Шинэчлэх')]),
      body: SafeArea(child: d == null ? Center(child: error == null ? const CircularProgressIndicator() : Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(error!)), TextButton(onPressed: load, child: const Text('Дахин оролдох'))])) :
      SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1050), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 4, children: [Chip(avatar: Icon(Icons.bolt, size: 17, color: p.accentInk), label: const Text('Автомат шүүлт')), Chip(label: Text('${d['status']}'))]),
          const SizedBox(height: 8), Text('${d['title']}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          if ('${d['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${d['description']}')),
          if ('${d['announcement'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${d['announcement']}')),
          const SizedBox(height: 14),
          if (d['status'] != 'Дууссан') ...[
            Text(d['status'] == 'Удахгүй' ? 'Эхлэх хүртэл' : 'Үлдсэн хугацаа', style: TextStyle(color: p.muted)),
            Text(durationText(remaining(d)), key: const ValueKey('contest-countdown'), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: p.accentInk, fontFamily: 'monospace')),
          ] else Text(d['final'] == true ? 'Эцсийн дүн' : 'Хугацаа дууссан · Шүүлт үргэлжилж байна', style: TextStyle(color: p.accentInk, fontWeight: FontWeight.bold)),
          Text('Шалгах илгээлт: ${d['pending'] ?? 0}', style: TextStyle(color: p.muted)),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Холболт: $error', style: TextStyle(color: p.negative))),
          if (d['judge_ready'] != true) const Text('Шүүгчийн тохиргоо идэвхгүй байна.'),
          if (PracticeApi.token == null) Padding(padding: const EdgeInsets.only(top: 12), child: FilledButton.icon(onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => const AuthScreen()));
            if (mounted) await load();
          }, icon: const Icon(Icons.login), label: const Text('Нэвтрэх / Бүртгүүлэх'))),
        ])),
        const SizedBox(height: 20), const Text('Бодлогууд', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), const SizedBox(height: 10),
        if (_rows(d['problems']).isEmpty) panel(const Text('Бодлогууд тэмцээн эхлэхэд нээгдэнэ.')),
        for (final task in _rows(d['problems'])) Padding(padding: const EdgeInsets.only(bottom: 8), child: panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [CircleAvatar(child: Text('${task['label']}')), const SizedBox(width: 12), Expanded(child: Text('${task['title']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))), Text('${task['points']} оноо')]),
          ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Нөхцөл, жишээ'), children: [Align(alignment: Alignment.centerLeft, child: SelectableText('${task['statement']}')), const SizedBox(height: 10), Align(alignment: Alignment.centerLeft, child: SelectableText('Оролт:\n${task['input']}\n\nГаралт:\n${task['output']}'))]),
          if (PracticeApi.token != null && loadedToken == PracticeApi.token) Align(alignment: Alignment.centerRight, child: FilledButton.icon(
            key: ValueKey('contest-task-${task['id']}'), onPressed: () => openTask(task, review: d['can_submit'] != true || remaining(d) == Duration.zero || error != null),
            icon: Icon(d['can_submit'] == true && remaining(d) > Duration.zero && error == null ? Icons.code : Icons.history),
            label: Text(d['can_submit'] == true && remaining(d) > Duration.zero && error == null ? 'Бодлого бодох' : 'Миний илгээлтүүд'))),
        ]))),
        const SizedBox(height: 20), const Text('Дүнгийн хүснэгт', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        Text('Бүрэн зөв бодолтод бүтэн оноо. Оноо тэнцвэл торгууль бага нь түрүүлнэ. Зөв хариунаас өмнөх буруу илгээлт бүр +20 минут.', style: TextStyle(color: p.muted)),
        const SizedBox(height: 10),
        if (_rows(d['standings']).isEmpty) panel(const Text('Одоогоор илгээлт алга.')),
        if (_rows(d['standings']).isNotEmpty) panel(SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columnSpacing: 18,
          columns: [const DataColumn(label: Text('#')), const DataColumn(label: Text('Оролцогч')), for (final task in _rows(d['problems'])) DataColumn(label: Text('${task['label']}')), const DataColumn(label: Text('Оноо'), numeric: true), const DataColumn(label: Text('Торгууль'), numeric: true)],
          rows: [for (final row in _rows(d['standings'])) DataRow(cells: [DataCell(Text('${row['rank']}')), DataCell(Text('${row['participant']}')), for (final task in _rows(d['problems'])) DataCell(_taskMark(row, task, p)), DataCell(Text('${row['score']}')), DataCell(Text('${row['penalty']}'))])],
        ))),
        const SizedBox(height: 20), Text('Дүн 5 секунд тутам шинэчлэгдэнэ. Тэмцээний код нь дадлагын оноо, нийтлэх бодолтод нэмэгдэхгүй.', style: TextStyle(color: p.muted)),
      ]))))));
  }

  Widget _taskMark(Map<String, dynamic> row, Map<String, dynamic> task, MandakhPalette p) {
    final value = row['tasks'] is Map ? (row['tasks'] as Map)['${task['id']}'] : null;
    if (value is! Map) return const Text('—');
    final solved = value['solved'] == true, pending = (value['pending'] as num? ?? 0) > 0;
    return Text(solved ? '+${task['points']}' : pending ? '…' : '−${value['attempts']}', style: TextStyle(color: solved ? p.positive : pending ? p.accentInk : p.muted, fontWeight: FontWeight.w700));
  }
}
