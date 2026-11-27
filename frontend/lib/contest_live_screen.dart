import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'data.dart';
import 'theme_settings.dart';
import 'practice_screen.dart';
import 'auth_screen.dart';

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
int _int(Object? value) => value is int ? value : 0;
Map<String, dynamic> _map(Object? value) => value is Map
    ? Map<String, dynamic>.from(value) : <String, dynamic>{};

// Semantic states, not just colors: solved always wins over later retries.
String contestTaskState(Map<String, dynamic> task) {
  if (task['solved'] == true) return 'solved';
  if (_int(task['pending']) > 0) return 'pending';
  if (task['latest_status'] == 'Judge Error') return 'judge-error';
  if (_int(task['attempts']) > 0) return 'incorrect';
  return 'unsolved';
}

// Ensure foreground contrast on actual tinted surfaces, including custom themes.
Color _ink(Color candidate, Color background, MandakhPalette p) {
  final fallback = MandakhPalette.contrast(Colors.black, background) >=
          MandakhPalette.contrast(Colors.white, background) ? Colors.black : Colors.white;
  for (final target in [p.text, fallback]) {
    for (var i = 0; i <= 20; i++) {
      final c = Color.lerp(candidate, target, i / 20)!;
      if (MandakhPalette.contrast(c, background) >= 4.5) return c;
    }
  }
  return fallback;
}

