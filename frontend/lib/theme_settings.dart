import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-selected opaque colors. Game artwork keeps its own team colors.
class MandakhPalette {
  const MandakhPalette(this.background, this.surface, this.text, this.accent);
  final Color background, surface, text, accent;
  static const original = MandakhPalette(Color(0xFF080E1C), Color(0xFF111C30), Color(0xFFE4E9F3), Color(0xFF4C86FF));
  static const light = MandakhPalette(Color(0xFFF5F7FB), Color(0xFFFFFFFF), Color(0xFF17243A), Color(0xFF245BC5));
  static const orange = MandakhPalette(Color(0xFFFFFFFF), Color(0xFFFFF8F0), Color(0xFF8F390C), Color(0xFFB54708));
  static const purple = MandakhPalette(Color(0xFF171022), Color(0xFF241A35), Color(0xFFECE4FA), Color(0xFFC3A0FF));
  static const midnight = MandakhPalette(Color(0xFF121212), Color(0xFF202020), Color(0xFFF1F1F1), Color(0xFFFFA64D));
  static const storageKey = 'mandakhrank.theme.v1';

  static MandakhPalette of(BuildContext context) => Theme.of(context).extension<MandakhTheme>()?.palette ?? original;
  Brightness get brightness => background.computeLuminance() > .40 ? Brightness.light : Brightness.dark;
  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
  }
  bool get isReadable => contrast(text, background) >= 4.5 && contrast(text, surface) >= 4.5;
  Color get muted => readable(Color.lerp(text, surface, .32)!);
  Color get outline => Color.lerp(surface, text, .29)!;
  Color get accentInk => readable(accent);
  Color get onAccent => contrast(accentInk, Colors.white) >= contrast(accentInk, Colors.black) ? Colors.white : Colors.black;
  Color get tint => Color.lerp(surface, accentInk, .09)!;
  Color readable(Color candidate) {
    for (var i = 0; i <= 20; i++) {
      final c = Color.lerp(candidate, text, i / 20)!;
      if (contrast(c, surface) >= 4.5 && contrast(c, background) >= 4.5) return c;
    }
    return text;
  }
  Color get positive => readable(const Color(0xFF3FAE83));
  Color get negative => readable(const Color(0xFFE36B78));
  MandakhPalette withColor(int index, Color value) => MandakhPalette(
    index == 0 ? value : background, index == 1 ? value : surface,
    index == 2 ? value : text, index == 3 ? value : accent,
  );
  List<Color> get colors => [background, surface, text, accent];
  Map<String, int> toJson() => {'background': background.value, 'surface': surface.value, 'text': text.value, 'accent': accent.value};
  factory MandakhPalette.fromJson(Map<String, dynamic> map) {
    Color read(String key) {
      final value = map[key];
      if (value is! int || value < 0xFF000000 || value > 0xFFFFFFFF) throw const FormatException('Invalid color');
      return Color(value);
    }
    final p = MandakhPalette(read('background'), read('surface'), read('text'), read('accent'));
    if (!p.isReadable) throw const FormatException('Invalid contrast');
    return p;
  }
  static Future<MandakhPalette> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);
      if (raw != null) return MandakhPalette.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) { /* Bad or unavailable storage falls back to the default. */ }
    return original;
  }
  Future<void> save() async {
    if (!isReadable) throw StateError('Unreadable theme');
    if (!await (await SharedPreferences.getInstance()).setString(storageKey, jsonEncode(toJson()))) {
      throw StateError('Theme storage unavailable');
    }
  }
  ThemeData themeData() {
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
      primary: accentInk, onPrimary: onAccent, primaryContainer: tint, onPrimaryContainer: text,
      secondary: accentInk, onSecondary: onAccent, secondaryContainer: tint, onSecondaryContainer: text,
      tertiary: accentInk, onTertiary: onAccent, tertiaryContainer: tint, onTertiaryContainer: text,
      surface: surface, onSurface: text, onSurfaceVariant: muted, surfaceTint: Colors.transparent,
      surfaceContainerLowest: background, surfaceContainerLow: surface, surfaceContainer: surface,
      surfaceContainerHigh: tint, surfaceContainerHighest: tint, outline: outline, outlineVariant: outline,
      error: negative, onError: contrast(negative, Colors.white) >= contrast(negative, Colors.black) ? Colors.white : Colors.black,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    return base.copyWith(
      extensions: [MandakhTheme(this)], scaffoldBackgroundColor: background, canvasColor: surface,
      cardColor: surface, dividerColor: outline,
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      primaryTextTheme: base.primaryTextTheme.apply(bodyColor: text, displayColor: text),
      iconTheme: IconThemeData(color: text),
      appBarTheme: AppBarTheme(backgroundColor: background, foregroundColor: text, surfaceTintColor: Colors.transparent),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: surface, indicatorColor: tint, labelTextStyle: WidgetStatePropertyAll(TextStyle(color: text))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface, hintStyle: TextStyle(color: muted), labelStyle: TextStyle(color: muted), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
      textSelectionTheme: TextSelectionThemeData(cursorColor: accentInk, selectionColor: accentInk.withOpacity(.25), selectionHandleColor: accentInk),
    );
  }
}

