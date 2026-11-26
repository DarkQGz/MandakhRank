import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_screen.dart';
import 'data.dart';
import 'theme_settings.dart';
import 'lesson_practice.dart';

Map<String, dynamic> learningMap(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> learningRows(Object? value) => value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
int learningInt(Object? value) => value is int ? value : 0;
String learningText(Object? value) => value?.toString() ?? '';
double fraction(int done, int total) => total == 0 ? 0 : (done / total).clamp(0.0, 1.0).toDouble();

const tracks = <String, List<String>>{
  'Програмчлалын үндэс': ['Python-ийн үндэс', 'Нөхцөл шалгалт ба давталт', 'Функц ба алдаа засварлалт', 'Массив ба тэмдэгт мөр'],
  'Алгоритм ба өгөгдлийн бүтэц': ['Алгоритмын сэтгэлгээ', 'Хайлт ба эрэмбэлэлт', 'Өгөгдлийн бүтэц', 'Тооны онол ба дискрет математик'],
  'Ахисан түвшин': ['Графын алгоритм', 'Динамик програмчлал', 'Ахисан түвшний алгоритм', 'Олимпиад ба тэмцээний програмчлал'],
  'Хөгжүүлэлт': ['Git ба GitHub', 'SQL ба өгөгдлийн сан', 'HTML, CSS ба JavaScript', 'Django ба REST API хөгжүүлэлт'],
};
String trackFor(Map<String, dynamic> row) {
  for (final entry in tracks.entries) {
    if (entry.value.contains(row['title'])) return entry.key;
  }
  return 'Бусад сургалт';
}
IconData courseIcon(String tag) {
  if (tag == 'Git') return Icons.call_split;
  if (tag == 'SQL') return Icons.storage_outlined;
  if (tag == 'Web') return Icons.language;
  if (tag == 'Django') return Icons.dns_outlined;
  if (tag == 'Mathematics') return Icons.calculate_outlined;
  if (tag == 'Graph' || tag == 'Data structure') return Icons.account_tree_outlined;
  if (tag == 'Competitive programming') return Icons.emoji_events_outlined;
  return Icons.code_rounded;
}

class LearningPanel extends StatelessWidget {
  const LearningPanel({super.key, required this.child, this.onTap, this.highlight = false});
  final Widget child;
  final VoidCallback? onTap;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: highlight ? p.accentInk : p.outline));
    return Material(color: highlight ? p.tint : p.surface, shape: shape, clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: child)));
  }
}

