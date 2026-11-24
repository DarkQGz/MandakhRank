import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'tv_castle_game.dart';

const _background = Color(0xFF091121);
const _surface = Color(0xFF14223A);
const _outline = Color(0xFF30425E);
const _left = Color(0xFF338CF5);
const _right = Color(0xFFFF9A36);
const _dim = Color(0xFFA5B6D0);

class _GameInfo {
  const _GameInfo(this.id, this.name, this.subtitle, this.icon, this.accent);
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

const _games = [
  _GameInfo('tug', 'ÐžÐ»Ñ Ñ‚Ð°Ñ‚Ð°Ð»Ñ‚', 'ÐšÐ¾Ð´Ñ‹Ð½ Ñ…Ð¾Ð¾ÑÐ¾Ð½ Ñ…ÑÑÐ³Ð¸Ð¹Ð³ Ð½Ó©Ñ…Ó©Ð¶, Ð¾Ð»ÑÑ‹Ð³ Ó©Ó©Ñ€ Ð»Ò¯Ò¯Ð³ÑÑ Ñ‚Ð°Ñ‚!', Icons.sports_handball, Color(0xFFFFC829)),
  _GameInfo('frog', 'ÐœÑÐ»Ñ…Ð¸Ð¹Ð½ Ò¯ÑÑ€ÑÐ»Ñ‚', 'ÐšÐ¾Ð´Ñ‹Ð½ Ò¯Ñ€ Ð´Ò¯Ð½Ð³ Ð·Ó©Ð² Ñ‚Ð°Ð°Ð¶, Ð¼ÑÐ»Ñ…Ð¸Ð¹Ð³ÑÑ Ñ‚Ò¯Ñ€Ò¯Ò¯Ð»Ò¯Ò¯Ð»!', Icons.water, Color(0xFF42DBB6)),
  _GameInfo('rocket', 'ÐšÐ¾Ð´Ñ‹Ð½ Ð¿ÑƒÑƒÐ¶Ð¸Ð½', 'ÐÐ»Ð³Ð¾Ñ€Ð¸Ñ‚Ð¼Ñ‹Ð½ Ð°ÑÑƒÑƒÐ»Ñ‚Ð°Ð´ Ñ…Ð°Ñ€Ð¸ÑƒÐ»Ð¶, ÑÐ°Ð½ÑÐ°Ñ€Ñ‚ ÑƒÑ€Ð°Ð»Ð´!', Icons.rocket_launch_rounded, Color(0xFFA98BFF)),
];

class MiniGamesPreview extends StatelessWidget {
  const MiniGamesPreview({super.key, required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 26),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF172E61), Color(0xFF17223F)]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF4164B4)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Ð¨Ð˜ÐÐ­ â€¢ Ð‘Ð¯Ð¦Ð¥ÐÐ Ð¢ÐžÐ“Ð›ÐžÐžÐœÐ£Ð£Ð”', style: TextStyle(color: Color(0xFF8FBDFF), fontWeight: FontWeight.w800, fontSize: 12)),
      const SizedBox(height: 8),
      const Text('Ð¥Ð°Ð¼Ñ‚Ð´Ð°Ð° ÐºÐ¾Ð´Ð»Ð¾Ð¶, Ó©Ñ€ÑÓ©Ð»Ð´Ó©Ñ†Ð³Ó©Ó©Ðµ!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Ð“Ð°Ñ€ ÑƒÑ‚Ð°Ñ, Ñ‚Ð°Ð±Ð»ÐµÑ‚, ÐºÐ¾Ð¼Ð¿ÑŒÑŽÑ‚ÐµÑ€ Ð´ÑÑÑ€ Ó©Ñ€Ó©Ó©Ð½Ð¸Ð¹ ÐºÐ¾Ð´Ð¾Ð¾Ñ€ Ó©Ñ€ÑÓ©Ð»Ð´Ó©Ó©Ñ€ÑÐ¹. ÐœÓ©Ð½ Ð½ÑÐ³ Ð¼ÑÐ´Ñ€ÑÐ³Ñ‡ Ð´ÑÐ»Ð³ÑÑ† Ð´ÑÑÑ€ Ñ…Ð¾Ñ‘Ñ€ Ð±Ð°Ð³ Ð·ÑÑ€ÑÐ³ Ñ‚Ð¾Ð³Ð»Ð¾Ñ… Ñ‚ÑƒÑÐ³Ð°Ð¹ Ð³Ð¾Ñ€Ð¸Ð¼Ñ‚Ð¾Ð¹.', style: TextStyle(color: _dim, height: 1.5)),
      const SizedBox(height: 18),
      Wrap(spacing: 14, runSpacing: 8, children: const [
        _PreviewTag(icon: Icons.sports_handball, label: 'ÐžÐ»Ñ Ñ‚Ð°Ñ‚Ð°Ð»Ñ‚'),
        _PreviewTag(icon: Icons.water, label: 'ÐœÑÐ»Ñ…Ð¸Ð¹Ð½ Ò¯ÑÑ€ÑÐ»Ñ‚'),
        _PreviewTag(icon: Icons.rocket_launch, label: 'ÐšÐ¾Ð´Ñ‹Ð½ Ð¿ÑƒÑƒÐ¶Ð¸Ð½'),
        _PreviewTag(icon: Icons.shield, label: 'Ð¦Ð°Ð¹Ð·Ñ‹Ð½ Ñ‚ÑƒÐ»Ð°Ð°Ð½'),
      ]),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: onPlay, icon: const Icon(Icons.sports_esports), label: const Text('Ð¢Ð¾Ð³Ð»Ð¾Ð¶ ÑÑ…Ð»ÑÑ…')),
    ]),
  );
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 18, color: const Color(0xFFB4D4FF)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  ]);
}

