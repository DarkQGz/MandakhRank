import 'dart:async';

import 'package:flutter/material.dart';

import 'data.dart';
import 'auth_screen.dart';
import 'practice_screen.dart';
import 'dashboard_screen.dart';
import 'teacher_screen.dart';
import 'minigames_screen.dart';
import 'theme_settings.dart';
import 'learning_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PracticeApi.restoreSession();
  final palette = await MandakhPalette.load();
  runApp(MandakhApp(initialPalette: palette));
}

class MandakhApp extends StatefulWidget {
  const MandakhApp({super.key, this.initialPalette = MandakhPalette.original});
  final MandakhPalette initialPalette;
  @override
  State<MandakhApp> createState() => _MandakhAppState();
}

class _MandakhAppState extends State<MandakhApp> {
  late MandakhPalette palette = widget.initialPalette;
  @override
  Widget build(BuildContext context) => ThemeSettingsScope(
        palette: palette,
        onChanged: (value) => setState(() => palette = value),
        child: MaterialApp(
          title: 'Mandakhrank',
          debugShowCheckedModeBanner: false,
          theme: palette.themeData(),
          themeAnimationDuration: const Duration(milliseconds: 180),
          home: const Home(),
        ),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  MandakhPalette get palette => MandakhPalette.of(context);
  Color get bg => palette.background;
  Color get panel => palette.surface;
  Color get blue => palette.accentInk;
  Color get muted => palette.muted;
  late Future<Map<String, dynamic>> future;
  Timer? refreshTimer;
  bool refreshing = false;
  Map<String, dynamic>? liveData;
  Future<void> refreshLive() async {
    if (refreshing || Repository.base.isEmpty) return;
    refreshing = true;
    final tokenAtStart = PracticeApi.token;
    try {
      final data = await Repository().load();
      if (mounted && tokenAtStart == PracticeApi.token)
        setState(() {
          liveData = data;
        });
    } catch (_) {
      /* Keep the last successful view during a transient outage. */
    } finally {
      refreshing = false;
    }
  }

  int page = PracticeApi.token != null ? 4 : 0;
  String query = '', difficulty = 'Бүгд', topic = 'Бүгд', level = 'Бүгд';
  final search = TextEditingController();
  final labels = [
    'Эрэмбэ',
    'Бодлогууд',
    'Сургалтууд',
    'Тэмцээнүүд',
    'Миний самбар'
  ];
  final icons = [
    Icons.emoji_events_outlined,
    Icons.code_rounded,
    Icons.school_outlined,
    Icons.flag_outlined,
    Icons.space_dashboard_outlined,
  ];
  @override
  void initState() {
    super.initState();
    future = Repository().load();
    refreshTimer = Timer.periodic(
      Duration(seconds: 15),
      (_) => refreshLive(),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  void navigate(int value) => setState(() {
        page = value;
        query = '';
        search.clear();
      });
  Future<void> authAction() async {
    try {
      if (PracticeApi.token != null) {
        await PracticeApi.request('auth/logout/', body: {});
        await PracticeApi.signOut();
      } else {
        await Navigator.push(
            context, MaterialPageRoute<bool>(builder: (_) => AuthScreen()));
      }
    } catch (_) {
      // Temporary network failures must not leave the user stranded on logout.
      if (PracticeApi.token != null) await PracticeApi.signOut();
    }
    if (mounted)
      setState(() {
        liveData = null;
        future = Repository().load();
        if (PracticeApi.token != null) page = 4;
      });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 950 && MediaQuery.sizeOf(context).height >= 620;
    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              labelBehavior: MediaQuery.sizeOf(context).width < 600
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: page,
              onDestinationSelected: navigate,
              destinations: List.generate(
                5,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: labels[i],
                ),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 224,
                decoration: BoxDecoration(
                  color: panel,
                  border: Border(right: BorderSide(color: palette.outline)),
                ),
                padding: const EdgeInsets.all(16),
                child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        brand(),
                        const SizedBox(height: 32),
                        Text('ҮНДСЭН ЦЭС',
                            style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ...[4, 0, 1, 2, 3].map((i) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  selected: page == i,
                                  selectedTileColor: palette.tint,
                                  selectedColor: blue,
                                  leading: Icon(icons[i], size: 22),
                                  title: Text(labels[i],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  onTap: () => navigate(i)),
                            )),
                        ListTile(
                            dense: true,
                            leading: Icon(Icons.sports_esports_outlined,
                                color: muted),
                            title: const Text('Тоглоомууд'),
                            onTap: openMiniGames),
                        const Spacer(),
                        const Divider(),
                        ListTile(
                            dense: true,
                            leading: Icon(Icons.palette_outlined, color: muted),
                            title: const Text('Өнгө, загвар'),
                            onTap: () => openThemeSettings(context)),
                        ListTile(
                            dense: true,
                            leading: Icon(Icons.person_outline, color: muted),
                            title: Text(PracticeApi.username ?? 'Нэвтрэх',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => PracticeApi.token == null
                                ? authAction()
                                : navigate(4)),
                      ],
                    )),
              ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return Semantics(
                        label: 'Өгөгдөл ачаалж байна',
                        child: ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                      width: 180,
                                      height: 25,
                                      decoration: BoxDecoration(
                                          color: palette.tint,
                                          borderRadius:
                                              BorderRadius.circular(6)))),
                              const SizedBox(height: 20),
                              for (var i = 0; i < 4; i++)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                        height: 88,
                                        decoration: BoxDecoration(
                                            color: panel,
                                            border: Border.all(
                                                color: palette.outline),
                                            borderRadius:
                                                BorderRadius.circular(14)))),
                              const LinearProgressIndicator(minHeight: 2),
                            ]));
                  if (snapshot.hasError)
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off, size: 48, color: muted),
                            SizedBox(height: 16),
                            Text('Сервертэй холбогдож чадсангүй.'),
                            Text(
                              'Django ажиллаж байгаа эсэх болон API_BASE_URL-ийг шалгана уу.',
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => setState(() {
                                liveData = null;
                                future = Repository().load();
                              }),
                              child: Text('Дахин оролдох'),
                            ),
                            TextButton.icon(
                                onPressed: () => openThemeSettings(context),
                                icon: Icon(Icons.palette_outlined),
                                label: Text('Өнгө, загвар')),
                          ],
                        ),
                      ),
                    );
                  final data = liveData ?? snapshot.data!;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 32 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: wide
                                      ? Text('Нүүр / ${labels[page]}',
                                          style: TextStyle(
                                              color: muted, fontSize: 13))
                                      : brand()),
                              IconButton(
                                  tooltip: PracticeApi.token == null
                                      ? 'Нэвтрэх'
                                      : 'Гарах',
                                  onPressed: authAction,
                                  icon: Icon(
                                      PracticeApi.token == null
                                          ? Icons.login_rounded
                                          : Icons.logout_rounded,
                                      size: 20)),
                              IconButton(
                                  tooltip: 'Өнгө, загвар',
                                  onPressed: () => openThemeSettings(context),
                                  icon: const Icon(Icons.palette_outlined,
                                      size: 20)),
                              IconButton(
                                  tooltip: 'Шинэчлэх',
                                  onPressed: () => setState(() {
                                        liveData = null;
                                        future = Repository().load();
                                      }),
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 20)),
                              IconButton(
                                  tooltip: 'Миний самбар / Зураг солих',
                                  onPressed: () => navigate(4),
                                  icon: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: palette.tint,
                                      backgroundImage:
                                          PracticeApi.avatarUrl == null
                                              ? null
                                              : NetworkImage(
                                                  PracticeApi.avatarUrl!),
                                      child: PracticeApi.avatarUrl == null
                                          ? Icon(Icons.person_outline,
                                              size: 18, color: blue)
                                          : null)),
                            ]),
                            const SizedBox(height: 12),
                            Divider(color: palette.outline),
                            const SizedBox(height: 20),
                            if (Repository.base.isEmpty) ...[
                              badge('Жишээ өгөгдөл', Colors.amber),
                              const SizedBox(height: 12)
                            ],
                            if (page == 0)
                              rankings(data)
                            else if (page == 1)
                              problems(data)
                            else if (page == 2)
                              courses(data)
                            else if (page == 3)
                              contests(data)
                            else
                              StudentDashboard(
                                catalog: data,
                                onNavigate: navigate,
                                onLogin: authAction,
                                onAvatarChanged: () {
                                  if (mounted) setState(() {});
                                },
                                onOpenProfile: (id) =>
                                    openStudentProfile(id, data),
                              ),
                            SizedBox(height: 32),
                            Text(
                              'Mandakhrank • Монгол хэлээр кодлож суръя.',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget brand() => Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: palette.button,
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.code_rounded,
                    color: palette.onButton, size: 21)),
            const SizedBox(width: 8),
            Text.rich(
                TextSpan(text: 'mandakh', children: [
                  TextSpan(text: 'rank', style: TextStyle(color: blue))
                ]),
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5)),
          ])));
  Widget box(Widget child, {Color? color}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.outline),
        ),
        child: child,
      );
  Widget badge(String text, Color color) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: palette.readable(color),
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
      );
  Widget title(String eyebrow, String heading, String subtitle) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(heading,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.6)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: TextStyle(color: muted, height: 1.45, fontSize: 14)),
        const SizedBox(height: 20),
      ]);
  Widget searchField(String hint) => TextField(
        controller: search,
        onChanged: (v) => setState(() {
          query = v.toLowerCase().trim();
        }),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: muted),
          hintText: hint,
        ),
      );
  Widget filters(
    List<String> choices,
    String selected,
    void Function(String) select,
  ) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: choices
            .map(
              (c) => ChoiceChip(
                label: Text(c),
                selected: selected == c,
                onSelected: (_) => setState(() => select(c)),
              ),
            )
            .toList(),
      );
  List<Map<String, dynamic>> items(Map<String, dynamic> data, String key) =>
      (data[key] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Widget empty() => Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 40, color: muted),
              SizedBox(height: 12),
              Text('Илэрц олдсонгүй'),
              TextButton(
                onPressed: () => setState(() {
                  query = '';
                  search.clear();
                  difficulty = 'Бүгд';
                  topic = 'Бүгд';
                  level = 'Бүгд';
                }),
                child: Text('Шүүлтүүр арилгах'),
              ),
            ],
          ),
        ),
      );
  void openStudentProfile(int id, Map<String, dynamic> data) {
    if (id <= 0 || Repository.base.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
              appBar: AppBar(title: const Text('Профайл')),
              body: SafeArea(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                    child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: StudentDashboard(
                    userId: id,
                    catalog: data,
                    onNavigate: (page) {
                      Navigator.of(routeContext)
                          .popUntil((route) => route.isFirst);
                      if (mounted) navigate(page);
                    },
                    onLogin: authAction,
                    onAvatarChanged: () {
                      if (mounted) setState(() {});
                    },
                    onOpenProfile: (otherId) =>
                        openStudentProfile(otherId, data),
                  ),
                )),
              )),
            )));
  }

  Widget rankingCard(
      Map<String, dynamic> person, Map<String, dynamic> data, Widget child,
      {required bool featured, Color? color}) {
    final id = int.tryParse('${person['id']}');
    final isTeacher = person['role'] == 'teacher';
    return Material(
      color: isTeacher ? teacherSurface(context) : (color ?? panel),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isTeacher ? teacherAccent(context) : palette.outline, width: isTeacher ? 1.5 : 1)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('rank-card-${featured ? 'top' : 'row'}-$id'),
        onTap: id == null || id <= 0 || Repository.base.isEmpty
            ? null
            : () => openStudentProfile(id, data),
        child: Padding(padding: EdgeInsets.all(featured ? 8 : 12), child: isTeacher ? Column(crossAxisAlignment: featured ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [child, const SizedBox(height: 6), const TeacherRoleChip()]) : child),
      ),
    );
  }

  Widget rankings(Map<String, dynamic> data) {
    final all = items(data, 'rankings');
    final found = all
        .where(
          (p) => '${p['name']} ${p['handle']} ${p['school']}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title(
          'LEADERBOARD',
          'Эрэмбэ',
          'Шилдэг суралцагчид · 15 секунд тутам шинэчлэгдэнэ.',
        ),
        LayoutBuilder(builder: (context, c) {
          final count = all.length < 3 ? all.length : 3;
          if (count == 0) return const SizedBox.shrink();
          final order = count == 3 ? [1, 0, 2] : List.generate(count, (i) => i);
          final width = (c.maxWidth - 8 * (count - 1)) / count;
          return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final i in order) ...[
              if (i != order.first) const SizedBox(width: 8),
              SizedBox(
                  width: width,
                  child: rankingCard(
                      all[i],
                      data,
                      Column(children: [
                        Text('#${all[i]['rank'] ?? i + 1}',
                            style: TextStyle(
                                color: palette.readable([
                                  const Color(0xFFFFCA6A),
                                  const Color(0xFFAFC6EA),
                                  const Color(0xFFDBA087)
                                ][i]),
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        const SizedBox(height: 10),
                        CircleAvatar(
                            radius: c.maxWidth < 440 ? 18 : 27,
                            backgroundColor: palette.tint,
                            backgroundImage: ProfileApi.imageUrl(
                                        all[i]['avatar_url'] as String?) ==
                                    null
                                ? null
                                : NetworkImage(ProfileApi.imageUrl(
                                    all[i]['avatar_url'] as String?)!),
                            child: all[i]['avatar_url'] == null
                                ? Icon(Icons.person_outline, color: blue)
                                : null),
                        const SizedBox(height: 8),
                        Text('${all[i]['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('${all[i]['score']}',
                                style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: blue))),
                        Text('оноо',
                            style: TextStyle(color: muted, fontSize: 11)),
                        SizedBox(height: i == 0 ? 16 : 4),
                      ]),
                      featured: true,
                      color: i == 0 ? palette.tint : null)),
            ],
          ]);
        }),
        SizedBox(height: 32),
        Text(
          'Нийт эрэмбэ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        searchField('Хэрэглэгч хайх'),
        SizedBox(height: 16),
        if (found.isEmpty)
          empty()
        else
          Column(
            children: found
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: rankingCard(
                        p,
                        data,
                        Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${p['rank'] ?? all.indexOf(p) + 1}'.padLeft(
                                  2,
                                  '0',
                                ),
                                style: TextStyle(color: muted),
                              ),
                            ),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: blue.withOpacity(.14),
                              backgroundImage: ProfileApi.imageUrl(
                                          p['avatar_url'] as String?) ==
                                      null
                                  ? null
                                  : NetworkImage(ProfileApi.imageUrl(
                                      p['avatar_url'] as String?)!),
                              child: p['avatar_url'] == null
                                  ? Text((p['name'] as String).substring(0, 1))
                                  : null,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['name'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '@${p['handle']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${p['score']}',
                                  style: TextStyle(
                                    color: blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${p['solved']} бодлого',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        featured: false),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget problems(Map<String, dynamic> data) {
    final all = items(data, 'problems');
    final found = all
        .where(
          (p) =>
              '${p['title']} ${p['topic']}'.toLowerCase().contains(query) &&
              (difficulty == 'Бүгд' || p['difficulty'] == difficulty) &&
              (topic == 'Бүгд' || p['topic'] == topic),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title(
          'PROBLEM SET',
          'Бодлогууд',
          'Энгийн бодлогоос эхлээд алгоритмын ур чадвараа алхам алхмаар хөгжүүл.',
        ),
        box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('Таны ахиц',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            Text(
                '${all.where((p) => p['completed'] == true).length} / ${all.length}',
                style: TextStyle(color: blue, fontWeight: FontWeight.w700))
          ]),
          const SizedBox(height: 12),
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  minHeight: 6,
                  value: all.isEmpty
                      ? 0.0
                      : all.where((p) => p['completed'] == true).length /
                          all.length,
                  backgroundColor: palette.tint)),
        ])),
        SizedBox(height: 24),
        searchField('Бодлогын нэр, сэдвээр хайх'),
        SizedBox(height: 16),
        filters(
          ['Бүгд', 'Анхан шат', 'Хялбар', 'Дунд', 'Хүнд', 'Мэргэжлийн'],
          difficulty,
          (v) => difficulty = v,
        ),
        SizedBox(height: 12),
        filters(
          ['Бүгд', ...all.map((p) => p['topic'] as String).toSet()],
          topic,
          (v) => topic = v,
        ),
        SizedBox(height: 20),
        Text('${found.length} бодлого', style: TextStyle(color: muted)),
        SizedBox(height: 12),
        if (found.isEmpty) empty(),
        ...found.map(
          (p) => Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Material(
              color: panel,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: palette.outline)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => problemDetail(p),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${p['id']}'.padLeft(2, '0'),
                          style: TextStyle(color: muted),
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['completed'] == true ? '✓ ' : ''}${p['title']}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                badge(
                                  p['difficulty'],
                                  p['difficulty'] == 'Хялбар'
                                      ? Color(0xFF58D6AE)
                                      : p['difficulty'] == 'Дунд'
                                          ? Colors.amber
                                          : Color(0xFFFF8197),
                                ),
                                badge(p['topic'], muted),
                                badge('${p['points']} оноо', blue),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> problemDetail(Map<String, dynamic> p) async {
    if (Repository.base.isEmpty) {
      demoProblemDetail(p);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PracticeScreen(problem: p)),
    );
    if (mounted)
      setState(() {
        liveData = null;
        future = Repository().load();
      });
  }

  void demoProblemDetail(Map<String, dynamic> p) => detail(
        p['title'],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            badge('${p['difficulty']} • ${p['points']} оноо', blue),
            SizedBox(height: 20),
            Text(
              p['description'],
              style: TextStyle(fontSize: 16, height: 1.7),
            ),
            SizedBox(height: 24),
            Text('Жишээ оролт', style: TextStyle(color: muted)),
            SizedBox(height: 8),
            box(
              SelectableText(
                p['input'],
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
            SizedBox(height: 16),
            Text('Жишээ гаралт', style: TextStyle(color: muted)),
            SizedBox(height: 8),
            box(
              SelectableText(
                p['output'],
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Энэ хувилбар нь бодлогын загвар. Код илгээх, ажиллуулах, оноо тооцох боломж дараагийн хувилбарт нэмэгдэнэ.',
              style: TextStyle(color: muted, height: 1.5),
            ),
          ],
        ),
      );
  Widget courses(Map<String, dynamic> data) => LearningLibrary(
    courses: items(data, 'courses'),
    onOpen: courseDetail,
  );

  Future<void> courseDetail(Map<String, dynamic> c) async {
    final id = int.tryParse('${c['id']}');
    if (id == null || Repository.base.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сургалтыг сервертэй холбогдож үзнэ үү.')));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LearningCourseScreen(courseId: id, title: '${c['title']}')));
    if (mounted) {
      setState(() { liveData = null; future = Repository().load(); });
    }
  }
  String contestFilter = 'Бүгд';
  String localTime(String value) {
    final d = DateTime.parse(value).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> openMiniGames() async {
    if (PracticeApi.token == null) await authAction();
    if (!mounted || PracticeApi.token == null) return;
    await Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => MiniGamesLobby()));
  }

  Widget contests(Map<String, dynamic> data) {
    final found = items(data, 'contests')
        .where(
          (c) =>
              (c['title'] as String).toLowerCase().contains(query) &&
              (contestFilter == 'Бүгд' || c['status'] == contestFilter),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title(
          'ТЭМЦЭЭНҮҮД',
          'Тэмцээнүүд',
          'Тэмцээний хуваарь, бодлогууд болон дүнгийн хүснэгт.',
        ),
        MiniGamesPreview(onPlay: openMiniGames),
        searchField('Тэмцээний нэрээр хайх'),
        SizedBox(height: 16),
        filters(
          ['Бүгд', 'Удахгүй', 'Явагдаж байна', 'Дууссан'],
          contestFilter,
          (v) => contestFilter = v,
        ),
        SizedBox(height: 20),
        if (found.isEmpty)
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Тэмцээн олдсонгүй. Нийтэлсэн тэмцээнүүд энд харагдана.',
            ),
          ),
        ...found.map(
          (c) => Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 86,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: palette.tint,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('MANDAKHRANK',
                                  style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.4,
                                      color: blue,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              const Text('Кодын сорилт',
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700)),
                            ])),
                        Icon(Icons.emoji_events_outlined,
                            color: blue, size: 42),
                      ])),
                  const SizedBox(height: 14),
                  badge(c['status'], c['status'] == 'Явагдаж байна' ? palette.positive : blue),
                  if (c['organizer'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Зохион байгуулагч: ${c['organizer']}', style: TextStyle(color: teacherAccent(context), fontWeight: FontWeight.w600))),
                  const SizedBox(height: 12),
                  Text(
                    c['title'],
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(c['description'], style: TextStyle(color: muted)),
                  SizedBox(height: 12),
                  Text(
                    '${localTime(c['starts_at'])} • ${c['duration_minutes']} минут',
                  ),
                  Text(
                    'Цагийг таны төхөөрөмжийн бүсээр харуулав.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                  SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => contestDetail(c),
                    child: Text('Тэмцээн үзэх'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void contestDetail(Map<String, dynamic> c) => detail(
        c['title'],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            badge(c['status'], blue),
            if (c['organizer'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Зохион байгуулагч: ${c['organizer']}', style: TextStyle(color: teacherAccent(context), fontWeight: FontWeight.w600))),
            SizedBox(height: 16),
            Text(c['announcement']),
            SizedBox(height: 16),
            if (c['status'] == 'Удахгүй')
              Text(
                'Бодлогууд тэмцээн эхлэхэд нээгдэнэ. Шинэчлэх товчоор дахин ачаална уу.',
              ),
            ...(c['problems'] as List).map(
              (p) => ExpansionTile(
                title: Text("${p['label']}. ${p['title']}"),
                subtitle: Text("${p['points']} оноо"),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(p['statement']),
                        SizedBox(height: 16),
                        Text('Жишээ оролт'),
                        SelectableText(p['input']),
                        SizedBox(height: 12),
                        Text('Жишээ гаралт'),
                        SelectableText(p['output']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Дүнгийн хүснэгт',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Админы баталгаажуулсан оноо. Оноо тэнцвэл торгуулийн минут бага нь түрүүлнэ.',
              style: TextStyle(color: muted),
            ),
            if ((c['standings'] as List).isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Дүн хараахан ороогүй.'),
              ),
            ...(c['standings'] as List).map(
              (r) => ListTile(
                leading: Text("#${r['rank']}"),
                title: Text(r['participant']),
                subtitle: Text("Торгууль: ${r['penalty']} минут"),
                trailing: Text("${r['score']} оноо"),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Код илгээх, автоматаар шалгах боломж энэ хувилбарт ороогүй.',
              style: TextStyle(color: muted),
            ),
          ],
        ),
      );
  void detail(String heading, Widget content) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
              appBar: AppBar(
                  title: Text(heading,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              body: SafeArea(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: box(content))))),
            )));
  }
}
