import 'package:flutter/material.dart';
import 'theme_settings.dart';

Map<String, dynamic> progressionMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int progressionInt(dynamic value) => value is num ? value.toInt() : 0;
List<Map<String, dynamic>> _rows(dynamic value) => value is List
    ? value.whereType<Map>().map(progressionMap).toList() : [];

const _categoryColors = <String, Color>{
  'Бодлого': Color(0xFF60A5FA), 'Суралцах': Color(0xFF4ADE80),
  'Тууштай байдал': Color(0xFFFB923C), 'Тэмцээн': Color(0xFFFBBF24),
  'Ур чадвар': Color(0xFFC084FC),
};
const _icons = <String, IconData>{
  'code': Icons.code_rounded, 'brain': Icons.psychology_outlined,
  'trophy': Icons.emoji_events_outlined, 'crown': Icons.workspace_premium_rounded,
  'book': Icons.menu_book_rounded, 'school': Icons.school_outlined,
  'flame': Icons.local_fire_department_rounded, 'flag': Icons.flag_outlined,
  'medal': Icons.military_tech_rounded,
};

Widget _panel(BuildContext context, Widget child) {
  final p = MandakhPalette.of(context);
  return Container(width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p.outline)), child: child);
}

Widget _bar(BuildContext context, double value, Color color) {
  final p = MandakhPalette.of(context);
  return ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
    value: value.clamp(0.0, 1.0).toDouble(), minHeight: 7,
    backgroundColor: p.tint, valueColor: AlwaysStoppedAnimation<Color>(color)));
}

class ProgressionOverview extends StatelessWidget {
  const ProgressionOverview({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final level = progressionInt(data['level']);
    final xp = progressionInt(data['xp']);
    final current = progressionInt(data['xp_in_level']);
    final goal = progressionInt(data['xp_per_level']);
    final streak = progressionInt(data['current_streak']);
    final longest = progressionInt(data['longest_streak']);
    final flame = p.readable(const Color(0xFFFB923C));
    return _panel(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: p.tint,
          borderRadius: BorderRadius.circular(14)), child: Icon(Icons.bolt_rounded, color: p.accentInk, size: 30)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Level $level', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          Text('Нийт $xp XP', style: TextStyle(color: p.muted, fontSize: 13)),
        ])),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(color: Color.lerp(p.surface, flame, .09), borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_fire_department_rounded, color: flame, size: 20),
              const SizedBox(width: 4), Text('$streak', style: TextStyle(color: flame, fontSize: 20, fontWeight: FontWeight.w800))]),
            Text('өдөр дараалан', style: TextStyle(color: p.muted, fontSize: 10)),
          ])),
      ]),
      const SizedBox(height: 18),
      Row(children: [const Expanded(child: Text('Дараагийн түвшин', style: TextStyle(fontWeight: FontWeight.w600))),
        Text('$current / $goal XP', style: TextStyle(color: p.muted, fontSize: 12))]),
      const SizedBox(height: 8),
      _bar(context, goal > 0 ? current / goal : 0.0, p.accentInk),
      const SizedBox(height: 10),
      Wrap(spacing: 16, runSpacing: 6, children: [
        Text('Level ${level + 1} хүртэл ${goal - current} XP', style: TextStyle(color: p.muted, fontSize: 12)),
        Text('Дээд амжилт: $longest өдөр', style: TextStyle(color: flame, fontSize: 12)),
      ]),
      const SizedBox(height: 10),
      Text('XP нь эрэмбийн онооноос тусдаа.', style: TextStyle(color: p.muted, fontSize: 12)),
      TextButton.icon(onPressed: () => showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: const Text('XP ба өдөр дараалсан идэвх'),
        content: const SingleChildScrollView(child: Text('Шинээр зөв бодсон бодлого бүр: 20 XP\nДуусгасан хичээл бүр: 10 XP\nДуусгасан сургалт бүр: 100 XP\nЭерэг оноотой дууссан тэмцээн бүр: 50 XP\n\n250 XP тутамд нэг түвшин ахина. Нэг бодлогыг давтан бодох эсвэл нэг шалгалтыг давтах нь XP нэмэхгүй.\n\nУлаанбаатарын цагаар тухайн өдөр зөв бодлого илгээх, хичээл эсвэл сургалт дуусгах нь идэвхтэй өдөрт тооцогдоно. Өнөөдөр идэвхгүй байсан ч өчигдрийн дараалал өдөр дуустал хадгалагдана.')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Хаах'))])),
        icon: const Icon(Icons.info_outline, size: 18), label: const Text('Хэрхэн XP цуглуулах вэ?')),
    ]));
  }
}

