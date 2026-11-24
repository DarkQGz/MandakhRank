import 'dart:async';

import 'package:flutter/material.dart';

import 'data.dart';
import 'auth_screen.dart';
import 'practice_screen.dart';
import 'dashboard_screen.dart';
import 'minigames_screen.dart';
import 'theme_settings.dart';

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
      title: 'Mandakhrank', debugShowCheckedModeBanner: false,
      theme: palette.themeData(), themeAnimationDuration: Duration.zero,
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
  final labels = ['Эрэмбэ', 'Бодлогууд', 'Сургалтууд', 'Тэмцээнүүд', 'Миний самбар'];
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
        await Navigator.push(context, MaterialPageRoute<bool>(builder: (_) => AuthScreen()));
      }
    } catch (_) {
      // Temporary network failures must not leave the user stranded on logout.
      if (PracticeApi.token != null) await PracticeApi.signOut();
    }
    if (mounted) setState(() {
      liveData = null;
      future = Repository().load();
      if (PracticeApi.token != null) page = 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 950;
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
                width: 238,
                decoration: BoxDecoration(
                  color: panel,
                  border: Border(right: BorderSide(color: palette.outline)),
                ),
                padding: EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brand(),
                    SizedBox(height: 48),
                    Text(
                      'СУРАЛЦ. БОД. АХИ.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 20),
                    ...List.generate(
                      5,
                      (i) => Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          selected: page == i,
                          selectedTileColor: blue.withOpacity(.16),
                          selectedColor: blue,
                          leading: Icon(icons[i]),
                          title: Text(labels[i]),
                          onTap: () => navigate(i),
                        ),
                      ),
                    ),
                    Spacer(),
                    box(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome, color: blue),
                          SizedBox(height: 12),
                          Text(
                            'Өдөр бүр нэг алхам',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Нэг бодлогоос эхэл.\nЧадвараа хамтдаа хөгжүүлье.',
                            style: TextStyle(color: muted, height: 1.6),
                          ),
                          SizedBox(height: 12),
                          TextButton(
                            onPressed: () => navigate(1),
                            child: Text('Бодлого үзэх →'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'MANDАKHRANK / v0.1',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return Center(child: CircularProgressIndicator());
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
                            TextButton.icon(onPressed: () => openThemeSettings(context), icon: Icon(Icons.palette_outlined), label: Text('Өнгө, загвар')),
                          ],
                        ),
                      ),
                    );
                  final data = liveData ?? snapshot.data!;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 36 : 18),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!wide && width < 600) ...[brand(), SizedBox(height: 8)],
                            Row(
                              children: [
                                if (!wide && width >= 600)
                                  brand()
                                else if (wide)
                                  Text(
                                    'Суралцах орчин / ${labels[page]}',
                                    style: TextStyle(color: muted),
                                  ),
                                Spacer(),
                                TextButton(
                                  onPressed: authAction,
                                  child: Text(
                                    PracticeApi.token == null
                                        ? 'Нэвтрэх'
                                        : 'Гарах',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Өнгө, загвар',
                                  onPressed: () => openThemeSettings(context),
                                  icon: Icon(Icons.palette_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Шинэчлэх',
                                  onPressed: () => setState(() {
                                    liveData = null;
                                    future = Repository().load();
                                  }),
                                  icon: Icon(Icons.refresh),
                                ),
                                IconButton(
                                  tooltip: 'Миний самбар / Зураг солих',
                                  onPressed: () => navigate(4),
                                  icon: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: panel,
                                    backgroundImage: PracticeApi.avatarUrl == null ? null : NetworkImage(PracticeApi.avatarUrl!),
                                    child: PracticeApi.avatarUrl == null ? Icon(Icons.person_outline, size: 20) : null,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (Repository.base.isEmpty)
                                  badge('ЖИШЭЭ ӨГӨГДӨЛ', Colors.amber),
                                badge(
                                  Repository.base.isEmpty
                                      ? 'Demo горим'
                                      : 'Шууд шинэчлэгдэнэ',
                                  blue,
                                ),
                              ],
                            ),
                            SizedBox(height: 22),
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
                                onAvatarChanged: () { if (mounted) setState(() {}); },
                                onOpenProfile: (id) => openStudentProfile(id, data),
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

  Widget brand() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.terminal_rounded, color: blue, size: 30),
      SizedBox(width: 9),
      Text(
        'mandakh',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      Text(
        'rank',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: blue,
        ),
      ),
    ],
  );
  Widget box(Widget child, {Color? color}) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? panel,
      borderRadius: BorderRadius.circular(18),
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
      style: TextStyle(color: palette.readable(color), fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
  Widget title(String eyebrow, String heading, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: TextStyle(
          color: blue,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: 10),
      Text(
        heading,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
        ),
      ),
      SizedBox(height: 8),
      Text(subtitle, style: TextStyle(color: muted, height: 1.6)),
      SizedBox(height: 26),
    ],
  );
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
  ) => Wrap(
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
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (routeContext) => Scaffold(
      appBar: AppBar(title: const Text('Профайл')),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: StudentDashboard(
            userId: id,
            catalog: data,
            onNavigate: (page) {
              Navigator.of(routeContext).popUntil((route) => route.isFirst);
              if (mounted) navigate(page);
            },
            onLogin: authAction,
            onAvatarChanged: () { if (mounted) setState(() {}); },
            onOpenProfile: (otherId) => openStudentProfile(otherId, data),
          ),
        )),
      )),
    )));
  }

  Widget rankingCard(Map<String, dynamic> person, Map<String, dynamic> data,
      Widget child, {required bool featured, Color? color}) {
    final id = int.tryParse('${person['id']}');
    return Material(
      color: color ?? panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('rank-card-${featured ? 'top' : 'row'}-$id'),
        onTap: id == null || id <= 0 || Repository.base.isEmpty ? null : () => openStudentProfile(id, data),
        child: Padding(padding: EdgeInsets.all(featured ? 20 : 12), child: child),
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
          'Өнөөдрийн хичээл зүтгэл,\nмаргаашийн амжилт.',
          'Accepted болсон бодлого бүрийн оноог нэг удаа тооцно. Эрэмбэ 15 секунд тутам шинэчлэгдэнэ.',
        ),
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth < 600 ? c.maxWidth : (c.maxWidth - 28) / 3;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: List.generate(all.length < 3 ? all.length : 3, (i) {
                final p = all[i];
                final color = [
                  Color(0xFFFFCA6A),
                  Color(0xFFAFC6EA),
                  Color(0xFFDBA087),
                ][i];
                return SizedBox(
                  width: width,
                  child: rankingCard(p, data,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            badge('#${p['rank'] ?? i + 1}', color),
                            Spacer(),
                            Icon(
                              Icons.workspace_premium_outlined,
                              color: palette.readable(color),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        CircleAvatar(
                          radius: 23,
                          backgroundColor: color.withOpacity(.13),
                          backgroundImage: ProfileApi.imageUrl(p['avatar_url'] as String?) == null
                              ? null
                              : NetworkImage(ProfileApi.imageUrl(p['avatar_url'] as String?)!),
                          child: p['avatar_url'] == null
                              ? Text((p['name'] as String).substring(0, 1), style: TextStyle(color: color))
                              : null,
                        ),
                        SizedBox(height: 14),
                        Text(
                          p['name'],
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${p['handle']}',
                          style: TextStyle(color: muted),
                        ),
                        SizedBox(height: 18),
                        Text(
                          '${p['score']} оноо',
                          style: TextStyle(
                            color: palette.readable(color),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${p['solved']} бодлого',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                    featured: true,
                    color: i == 0 ? palette.tint : null,
                  ),
                );
              }),
            );
          },
        ),
        SizedBox(height: 32),
        Text(
          'Нийт эрэмбэ',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        searchField('Username хайх'),
        SizedBox(height: 16),
        if (found.isEmpty)
          empty()
        else
          Column(
              children: found
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: rankingCard(p, data, Row(
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
                            backgroundImage: ProfileApi.imageUrl(p['avatar_url'] as String?) == null ? null : NetworkImage(ProfileApi.imageUrl(p['avatar_url'] as String?)!),
                            child: p['avatar_url'] == null ? Text((p['name'] as String).substring(0, 1)) : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'],
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '@${p['handle']}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
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
                      ), featured: false),
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
          'Дараагийн сорилтоо сонго.',
          'Энгийн бодлогоос эхлээд алгоритмын ур чадвараа алхам алхмаар хөгжүүл.',
        ),
        box(
          Row(
            children: [
              Icon(Icons.code, size: 38, color: blue),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Жижиг алхам. Том ахиц.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${all.length} бодлого • ${all.where((p) => p['completed'] == true).length} бодсон',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        searchField('Бодлогын нэр, сэдвээр хайх'),
        SizedBox(height: 16),
        filters(
          ['Бүгд', 'Хялбар', 'Дунд', 'Хүнд'],
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
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => problemDetail(p),
                child: box(
                  Row(
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
  Widget courses(Map<String, dynamic> data) {
    final found = items(data, 'courses')
        .where(
          (c) =>
              '${c['title']} ${c['tag']}'.toLowerCase().contains(query) &&
              (level == 'Бүгд' || c['level'] == level),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title(
          'LEARNING PATHS',
          'Мэдлэгээ дараагийн\nтүвшинд хүргэ.',
          'Монгол хэлээр ойлгож, өөрийн хурдаар суралц. Чиглэлээ сонгоод эхэлцгээе.',
        ),
        searchField('Сургалт хайх'),
        SizedBox(height: 16),
        filters(
          ['Бүгд', 'Анхан шат', 'Дунд шат', 'Ахисан шат'],
          level,
          (v) => level = v,
        ),
        SizedBox(height: 24),
        if (found.isEmpty) empty(),
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth < 650 ? c.maxWidth : (c.maxWidth - 18) / 2;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: found.map((course) {
                final colors = {
                  'blue': blue,
                  'purple': Color(0xFFB392FF),
                  'cyan': Color(0xFF58D7EC),
                  'green': Color(0xFF58D6AE),
                };
                final color = palette.readable(colors[course['color']] ?? blue);
                return SizedBox(
                  width: width,
                  child: box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 105,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withOpacity(.22), bg],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(Icons.data_object, size: 44, color: color),
                              Spacer(),
                              Text(
                                course['tag'],
                                style: TextStyle(
                                  fontSize: 18,
                                  color: palette.readable(color),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        badge(course['level'], color),
                        SizedBox(height: 12),
                        Text(
                          course['title'],
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          course['description'],
                          style: TextStyle(color: muted, height: 1.6),
                        ),
                        SizedBox(height: 20),
                        Text(
                          '${(course['lessons'] as List).length} сэдэв • Сургалтын хөтөлбөр',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => courseDetail(course),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Хөтөлбөр үзэх →'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void courseDetail(Map<String, dynamic> c) => detail(
    c['title'],
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c['description'],
          style: TextStyle(color: muted, height: 1.6),
        ),
        SizedBox(height: 16),
        ...List.generate(
          (c['lessons'] as List).length,
          (i) => ExpansionTile(
            title: Text(c['lessons'][i]),
            leading: Text('${i + 1}'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    c['lesson_content'] != null
                        ? c['lesson_content'][i]['content'] as String
                        : 'Жишээ хөтөлбөр. Агуулгыг CMS-ээс нэмнэ.',
                    style: TextStyle(height: 1.7),
                  ),
                ),
              ),
            ],
          ),
        ),
        if ((c['lessons'] as List).isEmpty)
          Text('Хичээл хараахан нийтлэгдээгүй.'),
      ],
    ),
  );
  String contestFilter = 'Бүгд';
  String localTime(String value) {
    final d = DateTime.parse(value).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> openMiniGames() async {
    if (PracticeApi.token == null) await authAction();
    if (!mounted || PracticeApi.token == null) return;
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MiniGamesLobby()));
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
          'Ур чадвараа сориорой.',
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
                  badge(c['status'], blue),
                  SizedBox(height: 12),
                  Text(
                    c['title'],
                    style: TextStyle(
                      fontSize: 23,
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
                    child: Text('Тэмцээн үзэх →'),
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
  void detail(String heading, Widget content) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      heading,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Хаах',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 20),
              content,
            ],
          ),
        ),
      ),
    ),
  );
}