class MandakhTheme extends ThemeExtension<MandakhTheme> {
  const MandakhTheme(this.palette);
  final MandakhPalette palette;
  @override
  MandakhTheme copyWith({MandakhPalette? palette}) => MandakhTheme(palette ?? this.palette);
  @override
  MandakhTheme lerp(covariant MandakhTheme? other, double t) => t < .5 ? this : other ?? this;
}

/// Located above MaterialApp so all navigator routes share the same settings.
class ThemeSettingsScope extends InheritedWidget {
  const ThemeSettingsScope({super.key, required this.palette, required this.onChanged, required super.child});
  final MandakhPalette palette;
  final ValueChanged<MandakhPalette> onChanged;
  static ThemeSettingsScope? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ThemeSettingsScope>();
  @override
  bool updateShouldNotify(ThemeSettingsScope oldWidget) => palette != oldWidget.palette;
}

void openThemeSettings(BuildContext context) {
  final scope = ThemeSettingsScope.maybeOf(context);
  if (scope == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ThemeSettingsScreen(initial: scope.palette, onChanged: scope.onChanged)));
}

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key, required this.initial, required this.onChanged});
  final MandakhPalette initial;
  final ValueChanged<MandakhPalette> onChanged;
  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  late MandakhPalette draft = widget.initial;
  bool saving = false;
  String? error;
  static const labels = ['Дэвсгэр өнгө', 'Карт, талбарын өнгө', 'Бичвэрийн өнгө', 'Товч, онцлох өнгө'];
  Future<void> edit(int i) async {
    final color = await showDialog<Color>(context: context, builder: (_) => _ColorDialog(initial: draft.colors[i], title: labels[i]));
    if (color != null && mounted) setState(() { draft = draft.withColor(i, color); error = null; });
  }
  Future<void> apply() async {
    if (!draft.isReadable || saving) return;
    setState(() { saving = true; error = null; });
    try {
      await draft.save();
      if (!mounted) return;
      widget.onChanged(draft);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() { saving = false; error = 'Тохиргоог хадгалж чадсангүй. Дахин оролдоно уу.'; });
    }
  }
  @override
  Widget build(BuildContext context) {
    final presets = <String, MandakhPalette>{'Үндсэн бараан': MandakhPalette.original, 'Цайвар': MandakhPalette.light, 'Улбар шар': MandakhPalette.orange, 'Нил ягаан': MandakhPalette.purple, 'Хар / улбар шар': MandakhPalette.midnight};
    return Scaffold(
      appBar: AppBar(title: const Text('Өнгө, загварын тохиргоо')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Өөрийн загвараа бүтээ', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Бэлэн загвар сонгох эсвэл өнгө бүрийг өөрчил. Тохиргоо энэ төхөөрөмжид хадгалагдана.'),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, children: presets.entries.map((entry) => ChoiceChip(
            label: Text(entry.key), selected: draft.colors.asMap().entries.every((e) => e.value == entry.value.colors[e.key]),
            avatar: CircleAvatar(backgroundColor: entry.value.accent), onSelected: saving ? null : (_) => setState(() { draft = entry.value; error = null; }),
          )).toList()),
          const SizedBox(height: 24),
          for (var i = 0; i < labels.length; i++) Card(child: ListTile(
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: draft.colors[i], borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).dividerColor))),
            title: Text(labels[i]), subtitle: Text(_hex(draft.colors[i])), trailing: const Icon(Icons.edit_outlined), onTap: saving ? null : () => edit(i),
          )),
          const SizedBox(height: 24),
          const Text('Урьдчилан харах', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Theme(data: draft.themeData(), child: Builder(builder: (context) => Material(color: draft.background, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MandakhRank', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: draft.accentInk, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(color: draft.surface, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Миний самбар', style: Theme.of(context).textTheme.titleLarge),
              Text('Бодлого бодож, чадвараа хөгжүүлээрэй.', style: TextStyle(color: draft.muted)),
              const SizedBox(height: 12), const TextField(readOnly: true, decoration: InputDecoration(hintText: 'Бодлого хайх')),
              const SizedBox(height: 12), FilledButton(onPressed: () {}, child: const Text('Бодлого үзэх')),
            ]))),
          ]))))),
          const SizedBox(height: 14),
          if (!draft.isReadable) const Text('Бичвэр болон дэвсгэрийн ялгарал бага байна. Уншихад хялбар өнгө сонгоно уу.', style: TextStyle(fontWeight: FontWeight.bold)),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: saving || !draft.isReadable ? null : apply, icon: const Icon(Icons.check), label: Padding(padding: const EdgeInsets.all(12), child: Text(saving ? 'Хадгалж байна…' : 'Хадгалах'))),
          TextButton(onPressed: saving ? null : () => setState(() { draft = MandakhPalette.original; error = null; }), child: const Text('Үндсэн загвар сэргээх')),
        ]))),
      ])),
    );
  }
}