Widget learningHeading(BuildContext context, String title, [String? detail]) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5)),
  if (detail != null) ...[const SizedBox(height: 6), Text(detail, style: TextStyle(color: MandakhPalette.of(context).muted, height: 1.45))],
]);
Widget learningProgress(BuildContext context, int done, int total) => ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: fraction(done, total), minHeight: 7, backgroundColor: MandakhPalette.of(context).outline));
Widget pageBody(Widget child) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: SizedBox(width: double.infinity, child: child)))));
Widget learningError(Object? error, VoidCallback retry) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 40), const SizedBox(height: 12), Text(error is ApiException ? error.toString() : 'Мэдээлэл ачаалж чадсангүй. Холболтоо шалгана уу.', textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Дахин оролдох'))])));

class LearningLibrary extends StatefulWidget {
  const LearningLibrary({super.key, required this.courses, required this.onOpen});
  final List<Map<String, dynamic>> courses;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  State<LearningLibrary> createState() => _LearningLibraryState();
}
class _LearningLibraryState extends State<LearningLibrary> {
  String query = '', group = 'Бүгд';
  int total(Map<String, dynamic> c) => learningInt(learningMap(c['learning'])['total']) == 0 ? (c['lessons'] is List ? (c['lessons'] as List).length : 0) : learningInt(learningMap(c['learning'])['total']);
  int done(Map<String, dynamic> c) => learningInt(learningMap(c['learning'])['completed']);
  bool passed(Map<String, dynamic> c) => learningMap(c['learning'])['passed'] == true;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final all = widget.courses;
    final count = all.fold<int>(0, (sum, c) => sum + total(c));
    final completed = all.fold<int>(0, (sum, c) => sum + done(c));
    final groups = [...tracks.keys, if (all.any((c) => trackFor(c) == 'Бусад сургалт')) 'Бусад сургалт'];
    final shown = all.where((c) => (group == 'Бүгд' || trackFor(c) == group) && '${c['title']} ${c['tag']} ${c['description']}'.toLowerCase().contains(query)).toList();
    final inProgress = all.where((c) => done(c) > 0 && !passed(c)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      learningHeading(context, 'Сургалтууд', 'Бага багаар суралцаж, мэдлэгээ шалгаарай.'),
      const SizedBox(height: 16),
      LearningPanel(highlight: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.school_outlined, color: p.accentInk), const SizedBox(width: 10), const Expanded(child: Text('Таны суралцах ахиц', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)))]),
        const SizedBox(height: 14),
        Text('$completed / $count хичээл', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), learningProgress(context, completed, count), const SizedBox(height: 8),
        Text('${all.where(passed).length} / ${all.length} сургалт дуусгасан', style: TextStyle(color: p.muted)),
        if (inProgress.isNotEmpty) ...[const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => widget.onOpen(inProgress.first), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Үргэлжлүүлэн суралцах')))],
        if (PracticeApi.token == null) ...[const SizedBox(height: 8), Text('Нэвтэрснээр таны ахиц бүртгэлд хадгалагдана.', style: TextStyle(color: p.muted, fontSize: 12))],
      ])),
      const SizedBox(height: 20), TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Сургалт хайх'), onChanged: (v) => setState(() => query = v.toLowerCase().trim())),
      const SizedBox(height: 12), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['Бүгд', ...groups].map((g) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(g), selected: g == group, onSelected: (_) => setState(() => group = g)))).toList())),
      const SizedBox(height: 20),
      if (shown.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Сургалт олдсонгүй.')),
      for (final g in groups) if (shown.any((c) => trackFor(c) == g)) ...[
        Text(g, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 620 ? 2 : 1;
          final width = (constraints.maxWidth - (cols - 1) * 12) / cols;
          final rows = shown.where((c) => trackFor(c) == g).toList();
          if (tracks.containsKey(g)) rows.sort((a,b) => tracks[g]!.indexOf(learningText(a['title'])).compareTo(tracks[g]!.indexOf(learningText(b['title']))));
          return Wrap(spacing: 12, runSpacing: 12, children: rows.map((c) => SizedBox(width: width, child: LearningPanel(onTap: () => widget.onOpen(c), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(12)), child: Icon(courseIcon(learningText(c['tag'])), color: p.accentInk)), const SizedBox(width: 12), Expanded(child: Text(learningText(c['title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))), const Icon(Icons.chevron_right)]),
            const SizedBox(height: 12), Text('${c['level']}  ·  ${total(c)} хичээл', style: TextStyle(color: p.muted, fontSize: 12)), const SizedBox(height: 6),
            Text(learningText(c['description']), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, height: 1.4)), const SizedBox(height: 14),
            learningProgress(context, done(c), total(c)), const SizedBox(height: 8),
            Row(children: [Expanded(child: Text('${done(c)}/${total(c)} дуусгасан', style: TextStyle(color: p.muted, fontSize: 12))), Text(passed(c) ? 'Дууссан' : done(c) > 0 ? 'Үргэлжлүүлэх' : 'Эхлэх', style: TextStyle(color: passed(c) ? p.positive : p.accentInk, fontWeight: FontWeight.w700, fontSize: 12))]),
          ])))).toList());
        }), const SizedBox(height: 24),
      ],
    ]);
  }
}

