import 'dart:async';
import 'package:flutter/material.dart';
import 'data.dart';
import 'theme_settings.dart';
import 'learning_screen.dart';
import 'contest_live_screen.dart';
import 'practice_screen.dart';

List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
String _str(Object? v) => v?.toString() ?? '';
String _date(Object? v) {
  final date = DateTime.tryParse(_str(v))?.toUtc().add(const Duration(hours: 8));
  if (date == null) return '';
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${date.year}.${pad(date.month)}.${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)} (УБ)';
}

/// Stale responses never update another account. Never store tokens in widget keys.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.token});
  final String token;
  @override State<NotificationBell> createState() => _NotificationBellState();
}
class _NotificationBellState extends State<NotificationBell> {
  int? unread;
  bool busy = false;
  Timer? timer;
  @override void initState() {
    super.initState();
    // Delay initial polling until after this frame, so existing layout is never blocked.
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) refresh(); });
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) refresh();
    });
  }
  @override void didUpdateWidget(covariant NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      unread = null;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) refresh(); });
    }
  }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  Future<void> refresh() async {
    if (!mounted || busy || PracticeApi.token != widget.token) return;
    busy = true;
    final token = widget.token;
    try {
      final r = await PracticeApi.request('notifications/?summary=1');
      if (mounted && token == widget.token && PracticeApi.token == token) setState(() => unread = r['unread'] is int ? r['unread'] as int : null);
    } catch (_) {
      if (mounted && token == widget.token && PracticeApi.token == token) setState(() => unread = null);
    } finally {
      busy = false;
      if (mounted && token != widget.token && PracticeApi.token == widget.token) unawaited(refresh());
    }
  }
  @override Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final count = PracticeApi.token == widget.token ? unread : null;
    return IconButton(key: const ValueKey('notification-bell'),
      tooltip: count == null ? 'Мэдэгдэл' : 'Мэдэгдэл · $count уншаагүй',
      onPressed: () async {
        if (PracticeApi.token != widget.token) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NotificationScreen(token: widget.token)));
        if (mounted) await refresh();
      }, icon: Badge(isLabelVisible: (count ?? 0) > 0, backgroundColor: p.button, textColor: p.onButton,
        label: Text((count ?? 0) > 99 ? '99+' : '${count ?? 0}'), child: const Icon(Icons.notifications_outlined, size: 21)));
  }
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, required this.token});
  final String token;
  @override State<NotificationScreen> createState() => _NotificationScreenState();
}
class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> items = [];
  bool loaded = false, busy = false;
  String? error;
  String filter = 'all';
  Timer? timer;
  bool get valid => mounted && PracticeApi.token == widget.token;
  @override void initState() {
    super.initState(); load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted && ModalRoute.of(context)?.isCurrent == true) load(); });
  }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  Future<void> load({Map<String, dynamic>? body}) async {
    if (!valid || busy) return;
    setState(() { busy = true; error = null; });
    try {
      final r = await PracticeApi.request('notifications/', body: body);
      if (!valid) return;
      if (r['results'] is! List) throw const FormatException('Мэдэгдлийн мэдээлэл буруу байна.');
      setState(() { items = _rows(r['results']); loaded = true; });
    } catch (e) { if (valid) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> mark(List<String> ids, bool read) async {
    if (ids.isEmpty) return;
    await load(body: {'action': read ? 'read' : 'unread', 'ids': ids});
  }
  Future<void> open(Map<String, dynamic> item) async {
    if (!valid || busy || item['target_id'] is! int) return;
    final id = item['target_id'] as int;
    final target = item['target'];
    Widget? route;
    if (target == 'classroom') route = ClassroomDetailScreen(classroomId: id);
    if (target == 'contest') route = ContestLiveScreen(contestId: id, title: _str(item['target_title']));
    if (target == 'problem') {
      setState(() => busy = true);
      try {
        final problem = await PracticeApi.request('problems/$id/');
        if (!valid) return;
        route = PracticeScreen(problem: problem);
      } catch (e) { if (valid) setState(() => error = '$e'); }
      finally { if (mounted) setState(() => busy = false); }
    }
    if (!valid || route == null) return;
    final destination = route;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => destination));
    if (valid) await load();
  }
  IconData icon(Map<String,dynamic> n) => switch(n['kind']) {
    'announcement' => Icons.campaign_outlined, 'assignment' => Icons.assignment_outlined,
    'contest' => Icons.emoji_events_outlined, _ => n['verdict']=='Accepted' ? Icons.check_circle_outline : Icons.code_outlined,
  };
  Widget card(Map<String,dynamic> n) {
    final p = MandakhPalette.of(context), isRead = n['read'] == true;
    final tone = n['verdict'] == 'Accepted' ? p.positive : n['kind'] == 'verdict' && n['verdict'] != null ? p.negative : p.accentInk;
    return Container(key: ValueKey('notice-${n['id']}'), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surface, border: Border.all(color: isRead ? p.outline : p.accentInk), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(10)), child: Icon(icon(n), color: tone)),
          const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_str(n['title']), style: TextStyle(fontSize: 16, fontWeight: isRead ? FontWeight.w600 : FontWeight.w800)),
            const SizedBox(height: 4), Text(_date(n['at']), style: TextStyle(color: p.muted, fontSize: 12)),
          ])), if (!isRead) Padding(padding: const EdgeInsets.only(left: 6, top: 6), child: Icon(Icons.circle, size: 9, color: p.accentInk)),
        ]), const SizedBox(height: 10), Text(_str(n['body']), style: const TextStyle(height: 1.5)),
        const SizedBox(height: 6), Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.end, children: [
          TextButton.icon(key: ValueKey('notice-mark-${n['id']}'), onPressed: busy ? null : () => mark([_str(n['id'])], !isRead),
            icon: Icon(isRead ? Icons.mark_email_unread_outlined : Icons.done, size: 18), label: Text(isRead ? 'Уншаагүй болгох' : 'Уншсан болгох')),
          if (n['target_id'] is int && ['classroom','contest','problem'].contains(n['target'])) OutlinedButton.icon(onPressed: busy ? null : () => open(n), icon: const Icon(Icons.arrow_forward, size: 16), label: const Text('Нээх')),
        ]),
      ]));
  }
  @override Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    if (!valid) return Scaffold(appBar: AppBar(title: const Text('Мэдэгдэл')), body: const Center(child: Text('Дахин нэвтэрнэ үү.')));
    final unread = items.where((n) => n['read'] != true).toList();
    final shown = items.where((n) => filter == 'all' || (filter == 'unread' ? n['read'] != true : n['kind'] == filter)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Мэдэгдэл'), actions: [IconButton(onPressed: busy ? null : () => load(), icon: const Icon(Icons.refresh), tooltip: 'Шинэчлэх')]),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: RefreshIndicator(onRefresh: () => load(), child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: p.surface, border: Border.all(color: p.outline), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('МЭДЭГДЛИЙН ТӨВ', style: TextStyle(color: p.accentInk, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 11)),
            const SizedBox(height: 8), Text('${unread.length} уншаагүй', key: const ValueKey('notice-unread-count'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6), Text('Сүүлийн 30 хоногийн хамгийн шинэ 100 мэдэгдэл.', style: TextStyle(color: p.muted)),
            const SizedBox(height: 12), OutlinedButton.icon(key: const ValueKey('notice-read-all'), onPressed: busy || unread.isEmpty ? null : () => mark(unread.map((n)=>_str(n['id'])).toList(), true), icon: const Icon(Icons.done_all), label: const Text('Бүгдийг уншсан болгох')),
          ])), const SizedBox(height: 14),
          Wrap(spacing: 7, runSpacing: 6, children: [for (final pair in const [('all','Бүгд'),('unread','Уншаагүй'),('announcement','Зарлал'),('assignment','Даалгавар'),('contest','Тэмцээн'),('verdict','Шүүлтийн дүн')]) ChoiceChip(label: Text(pair.$2), selected: filter == pair.$1, onSelected: (_) => setState(() => filter = pair.$1))]),
          const SizedBox(height: 12), if (busy) const LinearProgressIndicator(minHeight: 2),
          if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!, style: TextStyle(color: p.negative))),
          if (loaded && shown.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Мэдэгдэл байхгүй.'))),
          for (final n in shown) card(n),
        ]))))));
  }
}

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key, required this.token});
  final String token;
  @override State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}