class _Medal extends StatelessWidget {
  const _Medal(this.award, {this.size = 48});
  final Map<String, dynamic> award;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final unlocked = award['unlocked'] == true;
    final color = unlocked ? p.readable(_categoryColors[award['category']] ?? p.accentInk) : p.muted;
    return SizedBox(width: size, height: size * 1.10, child: Stack(alignment: Alignment.center, children: [
      Positioned.fill(child: CustomPaint(painter: _MedalPainter(color, unlocked, p.surface))),
      Positioned(top: size * .22, child: Icon(unlocked ? (_icons[award['icon']] ?? Icons.star_outline) : Icons.lock_outline,
        color: color, size: size * .43)),
    ]));
  }
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter(this.color, this.unlocked, this.surface);
  final Color color, surface;
  final bool unlocked;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (unlocked) {
      final ribbons = Path()..moveTo(w*.31,h*.65)..lineTo(w*.20,h*.98)..lineTo(w*.43,h*.90)..lineTo(w*.50,h*.72)..close()
        ..moveTo(w*.69,h*.65)..lineTo(w*.80,h*.98)..lineTo(w*.57,h*.90)..lineTo(w*.50,h*.72)..close();
      canvas.drawPath(ribbons, Paint()..color = Color.lerp(surface, color, .4)!);
    }
    Path shield(double inset) {
      final left = w*(.08+inset), right = w*(.92-inset);
      return Path()..moveTo(w*.5,h*(.03+inset))..lineTo(right,h*(.22+inset))
        ..lineTo(right,h*(.58-inset))..lineTo(w*.5,h*(.79-inset))
        ..lineTo(left,h*(.58-inset))..lineTo(left,h*(.22+inset))..close();
    }
    canvas.drawPath(shield(0), Paint()..color=Color.lerp(surface,color,unlocked ? .15 : .05)!);
    canvas.drawPath(shield(0), Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=unlocked ? 1.8 : 1.0);
    if (unlocked) canvas.drawPath(shield(.07), Paint()..color=Color.lerp(surface,color,.55)!..style=PaintingStyle.stroke..strokeWidth=1);
  }
  @override
  bool shouldRepaint(covariant _MedalPainter oldDelegate) => color != oldDelegate.color || unlocked != oldDelegate.unlocked || surface != oldDelegate.surface;
}

class ProgressionAchievements extends StatelessWidget {
  const ProgressionAchievements({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final all = _rows(data['achievements']);
    if (all.isEmpty) return const SizedBox.shrink();
    final earned = all.where((a) => a['unlocked'] == true).toList();
    final preview = [...earned.reversed, ...all.where((a) => a['unlocked'] != true)].take(5);
    void open() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AchievementScreen(data: data)));
    return _panel(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Амжилтууд', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        Text('${earned.length} / ${all.length}', style: TextStyle(color: p.accentInk, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 9), _bar(context, earned.length / all.length, p.accentInk),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final a in preview)
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Semantics(button: true,
          label: '${a['title']}, ${a['unlocked'] == true ? 'Нээсэн' : 'Түгжээтэй'}', child: Material(type: MaterialType.transparency, child: InkWell(
            borderRadius: BorderRadius.circular(10), onTap: open, child: Padding(padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(children: [FittedBox(fit: BoxFit.scaleDown, child: _Medal(a, size: 48)),
                const SizedBox(height: 4), Text('${a['title']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: p.muted))]))))))),
      ]),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: open,
        icon: const Icon(Icons.emoji_events_outlined), label: const Text('Бүх амжилт'))),
    ]));
  }
}

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}
class _AchievementScreenState extends State<AchievementScreen> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final all = _rows(widget.data['achievements']);
    final unlocked = all.where((a) => a['unlocked'] == true).length;
    final visible = all.where((a) => filter == 0 || (a['unlocked'] == true) == (filter == 1)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Амжилтууд')), body: SafeArea(child: ListView(
      padding: const EdgeInsets.all(16), children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _panel(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$unlocked / ${all.length} амжилт', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8), _bar(context, all.isEmpty ? 0.0 : unlocked / all.length, p.accentInk),
            const SizedBox(height: 8), Text('Зөв бодолт, сургалт, идэвх болон тэмцээний дүнгээр нээгдэнэ.', style: TextStyle(color: p.muted)),
          ])),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 6, children: [for (var i = 0; i < 3; i++)
            ChoiceChip(label: Text(['Бүгд', 'Нээсэн', 'Түгжээтэй'][i]), selected: filter == i,
              onSelected: (_) => setState(() => filter = i))]),
          if (visible.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 28), child: Center(child: Text('Энэ хэсэгт амжилт алга.', style: TextStyle(color: p.muted)))),
          for (final category in _categoryColors.keys) if (visible.any((a) => a['category'] == category)) ...[
            const SizedBox(height: 22), Text(category, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth >= 790 ? 3 : constraints.maxWidth >= 510 ? 2 : 1;
              final width = (constraints.maxWidth - (cols - 1) * 12) / cols;
              return Wrap(spacing: 12, runSpacing: 12, children: [for (final a in visible.where((a) => a['category'] == category))
                SizedBox(width: width, child: _AchievementCard(a))]);
            }),
          ],
        ])))],
    )));
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard(this.award);
  final Map<String, dynamic> award;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final done = award['unlocked'] == true;
    final target = progressionInt(award['target']);
    final progress = progressionInt(award['progress']).clamp(0, target);
    final color = done ? p.positive : p.accentInk;
    return _panel(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [_Medal(award, size: 58), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${award['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5), Text('${award['description']}', style: TextStyle(color: p.muted, fontSize: 12)),
        ]))]),
      const SizedBox(height: 12), _bar(context, target > 0 ? progress / target : 0.0, color),
      const SizedBox(height: 7), Row(children: [Icon(done ? Icons.check_circle_outline : Icons.lock_outline, size: 16, color: done ? p.positive : p.muted),
        const SizedBox(width: 5), Expanded(child: Text(done ? 'Нээсэн' : 'Түгжээтэй', style: TextStyle(color: done ? p.positive : p.muted, fontSize: 12))),
        Text('$progress / $target', style: TextStyle(color: p.muted, fontSize: 12))]),
    ]));
  }
}

