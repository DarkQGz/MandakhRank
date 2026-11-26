import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'theme_settings.dart';
import 'public_profile_screen.dart';
import 'learning_screen.dart';
import 'progression_screen.dart';


/// Dashboard is part of the existing app, not a separate site.
/// The same dashboard renders the signed-in student and any visited student.
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
    required this.catalog,
    required this.onNavigate,
    required this.onLogin,
    required this.onAvatarChanged,
    required this.onOpenProfile,
    this.userId,
  });

  final Map<String, dynamic> catalog;
  final ValueChanged<int> onNavigate;
  final Future<void> Function() onLogin;
  final VoidCallback onAvatarChanged;
  final ValueChanged<int> onOpenProfile;
  final int? userId;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  MandakhPalette get palette => MandakhPalette.of(context);
  Color get _surface => palette.surface;
  Color get _line => palette.outline;
  Color get _primary => palette.accentInk;
  Color get _subdued => palette.muted;
  Map<String, dynamic>? profile;
  String? error;
  bool loading = false;
  bool saving = false;
  String? previousToken;
  int _loadGeneration = 0;
  int _identityGeneration = 0;
  bool get isOwner => profile?['is_owner'] == true && PracticeApi.token != null && previousToken == PracticeApi.token;
  bool get canLoad => widget.userId != null || PracticeApi.token != null;

  @override
  void initState() {
    super.initState();
    previousToken = PracticeApi.token;
    if (canLoad) load();
  }

  @override
  void didUpdateWidget(covariant StudentDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (previousToken != PracticeApi.token || oldWidget.userId != widget.userId) {
      previousToken = PracticeApi.token;
      _loadGeneration++;
      _identityGeneration++;
      loading = false;
      profile = null;
      error = null;
      if (canLoad) load();
    }
  }

  Future<void> load() async {
    if (loading || !canLoad) return;
    final generation = ++_loadGeneration;
    setState(() {
      loading = true;
      error = null;
    });
    final requestedToken = PracticeApi.token;
    try {
      final result = await PracticeApi.request(widget.userId == null
          ? 'profile/me/' : 'profile/public/${widget.userId}/');
      if (!mounted || generation != _loadGeneration || requestedToken != PracticeApi.token) return;
      setState(() => profile = result);
      if (result['is_owner'] == true && requestedToken != null) {
        PracticeApi.avatarUrl = ProfileApi.imageUrl(result['avatar_url'] as String?);
        widget.onAvatarChanged();
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration && requestedToken == PracticeApi.token) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && generation == _loadGeneration) setState(() => loading = false);
    }
  }

  Future<void> upload() async {
    if (saving || !isOwner) return;
    final token = PracticeApi.token;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (!mounted || token != PracticeApi.token || !isOwner || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) {
        throw Exception('Зургийг уншиж чадсангүй. Дахин сонгоно уу.');
      }
      if (file.size > 2 * 1024 * 1024) {
        throw Exception('2 MB-аас бага хэмжээтэй зураг сонгоно уу.');
      }
      setState(() => saving = true);
      final output = await ProfileApi.uploadAvatar(file.bytes!, file.name);
      if (!mounted || token != PracticeApi.token || !isOwner) return;
      setState(() { if (profile != null) profile!['avatar_url'] = output['avatar_url']; });
      widget.onAvatarChanged();
      notify('Профайл зураг шинэчлэгдлээ.');
    } catch (e) {
      if (mounted) notify(e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> removeAvatar() async {
    if (saving || !isOwner) return;
    final token = PracticeApi.token;
    setState(() => saving = true);
    try {
      await ProfileApi.deleteAvatar();
      if (!mounted || token != PracticeApi.token || !isOwner) return;
      setState(() { if (profile != null) profile!['avatar_url'] = null; });
      widget.onAvatarChanged();
      notify('Зургийг устгалаа.');
    } catch (e) {
      if (mounted) notify(e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void notify(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget surface(Widget content, {EdgeInsets padding = const EdgeInsets.all(16)}) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: content,
      );

  Widget iconBox(IconData icon, Color color) => Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: palette.readable(color), size: 24),
      );

  Widget avatar({double radius = 30}) {
    final url = ProfileApi.imageUrl(profile?['avatar_url'] as String?);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _primary.withOpacity(.17),
      child: ClipOval(
        child: url == null
            ? Icon(Icons.person_rounded, size: radius, color: _primary)
            : Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, size: radius, color: _primary),
              ),
      ),
    );
  }

  Widget metric(String label, String value, IconData icon, Color color) =>
      surface(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconBox(icon, color),
          SizedBox(height: 16),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
          SizedBox(height: 5),
          Text(label, style: TextStyle(color: _subdued, fontSize: 13)),
        ],
      ));

  Widget activityChart(List values) {
    final counts = values.map((v) => (v as Map)['count'] as int).toList();
    if (counts.isEmpty) return const SizedBox.shrink();
    final peak = counts.fold<int>(1, (a, b) => a > b ? a : b);
    final total = counts.fold<int>(0, (a, b) => a + b);
    return surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Илгээлтийн идэвх', style: TextStyle(fontWeight: FontWeight.w700))), Text('28 хоног', style: TextStyle(color: _subdued, fontSize: 12))]),
      const SizedBox(height: 6),
      Text('$total илгээлт', style: TextStyle(color: _subdued, fontSize: 12)),
      const SizedBox(height: 16),
      Semantics(label: 'Сүүлийн 28 хоногт $total илгээлт', child: SizedBox(height: 74, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < counts.length; i++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: Tooltip(message: '${(values[i] as Map)['date']}: ${counts[i]} илгээлт', child: AnimatedContainer(duration: const Duration(milliseconds: 220), height: counts[i] == 0 ? 4 : 74.0 * counts[i] / peak, decoration: BoxDecoration(color: counts[i] == 0 ? _line : _primary.withOpacity(.75), borderRadius: BorderRadius.circular(3)))))),
      ]))),
    ]));
  }

  Widget action(String label, String description, IconData icon, Color color, int destination) =>
      InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => widget.onNavigate(destination),
        child: surface(Row(children: [
          iconBox(icon, color),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text(description, style: TextStyle(color: _subdued, fontSize: 12)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _subdued),
        ]), padding: EdgeInsets.symmetric(horizontal: 16, vertical: 17)),
      );

  Widget sectionTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          SizedBox(height: 5),
          Text(subtitle, style: TextStyle(color: _subdued, fontSize: 13)),
        ],
      );

  String formatDate(dynamic value, {bool time = false}) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '—';
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}.${pad(d.month)}.${pad(d.day)}${time ? ' ${pad(d.hour)}:${pad(d.minute)}' : ''}';
  }

  String verdict(dynamic value) => const <String, String>{
    'Accepted': 'Зөв', 'Wrong Answer': 'Буруу хариу', 'Queued': 'Хүлээгдэж байна',
    'Running': 'Шалгаж байна', 'Time Limit Exceeded': 'Хугацаа хэтэрсэн',
    'Memory Limit Exceeded': 'Санах ой хэтэрсэн', 'Runtime Error': 'Ажиллуулах алдаа',
    'Compilation Error': 'Хөрвүүлэх алдаа', 'Judge Error': 'Шүүгчийн алдаа',
    'Output Limit Exceeded': 'Гаралтын хэмжээ хэтэрсэн',
  }[value] ?? value.toString();

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null && PracticeApi.token == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionTitle('Миний самбар', 'Суралцах явцаа нэг дороос удирдаарай.'),
        SizedBox(height: 22),
        surface(Column(children: [
          Icon(Icons.lock_person_outlined, size: 50, color: _primary),
          SizedBox(height: 14),
          Text('Нэвтэрч өөрийн самбараа нээнэ үү', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          SizedBox(height: 10),
          Text('Ахиц, бодолтын түүх, профайл зураг энд харагдана.', style: TextStyle(color: _subdued), textAlign: TextAlign.center),
          SizedBox(height: 18),
          FilledButton.icon(onPressed: widget.onLogin, icon: Icon(Icons.login), label: Text('Нэвтрэх / Бүртгүүлэх')),
        ])),
      ]);
    }
    if (loading && profile == null) {
      return Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()));
    }
    if (profile == null) {
      return surface(Column(children: [
        Icon(Icons.cloud_off_outlined, size: 36, color: _subdued),
        SizedBox(height: 10),
        Text(error ?? 'Профайл ачаалж чадсангүй.'),
        TextButton(onPressed: load, child: Text('Дахин оролдох')),
      ]));
    }

    final owner = isOwner;
    final stats = Map<String, dynamic>.from(profile!['statistics'] as Map);
    final completedCourseCount = learningMap(profile!['learning'])['courses'];
    final progression = progressionMap(profile!['progression']);
    final hasProgression = progression['level'] is num;
    final totals = progressionMap(progression['totals']);
    final recent = (profile!['recent'] as List).cast<Map>();
    final courses = (widget.catalog['courses'] as List?) ?? [];
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 740;
      final cell = wide ? (constraints.maxWidth - 14 * 3) / 4 : constraints.maxWidth < 250 ? constraints.maxWidth : (constraints.maxWidth - 14) / 2;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionTitle(owner ? 'Миний самбар' : 'Хэрэглэгчийн самбар', owner ? 'Тавтай морил! Өнөөдөр бас нэг бодлого бодоцгооё.' : 'Суралцах явц, бодолтын түүх, сэтгэгдлүүд.'),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: loading ? null : load, icon: const Icon(Icons.refresh), label: const Text('Шинэчлэх'))),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Text(error!, style: TextStyle(color: palette.muted)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _surface,
            border: Border.all(color: _line),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 22,
            runSpacing: 20,
            children: [
              Row(children: [
                avatar(),
                SizedBox(width: 18),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(owner ? 'САЙН БАЙНА УУ!' : 'СУРАЛЦАГЧ', style: TextStyle(color: _primary, fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w700)),
                  SizedBox(height: 5),
                  Text(profile!['username'].toString(), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                  if (hasProgression) Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: Text('${progression['rank']} · Level ${progression['level']}', style: TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w700))),
                  if (owner && profile!['email'] != null) Text(profile!['email'].toString(), style: TextStyle(color: _subdued, fontSize: 11)),
                  Text('Элссэн: ${formatDate(profile!['joined_at'])}', style: TextStyle(color: _subdued, fontSize: 11)),
                ])),
              ]),
              if (owner) Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: saving ? null : upload,
                  icon: Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(saving ? 'Түр хүлээнэ үү' : 'Зураг оруулах'),
                ),
                if (profile!['avatar_url'] != null)
                  TextButton.icon(
                    onPressed: saving ? null : removeAvatar,
                    icon: Icon(Icons.delete_outline, size: 18),
                    label: Text('Устгах'),
                  ),
              ]),
            ],
          ),
        ),
        SizedBox(height: 16),
        if (owner) Text('JPG, PNG, WebP • 2 MB хүртэл • Зураг таны профайлд хадгалагдана.', style: TextStyle(color: _subdued, fontSize: 11)),
        if (hasProgression) ...[
          const SizedBox(height: 16),
          ProgressionOverview(data: progression),
        ],
        SizedBox(height: 26),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: cell, child: metric('Нийт оноо', '${stats['points'] ?? 0}', Icons.stars_outlined, Color(0xFFFFC66B))),
          SizedBox(width: cell, child: metric('Бодсон бодлого', hasProgression ? '${progression['solved']} / ${totals['problems']}' : '${stats['solved'] ?? 0}', Icons.task_alt_rounded, palette.positive)),
          if (hasProgression) SizedBox(width: cell, child: metric('Дуусгасан хичээл', '${progression['lessons']} / ${totals['lessons']}', Icons.menu_book_outlined, Color(0xFF8CB3FF)))
          else SizedBox(width: cell, child: metric('Илгээлт', '${stats['submissions'] ?? 0}', Icons.terminal_rounded, Color(0xFF8CB3FF))),
          SizedBox(width: cell, child: metric(completedCourseCount != null ? 'Дуусгасан сургалт' : 'Нийт сургалт', hasProgression ? '${progression['courses']} / ${totals['courses']}' : '${completedCourseCount ?? stats['courses'] ?? 0}', Icons.school_outlined, Color(0xFFBE9BFF))),
        ]),
        if (hasProgression) ...[
          const SizedBox(height: 16),
          ProgressionAchievements(data: progression),
          const SizedBox(height: 16),
          ProgressionHeatmap(data: progression),
        ],
        if (profile!['learning'] is Map) LearningProfileSection(data: learningMap(profile!['learning'])),
        if (profile!['activity'] is List) ...[
          const SizedBox(height: 20),
          activityChart(profile!['activity'] as List),
        ],
        if (owner) ...[
        SizedBox(height: 24),
        sectionTitle('Түргэн холбоос', 'Дараагийн алхмаа сонгоорой.'),
        SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: wide ? (constraints.maxWidth - 28) / 3 : constraints.maxWidth, child: action('Бодлого бодох', 'Шинэ даалгавар сонгох', Icons.code_rounded, _primary, 1)),
          SizedBox(width: wide ? (constraints.maxWidth - 28) / 3 : constraints.maxWidth, child: action('Сургалт үзэх', 'Хичээлүүдээ үргэлжлүүлэх', Icons.menu_book_outlined, Color(0xFFBE9BFF), 2)),
          SizedBox(width: wide ? (constraints.maxWidth - 28) / 3 : constraints.maxWidth, child: action('Эрэмбэ харах', 'Бусадтай өрсөлдөх', Icons.emoji_events_outlined, Color(0xFFFFC66B), 0)),
        ]),
        SizedBox(height: 30),
        ],
        if (!owner) const SizedBox(height: 30),
        sectionTitle('Сүүлийн илгээлтүүд', owner ? 'Таны хамгийн сүүлд шалгуулсан кодууд.' : 'Нийтлэгдсэн бодлогын сүүлийн илгээлтүүд.'),
        if (hasProgression) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Нийт ${stats['submissions'] ?? 0} илгээлт', style: TextStyle(color: _subdued, fontSize: 13))),
        SizedBox(height: 14),
        surface(recent.isEmpty
            ? Padding(padding: EdgeInsets.all(14), child: Text(owner ? 'Одоогоор илгээлт алга. Эхний бодлогоо бодоорой!' : 'Одоогоор илгээлт алга.', style: TextStyle(color: _subdued)))
            : Column(children: [
                ...recent.map((item) {
                  final accepted = item['status'] == 'Accepted';
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 9),
                    child: Row(children: [
                      iconBox(accepted ? Icons.check_circle_outline : item['status'] == 'Wrong Answer' ? Icons.cancel_outlined : Icons.code, accepted ? palette.positive : item['status'] == 'Wrong Answer' ? palette.negative : _primary),
                      SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${item['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('#${item['id']} • ${item['passed']}/${item['total']} тест', style: TextStyle(color: _subdued, fontSize: 12)),
                        Text(formatDate(item['created_at'], time: true), style: TextStyle(color: _subdued, fontSize: 11)),
                        Text(verdict(item['status']), style: TextStyle(color: accepted ? palette.positive : _subdued, fontSize: 12, fontWeight: FontWeight.w600)),
                      ])),
                    ]),
                  );
                }),
              ])),
        SizedBox(height: 30),
        ProfileComments(
          key: ValueKey('profile-comments-${profile!['id']}-$_identityGeneration'),
          initialData: profile!.containsKey('comments') ? profile : null,
          userId: profile!['id'] as int,
          onOpenProfile: widget.onOpenProfile,
        ),
        if (owner && courses.isNotEmpty) ...[
          SizedBox(height: 30),
          sectionTitle('Санал болгох сургалт', 'Одоогоор нийтлэгдсэн сургалтууд.'),
          SizedBox(height: 14),
          surface(Column(children: [
            ...courses.take(3).map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: iconBox(Icons.school_outlined, Color(0xFFBE9BFF)),
              title: Text('${c['title']}', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${c['level']} • ${(c['lessons'] as List?)?.length ?? 0} хичээл'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () => widget.onNavigate(2),
            )),
          ])),
        ],
        SizedBox(height: 6),
      ]);
    });
  }
}
