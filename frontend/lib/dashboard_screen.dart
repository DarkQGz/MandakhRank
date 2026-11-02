import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'data.dart';

const _background = Color(0xFF080E1C);
const _surface = Color(0xFF111C30);
const _line = Color(0xFF253550);
const _primary = Color(0xFF4C86FF);
const _subdued = Color(0xFF96A8C5);

/// Dashboard is part of the existing app, not a separate site.
/// Private activity is fetched from the authenticated Django endpoint.
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
    required this.catalog,
    required this.onNavigate,
    required this.onLogin,
    required this.onAvatarChanged,
  });

  final Map<String, dynamic> catalog;
  final ValueChanged<int> onNavigate;
  final Future<void> Function() onLogin;
  final VoidCallback onAvatarChanged;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  Map<String, dynamic>? profile;
  String? error;
  bool loading = false;
  bool saving = false;
  String? previousToken;

  @override
  void initState() {
    super.initState();
    previousToken = PracticeApi.token;
    if (previousToken != null) load();
  }

  @override
  void didUpdateWidget(covariant StudentDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (previousToken != PracticeApi.token) {
      previousToken = PracticeApi.token;
      profile = null;
      error = null;
      if (previousToken != null) load();
    }
  }

  Future<void> load() async {
    if (loading || PracticeApi.token == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    final requestedToken = PracticeApi.token;
    try {
      final result = await PracticeApi.request('profile/me/');
      if (!mounted || requestedToken != PracticeApi.token) return;
      setState(() => profile = result);
      PracticeApi.avatarUrl = ProfileApi.imageUrl(result['avatar_url'] as String?);
      widget.onAvatarChanged();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> upload() async {
    if (saving) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) {
        throw Exception('Зургийг уншиж чадсангүй. Дахин сонгоно уу.');
      }
      if (file.size > 2 * 1024 * 1024) {
        throw Exception('2 MB-аас бага хэмжээтэй зураг сонгоно уу.');
      }
      setState(() => saving = true);
      final output = await ProfileApi.uploadAvatar(file.bytes!, file.name);
      if (!mounted) return;
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
    if (saving) return;
    setState(() => saving = true);
    try {
      await ProfileApi.deleteAvatar();
      if (!mounted) return;
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

  Widget surface(Widget content, {EdgeInsets padding = const EdgeInsets.all(22)}) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
        ),
        child: content,
      );

  Widget iconBox(IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 24),
      );

  Widget avatar({double radius = 40}) {
    final url = ProfileApi.imageUrl(profile?['avatar_url'] as String?);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _primary.withOpacity(.17),
      child: ClipOval(
        child: url == null
            ? Icon(Icons.person_rounded, size: radius, color: const Color(0xFFA5C1FF))
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
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: _subdued, fontSize: 13)),
        ],
      ));

  Widget action(String label, String description, IconData icon, Color color, int destination) =>
      InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => widget.onNavigate(destination),
        child: surface(Row(children: [
          iconBox(icon, color),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: _subdued, fontSize: 12)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _subdued),
        ]), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17)),
      );

  Widget sectionTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: _subdued, fontSize: 13)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (PracticeApi.token == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionTitle('Миний самбар', 'Суралцах явцаа нэг дороос удирдаарай.'),
        const SizedBox(height: 22),
        surface(Column(children: [
          const Icon(Icons.lock_person_outlined, size: 50, color: _primary),
          const SizedBox(height: 14),
          const Text('Нэвтэрч өөрийн самбараа нээнэ үү', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          const Text('Ахиц, бодолтын түүх, профайл зураг энд харагдана.', style: TextStyle(color: _subdued), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: widget.onLogin, icon: const Icon(Icons.login), label: const Text('Нэвтрэх / Бүртгүүлэх')),
        ])),
      ]);
    }
    if (loading && profile == null) {
      return const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()));
    }
    if (profile == null) {
      return surface(Column(children: [
        const Icon(Icons.cloud_off_outlined, size: 36, color: _subdued),
        const SizedBox(height: 10),
        Text(error ?? 'Профайл ачаалж чадсангүй.'),
        TextButton(onPressed: load, child: const Text('Дахин оролдох')),
      ]));
    }

    final stats = Map<String, dynamic>.from(profile!['statistics'] as Map);
    final recent = (profile!['recent'] as List).cast<Map>();
    final courses = (widget.catalog['courses'] as List?) ?? [];
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 740;
      final cell = wide ? (constraints.maxWidth - 14 * 3) / 4 : (constraints.maxWidth - 14) / 2;
      // The profile header has 24px padding on each side, an 80px avatar,
      // and an 18px gap. Keep the name/email inside the available width.
      final identityWidth = (constraints.maxWidth - 146.0)
          .clamp(0.0, 320.0)
          .toDouble();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionTitle('Миний самбар', 'Тавтай морил! Өнөөдөр бас нэг бодлого бодоцгооё.'),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF182B50), Color(0xFF121D32)]),
            border: Border.all(color: const Color(0xFF31528A)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 22,
            runSpacing: 20,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                avatar(),
                const SizedBox(width: 18),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('САЙН БАЙНА УУ!', style: TextStyle(color: Color(0xFFA8C4FF), fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  SizedBox(width: identityWidth, child: Text(profile!['username'].toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold))),
                  SizedBox(width: identityWidth, child: Text(profile!['email'].toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(color: _subdued, fontSize: 11))),
                ]),
              ]),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: saving ? null : upload,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(saving ? 'Түр хүлээнэ үү' : 'Зураг оруулах'),
                ),
                if (profile!['avatar_url'] != null)
                  TextButton.icon(
                    onPressed: saving ? null : removeAvatar,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Устгах'),
                  ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('JPG, PNG, WebP • 2 MB хүртэл • Зураг таны профайлд хадгалагдана.', style: TextStyle(color: _subdued, fontSize: 11)),
        const SizedBox(height: 26),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: cell, child: metric('Нийт оноо', '${stats['points'] ?? 0}', Icons.stars_outlined, const Color(0xFFFFC66B))),
          SizedBox(width: cell, child: metric('Бодсон бодлого', '${stats['solved'] ?? 0}', Icons.task_alt_rounded, const Color(0xFF55D4B0))),
          SizedBox(width: cell, child: metric('Илгээлт', '${stats['submissions'] ?? 0}', Icons.terminal_rounded, const Color(0xFF8CB3FF))),
          SizedBox(width: cell, child: metric('Сургалт', '${stats['courses'] ?? 0}', Icons.school_outlined, const Color(0xFFBE9BFF))),
        ]),
        const SizedBox(height: 30),
        sectionTitle('Түргэн холбоос', 'Дараагийн алхмаа сонгоорой.'),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: wide ? (constraints.maxWidth - 28) / 3 : constraints.maxWidth, child: action('Бодлого бодох', 'Шинэ даалгавар сонгох', Icons.code_rounded, _primary, 1)),
          SizedBox(width: wide ? (constraints.maxWidth - 28) / 3 : constraints.maxWidth, child: action('Сургалт үзэх', 'Хичээлүүдээ үргэлжлүүлэх', Icons.menu_book_outlined, const Color(0xFFBE9BFF), 2)),
          SizedBox(width: wide ? (constraints.maxWidth - 28) / 3 : constraints.maxWidth, child: action('Эрэмбэ харах', 'Бусадтай өрсөлдөх', Icons.emoji_events_outlined, const Color(0xFFFFC66B), 0)),
        ]),
        const SizedBox(height: 30),
        sectionTitle('Сүүлийн илгээлтүүд', 'Таны хамгийн сүүлд шалгуулсан кодууд.'),
        const SizedBox(height: 14),
        surface(recent.isEmpty
            ? const Padding(padding: EdgeInsets.all(14), child: Text('Одоогоор илгээлт алга. Эхний бодлогоо бодоорой!', style: TextStyle(color: _subdued)))
            : Column(children: [
                ...recent.map((item) {
                  final accepted = item['status'] == 'Accepted';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(children: [
                      iconBox(accepted ? Icons.check_circle_outline : Icons.code, accepted ? const Color(0xFF55D4B0) : _primary),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${item['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('#${item['id']} • ${item['passed']}/${item['total']} тест', style: const TextStyle(color: _subdued, fontSize: 12)),
                      ])),
                      Text('${item['status']}', style: TextStyle(color: accepted ? const Color(0xFF55D4B0) : _subdued, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: load, icon: const Icon(Icons.refresh, size: 16), label: const Text('Шинэчлэх'))),
              ])),
        if (courses.isNotEmpty) ...[
          const SizedBox(height: 30),
          sectionTitle('Санал болгох сургалт', 'Одоогоор нийтлэгдсэн сургалтууд.'),
          const SizedBox(height: 14),
          surface(Column(children: [
            ...courses.take(3).map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: iconBox(Icons.school_outlined, const Color(0xFFBE9BFF)),
              title: Text('${c['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${c['level']} • ${(c['lessons'] as List?)?.length ?? 0} хичээл'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () => widget.onNavigate(2),
            )),
          ])),
        ],
        const SizedBox(height: 6),
      ]);
    });
  }
}