class ProgressionHeatmap extends StatelessWidget {
  const ProgressionHeatmap({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final days = _rows(data['heatmap']);
    if (days.length != 140) return const SizedBox.shrink();
    final active = days.where((d) => progressionInt(d['count']) > 0).length;
    final total = days.fold<int>(0, (sum, d) => sum + progressionInt(d['count']));
    final green = p.readable(const Color(0xFF22C55E));
    Color shade(int count) => count <= 0 ? p.tint : Color.lerp(p.surface, green, count == 1 ? .32 : count <= 3 ? .54 : count <= 6 ? .77 : 1)!;
    String date(dynamic d) => '${d ?? ''}';
    final start = DateTime.tryParse(date(days.first['date']));
    const labels = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];
    return _panel(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Суралцсан идэвх', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        Text('140 хоног', style: TextStyle(color: p.muted, fontSize: 12))]),
      const SizedBox(height: 5), Text('$active идэвхтэй өдөр · $total гүйцэтгэл', style: TextStyle(color: p.muted, fontSize: 12)),
      const SizedBox(height: 14),
      Align(alignment: Alignment.centerLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 24 - 19*2) / 20;
        final h = width.clamp(4.0, 22.0).toDouble();
        if (width <= 0) return const SizedBox.shrink();
        return Semantics(label: 'Сүүлийн 140 хоногийн идэвхийн хүснэгт, $active идэвхтэй өдөр', child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 24, child: Column(children: [for (var r = 0; r < 7; r++)
            SizedBox(height: h+2, child: Align(alignment: Alignment.centerLeft, child: Text(labels[((start?.weekday ?? 1)-1+r)%7], style: TextStyle(color: p.muted, fontSize: 9))))])),
          for (var col = 0; col < 20; col++) Expanded(child: Padding(padding: EdgeInsets.only(right: col == 19 ? 0 : 2), child: Column(children: [
            for (var row = 0; row < 7; row++) Padding(padding: const EdgeInsets.only(bottom: 2), child: Tooltip(
              message: '${days[col*7+row]['date']}: ${progressionInt(days[col*7+row]['count'])} гүйцэтгэл',
              child: Container(height: h, width: double.infinity, decoration: BoxDecoration(color: shade(progressionInt(days[col*7+row]['count'])), borderRadius: BorderRadius.circular(3))))),
          ]))),
        ]));
      }))),
      const SizedBox(height: 7),
      Wrap(spacing: 12, runSpacing: 6, alignment: WrapAlignment.spaceBetween, children: [
        Text('${date(days.first['date'])} – ${date(days.last['date'])}', style: TextStyle(color: p.muted, fontSize: 11)),
        Row(mainAxisSize: MainAxisSize.min, children: [Text('Бага', style: TextStyle(color: p.muted, fontSize: 11)),
          for (final n in [0, 1, 3, 5, 7]) Padding(padding: const EdgeInsets.only(left: 3), child: Container(width: 12, height: 12, decoration: BoxDecoration(color: shade(n), borderRadius: BorderRadius.circular(3)))),
          const SizedBox(width: 4), Text('Их', style: TextStyle(color: p.muted, fontSize: 11))]),
      ]),
      const SizedBox(height: 10), Text('Зөв бодолт (өдөрт бодлого бүр нэг удаа), дуусгасан хичээл болон сургалт.', style: TextStyle(color: p.muted, fontSize: 12)),
    ]));
  }
}