class LearningCourseScreen extends StatefulWidget {
  const LearningCourseScreen({super.key, required this.courseId, required this.title});
  final int courseId;
  final String title;
  @override
  State<LearningCourseScreen> createState() => _LearningCourseScreenState();
}
class _LearningCourseScreenState extends State<LearningCourseScreen> {
  late Future<Map<String,dynamic>> future;
  String get route => 'learning/${widget.courseId}/';
  @override
  void initState() { super.initState(); future = PracticeApi.request(route); }
  void reload() { if (mounted) setState(() => future = PracticeApi.request(route)); }
  Future<void> openLesson(Map<String,dynamic> lesson, int index, int total) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LearningLessonScreen(courseId: widget.courseId, lesson: lesson, index: index, total: total)));
    reload();
  }
  Future<void> finalExam() async {
    await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => LearningQuizScreen(courseId: widget.courseId, lessonId: 0)));
    reload();
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Сургалтын хөтөлбөр'), actions: [IconButton(tooltip: 'Шинэчлэх', onPressed: reload, icon: const Icon(Icons.refresh))]), body: FutureBuilder<Map<String,dynamic>>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError || !snapshot.hasData) return learningError(snapshot.error, reload);
    final c = snapshot.data!, rows = learningRows(c['lessons']);
    final p = MandakhPalette.of(context), completed = learningInt(c['completed']);
    final next = rows.indexWhere((l) => l['completed'] != true);
    return pageBody(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LearningPanel(highlight: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c['level']}  ·  ${c['tag']}', style: TextStyle(color: p.accentInk, fontWeight: FontWeight.w600)), const SizedBox(height: 8), learningHeading(context, learningText(c['title']), learningText(c['description'])), const SizedBox(height: 18),
        learningProgress(context, completed, rows.length), const SizedBox(height: 8), Text('$completed/${rows.length} хичээл дуусгасан', style: TextStyle(color: p.muted)),
        if (next >= 0) ...[const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => openLesson(rows[next], next, rows.length), icon: const Icon(Icons.play_arrow), label: Text(completed == 0 ? 'Сургалтаа эхлэх' : 'Үргэлжлүүлэх')))],
      ])), const SizedBox(height: 24),
      learningHeading(context, 'Хичээлийн замнал', 'Ойлголт → Жишээ → Дадлага → Шалгалт'), const SizedBox(height: 12),
      for (var i = 0; i < rows.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: LearningPanel(highlight: i == next, onTap: () => openLesson(rows[i], i, rows.length), child: Row(children: [
        Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(12)), child: rows[i]['completed'] == true ? Icon(Icons.check_circle_outline, color: p.positive) : Text('${i+1}'.padLeft(2,'0'), style: TextStyle(color: p.accentInk, fontWeight: FontWeight.w700))), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(learningText(rows[i]['title']), style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(rows[i]['completed'] == true ? 'Шалгалтад тэнцсэн' : rows[i]['has_quiz'] == true ? '4 алхам · 2 асуулт' : 'Унших хичээл · шалгалт бэлэн биш', style: TextStyle(color: p.muted, fontSize: 12))])), const Icon(Icons.chevron_right),
      ]))),
      const SizedBox(height: 14),
      LearningPanel(highlight: c['passed'] == true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(c['passed'] == true ? Icons.verified_outlined : c['final_unlocked'] == true ? Icons.assignment_turned_in_outlined : Icons.lock_outline, color: c['passed'] == true ? p.positive : p.accentInk), const SizedBox(width: 10), const Expanded(child: Text('Нэгдсэн шалгалт', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))]), const SizedBox(height: 8),
        Text(c['passed'] == true ? 'Сургалтаа амжилттай дуусгасан. Таны профайлд бүртгэгдсэн.' : c['has_final'] != true ? 'Бүх хичээлийн шалгалт бэлэн болсны дараа нээгдэнэ.' : 'Бүх хичээлд тэнцсэний дараа ${rows.length} шинэ асуулттай шалгалт өгнө. 80% ба түүнээс дээш зөв хариулбал сургалт дуусна.', style: TextStyle(color: p.muted, height: 1.5)), const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: c['final_unlocked'] == true ? finalExam : null, child: Text(c['passed'] == true ? 'Дахин шалгуулах' : 'Шалгалт эхлүүлэх'))),
      ])),
    ]));
  }));
}

