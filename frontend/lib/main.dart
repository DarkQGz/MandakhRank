import 'dart:async';

import 'package:flutter/material.dart';

import 'data.dart';
import 'auth_screen.dart';
import 'practice_screen.dart';

const bg = Color(0xFF080E1C);
const panel = Color(0xFF111C30);
const blue = Color(0xFF4C86FF);
const muted = Color(0xFF96A8C5);
void main() => runApp(const MandakhApp());

class MandakhApp extends StatelessWidget {
  const MandakhApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mandakhrank',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue,
        brightness: Brightness.dark,
        surface: panel,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: panel),
      dividerColor: const Color(0xFF22314A),
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
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

  int page = 0;
  String query = '', difficulty = 'Бүгд', topic = 'Бүгд', level = 'Бүгд';
  final search = TextEditingController();
  final labels = ['Эрэмбэ', 'Бодлогууд', 'Сургалтууд', 'Тэмцээнүүд'];
  final icons = [
    Icons.emoji_events_outlined,
    Icons.code_rounded,
    Icons.school_outlined,
    Icons.flag_outlined,
  ];
  @override
  void initState() {
    super.initState();
    future = Repository().load();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
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
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: navigate,
              destinations: List.generate(
                4,
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
                decoration: const BoxDecoration(
                  color: Color(0xFF0C1425),
                  border: Border(right: BorderSide(color: Color(0xFF22314A))),
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    brand(),
                    const SizedBox(height: 48),
                    const Text(
                      'СУРАЛЦ. БОД. АХИ.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          selected: page == i,
                          selectedTileColor: blue.withOpacity(.16),
                          selectedColor: const Color(0xFF8DB0FF),
                          leading: Icon(icons[i]),
                          title: Text(labels[i]),
                          onTap: () => navigate(i),
                        ),
                      ),
                    ),
                    const Spacer(),
                    box(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome, color: blue),
                          const SizedBox(height: 12),
                          const Text(
                            'Өдөр бүр нэг алхам',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Нэг бодлогоос эхэл.\nЧадвараа хамтдаа хөгжүүлье.',
                            style: TextStyle(color: muted, height: 1.6),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => navigate(1),
                            child: const Text('Бодлого үзэх →'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
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
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off, size: 48, color: muted),
                            const SizedBox(height: 16),
                            const Text('Сервертэй холбогдож чадсангүй.'),
                            const Text(
                              'Django ажиллаж байгаа эсэх болон API_BASE_URL-ийг шалгана уу.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => setState(() {
                                liveData = null;
                                future = Repository().load();
                              }),
                              child: const Text('Дахин оролдох'),
                            ),
                          ],
                        ),
                      ),
                    );
                  final data = liveData ?? snapshot.data!;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 36 : 18),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (!wide)
                                  brand()
                                else
                                  Text(
                                    'Суралцах орчин / ${labels[page]}',
                                    style: const TextStyle(color: muted),
                                  ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () async {
                                    if (PracticeApi.token != null) {
                                      await PracticeApi.request(
                                        'auth/logout/',
                                        body: {},
                                      );
                                      PracticeApi.token = null;
                                      PracticeApi.username = null;
                                    } else {
                                      if (!context.mounted) return;
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute<bool>(
                                          builder: (_) => const AuthScreen(),
                                        ),
                                      );
                                    }
                                    if (mounted)
                                      setState(() {
                                        liveData = null;
                                        future = Repository().load();
                                      });
                                  },
                                  child: Text(
                                    PracticeApi.token == null
                                        ? 'Нэвтрэх'
                                        : 'Гарах',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Шинэчлэх',
                                  onPressed: () => setState(() {
                                    liveData = null;
                                    future = Repository().load();
                                  }),
                                  icon: const Icon(Icons.refresh),
                                ),
                                const Tooltip(
                                  message: 'Хэрэглэгч',
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: panel,
                                    child: Icon(Icons.person_outline, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
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
                            const SizedBox(height: 22),
                            if (page == 0)
                              rankings(data)
                            else if (page == 1)
                              problems(data)
                            else if (page == 2)
                              courses(data)
                            else
                              contests(data),
                            const SizedBox(height: 32),
                            const Text(
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

  Widget brand() => const Row(
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
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF22314A)),
    ),
    child: child,
  );
  Widget badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
  Widget title(String eyebrow, String heading, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: blue,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        heading,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(color: muted, height: 1.6)),
      const SizedBox(height: 26),
    ],
  );
  Widget searchField(String hint) => TextField(
    controller: search,
    onChanged: (v) => setState(() {
      query = v.toLowerCase().trim();
    }),
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search, color: muted),
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
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 40, color: muted),
          const SizedBox(height: 12),
          const Text('Илэрц олдсонгүй'),
          TextButton(
            onPressed: () => setState(() {
              query = '';
              search.clear();
              difficulty = 'Бүгд';
              topic = 'Бүгд';
              level = 'Бүгд';
            }),
            child: const Text('Шүүлтүүр арилгах'),
          ),
        ],
      ),
    ),
  );
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
                  const Color(0xFFFFCA6A),
                  const Color(0xFFAFC6EA),
                  const Color(0xFFDBA087),
                ][i];
                return SizedBox(
                  width: width,
                  child: box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            badge('#${p['rank'] ?? i + 1}', color),
                            const Spacer(),
                            Icon(
                              Icons.workspace_premium_outlined,
                              color: color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        CircleAvatar(
                          backgroundColor: color.withOpacity(.13),
                          child: Text(
                            (p['name'] as String).substring(0, 1),
                            style: TextStyle(color: color),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          p['name'],
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${p['handle']}',
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${p['score']} оноо',
                          style: TextStyle(
                            color: color,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${p['solved']} бодлого',
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
                    color: i == 0 ? const Color(0xFF142442) : null,
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 32),
        const Text(
          'Нийт эрэмбэ',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        searchField('Username хайх'),
        const SizedBox(height: 16),
        if (found.isEmpty)
          empty()
        else
          box(
            Column(
              children: found
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${p['rank'] ?? all.indexOf(p) + 1}'.padLeft(
                                2,
                                '0',
                              ),
                              style: const TextStyle(color: muted),
                            ),
                          ),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: blue.withOpacity(.14),
                            child: Text((p['name'] as String).substring(0, 1)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '@${p['handle']}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${p['score']}',
                                style: const TextStyle(
                                  color: Color(0xFF9BB9FF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${p['solved']} бодлого',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
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
              const Icon(Icons.code, size: 38, color: blue),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Жижиг алхам. Том ахиц.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${all.length} бодлого • ${all.where((p) => p['completed'] == true).length} бодсон',
                      style: const TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        searchField('Бодлогын нэр, сэдвээр хайх'),
        const SizedBox(height: 16),
        filters(
          ['Бүгд', 'Хялбар', 'Дунд', 'Хүнд'],
          difficulty,
          (v) => difficulty = v,
        ),
        const SizedBox(height: 12),
        filters(
          ['Бүгд', ...all.map((p) => p['topic'] as String).toSet()],
          topic,
          (v) => topic = v,
        ),
        const SizedBox(height: 20),
        Text('${found.length} бодлого', style: const TextStyle(color: muted)),
        const SizedBox(height: 12),
        if (found.isEmpty) empty(),
        ...found.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
                          style: const TextStyle(color: muted),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['completed'] == true ? '✓ ' : ''}${p['title']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                badge(
                                  p['difficulty'],
                                  p['difficulty'] == 'Хялбар'
                                      ? const Color(0xFF58D6AE)
                                      : p['difficulty'] == 'Дунд'
                                      ? Colors.amber
                                      : const Color(0xFFFF8197),
                                ),
                                badge(p['topic'], muted),
                                badge('${p['points']} оноо', blue),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: muted),
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
        const SizedBox(height: 20),
        Text(
          p['description'],
          style: const TextStyle(fontSize: 16, height: 1.7),
        ),
        const SizedBox(height: 24),
        const Text('Жишээ оролт', style: TextStyle(color: muted)),
        const SizedBox(height: 8),
        box(
          SelectableText(
            p['input'],
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Жишээ гаралт', style: TextStyle(color: muted)),
        const SizedBox(height: 8),
        box(
          SelectableText(
            p['output'],
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
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
        const SizedBox(height: 16),
        filters(
          ['Бүгд', 'Анхан шат', 'Дунд шат', 'Ахисан шат'],
          level,
          (v) => level = v,
        ),
        const SizedBox(height: 24),
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
                  'purple': const Color(0xFFB392FF),
                  'cyan': const Color(0xFF58D7EC),
                  'green': const Color(0xFF58D6AE),
                };
                final color = colors[course['color']]!;
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
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(Icons.data_object, size: 44, color: color),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  course['tag'],
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        badge(course['level'], color),
                        const SizedBox(height: 12),
                        Text(
                          course['title'],
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          course['description'],
                          style: const TextStyle(color: muted, height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '${(course['lessons'] as List).length} сэдэв • Сургалтын хөтөлбөр',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => courseDetail(course),
                            child: const Padding(
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
          style: const TextStyle(color: muted, height: 1.6),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          (c['lessons'] as List).length,
          (i) => ExpansionTile(
            title: Text(c['lessons'][i]),
            leading: Text('${i + 1}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    c['lesson_content'] != null
                        ? c['lesson_content'][i]['content'] as String
                        : 'Жишээ хөтөлбөр. Агуулгыг CMS-ээс нэмнэ.',
                    style: const TextStyle(height: 1.7),
                  ),
                ),
              ),
            ],
          ),
        ),
        if ((c['lessons'] as List).isEmpty)
          const Text('Хичээл хараахан нийтлэгдээгүй.'),
      ],
    ),
  );
  String contestFilter = 'Бүгд';
  String localTime(String value) {
    final d = DateTime.parse(value).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
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
          'CONTESTS',
          'Ур чадвараа сориорой.',
          'Тэмцээний хуваарь, бодлогууд болон дүнгийн хүснэгт.',
        ),
        searchField('Тэмцээний нэрээр хайх'),
        const SizedBox(height: 16),
        filters(
          ['Бүгд', 'Удахгүй', 'Явагдаж байна', 'Дууссан'],
          contestFilter,
          (v) => contestFilter = v,
        ),
        const SizedBox(height: 20),
        if (found.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Тэмцээн олдсонгүй. Нийтэлсэн тэмцээнүүд энд харагдана.',
            ),
          ),
        ...found.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  badge(c['status'], blue),
                  const SizedBox(height: 12),
                  Text(
                    c['title'],
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(c['description'], style: const TextStyle(color: muted)),
                  const SizedBox(height: 12),
                  Text(
                    '${localTime(c['starts_at'])} • ${c['duration_minutes']} минут',
                  ),
                  const Text(
                    'Цагийг таны төхөөрөмжийн бүсээр харуулав.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => contestDetail(c),
                    child: const Text('Тэмцээн үзэх →'),
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
        const SizedBox(height: 16),
        Text(c['announcement']),
        const SizedBox(height: 16),
        if (c['status'] == 'Удахгүй')
          const Text(
            'Бодлогууд тэмцээн эхлэхэд нээгдэнэ. Шинэчлэх товчоор дахин ачаална уу.',
          ),
        ...(c['problems'] as List).map(
          (p) => ExpansionTile(
            title: Text("${p['label']}. ${p['title']}"),
            subtitle: Text("${p['points']} оноо"),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(p['statement']),
                    const SizedBox(height: 16),
                    const Text('Жишээ оролт'),
                    SelectableText(p['input']),
                    const SizedBox(height: 12),
                    const Text('Жишээ гаралт'),
                    SelectableText(p['output']),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Дүнгийн хүснэгт',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Админы баталгаажуулсан оноо. Оноо тэнцвэл торгуулийн минут бага нь түрүүлнэ.',
          style: TextStyle(color: muted),
        ),
        if ((c['standings'] as List).isEmpty)
          const Padding(
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
        const SizedBox(height: 16),
        const Text(
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
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      heading,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Хаах',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              content,
            ],
          ),
        ),
      ),
    ),
  );
}