class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final title = TextEditingController(), body = TextEditingController();
  Map<String,dynamic>? data;
  bool busy = false;
  String? error, audience;
  bool get valid => mounted && PracticeApi.token == widget.token;
  @override void initState() { super.initState(); request(); }
  @override void dispose() { title.dispose(); body.dispose(); super.dispose(); }
  Future<bool> request({Map<String,dynamic>? action}) async {
    if (!valid || busy) return false;
    setState(() { busy = true; error = null; });
    try {
      final r = await PracticeApi.request('announcements/', body: action);
      if (!valid) return false;
      setState(() {
        data = r;
        final ids = choices.map((e) => e.$1).toList();
        if (!ids.contains(audience)) audience = null;
      });
      return true;
    } catch (e) { if (valid) setState(() => error = '$e'); return false; }
    finally { if (mounted) setState(() => busy = false); }
  }
  List<(String,String)> get choices => [
    if (data?['global_allowed'] == true) ('global','Бүх хэрэглэгч'),
    for (final c in _rows(data?['classrooms'])) ('${c['id']}',_str(c['name'])),
  ];
  Future<bool> confirm(String question, String description) async => await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(question), content: Text(description), actions: [TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('Болих')), FilledButton(onPressed: () => Navigator.pop(ctx,true), child: const Text('Батлах'))])) ?? false;
  Future<void> publish() async {
    if (busy || !valid || audience == null || title.text.trim().isEmpty || body.text.trim().isEmpty) return;
    final dest = audience!;
    final name = choices.firstWhere((e)=>e.$1==dest).$2;
    final t = title.text.trim(), b = body.text.trim();
    if (!await confirm('Зарлал нийтлэх үү?', 'Хүлээн авагч: $name\n\n$t')) return;
    if (!valid) return;
    if (await request(action: {'action':'publish','classroom_id':dest=='global'?null:int.parse(dest),'title':t,'body':b}) && valid) {
      title.clear(); body.clear(); setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Зарлал нийтлэгдлээ.')));
    }
  }
  @override Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    if (!valid) return Scaffold(appBar: AppBar(title: const Text('Зарлал')), body: const Center(child: Text('Дахин нэвтэрнэ үү.')));
    return Scaffold(appBar: AppBar(title: const Text('Зарлал удирдах'), actions: [IconButton(onPressed: busy ? null : () => request(), icon: const Icon(Icons.refresh), tooltip: 'Шинэчлэх')]),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: ListView(padding: const EdgeInsets.all(16), children: [
        if (busy) const LinearProgressIndicator(minHeight: 2), if (error != null) Text(error!, style: TextStyle(color:p.negative)),
        if (data != null) ...[
          const Text('Шинэ зарлал', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
          Text('Өөрийн ангийн суралцагчдад зарлал илгээнэ. Нийтэд зарлах эрх зөвхөн админд байна.', style: TextStyle(color:p.muted)), const SizedBox(height: 14),
          if (choices.isEmpty) const Text('Идэвхтэй анги байхгүй.'),
          DropdownButtonFormField<String>(key: ValueKey('notice-audience-$audience'), initialValue: audience, isExpanded: true, decoration: const InputDecoration(labelText: 'Хүлээн авагч'), items: [for (final e in choices) DropdownMenuItem(value: e.$1, child: Text(e.$2, overflow: TextOverflow.ellipsis))], onChanged: busy ? null : (v)=>setState(()=>audience=v)),
          const SizedBox(height: 12), TextField(key: const ValueKey('notice-title'), controller: title, maxLength: 120, enabled: !busy, onChanged: (_)=>setState((){}), decoration: const InputDecoration(labelText: 'Гарчиг')),
          TextField(key: const ValueKey('notice-body'), controller: body, maxLength: 2000, minLines: 3, maxLines: 8, enabled: !busy, onChanged: (_)=>setState((){}), decoration: const InputDecoration(labelText: 'Зарлалын агуулга')),
          FilledButton.icon(key: const ValueKey('notice-publish'), onPressed: busy || audience == null || title.text.trim().isEmpty || body.text.trim().isEmpty ? null : publish, icon: const Icon(Icons.send_outlined), label: const Text('Нийтлэх')),
          const SizedBox(height: 24), const Text('Сүүлийн зарлалууд', style: TextStyle(fontSize: 21,fontWeight:FontWeight.w800)), const SizedBox(height: 8),
          for (final n in _rows(data?['results'])) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color:p.surface,border:Border.all(color:p.outline),borderRadius:BorderRadius.circular(12)), child: Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text(_str(n['title']),style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16)), Text('${n['classroom_name'] ?? 'Бүх хэрэглэгч'} · ${_date(n['created_at'])}',style:TextStyle(color:p.muted,fontSize:12)), const SizedBox(height:8),Text(_str(n['body'])),
            if(n['withdrawn']==true) Text('Цуцалсан',style:TextStyle(color:p.muted)) else Align(alignment:Alignment.centerRight,child:TextButton(onPressed:busy?null:()async{if(await confirm('Зарлал цуцлах уу?', 'Мэдэгдлийн төвөөс хасагдана.') && valid) await request(action:{'action':'withdraw','id':n['id']});},child:const Text('Цуцлах'))),
          ])),
        ],
      ])))));
  }
}