class LearningLessonScreen extends StatefulWidget {
  const LearningLessonScreen({super.key, required this.courseId, required this.lesson, required this.index, required this.total});
  final int courseId, index, total;
  final Map<String,dynamic> lesson;
  @override
  State<LearningLessonScreen> createState() => _LearningLessonScreenState();
}
class _LearningLessonScreenState extends State<LearningLessonScreen> {
  int step = 0;
  bool reveal = false;
  final scroll = ScrollController();
  static const steps = ['Ойлголт','Жишээ','Дадлага','Шалгалт'];
  @override
  void dispose() { scroll.dispose(); super.dispose(); }
  void move(int value) { setState(() => step = value); if (scroll.hasClients) scroll.jumpTo(0); }
  Future<void> startQuiz() async {
    if (PracticeApi.token == null) {
      await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => const AuthScreen()));
      if (!mounted || PracticeApi.token == null) return;
    }
    final passed = await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => LearningQuizScreen(courseId: widget.courseId, lessonId: learningInt(widget.lesson['id']))));
    if (mounted && passed == true) Navigator.of(context).pop();
  }
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context), l = widget.lesson;
    final canQuiz = l['has_quiz'] == true;
    final last = canQuiz ? 3 : 2;
    return Scaffold(appBar: AppBar(title: Text('Хичээл ${widget.index+1}/${widget.total}')), body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16,8,16,12), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: Column(children: [
        Row(children: List.generate(last+1, (i) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Column(children: [Container(height: 5, decoration: BoxDecoration(color: i <= step ? p.accentInk : p.outline, borderRadius: BorderRadius.circular(6))), const SizedBox(height: 5), Text(steps[i], style: TextStyle(fontSize: 11, color: i == step ? p.accentInk : p.muted, fontWeight: i == step ? FontWeight.w700 : FontWeight.normal), textAlign: TextAlign.center)]))))),
      ])))),
      Expanded(child: SingleChildScrollView(controller: scroll, padding: const EdgeInsets.fromLTRB(16,4,16,20), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: SizedBox(width: double.infinity, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        learningHeading(context, learningText(l['title']), 'Алхам ${step+1} / ${last+1} · ${steps[step]}'), const SizedBox(height: 20),
        if (step == 0) ...[
          LearningPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Гол ойлголт', style: TextStyle(color: p.accentInk, fontWeight: FontWeight.w700)), const SizedBox(height: 12), ConceptPoints(text: learningText(l['theory']))])), const SizedBox(height: 12),
          LearningPanel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lightbulb_outline, color: p.accentInk), const SizedBox(width: 10), const Expanded(child: Text('Энэ ойлголтыг дараагийн жишээнд хэрхэн ашиглаж байгааг ажиглаарай.', style: TextStyle(height: 1.45)))])),
        ] else if (step == 1) ...[
          const Text('Ажиллах зарчим', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)), const SizedBox(height: 8), const Text('Кодыг мөр мөрөөр уншаад үр дүнг нь өөрөө таамаглаарай.'), const SizedBox(height: 12),
          if (learningText(l['example']).isNotEmpty) CodeExample(code: learningText(l['example'])), const SizedBox(height: 14),
          if (learningText(l['result']).isNotEmpty) LearningPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.visibility_outlined, color: p.accentInk), const SizedBox(width: 8), const Expanded(child: Text('Үр дүн ба тайлбар', style: TextStyle(fontWeight: FontWeight.w700)))]), const SizedBox(height: 8), if (reveal) SelectableText(learningText(l['result']), style: const TextStyle(height: 1.55, fontSize: 15)) else OutlinedButton(onPressed: () => setState(() => reveal = true), child: const Text('Үр дүнг харах'))])),
        ] else if (step == 2) ...[
          LessonPractice(lesson: l),
        ] else ...[
          LearningPanel(highlight: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.fact_check_outlined, size: 44, color: p.accentInk), const SizedBox(height: 14), const Text('Мэдлэгээ бататгах', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('2 асуулт · 100% зөв хариулт', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 12), const Text('Асуулт бүрд нэг хариулт сонгоно. Буруу бол тайлбарыг уншаад дахин оролдоорой. Тэнцсэн хичээл таны профайлд автоматаар бүртгэгдэнэ.', style: TextStyle(height: 1.55))])),
        ],
      ])))))),
    ])), bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16,8,16,12), child: Row(children: [
      if (step > 0) ...[OutlinedButton(onPressed: () => move(step-1), child: const Icon(Icons.arrow_back)), const SizedBox(width: 10)],
      Expanded(child: FilledButton(onPressed: step == last ? (canQuiz ? startQuiz : () => Navigator.pop(context)) : () => move(step+1), child: Text(step == last ? (canQuiz ? 'Шалгалт өгөх' : 'Буцах') : 'Дараах алхам'))),
    ]))));
  }
}

class ConceptPoints extends StatelessWidget {
  const ConceptPoints({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    // The original prose is retained, but sentence boundaries become readable chunks.
    final parts = text.replaceAllMapped(RegExp(r'([.!?])\s+(?=[А-ЯЁӨҮA-Z])'), (m) => '${m[1]}\n').split('\n').where((s) => s.trim().isNotEmpty).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i=0; i<parts.length; i++) ...[
        if (i>0) const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(7)), child: Text('${i+1}', style: TextStyle(color: p.accentInk, fontWeight: FontWeight.w700, fontSize: 12))), const SizedBox(width: 10), Expanded(child: SelectableText(parts[i], style: const TextStyle(fontSize: 16, height: 1.55)))]),
      ],
    ]);
  }
}