class MiniGamesLobby extends StatefulWidget {
  const MiniGamesLobby({super.key});
  @override
  State<MiniGamesLobby> createState() => _MiniGamesLobbyState();
}

class _MiniGamesLobbyState extends State<MiniGamesLobby> {
  String selectedMode = 'tug';
  String format = 'solo';
  String invite = '';
  int? side;
  bool loading = false;
  String? error;
  final inviteController = TextEditingController();

  @override
  void dispose() {
    inviteController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final room = await action();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MiniGameRoomScreen(initialRoom: room)));
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(backgroundColor: _background, title: const Text('Ð¢Ð¾Ð³Ð»Ð¾Ð¾Ð¼Ñ‹Ð½ Ñ‚Ð°Ð»Ð±Ð°Ñ€'), centerTitle: false),
      body: SafeArea(child: ListView(padding: EdgeInsets.symmetric(horizontal: width < 600 ? 16 : 30, vertical: 18), children: [
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 940), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ÐšÐžÐ”ÐžÐžÐ  Ó¨Ð Ð¡Ó¨Ð›Ð”Ó¨Ð•', style: TextStyle(color: Color(0xFF7CB0FF), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('3 Ð¾Ð½Ð»Ð°Ð¹Ð½ + 1 Ð´ÑÐ»Ð³ÑÑ†Ð¸Ð¹Ð½ Ñ‚Ð¾Ð³Ð»Ð¾Ð¾Ð¼', style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text('ÐÑÑƒÑƒÐ»Ñ‚Ð°Ð´ Ñ…ÑƒÑ€Ð´Ð°Ð½, Ð·Ó©Ð² Ñ…Ð°Ñ€Ð¸ÑƒÐ»Ð¶ Ð±Ð°Ð³Ñ‚Ð°Ð° Ð´Ð°Ð²ÑƒÑƒ Ñ‚Ð°Ð» Ð°Ð². ÐÐ°Ð¹Ð·Ñ‚Ð°Ð¹Ð³Ð°Ð° Ð½ÑÐ³ Ó©Ñ€Ó©Ó©Ð½Ð´ Ð¾Ñ€Ð¶ Ñ‚Ð¾Ð³Ð»Ð¾Ð½Ð¾.', style: TextStyle(color: _dim, height: 1.6)),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 770 ? (constraints.maxWidth - 26) / 3 : constraints.maxWidth;
            return Wrap(spacing: 13, runSpacing: 13, children: _games.map((game) => SizedBox(width: cardWidth, child: _gameCard(game))).toList());
          }),
          const SizedBox(height: 17),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B355E), Color(0xFF302342)]),
              border: Border.all(color: const Color(0xFF6887CF)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 15,
              runSpacing: 14,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 560),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Ð¨Ð˜ÐÐ­ â€¢ ÐÐ­Ð“ Ð”Ð­Ð›Ð“Ð­Ð¦Ð˜Ð™Ð Ð¢ÐžÐ“Ð›ÐžÐžÐœ', style: TextStyle(color: Color(0xFFB4D4FF), fontSize: 12, fontWeight: FontWeight.w900)),
                    SizedBox(height: 7),
                    Text('Ð¦Ð°Ð¹Ð·Ñ‹Ð½ Ñ‚ÑƒÐ»Ð°Ð°Ð½', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                    SizedBox(height: 7),
                    Text('ÐœÑÐ´Ñ€ÑÐ³Ñ‡ Ð·ÑƒÑ€Ð°Ð³Ñ‚ Ð´ÑÑÑ€ Ñ…Ð¾Ñ‘Ñ€ Ð±Ð°Ð³ Ð½ÑÐ³ Ð´ÑÐ»Ð³ÑÑ†ÑÑÑ Ó©Ñ€ÑÓ©Ð»Ð´Ó©Ð½Ó©. ÐœÐ°Ñ‚ÐµÐ¼Ð°Ñ‚Ð¸Ðº, Ð°Ð»Ð³Ð¾Ñ€Ð¸Ñ‚Ð¼, Ð¿Ñ€Ð¾Ð³Ñ€Ð°Ð¼Ñ‡Ð»Ð°Ð», ÐµÑ€Ó©Ð½Ñ…Ð¸Ð¹ Ð¼ÑÐ´Ð»ÑÐ³Ð¸Ð¹Ð½ Ð°ÑÑƒÑƒÐ»Ñ‚Ð°Ð´ Ñ…Ð°Ñ€Ð¸ÑƒÐ»Ð°Ð°Ð´ Ð½Ó©Ð³Ó©Ó© Ð±Ð°Ð³Ð¸Ð¹Ð½ Ñ†Ð°Ð¹Ð· Ñ€ÑƒÑƒ Ð³ÑÑ€ÑÐ»Ñ‚ ÑÑƒÐ¼ Ñ…Ð°Ñ€Ð²Ð°Ð°Ñ€Ð°Ð¹!', style: TextStyle(color: _dim, height: 1.45)),
                  ]),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const TvCastleBattleScreen())),
                  icon: const Icon(Icons.castle_rounded),
                  label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('ÐÑÐ³ Ð´ÑÐ»Ð³ÑÑ†ÑÑÑ€ Ñ‚Ð¾Ð³Ð»Ð¾Ñ…', style: TextStyle(fontWeight: FontWeight.w800))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text('Ð¥ÑÑ€Ñ…ÑÐ½ Ñ‚Ð¾Ð³Ð»Ð¾Ñ… Ð²Ñ?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            ChoiceChip(label: const Text('1-Ð¸Ð¹Ð½ ÑÑÑ€ÑÐ³ 1'), selected: format == 'solo', onSelected: (_) => setState(() => format = 'solo')),
            ChoiceChip(label: const Text('Ð‘Ð°Ð³Ð¸Ð¹Ð½ Ñ‚Ð¾Ð³Ð»Ð¾Ð»Ñ‚ (3 Ñ…Ò¯Ñ€Ñ‚ÑÐ»)'), selected: format == 'team', onSelected: (_) => setState(() => format = 'team')),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: loading ? null : () => _run(() => PracticeApi.request('games/create/', body: {'mode': selectedMode, 'format': format})),
            icon: const Icon(Icons.add_circle_outline),
            label: const Padding(padding: EdgeInsets.all(12), child: Text('Ð¨Ð¸Ð½Ñ Ó©Ñ€Ó©Ó© Ð½ÑÑÑ…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          )),
          const SizedBox(height: 24),
          _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ÐÐ°Ð¹Ð·Ñ‹Ð½Ñ…Ð°Ð° Ó©Ñ€Ó©Ó©Ð½Ð´ Ð½ÑÐ³Ð´ÑÑ…', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('ÐÐ°Ð¹Ð·Ð°Ð°ÑÐ°Ð° 6 Ñ‚ÑÐ¼Ð´ÑÐ³Ñ‚Ñ‚ÑÐ¹ Ó©Ñ€Ó©Ó©Ð½Ð¸Ð¹ ÐºÐ¾Ð´Ñ‹Ð³ Ð°Ð²Ð°Ð°Ñ€Ð°Ð¹.', style: TextStyle(color: _dim)),
            const SizedBox(height: 15),
            TextField(
              controller: inviteController,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
              decoration: const InputDecoration(prefixIcon: Icon(Icons.key), hintText: 'Ó¨Ñ€Ó©Ó©Ð½Ð¸Ð¹ ÐºÐ¾Ð´', counterText: ''),
              onChanged: (value) => setState(() => invite = value.toUpperCase()),
            ),
            const SizedBox(height: 8),
            const Text('ÐÑÐ³Ð´ÑÑ… Ñ‚Ð°Ð»', style: TextStyle(color: _dim)),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('ÐÐ²Ñ‚Ð¾Ð¼Ð°Ñ‚Ð°Ð°Ñ€'), selected: side == null, onSelected: (_) => setState(() => side = null)),
              ChoiceChip(label: const Text('Ð¦ÑÐ½Ñ…ÑÑ€'), selected: side == 1, onSelected: (_) => setState(() => side = 1)),
              ChoiceChip(label: const Text('Ð£Ð»Ð±Ð°Ñ€ ÑˆÐ°Ñ€'), selected: side == 2, onSelected: (_) => setState(() => side = 2)),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: loading || invite.length != 6 ? null : () => _run(() => PracticeApi.request('games/$invite/join/', body: {if (side != null) 'side': side})),
              icon: const Icon(Icons.login), label: const Text('ÐšÐ¾Ð´Ð¾Ð¾Ñ€ Ð½ÑÐ³Ð´ÑÑ…'),
            )),
          ])),
          if (loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFFF9D98)))),
          const SizedBox(height: 18),
          const Text('Ð­Ð´Ð³ÑÑÑ€ Ñ‚Ð¾Ð³Ð»Ð¾Ð¾Ð¼Ñ‹Ð½ Ð¾Ð½Ð¾Ð¾ Ð½ÑŒ Ð°Ð»Ð±Ð°Ð½ Ñ‘ÑÐ½Ñ‹ Ð±Ð¾Ð´Ð»Ð¾Ð³Ð¾ Ð±Ð¾Ð´Ð¾Ð»Ñ‚Ñ‹Ð½ ÑÑ€ÑÐ¼Ð±ÑÐ´ Ð½Ó©Ð»Ó©Ó©Ð»Ó©Ñ…Ð³Ò¯Ð¹.', style: TextStyle(color: _dim, fontSize: 12)),
        ]))),
      ])),
    );
  }

  Widget _gameCard(_GameInfo game) {
    final selected = game.id == selectedMode;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: () => setState(() => selectedMode = game.id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 190,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [game.accent.withOpacity(.23), _surface]),
          border: Border.all(color: selected ? game.accent : _outline, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(game.icon, color: game.accent, size: 34),
            Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? game.accent : _dim),
          ]),
          const Spacer(),
          Text(game.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(game.subtitle, maxLines: 2, style: const TextStyle(color: _dim, fontSize: 12)),
        ]),
      ),
    ));
  }
}