Color _tone(MandakhPalette p, String state) => switch (state) {
  'solved' => const Color(0xFF36B98A),
  'pending' => const Color(0xFFE7B342),
  'incorrect' => const Color(0xFFE36B78),
  'judge-error' => const Color(0xFFE7B342),
  _ => p.muted,
};
String _stateLabel(String state) => switch (state) {
  'solved' => 'Бодсон', 'pending' => 'Шалгаж байна',
  'incorrect' => 'Буруу илгээлт', 'judge-error' => 'Шүүгчийн алдаа',
  _ => 'Бодоогүй',
};
IconData _stateIcon(String state) => switch (state) {
  'solved' => Icons.check_circle_outline, 'pending' => Icons.hourglass_top,
  'incorrect' => Icons.cancel_outlined, 'judge-error' => Icons.warning_amber_rounded,
  _ => Icons.radio_button_unchecked,
};

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
  final scoreboardScroll = ScrollController();
  final expandedTasks = <int>{};
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
  void dispose() { poll?.cancel(); clock?.cancel(); elapsed.stop(); scoreboardScroll.dispose(); super.dispose(); }

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

  bool get identityCurrent => PracticeApi.token != null && loadedToken == PracticeApi.token;
  int? viewer(Map<String, dynamic> d) => identityCurrent && d['viewer_id'] is int ? d['viewer_id'] as int : null;
  bool canSubmit(Map<String, dynamic> d) => identityCurrent && d['status'] == 'Явагдаж байна' &&
      d['can_submit'] == true && remaining(d) > Duration.zero && error == null;

  Widget panel(Widget child, {Color? color, Color? border, EdgeInsets padding = const EdgeInsets.all(16)}) {
    final p = MandakhPalette.of(context);
    return Container(width: double.infinity, padding: padding, decoration: BoxDecoration(
      color: color ?? p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border ?? p.outline)),
      child: Material(type: MaterialType.transparency, child: child));
  }

  Future<void> openTask(Map<String, dynamic> p, {required bool review}) async {
    if (!identityCurrent) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PracticeScreen(
      problem: {...p, 'description': p['statement']}, contestId: widget.contestId, contestReview: review)));
    if (mounted) await load();
  }

  Widget pill(String label, IconData icon, Color tone, Color bg) {
    final p = MandakhPalette.of(context);
    final fill = Color.lerp(bg, tone, .10)!;
    final ink = _ink(tone, fill, p);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(
      color: fill, borderRadius: BorderRadius.circular(8), border: Border.all(color: Color.lerp(bg, tone, .36)!)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: ink, size: 15), const SizedBox(width: 5),
        Flexible(child: Text(label, style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)))]));
  }

  Widget banner(Map<String, dynamic> d) {
    final p = MandakhPalette.of(context);
    final active = d['status'] == 'Явагдаж байна' && remaining(d) > Duration.zero;
    final ended = d['status'] == 'Дууссан';
    final upcoming = d['status'] == 'Удахгүй';
    final stateColor = active ? _tone(p, 'solved') : ended && d['final'] == true ? p.accentInk : _tone(p, 'pending');
    final surface = Color.lerp(p.surface, p.accent, .075)!;
    final timerBg = Color.lerp(p.background, p.accent, .08)!;
    final ink = _ink(p.text, surface, p), accent = _ink(p.accent, surface, p);
    final caption = _ink(p.muted, surface, p);
    final clockInk = _ink(p.accent, timerBg, p);
    final timeLabel = upcoming ? 'ЭХЛЭХ ХҮРТЭЛ' : 'ҮЛДСЭН ХУГАЦАА';
    final statusLabel = ended ? '${d['status']}' : remaining(d) == Duration.zero ? 'Төлөв шинэчилж байна' : '${d['status']}';
    return panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Icon(Icons.emoji_events_outlined, color: _ink(const Color(0xFFD6A449), surface, p), size: 26),
        Text('MANDAKHRANK COMPETITIVE', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        pill(statusLabel, active ? Icons.play_circle_outline : ended ? Icons.flag_outlined : Icons.schedule, stateColor, surface),
        pill('Автомат шүүлт', Icons.bolt, p.accent, surface),
      ]),
      const SizedBox(height: 16),
      Text('${d['title']}', style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w900, height: 1.2)),
      if ('${d['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${d['description']}', style: TextStyle(color: caption, height: 1.5))),
      if ('${d['announcement'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${d['announcement']}', style: TextStyle(color: ink, height: 1.5))),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12), decoration: BoxDecoration(
        color: timerBg, border: Border.all(color: Color.lerp(timerBg, p.accent, .35)!), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          if (!ended) ...[
            Text(timeLabel, style: TextStyle(color: _ink(p.muted, timerBg, p), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, child: Text(durationText(remaining(d)), key: const ValueKey('contest-countdown'),
              style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: clockInk, fontFamily: 'monospace', fontFeatures: const [FontFeature.tabularFigures()]))),
          ] else ...[
            Icon(d['final'] == true ? Icons.emoji_events_outlined : Icons.hourglass_top, color: clockInk, size: 32),
            const SizedBox(height: 8), Text(d['final'] == true ? 'Эцсийн дүн' : 'Хугацаа дууссан · Шүүлт үргэлжилж байна',
              textAlign: TextAlign.center, style: TextStyle(color: clockInk, fontSize: 22, fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 8), Text('Шалгах илгээлт: ${d['pending'] ?? 0}', style: TextStyle(color: _ink(p.muted, timerBg, p))),
        ])),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Шинэчилж чадсангүй. Сүүлийн амжилттай мэдээлэл: $error', style: TextStyle(color: _ink(p.negative, surface, p)))),
      if (d['judge_ready'] != true) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Шүүгчийн тохиргоо идэвхгүй байна.', style: TextStyle(color: ink))),
      if (PracticeApi.token == null) Padding(padding: const EdgeInsets.only(top: 12), child: FilledButton.icon(onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => const AuthScreen()));
        if (mounted) await load();
      }, icon: const Icon(Icons.login), label: const Text('Нэвтрэх / Бүртгүүлэх'))),
    ]), color: surface, border: Color.lerp(surface, p.accent, .30), padding: const EdgeInsets.all(18));
  }

  Widget stats(Map<String, dynamic> own, List<Map<String, dynamic>> tasks) {
    final p = MandakhPalette.of(context);
    final metrics = <(String, String, IconData, Color)>[
      ('Бодсон', '${_int(own['solved'])}/${tasks.length}', Icons.check_circle_outline, p.positive),
      ('Миний оноо', '${_int(own['score'])}', Icons.stars_outlined, p.accentInk),
      ('Торгууль (мин)', '${_int(own['penalty'])}', Icons.timer_outlined, p.readable(const Color(0xFFE7B342))),
      ('Миний байр', own['rank'] is int ? '#${own['rank']}' : '—', Icons.leaderboard_outlined, p.accentInk),
    ];
    return LayoutBuilder(builder: (context, b) {
      final columns = b.maxWidth >= 660 ? 4 : b.maxWidth >= 270 ? 2 : 1;
      final width = (b.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < metrics.length; i++) SizedBox(width: width, child: panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(metrics[i].$3, color: metrics[i].$4, size: 21), const SizedBox(height: 6),
          Text(metrics[i].$2, key: ValueKey('contest-metric-$i'), style: TextStyle(color: metrics[i].$4, fontWeight: FontWeight.w900, fontSize: 25)),
          Text(metrics[i].$1, style: TextStyle(color: p.muted, fontSize: 12)),
        ]), padding: const EdgeInsets.all(12))),
      ]);
    });
  }

  Future<void> copyExample(String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Хууллаа.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Хуулж чадсангүй.')));
    }
  }

  Widget exampleBox(String label, String value, String key, Color cardColor) {
    final p = MandakhPalette.of(context);
    final bg = Color.lerp(cardColor, p.background, .55)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.outline)),
      child: Material(type: MaterialType.transparency, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: _ink(p.muted, bg, p), fontWeight: FontWeight.w700, fontSize: 13))),
            IconButton(onPressed: () => copyExample(value), tooltip: '$label хуулах',
              icon: Icon(Icons.copy_outlined, color: _ink(p.accent, bg, p), size: 18)),
          ]),
          Text(value, key: ValueKey(key), softWrap: true,
            style: TextStyle(color: _ink(p.text, bg, p), fontFamily: 'monospace', fontSize: 14, height: 1.5)),
        ],
      )),
    );
  }

  Widget taskDetails(Map<String, dynamic> task, Color fill, Color text) {
    final p = MandakhPalette.of(context);
    final id = _int(task['id']);
    final open = expandedTasks.contains(id);
    final statement = task['statement']?.toString() ?? '';
    final input = task['input']?.toString() ?? '';
    final output = task['output']?.toString() ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      Divider(height: 1, color: p.outline),
      TextButton(
        key: ValueKey('contest-example-$id'),
        style: TextButton.styleFrom(foregroundColor: text, padding: const EdgeInsets.symmetric(vertical: 8)),
        onPressed: () => setState(() {
          if (open) { expandedTasks.remove(id); } else { expandedTasks.add(id); }
        }),
        child: Row(children: [
          const Expanded(child: Text('Нөхцөл, жишээ', style: TextStyle(fontWeight: FontWeight.w700))),
          Icon(open ? Icons.expand_less : Icons.expand_more, color: _ink(p.accent, fill, p)),
        ]),
      ),
      if (open) Padding(
        key: ValueKey('contest-details-$id'),
        padding: const EdgeInsets.only(top: 4, bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Бодлогын нөхцөл', style: TextStyle(color: _ink(p.muted, fill, p), fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Text(statement, key: ValueKey('contest-statement-$id'), softWrap: true,
            style: TextStyle(color: text, fontSize: 15, height: 1.6)),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, bounds) {
            final a = exampleBox('Жишээ оролт', input, 'contest-input-$id', fill);
            final b = exampleBox('Жишээ гаралт', output, 'contest-output-$id', fill);
            if (bounds.maxWidth >= 600) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 10), b]);
          }),
        ]),
      ),
    ]);
  }

  Widget taskCard(Map<String, dynamic> d, Map<String, dynamic> task, Map<String, dynamic> ownTasks, bool personal) {
    final p = MandakhPalette.of(context);
    final state = contestTaskState(_map(ownTasks['${task['id']}']));
    final tone = _tone(p, state);
    final fill = Color.lerp(p.surface, tone, state == 'unsolved' || !personal ? .025 : .07)!;
    final ink = _ink(tone, fill, p);
    final text = _ink(p.text, fill, p);
    final badgeBg = Color.lerp(fill, tone, .13)!;
    final submitting = canSubmit(d);
    final progress = _map(ownTasks['${task['id']}']);
    return panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(11)),
          child: Text('${task['label']}', style: TextStyle(color: _ink(tone, badgeBg, p), fontSize: 20, fontWeight: FontWeight.w900))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${task['title']}', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5), Wrap(spacing: 10, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (personal) Row(mainAxisSize: MainAxisSize.min, children: [Icon(_stateIcon(state), color: ink, size: 16), const SizedBox(width: 5),
              Flexible(child: Text(_stateLabel(state), key: ValueKey('contest-state-${task['id']}'), style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)))]),
            Text('${task['points']} оноо', style: TextStyle(color: _ink(p.text, fill, p), fontSize: 13, fontWeight: FontWeight.w700)),
            if (personal && _int(progress['attempts']) > 0) Text('${progress['attempts']} илгээлт', style: TextStyle(color: _ink(p.muted, fill, p), fontSize: 12)),
          ]),
        ])),
      ]),
      taskDetails(task, fill, text),
      if (identityCurrent) Align(alignment: Alignment.centerRight, child: FilledButton.icon(
        key: ValueKey('contest-task-${task['id']}'), onPressed: () => openTask(task, review: !canSubmit(d)),
        icon: Icon(submitting ? Icons.code : Icons.history), label: Text(submitting ? 'Бодлого бодох' : 'Миний илгээлтүүд'))),
    ]), color: fill, border: Color.lerp(p.outline, tone, personal && state != 'unsolved' ? .65 : .15));
  }

  Widget rankMark(Map<String, dynamic> row, Color bg) {
    final p = MandakhPalette.of(context);
    final rank = _int(row['rank']);
    final medal = _int(row['score']) > 0 && rank >= 1 && rank <= 3;
    final color = _ink(!medal ? p.muted : switch (rank) {1 => const Color(0xFFD6A449), 2 => const Color(0xFF9CAEC7), _ => const Color(0xFFC08456)}, bg, p);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (medal) ...[Icon(Icons.emoji_events_outlined, size: 17, color: color), const SizedBox(width: 4)],
      Text('#$rank', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
    ]);
  }

  Widget taskMark(Map<String, dynamic> row, Map<String, dynamic> task, Color bg) {
    final p = MandakhPalette.of(context);
    final value = _map(_map(row['tasks'])['${task['id']}']);
    final state = contestTaskState(value);
    final tone = _tone(p, state);
    final fill = Color.lerp(bg, tone, state == 'unsolved' ? .02 : .12)!;
    final label = switch (state) {
      'solved' => '+${task['points']}', 'pending' => '…', 'incorrect' => '−${value['attempts']}', 'judge-error' => '!', _ => '—',
    };
    return Tooltip(message: '${task['label']}: ${_stateLabel(state)}', child: Container(
      constraints: const BoxConstraints(minWidth: 36), alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: _ink(tone, fill, p), fontWeight: FontWeight.w800, fontSize: 12))));
  }

  Widget leaderboard(List<Map<String, dynamic>> rows, List<Map<String, dynamic>> tasks, int? viewerId) {
    final p = MandakhPalette.of(context);
    if (rows.isEmpty) return panel(const Text('Одоогоор илгээлт алга.'));
    return panel(LayoutBuilder(builder: (context, constraints) {
      final tableWidth = constraints.maxWidth;
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0).toDouble();
      final minWidth = (420.0 + 62.0 * tasks.length) * scale;
      final width = tableWidth > minWidth ? tableWidth : minWidth;
      final ownBg = Color.lerp(p.surface, p.accent, .12)!;
      return Scrollbar(controller: scoreboardScroll, thumbVisibility: width > tableWidth,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(controller: scoreboardScroll, scrollDirection: Axis.horizontal, key: const ValueKey('contest-scoreboard-scroll'),
        child: SizedBox(width: width, child: DataTable(
          key: const ValueKey('contest-scoreboard'), horizontalMargin: 12, columnSpacing: 12,
          dataRowMinHeight: 52 * scale, dataRowMaxHeight: 72 * scale, headingRowHeight: 56 * scale,
          headingRowColor: WidgetStatePropertyAll(p.background),
          headingTextStyle: TextStyle(color: _ink(p.text, p.background, p), fontWeight: FontWeight.w800, fontSize: 12),
          columns: [const DataColumn(label: Text('#')), const DataColumn(label: Text('Оролцогч')),
            for (final task in tasks) DataColumn(label: Text('${task['label']}')), const DataColumn(label: Text('Оноо'), numeric: true), const DataColumn(label: Text('Мин'), numeric: true)],
          rows: [for (final row in rows) _scoreRow(row, tasks, viewerId, ownBg)],
        ))));
    }), padding: const EdgeInsets.all(8));
  }

  DataRow _scoreRow(Map<String, dynamic> row, List<Map<String, dynamic>> tasks, int? viewerId, Color ownBg) {
    final p = MandakhPalette.of(context);
    final mine = viewerId != null && row['user_id'] == viewerId;
    final bg = mine ? ownBg : p.surface;
    final text = _ink(p.text, bg, p);
    return DataRow(key: ValueKey('contest-row-${row['user_id']}'), color: WidgetStatePropertyAll(bg), cells: [
      DataCell(rankMark(row, bg)),
      DataCell(ConstrainedBox(constraints: const BoxConstraints(minWidth: 90, maxWidth: 180), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${row['participant']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w700)),
        if (mine) Text('Та', key: const ValueKey('contest-own-row'), style: TextStyle(color: _ink(p.accent, bg, p), fontSize: 11, fontWeight: FontWeight.w800)),
      ]))),
      for (final task in tasks) DataCell(taskMark(row, task, bg)),
      DataCell(Text('${row['score']}', style: TextStyle(color: _ink(p.accent, bg, p), fontWeight: FontWeight.w900))),
      DataCell(Text('${row['penalty']}', style: TextStyle(color: text))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final d = data;
    if (d == null) return Scaffold(appBar: AppBar(title: Text(widget.title)), body: Center(child: error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Дахин оролдох'))]))));
    final tasks = _rows(d['problems']);
    final rows = _rows(d['standings']);
    final viewerId = viewer(d);
    final own = <String, dynamic>{};
    if (viewerId != null) {
      for (final row in rows) { if (row['user_id'] == viewerId) { own.addAll(row); break; } }
    }
    final personal = viewerId != null && (d['viewer_is_student'] == true || own.isNotEmpty);
    final ownTasks = _map(own['tasks']);
    return Scaffold(appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh), tooltip: 'Шинэчлэх')]),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          banner(d),
          if (personal && d['status'] != 'Удахгүй') ...[const SizedBox(height: 16), stats(own, tasks)],
          const SizedBox(height: 24),
          Row(children: [const Expanded(child: Text('Бодлогууд', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))), Text('${tasks.length} бодлого', style: TextStyle(color: p.muted))]),
          const SizedBox(height: 10),
          if (tasks.isEmpty) panel(const Text('Бодлогууд тэмцээн эхлэхэд нээгдэнэ.')),
          for (final task in tasks) Padding(key: ValueKey('contest-card-${task['id']}'), padding: const EdgeInsets.only(bottom: 10), child: taskCard(d, task, ownTasks, personal)),
          const SizedBox(height: 20),
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 6, children: [
            const Text('Дүнгийн хүснэгт', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(d['final'] == true ? 'Эцсийн дүн' : '5 секунд тутам шинэчлэгдэнэ', style: TextStyle(color: p.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 6), Text('${rows.length} оролцогч · Оноо их, торгууль бага нь түрүүлнэ. Зөв бодолтын өмнөх торгуультай илгээлт бүр +20 минут.', style: TextStyle(color: p.muted)),
          const SizedBox(height: 10), leaderboard(rows, tasks, viewerId),
          const SizedBox(height: 18), Text('Тэмцээний код нь дадлагын оноо, нийтлэх бодолтод нэмэгдэхгүй.', style: TextStyle(color: p.muted)),
        ]))))));
  }
}