String _hex(Color c) => '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
Color? _parseHex(String input) {
  final s = input.trim().replaceFirst(RegExp(r'^#'), '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) return null;
  return Color(0xFF000000 | int.parse(s, radix: 16));
}
class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial, required this.title});
  final Color initial;
  final String title;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}
class _ColorDialogState extends State<_ColorDialog> {
  late Color selected = widget.initial;
  late final TextEditingController controller = TextEditingController(text: _hex(selected));
  bool valid = true;
  void choose(Color c) => setState(() { selected = c; controller.text = _hex(c); valid = true; });
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(width: 360, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(height: 56, width: double.infinity, decoration: BoxDecoration(color: selected, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor))),
      const SizedBox(height: 12),
      TextField(controller: controller, decoration: InputDecoration(labelText: 'Өнгөний код (HEX)', errorText: valid ? null : '6 оронтой код оруулна уу'), onChanged: (value) => setState(() { final c = _parseHex(value); valid = c != null; if (c != null) selected = c; })),
      for (var i = 0; i < 3; i++) Row(children: [
        SizedBox(width: 44, child: Text(['Улаан', 'Ногоон', 'Хөх'][i], style: const TextStyle(fontSize: 11))),
        Expanded(child: Slider(value: [selected.red, selected.green, selected.blue][i].toDouble(), min: 0, max: 255, divisions: 255, onChanged: (v) => choose(Color.fromARGB(255, i == 0 ? v.round() : selected.red, i == 1 ? v.round() : selected.green, i == 2 ? v.round() : selected.blue)))),
        SizedBox(width: 30, child: Text('${[selected.red, selected.green, selected.blue][i]}')),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [Colors.white, Colors.black, const Color(0xFFFFA64D), const Color(0xFFB54708), const Color(0xFF245BC5), const Color(0xFF4C86FF), const Color(0xFF805AD5), const Color(0xFF168568), const Color(0xFFDC3645), const Color(0xFF111C30)].map((c) => InkWell(onTap: () => choose(c), borderRadius: BorderRadius.circular(8), child: Container(width: 37, height: 37, decoration: BoxDecoration(color: c, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)), child: c == selected ? Icon(Icons.check, color: MandakhPalette.contrast(c, Colors.white) > MandakhPalette.contrast(c, Colors.black) ? Colors.white : Colors.black) : null))).toList()),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Болих')), FilledButton(onPressed: valid ? () => Navigator.pop(context, selected) : null, child: const Text('Сонгох'))],
  );
}
