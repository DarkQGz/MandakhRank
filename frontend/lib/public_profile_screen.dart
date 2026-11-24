import 'package:flutter/material.dart';
import 'data.dart';

class ProfileComments extends StatefulWidget {
  const ProfileComments({super.key, required this.userId, required this.onOpenProfile, this.initialData});
  final int userId;
  final Map<String, dynamic>? initialData;
  final ValueChanged<int> onOpenProfile;
  @override
  State<ProfileComments> createState() => _ProfileCommentsState();
}

class _ProfileCommentsState extends State<ProfileComments> {
  final controller = TextEditingController();
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> comments = [];
  int? cursor;
  bool loading = true, busy = false;
  String? error;
  String get endpoint => 'profile/public/${widget.userId}/';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    if (initial != null) {
      profile = initial;
      comments = (initial['comments'] as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
      cursor = initial['next_before'] as int?;
      loading = false;
    } else {
      load();
    }
  }
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  String message(Object e) => e is ApiException ? e.toString() : 'Сервертэй холбогдож чадсангүй. Дахин оролдоно уу.';

  Future<void> load({bool more = false}) async {
    if (!mounted || (more && cursor == null)) return;
    setState(() { loading = true; error = null; });
    try {
      final data = await PracticeApi.request(more ? '$endpoint?before=$cursor' : endpoint);
      final rows = (data['comments'] as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
      if (!mounted) return;
      setState(() {
        profile = data;
        comments = more ? [...comments, ...rows] : rows;
        cursor = data['next_before'] as int?;
      });
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> post() async {
    final body = controller.text.trim();
    if (busy || loading || body.isEmpty || body.runes.length > 500) return;
    setState(() { busy = true; error = null; });
    try {
      await PracticeApi.request(endpoint, body: {'body': body});
      if (!mounted) return;
      controller.clear();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(Map<String, dynamic> comment) async {
    if (busy || loading) return;
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Сэтгэгдэл устгах уу?'),
      content: const Text('Устгасан сэтгэгдлийг сэргээх боломжгүй.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Болих')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Устгах'))],
    ));
    if (yes != true || !mounted || busy || loading) return;
    setState(() { busy = true; error = null; });
    try {
      await PracticeApi.request('${endpoint}comments/${comment['id']}/delete/', body: {});
      if (!mounted) return;
      await load();
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}.${pad(d.month)}.${pad(d.day)}';
  }

  Widget avatar(String name, dynamic relative, double radius) {
    final url = ProfileApi.imageUrl(relative as String?);
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(radius: radius, backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      foregroundImage: url == null ? null : NetworkImage(url),
      onForegroundImageError: url == null ? null : (_, __) {},
      child: Text(name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase()));
  }

  @override
  Widget build(BuildContext context) {
    final data = profile;
    final colors = Theme.of(context).colorScheme;
    final disabled = loading || busy;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (loading) const LinearProgressIndicator(),
      if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!, style: TextStyle(color: colors.error))),
      if (data == null && !loading) OutlinedButton(onPressed: () => load(), child: const Text('Дахин оролдох')),
      if (data != null) ...[
              Row(children: [
                Expanded(child: Text('Сэтгэгдлүүд', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                IconButton(tooltip: 'Сэтгэгдэл шинэчлэх', onPressed: disabled ? null : () => load(), icon: const Icon(Icons.refresh)),
              ]),
              const SizedBox(height: 8),
              if (data['can_comment'] == true) ...[
                TextField(controller: controller, maxLength: 500, minLines: 2, maxLines: 5, enabled: !busy,
                  decoration: const InputDecoration(labelText: 'Сэтгэгдэл бичих', hintText: 'Хүндэтгэлтэй харилцаарай.')),
                Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: disabled ? null : post, icon: const Icon(Icons.send), label: const Text('Илгээх'))),
              ] else const Text('Сэтгэгдэл бичихийн тулд нэвтэрнэ үү.'),
              const SizedBox(height: 12),
              if (comments.isEmpty && !loading) const Padding(padding: EdgeInsets.all(12), child: Text('Одоогоор сэтгэгдэл алга.')),
              for (final c in comments) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  avatar(c['author'].toString(), c['avatar_url'], 18),
                  const SizedBox(width: 10),
                  Expanded(child: InkWell(onTap: c['author_id'] == widget.userId ? null : () => widget.onOpenProfile(c['author_id'] as int), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c['author'].toString(), style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(date(c['created_at']), style: Theme.of(context).textTheme.bodySmall),
                  ]))),
                  if (c['can_delete'] == true) IconButton(tooltip: 'Сэтгэгдэл устгах', onPressed: disabled ? null : () => remove(c), icon: const Icon(Icons.delete_outline)),
                ]),
                const SizedBox(height: 12),
                SelectableText(c['body'].toString()),
              ]))),
              if (cursor != null) OutlinedButton(onPressed: disabled ? null : () => load(more: true), child: const Text('Өмнөх сэтгэгдлүүдийг үзэх')),
      ],
    ]);
  }
}