Widget _panel(Widget child) => Container(
  width: double.infinity,
  decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _outline)),
  padding: const EdgeInsets.all(18),
  child: child,
);

class MiniGameRoomScreen extends StatefulWidget {
  const MiniGameRoomScreen({super.key, required this.initialRoom});
  final Map<String, dynamic> initialRoom;

  @override
  State<MiniGameRoomScreen> createState() => _MiniGameRoomScreenState();
}

class _MiniGameRoomScreenState extends State<MiniGameRoomScreen> {
  late Map<String, dynamic> room;
  Timer? pollTimer;
  Timer? clockTimer;
  Timer? feedbackTimer;
  bool polling = false;
  bool answering = false;
  String? feedback;
  String? networkError;

  @override
  void initState() {
    super.initState();
    room = widget.initialRoom;
    pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _poll());
    clockTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted && room['status'] == 'running') setState(() {});
    });
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    clockTimer?.cancel();
    feedbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (polling || answering || room['status'] == 'finished') return;
    polling = true;
    try {
      final latest = await PracticeApi.request('games/${room['code']}/');
      if (mounted) setState(() { room = latest; networkError = null; });
    } catch (_) {
      if (mounted) setState(() => networkError = 'Ð¥Ð¾Ð»Ð±Ð¾Ð»Ñ‚ Ñ‚Ò¯Ñ€ Ñ‚Ð°ÑÐ°Ñ€Ð»Ð°Ð°. Ð”Ð°Ñ…Ð¸Ð½ Ñ…Ð¾Ð»Ð±Ð¾Ð³Ð´Ð¾Ð¶ Ð±Ð°Ð¹Ð½Ð°â€¦');
    } finally {
      polling = false;
    }
  }

  Future<void> _action(String action, {Map<String, dynamic>? data}) async {
    if (answering) return;
    setState(() => answering = true);
    try {
      final result = await PracticeApi.request('games/${room['code']}/$action/', body: data ?? {});
      if (!mounted) return;
      setState(() {
        room = action == 'answer' ? Map<String, dynamic>.from(result['room'] as Map) : result;
        networkError = null;
        if (action == 'answer') feedback = result['correct'] == true ? 'Ð—Ó©Ð² Ñ…Ð°Ñ€Ð¸ÑƒÐ»Ð»Ð°Ð°! +1 Ð¾Ð½Ð¾Ð¾' : 'Ð‘ÑƒÑ€ÑƒÑƒ Ñ…Ð°Ñ€Ð¸ÑƒÐ»Ð»Ð°Ð°. Ð”Ð°Ñ€Ð°Ð°Ð³Ð¸Ð¹Ð½Ñ…Ñ‹Ð³ Ð¾Ñ€Ð¾Ð»Ð´Ð¾Ð¾Ñ€Ð¾Ð¹!';
      });
      if (action == 'answer') {
        feedbackTimer?.cancel();
        feedbackTimer = Timer(const Duration(milliseconds: 1150), () { if (mounted) setState(() => feedback = null); });
      }
    } catch (e) {
      if (mounted) setState(() => networkError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => answering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = room['status'] as String;
    final scores = (room['scores'] as List).cast<int>();
    final players = (room['players'] as List).map((p) => Map<String, dynamic>.from(p as Map)).toList();
    final teamOne = players.where((p) => p['side'] == 1).toList();
    final teamTwo = players.where((p) => p['side'] == 2).toList();
    final mode = room['mode'] as String;
    final remaining = room['ends_at'] == null ? 0 : DateTime.parse(room['ends_at'] as String).difference(DateTime.now()).inSeconds.clamp(0, 150);
    final question = room['question'] == null ? null : Map<String, dynamic>.from(room['question'] as Map);
    final mySide = room['side'] as int? ?? 1;
    final leftWins = room['winner'] == mySide;
    final draw = room['winner'] == 0;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: Text(room['name'] as String),
        actions: [
          IconButton(tooltip: 'Ð¨Ð¸Ð½ÑÑ‡Ð»ÑÑ…', onPressed: _poll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 28), children: [
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Ó¨Ñ€Ó©Ó©Ð½Ð¸Ð¹ ÐºÐ¾Ð´', style: TextStyle(color: _dim, fontWeight: FontWeight.bold)),
            OutlinedButton.icon(
              onPressed: () { Clipboard.setData(ClipboardData(text: room['code'] as String)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ó¨Ñ€Ó©Ó©Ð½Ð¸Ð¹ ÐºÐ¾Ð´Ñ‹Ð³ Ñ…ÑƒÑƒÐ»Ð»Ð°Ð°.'))); },
              icon: const Icon(Icons.copy, size: 15),
              label: Text(room['code'] as String, style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 10),
          _panel(Column(children: [
            Row(children: [
              Expanded(child: _sideInfo('Ð¦Ð­ÐÐ¥Ð­Ð ', teamOne, scores[0], _left)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Ð­Ð¡Ð Ð­Ð“', style: TextStyle(color: _dim, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(child: _sideInfo('Ð£Ð›Ð‘ÐÐ  Ð¨ÐÐ ', teamTwo, scores[1], _right)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TweenAnimationBuilder<double>(tween: Tween<double>(end: scores[0] / 8.0), duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic, builder: (context, value, _) => LinearProgressIndicator(value: value.clamp(0.0, 1.0).toDouble(), minHeight: 10, backgroundColor: const Color(0xFF24344A), valueColor: const AlwaysStoppedAnimation(_left), borderRadius: BorderRadius.circular(8)))),
              const SizedBox(width: 10),
              Text('$remaining Ñ', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(child: TweenAnimationBuilder<double>(tween: Tween<double>(end: scores[1] / 8.0), duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic, builder: (context, value, _) => LinearProgressIndicator(value: value.clamp(0.0, 1.0).toDouble(), minHeight: 10, backgroundColor: const Color(0xFF24344A), valueColor: const AlwaysStoppedAnimation(_right), borderRadius: BorderRadius.circular(8)))),
            ]),
          ])),
          const SizedBox(height: 16),
          GameArena(mode: mode, leftScore: scores[0], rightScore: scores[1], target: room['target'] as int),
          const SizedBox(height: 18),
          if (status == 'waiting') _waiting(teamOne, teamTwo),
          if (status == 'running') ...[
            if (question != null) _questionCard(question) else _panel(const Column(children: [
              Icon(Icons.hourglass_top, color: Color(0xFFFFC829), size: 32),
              SizedBox(height: 12),
              Text('ÐÑÑƒÑƒÐ»Ñ‚ÑƒÑƒÐ´Ð°Ð° Ð´ÑƒÑƒÑÐ³Ð°Ð»Ð°Ð°!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('ÐÓ©Ð³Ó©Ó© Ñ‚Ð°Ð»Ñ‹Ð½ Ñ…Ð°Ñ€Ð¸ÑƒÐ»Ñ‚ ÑÑÐ²ÑÐ» Ñ…ÑƒÐ³Ð°Ñ†Ð°Ð° Ð´ÑƒÑƒÑÐ°Ñ…Ñ‹Ð³ Ñ…Ò¯Ð»ÑÑÐ½Ñ Ò¯Ò¯.', textAlign: TextAlign.center, style: TextStyle(color: _dim)),
            ])),
          ],
          if (status == 'finished') _panel(Column(children: [
            Icon(draw ? Icons.handshake_rounded : leftWins ? Icons.emoji_events_rounded : Icons.flag_outlined, color: draw ? Colors.white : leftWins ? const Color(0xFFFFCB3D) : _dim, size: 58),
            const SizedBox(height: 12),
            Text(draw ? 'Ð¢ÑÐ½Ñ†Ð»ÑÑ!' : leftWins ? 'Ð¯Ð»Ð°Ð»Ñ‚ Ð±Ð°Ð¹Ð³ÑƒÑƒÐ»Ð»Ð°Ð°!' : 'Ð­Ð½Ñ ÑƒÐ´Ð°Ð° Ð½Ó©Ð³Ó©Ó© Ñ‚Ð°Ð» ÑÐ»Ð»Ð°Ð°', textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('Ð­Ñ†ÑÐ¸Ð¹Ð½ Ð¾Ð½Ð¾Ð¾: ${scores[0]} â€“ ${scores[1]}', style: const TextStyle(color: _dim, fontSize: 17)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.replay), label: const Text('Ð”Ð°Ñ…Ð¸Ð½ Ñ‚Ð¾Ð³Ð»Ð¾Ñ… Ó©Ñ€Ó©Ó© Ð½ÑÑÑ…')),
          ])),
          if (feedback != null) Padding(padding: const EdgeInsets.only(top: 12), child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: Text(feedback!, key: ValueKey(feedback), textAlign: TextAlign.center, style: TextStyle(color: feedback!.startsWith('Ð—Ó©Ð²') ? const Color(0xFF63E5B1) : const Color(0xFFFFC176), fontWeight: FontWeight.w800)))),
          if (networkError != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(networkError!, style: const TextStyle(color: Color(0xFFFF9999)), textAlign: TextAlign.center)),
        ]))),
      ])),
    );
  }

  Widget _sideInfo(String label, List<Map<String, dynamic>> members, int score, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 5),
      Text('$score Ð¾Ð½Ð¾Ð¾', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 23)),
      const SizedBox(height: 4),
      Text(members.isEmpty ? 'Ð¥Ò¯Ð»ÑÑÐ¶ Ð±Ð°Ð¹Ð½Ð°â€¦' : members.map((p) => p['name']).join(', '), style: const TextStyle(color: _dim, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
    ]);
  }

  Widget _waiting(List<Map<String, dynamic>> teamOne, List<Map<String, dynamic>> teamTwo) {
    final ready = teamOne.isNotEmpty && teamTwo.isNotEmpty;
    final host = room['host'] == true;
    return _panel(Column(children: [
      const Icon(Icons.groups, color: Color(0xFFFFC829), size: 40),
      const SizedBox(height: 12),
      const Text('Ð¢Ð¾Ð³Ð»Ð¾Ð³Ñ‡Ð´Ð¾Ð¾ Ñ…Ò¯Ð»ÑÑÐ¶ Ð±Ð°Ð¹Ð½Ð°', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 9),
      const Text('Ó¨Ñ€Ó©Ó©Ð½Ð¸Ð¹ ÐºÐ¾Ð´Ð¾Ð¾ Ð½Ð°Ð¹Ð·Ð´Ð°Ð° Ð¸Ð»Ð³ÑÑÐ½Ñ Ò¯Ò¯. Ð¥Ð¾Ñ‘Ñ€ Ñ‚Ð°Ð»Ð´ Ñ‚Ð¾Ð³Ð»Ð¾Ð³Ñ‡ Ð¾Ñ€ÑÐ½Ñ‹ Ð´Ð°Ñ€Ð°Ð° Ñ‚Ð¾Ð³Ð»Ð¾Ð¾Ð¼ ÑÑ…ÑÐ»Ð½Ñ.', textAlign: TextAlign.center, style: TextStyle(color: _dim, height: 1.5)),
      const SizedBox(height: 18),
      if (host) SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: ready && !answering ? () => _action('start') : null,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Padding(padding: EdgeInsets.all(11), child: Text('Ð¢Ð¾Ð³Ð»Ð¾Ð¾Ð¼ ÑÑ…Ð»Ò¯Ò¯Ð»ÑÑ…')),
      )) else const Text('Ó¨Ñ€Ó©Ó© Ð½ÑÑÑÑÐ½ Ñ…Ò¯Ð½ Ñ‚Ð¾Ð³Ð»Ð¾Ð¾Ð¼ ÑÑ…Ð»Ò¯Ò¯Ð»Ð½Ñ.', style: TextStyle(color: _dim)),
    ]));
  }

  Widget _questionCard(Map<String, dynamic> question) {
    final options = (question['options'] as List).cast<String>();
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.psychology_rounded, color: Color(0xFFFFD15A)),
        const SizedBox(width: 8),
        Text('ÐÐ¡Ð£Ð£Ð›Ð¢ ${(question['index'] as int) + 1} / ${room['max_answers']}', style: const TextStyle(color: _dim, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        Expanded(child: Text('Ð—Ó©Ð² Ñ…Ð°Ñ€Ð¸ÑƒÐ»Ñ‚ = +1', textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.green.shade200))),
      ]),
      const SizedBox(height: 15),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 230),
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween(begin: const Offset(.07, 0), end: Offset.zero).animate(animation), child: child)),
        child: Column(key: ValueKey(question['index']), crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(question['prompt'] as String, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(color: const Color(0xFF080F1E), border: Border.all(color: const Color(0xFF314467)), borderRadius: BorderRadius.circular(15)),
            child: SelectableText(question['code'] as String, style: const TextStyle(color: Color(0xFF8AD9FF), fontFamily: 'monospace', height: 1.5, fontSize: 16)),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < 440 ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
            return Wrap(spacing: 10, runSpacing: 10, children: List.generate(options.length, (i) => SizedBox(width: cardWidth, child: OutlinedButton(
              onPressed: answering ? null : () {
                HapticFeedback.selectionClick();
                _action('answer', data: {'index': question['index'], 'choice': i});
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 62),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                side: const BorderSide(color: _outline),
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF1B304D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              child: Row(children: [
                CircleAvatar(radius: 13, backgroundColor: const Color(0xFF354E70), child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.white))),
                const SizedBox(width: 11),
                Expanded(child: Text(options[i], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              ]),
            ))));
          }),
        ]),
      ),
    ]));
  }
}