class CodeExample extends StatelessWidget {
  const CodeExample({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    return LearningPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.code, color: p.accentInk), const SizedBox(width: 8), const Expanded(child: Text('Кодын жишээ', style: TextStyle(fontWeight: FontWeight.w700))), IconButton(tooltip: 'Код хуулах', onPressed: () async { await Clipboard.setData(ClipboardData(text: code)); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код хуулагдлаа'))); }, icon: const Icon(Icons.copy_outlined))]),
      const Divider(), SingleChildScrollView(scrollDirection: Axis.horizontal, child: SelectableText(code, style: TextStyle(fontFamily: 'monospace', height: 1.55, fontSize: 14, color: p.text))),
    ]));
  }
}

class LearningQuizScreen extends StatefulWidget {
  const LearningQuizScreen({super.key, required this.courseId, required this.lessonId});
  final int courseId, lessonId;
  @override
  State<LearningQuizScreen> createState() => _LearningQuizScreenState();
}
class _LearningQuizScreenState extends State<LearningQuizScreen> {
  late Future<Map<String,dynamic>> future;
  final answers = <String,String>{};
  int index = 0;
  bool busy = false;
  Map<String,dynamic>? result;
  String? error;
  String get route => 'learning/${widget.courseId}/quiz/${widget.lessonId}/';
  @override
  void initState() { super.initState(); future = PracticeApi.request(route); }
  void retry() => setState(() { index = 0; answers.clear(); result = null; error = null; future = PracticeApi.request(route); });
  Future<void> submit() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final data = await PracticeApi.request(route, body: {'answers': answers});
      if (mounted) setState(() => result = data);
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.toString() : 'Шалгалтын хариу илгээгдсэнгүй. Дахин оролдоно уу.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final r = result;
    if (r != null) {
      final passed = r['passed'] == true;
      return Scaffold(appBar: AppBar(title: const Text('Шалгалтын дүн')), body: pageBody(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LearningPanel(highlight: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(passed ? Icons.verified_outlined : Icons.refresh_rounded, size: 52, color: passed ? p.positive : p.accentInk), const SizedBox(height: 12), learningHeading(context, passed ? 'Амжилттай тэнцлээ!' : 'Дахин бататгаарай', '${r['correct']} / ${r['total']} зөв хариулт'), const SizedBox(height: 12), Text('${r['score']}%', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: passed ? p.positive : p.accentInk)), learningProgress(context, learningInt(r['correct']), learningInt(r['total'])), const SizedBox(height: 12), Text(passed ? 'Таны профайлд амжилт бүртгэгдлээ.' : 'Тэнцэх босго: ${r['threshold']}%. Доорх тайлбарыг уншаад дахин оролдоорой.') ])), const SizedBox(height: 20),
        const Text('Хариултаа нягтлах', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
        for (final q in learningRows(r['review'])) Padding(padding: const EdgeInsets.only(bottom: 8), child: LearningPanel(child: ExpansionTile(tilePadding: EdgeInsets.zero, childrenPadding: EdgeInsets.zero, leading: Icon(q['correct'] == true ? Icons.check_circle_outline : Icons.cancel_outlined, color: q['correct'] == true ? p.positive : p.negative), title: Text(learningText(q['prompt']), style: const TextStyle(fontSize: 14)), children: [Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Таны хариулт: ${q['selected']}'), const SizedBox(height: 6), Text('Зөв хариулт: ${q['answer']}', style: TextStyle(color: p.positive, fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text(learningText(q['explanation']), style: TextStyle(height: 1.5, color: p.muted))]))]))),
      ])), bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: FilledButton(onPressed: passed ? () => Navigator.pop(context, true) : retry, child: Text(passed ? 'Дуусгах' : 'Дахин оролдох')))));
    }
    return Scaffold(appBar: AppBar(title: Text(widget.lessonId == 0 ? 'Нэгдсэн шалгалт' : 'Хичээлийн шалгалт')), body: FutureBuilder<Map<String,dynamic>>(future: future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError || !snapshot.hasData) return learningError(snapshot.error, retry);
      final questions = learningRows(snapshot.data!['questions']);
      if (questions.isEmpty) return const Center(child: Text('Асуулт алга.'));
      final q = questions[index], qid = learningText(q['id']);
      return SafeArea(child: Column(children: [Expanded(child: SingleChildScrollView(key: ValueKey(index), padding: const EdgeInsets.all(16), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: SizedBox(width: double.infinity, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Асуулт ${index+1} / ${questions.length}', style: TextStyle(color: p.accentInk, fontWeight: FontWeight.w700)), const SizedBox(height: 8), learningProgress(context, answers.length, questions.length), const SizedBox(height: 20),
        Text(learningText(q['prompt']), style: const TextStyle(fontSize: 22, height: 1.4, fontWeight: FontWeight.w700)), const SizedBox(height: 20),
        for (final o in learningRows(q['options'])) Padding(padding: const EdgeInsets.only(bottom: 10), child: LearningPanel(highlight: answers[qid] == o['id'], onTap: busy ? null : () => setState(() => answers[qid] = learningText(o['id'])), child: Row(children: [Icon(answers[qid] == o['id'] ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: p.accentInk), const SizedBox(width: 12), Expanded(child: Text(learningText(o['text']), style: const TextStyle(fontSize: 16, height: 1.4)))]))),
        if (error != null) Text(error!, style: TextStyle(color: p.negative)),
      ])))))), Padding(padding: const EdgeInsets.fromLTRB(16,8,16,12), child: Row(children: [
        if (index > 0) ...[OutlinedButton(onPressed: busy ? null : () => setState(() => index--), child: const Icon(Icons.arrow_back)), const SizedBox(width: 10)],
        Expanded(child: FilledButton(onPressed: busy || !answers.containsKey(qid) || (index == questions.length-1 && answers.length != questions.length) ? null : index == questions.length-1 ? submit : () => setState(() => index++), child: Text(busy ? 'Шалгаж байна...' : index == questions.length-1 ? 'Хариулт илгээх' : 'Дараагийн асуулт'))),
      ]))]));
    }));
  }
}

class LearningProfileSection extends StatelessWidget {
  const LearningProfileSection({super.key, required this.data});
  final Map<String,dynamic> data;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context), courses = learningRows(data['completed_courses']), lessons = learningRows(data['recent_lessons']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 24), learningHeading(context, 'Суралцсан амжилт', 'Шалгалтаар баталгаажсан ахиц'), const SizedBox(height: 12), LearningPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${data['lessons'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), Text('Дуусгасан хичээл', style: TextStyle(color: p.muted, fontSize: 12))])), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${data['courses'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), Text('Дуусгасан сургалт', style: TextStyle(color: p.muted, fontSize: 12))]))]),
      if (courses.isNotEmpty) ...[const Divider(), const Text('Дуусгасан сургалтууд', style: TextStyle(fontWeight: FontWeight.w700)), for (final c in courses) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(Icons.verified_outlined, color: p.positive), const SizedBox(width: 10), Expanded(child: Text(learningText(c['title']))), Text('${c['score']}%', style: TextStyle(color: p.positive, fontWeight: FontWeight.w700))]))],
      if (lessons.isNotEmpty) ...[const Divider(), const Text('Сүүлд дуусгасан хичээлүүд', style: TextStyle(fontWeight: FontWeight.w700)), for (final l in lessons) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(Icons.check_circle_outline, color: p.positive), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(learningText(l['title'])), Text(learningText(l['course']), style: TextStyle(color: p.muted, fontSize: 12))]))]))],
      if (learningRows(data['completed_lessons']).length > lessons.length) ...[const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LearningHistoryScreen(lessons: learningRows(data['completed_lessons'])))), icon: const Icon(Icons.history), label: const Text('Бүх дуусгасан хичээл')))],
      if (lessons.isEmpty && courses.isEmpty) ...[const SizedBox(height: 12), Text('Одоогоор дуусгасан хичээл алга.', style: TextStyle(color: p.muted))],
    ]))]);
  }
}


class LearningHistoryScreen extends StatelessWidget {
  const LearningHistoryScreen({super.key, required this.lessons});
  final List<Map<String,dynamic>> lessons;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    return Scaffold(appBar: AppBar(title: const Text('Дуусгасан хичээлүүд')), body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: ListView.separated(padding: const EdgeInsets.all(16), itemCount: lessons.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, i) {
      final l = lessons[i], dt = DateTime.tryParse(learningText(lessons[i]['completed_at']))?.toLocal();
      return LearningPanel(child: Row(children: [Icon(Icons.check_circle_outline, color: p.positive), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(learningText(l['title']), style: const TextStyle(fontWeight: FontWeight.w700)), Text(learningText(l['course']), style: TextStyle(color: p.muted, fontSize: 12)), if (dt != null) Text('${dt.year}.${dt.month.toString().padLeft(2,'0')}.${dt.day.toString().padLeft(2,'0')}', style: TextStyle(color: p.muted, fontSize: 12))]))]));
    })))));
  }
}