/// Animated, touch-friendly canvas. Progress comes only from server-scored data.
class GameArena extends StatefulWidget {
  const GameArena({super.key, required this.mode, required this.leftScore, required this.rightScore, required this.target});
  final String mode;
  final int leftScore;
  final int rightScore;
  final int target;
  @override
  State<GameArena> createState() => _GameArenaState();
}

class _GameArenaState extends State<GameArena> with SingleTickerProviderStateMixin {
  late final AnimationController ambience;
  @override
  void initState() {
    super.initState();
    ambience = AnimationController(vsync: this, duration: const Duration(milliseconds: 1850))..repeat();
  }
  @override
  void dispose() {
    ambience.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(end: widget.leftScore / widget.target),
      builder: (context, left, _) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(end: widget.rightScore / widget.target),
        builder: (context, right, _) => AnimatedBuilder(
          animation: ambience,
          builder: (_, __) => CustomPaint(
            size: const Size(double.infinity, 236),
            painter: _ArenaPainter(widget.mode, left.clamp(0.0, 1.0).toDouble(), right.clamp(0.0, 1.0).toDouble(), ambience.value),
          ),
        ),
      ),
    ),
  );
}

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter(this.mode, this.left, this.right, this.tick);
  final String mode;
  final double left;
  final double right;
  final double tick;

  void _circle(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  void _line(Canvas canvas, Offset a, Offset b, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, paint);
  }

  void _label(Canvas canvas, String text, Offset at, Color color, {double size = 13}) {
    final painter = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: size)), textDirection: TextDirection.ltr)..layout();
    painter.paint(canvas, at);
    painter.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (mode == 'tug') {
      final rect = Rect.fromLTWH(0, 0, w, h);
      canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFBCE9FF), Color(0xFF6CC7EE)]).createShader(rect));
      for (var i = 0; i < 4; i++) {
        final x = (i + .2) * w / 3.2 + math.sin(tick * math.pi * 2 + i) * 5;
        _circle(canvas, Offset(x, 31.0 + 6.0 * (i % 2)), 12, Colors.white.withOpacity(.72));
        _circle(canvas, Offset(x + 12, 32.0 + 6.0 * (i % 2)), 14, Colors.white.withOpacity(.72));
      }
      canvas.drawRect(Rect.fromLTWH(0, h * .74, w, h * .26), Paint()..color = const Color(0xFF22B87A));
      canvas.drawRect(Rect.fromLTWH(0, h * .88, w, h * .12), Paint()..color = const Color(0xFF12A365));
      _line(canvas, Offset(w / 2, h * .6), Offset(w / 2, h * .98), const Color(0xFFFFF5A5), 3);
      final shift = (right - left).clamp(-1.0, 1.0).toDouble() * w * .30;
      final ropeY = h * .62;
      _line(canvas, Offset(w * .09 + shift, ropeY), Offset(w * .91 + shift, ropeY), const Color(0xFF8D593D), 8);
      _line(canvas, Offset(w * .09 + shift, ropeY - 2), Offset(w * .91 + shift, ropeY - 2), const Color(0xFFEBC28F), 3);
      canvas.drawRect(Rect.fromCenter(center: Offset(w / 2 + shift, ropeY - 15), width: 17, height: 26), Paint()..color = const Color(0xFFE83D4B));
      for (var i = 0; i < 3; i++) {
        _character(canvas, Offset(w * (.21 + .12 * i) + shift, ropeY + 10), _left, tick + i);
        _character(canvas, Offset(w * (.63 + .10 * i) + shift, ropeY + 10), _right, tick + i + .5);
      }
      _label(canvas, 'Ð¦Ð­ÐÐ¥Ð­Ð ', Offset(14, h - 24), Colors.white);
      _label(canvas, 'Ð£Ð›Ð‘ÐÐ  Ð¨ÐÐ ', Offset(w - 104, h - 24), Colors.white);
    } else if (mode == 'frog') {
      final rect = Rect.fromLTWH(0, 0, w, h);
      canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF41D3DD), Color(0xFF147CA9)]).createShader(rect));
      for (var i = 0; i < 7; i++) {
        final x = w * (.10 + i * .133);
        for (final y in [h * .30, h * .71]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: math.min(52.0, w * .12), height: 21), Paint()..color = const Color(0xFF3FB878));
          _line(canvas, Offset(x + 4, y), Offset(x + 14, y - 9), const Color(0xFF2A9A60), 2);
        }
      }
      _line(canvas, Offset(w * .9, h * .1), Offset(w * .9, h * .89), const Color(0xFFFFF1A1), 3);
      _label(canvas, 'Ð‘ÐÐ Ð˜Ð', Offset(w * .75, 7), Colors.white, size: 11);
      final leftX = w * (.1 + left * .8);
      final rightX = w * (.1 + right * .8);
      _frog(canvas, Offset(leftX, h * .27 - math.sin(tick * math.pi * 2).abs() * 8), const Color(0xFF64EA91), _left);
      _frog(canvas, Offset(rightX, h * .68 - math.sin(tick * math.pi * 2 + .8).abs() * 8), const Color(0xFFFFCE5C), _right);
      _label(canvas, 'Ð¦Ð­ÐÐ¥Ð­Ð ', const Offset(11, 10), Colors.white);
      _label(canvas, 'Ð£Ð›Ð‘ÐÐ  Ð¨ÐÐ ', Offset(11, h * .50), Colors.white);
    } else {
      final rect = Rect.fromLTWH(0, 0, w, h);
      canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF192B65), Color(0xFF080E27)]).createShader(rect));
      for (var i = 0; i < 38; i++) {
        final x = ((i * 61 + 17) % 100) / 100 * w;
        final y = ((i * 43 + 13) % 100) / 100 * h;
        _circle(canvas, Offset(x, (y + tick * h * (.12 + (i % 3) * .06)) % h), i % 5 == 0 ? 2.1 : 1.2, Colors.white.withOpacity(.45 + .4 * ((i % 3) / 3)));
      }
      final aX = w * .32, bX = w * .68;
      _line(canvas, Offset(w * .08, h * .2), Offset(w * .92, h * .2), const Color(0xFFB9B0FF), 3);
      _label(canvas, 'Ð‘ÐÐ Ð˜Ð', Offset(w * .44, 12), Colors.white, size: 12);
      _rocket(canvas, Offset(aX, h * (.82 - .64 * left)), _left, tick);
      _rocket(canvas, Offset(bX, h * (.82 - .64 * right)), _right, tick + .5);
      _label(canvas, 'Ð¦Ð­ÐÐ¥Ð­Ð ', Offset(aX - 30, h - 22), const Color(0xFFA0CEFF));
      _label(canvas, 'Ð£Ð›Ð‘ÐÐ  Ð¨ÐÐ ', Offset(bX - 43, h - 22), const Color(0xFFFFD1A4));
    }
  }

  void _character(Canvas canvas, Offset pos, Color shirt, double phase) {
    final bob = math.sin(phase * math.pi * 2) * 2;
    _line(canvas, pos.translate(-6, 27 + bob), pos.translate(-14, 46 + bob), const Color(0xFF334E7F), 8);
    _line(canvas, pos.translate(8, 27 + bob), pos.translate(15, 46 + bob), const Color(0xFF334E7F), 8);
    _line(canvas, pos.translate(-10, 9 + bob), pos.translate(14, 9 + bob), const Color(0xFFFFC69D), 7);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pos.translate(0, 18 + bob), width: 31, height: 31), const Radius.circular(9)), Paint()..color = shirt);
    _circle(canvas, pos.translate(0, -10 + bob), 17, const Color(0xFFFFD1A3));
    _circle(canvas, pos.translate(-6, -13 + bob), 2, const Color(0xFF27364E));
    _circle(canvas, pos.translate(6, -13 + bob), 2, const Color(0xFF27364E));
    _line(canvas, pos.translate(-3, -4 + bob), pos.translate(3, -4 + bob), const Color(0xFF9B5F51), 2);
  }

  void _frog(Canvas canvas, Offset pos, Color body, Color eye) {
    _circle(canvas, pos.translate(-16, 7), 10, body);
    _circle(canvas, pos.translate(16, 7), 10, body);
    _circle(canvas, pos, 21, body);
    _circle(canvas, pos.translate(-11, -15), 10, body);
    _circle(canvas, pos.translate(11, -15), 10, body);
    _circle(canvas, pos.translate(-11, -15), 5, Colors.white);
    _circle(canvas, pos.translate(11, -15), 5, Colors.white);
    _circle(canvas, pos.translate(-10, -15), 2.5, eye);
    _circle(canvas, pos.translate(12, -15), 2.5, eye);
    _line(canvas, pos.translate(-5, 8), pos.translate(5, 8), const Color(0xFF277553), 2);
  }

  void _rocket(Canvas canvas, Offset pos, Color body, double phase) {
    final flame = 14 + math.sin(phase * math.pi * 2).abs() * 14;
    final fire = Path()..moveTo(pos.dx - 8, pos.dy + 19)..lineTo(pos.dx, pos.dy + 19 + flame)..lineTo(pos.dx + 8, pos.dy + 19)..close();
    canvas.drawPath(fire, Paint()..color = const Color(0xFFFFC33D));
    final fin = Path()..moveTo(pos.dx - 11, pos.dy + 9)..lineTo(pos.dx - 24, pos.dy + 24)..lineTo(pos.dx - 11, pos.dy + 19)
      ..moveTo(pos.dx + 11, pos.dy + 9)..lineTo(pos.dx + 24, pos.dy + 24)..lineTo(pos.dx + 11, pos.dy + 19);
    canvas.drawPath(fin, Paint()..color = body..strokeWidth = 7..style = PaintingStyle.stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: 26, height: 44), const Radius.circular(14)), Paint()..color = body);
    _circle(canvas, pos.translate(0, -5), 8, const Color(0xFFE8F8FF));
    _circle(canvas, pos.translate(0, -5), 4, const Color(0xFF31649B));
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter old) => old.left != left || old.right != right || old.tick != tick || old.mode != mode;
}

