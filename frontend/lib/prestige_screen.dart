import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'data.dart';
import 'theme_settings.dart';

Map<String, dynamic> appearanceMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> appearanceRows(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
int? prestigeRank(Object? v) => v is int && v >= 1 && v <= 5 ? v : null;

const _rankColors = <List<Color>>[
  [Color(0xFFF5B942), Color(0xFFFFF2AF), Color(0xFFEB8A32)],
  [Color(0xFF8FA9D6), Color(0xFFF4F8FF), Color(0xFF7CA9FF)],
  [Color(0xFFBE754D), Color(0xFFFFD1A5), Color(0xFFF39C6B)],
  [Color(0xFF7765F0), Color(0xFFD5B0FF), Color(0xFF9C7CFF)],
  [Color(0xFF0EA5A8), Color(0xFF95F5DE), Color(0xFF60A5FA)],
];
const _rankMotifs = ['royal', 'prism', 'ember', 'aurora', 'orbit'];

List<Color> _rewardColors(Map<String, dynamic> reward) {
  final raw = reward['colors'];
  if (raw is! List || raw.length != 2) return const [];
  final colors = <Color>[];
  for (final value in raw) {
    if (value is! String || !RegExp(r'^[A-Fa-f0-9]{6}$').hasMatch(value)) return const [];
    colors.add(Color(0xFF000000 | int.parse(value, radix: 16)));
  }
  return colors;
}

// The same background functions are used by the editor and both profiles.
// Keep the stored `soft` value compatible with Phase 5.2, but render it as
// a genuine solid tint rather than a second, nearly invisible gradient.
List<Color> _bannerColors(BuildContext context, Map<String, dynamic> appearance, Color base) {
  final p = MandakhPalette.of(context);
  final colors = _rewardColors(appearanceMap(appearance['accent']));
  final fallback = _rewardColors(appearanceMap(appearance['frame']));
  final chosen = colors.isNotEmpty ? colors : fallback;
  final first = chosen.isEmpty ? p.accent : chosen.first;
  final last = chosen.isEmpty ? Color.lerp(p.accent, p.text, .65)! : chosen.last;
  Color safeTint(Color c, double strength) {
    for (var i = 20; i >= 0; i--) {
      final candidate = Color.lerp(base, c, strength * i / 20)!;
      if (MandakhPalette.contrast(p.text, candidate) >= 4.5) return candidate;
    }
    return base;
  }
  if (appearance['background'] == 'soft') return [safeTint(first, .38)];
  if (appearance['background'] == 'gradient') {
    return [safeTint(first, .50), base, safeTint(last, .35)];
  }
  return [base];
}

Color prestigeBackgroundColor(BuildContext context, Map<String, dynamic> appearance, Color base) =>
    _bannerColors(context, appearance, base).first;

LinearGradient? prestigeBanner(BuildContext context, Map<String, dynamic> appearance, Color base) {
  if (appearance['background'] != 'gradient') return null;
  return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: _bannerColors(context, appearance, base));
}

Color prestigeBannerInk(BuildContext context, Map<String, dynamic> appearance, Color base, Color candidate) {
  final p = MandakhPalette.of(context);
  final colors = _bannerColors(context, appearance, base);
  final samples = <Color>[...colors];
  for (var i = 1; i < colors.length; i++) {
    for (var step = 1; step < 5; step++) {
      samples.add(Color.lerp(colors[i-1], colors[i], step / 5)!);
    }
  }
  for (var i = 0; i <= 20; i++) {
    final ink = Color.lerp(candidate, p.text, i / 20)!;
    if (samples.every((c) => MandakhPalette.contrast(ink, c) >= 4.5)) return ink;
  }
  return p.text;
}

Color prestigeInk(BuildContext context, Map<String, dynamic> appearance, {Color? base}) {
  final p = MandakhPalette.of(context);
  final colors = _rewardColors(appearanceMap(appearance['accent']));
  return prestigeBannerInk(context, appearance, base ?? p.surface,
      colors.isEmpty ? p.accentInk : p.readable(colors.first));
}

/// Paints within the existing card bounds. One finite entrance sweep, not an
/// infinite animation per leaderboard item. Does not alter layout or hit tests.
class PrestigeFrame extends StatefulWidget {
  const PrestigeFrame({super.key, required this.child, this.rank, this.reward = const {},
    this.animate = true, this.radius = 16});
  final Widget child;
  final int? rank;
  final Map<String, dynamic> reward;
  final bool animate;
  final double radius;
  @override State<PrestigeFrame> createState() => _PrestigeFrameState();
}

class _PrestigeFrameState extends State<PrestigeFrame> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool started = false;
  bool get decorated => prestigeRank(widget.rank) != null || _rewardColors(widget.reward).isNotEmpty;
  @override void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800), value: 1);
  }
  void sync() {
    final allowed = decorated && widget.animate && TickerMode.of(context) &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (!allowed) {
      controller.stop();
      if (controller.value != 1) controller.value = 1;
    } else if (!started) {
      started = true;
      controller.forward(from: 0);
    }
  }
  @override void didChangeDependencies() { super.didChangeDependencies(); sync(); }
  @override void didUpdateWidget(covariant PrestigeFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rank != oldWidget.rank || widget.reward['id'] != oldWidget.reward['id'] || widget.animate != oldWidget.animate) started = false;
    sync();
  }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (!decorated) return widget.child;
    final rank = prestigeRank(widget.rank);
    return AnimatedBuilder(animation: controller, child: widget.child, builder: (_, child) =>
      CustomPaint(foregroundPainter: _PrestigePainter(rank: rank, colors: _rewardColors(widget.reward),
        motif: '${widget.reward['motif'] ?? ''}', radius: widget.radius, phase: controller.value), child: child));
  }
}

class _PrestigePainter extends CustomPainter {
  const _PrestigePainter({required this.rank, required this.colors, required this.motif,
    required this.radius, required this.phase});
  final int? rank;
  final List<Color> colors;
  final String motif;
  final double radius, phase;
  @override void paint(Canvas canvas, Size size) {
    if (size.width < 20 || size.height < 20) return;
    void ring(List<Color> c, String style, double inset, double width) {
      final rect = (Offset.zero & size).deflate(inset);
      if (rect.width <= 0 || rect.height <= 0) return;
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(math.max(2.0, radius-inset).toDouble()));
      final base = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [c.first, ...c.skip(1), c.first]).createShader(rect);
      // The glow remains inside the card, even in compact leaderboard grids.
      canvas.drawRRect(rr, Paint()..color=c.first.withValues(alpha:.19)..style=PaintingStyle.stroke..strokeWidth=width+1);
      canvas.drawRRect(rr, Paint()..shader=base..style=PaintingStyle.stroke..strokeWidth=width);
      if (phase < 1) {
        final sweep = SweepGradient(startAngle: 0, endAngle: 2*math.pi,
          transform: GradientRotation(phase*2*math.pi),
          colors: [Colors.transparent, c.last.withValues(alpha:.0), c.last, Colors.white, Colors.transparent],
          stops: const [0,.68,.80,.85,1]).createShader(rect);
        canvas.drawRRect(rr, Paint()..shader=sweep..style=PaintingStyle.stroke..strokeWidth=width+0.6);
      }
      final len = math.min(12.0, math.min(rect.width,rect.height)/5).toDouble();
      if (style == 'royal' || style == 'prism' || style == 'ember') {
        final p = Paint()..color=c.last..strokeWidth=1.5..strokeCap=StrokeCap.round;
        final y = rect.top + 5;
        canvas.drawLine(Offset(rect.left+radius,y), Offset(rect.left+radius+len,y), p);
        canvas.drawLine(Offset(rect.right-radius-len,y), Offset(rect.right-radius,y), p);
        if (style == 'royal') {
          final x=rect.center.dx;
          final bottom=rect.bottom-4;
          final diamond=Path()..moveTo(x,bottom-3)..lineTo(x+4,bottom)..lineTo(x,bottom+3)..lineTo(x-4,bottom)..close();
          canvas.drawPath(diamond,Paint()..color=c.last);
        } else if (style == 'ember') {
          canvas.drawCircle(Offset(rect.right-radius, rect.bottom-5), 2, Paint()..color=c.last);
        }
      } else if (style == 'orbit' || style == 'pulse' || style == 'aurora') {
        final p=Paint()..color=c.last;
        canvas.drawCircle(Offset(rect.left+5,rect.center.dy), style=='pulse'?2.5:1.7,p);
        canvas.drawCircle(Offset(rect.right-5,rect.center.dy), style=='pulse'?2.5:1.7,p);
        if(style=='aurora') canvas.drawLine(Offset(rect.center.dx-len,rect.bottom-4),Offset(rect.center.dx+len,rect.bottom-4),Paint()..color=c.last..strokeWidth=1.5);
      }
    }
    if(rank!=null) ring(_rankColors[rank!-1],_rankMotifs[rank!-1],2,rank==1?3.0:2.3);
    if(colors.isNotEmpty) ring(colors,motif,rank==null?2:7,2);
  }
  @override bool shouldRepaint(covariant _PrestigePainter old) =>
      rank!=old.rank || motif!=old.motif || radius!=old.radius || phase!=old.phase ||
      colors.length!=old.colors.length || (colors.isNotEmpty && (colors.first!=old.colors.first || colors.last!=old.colors.last));
  @override bool hitTest(Offset position) => false;
}

class PrestigeIdentity extends StatelessWidget {
  const PrestigeIdentity({super.key, required this.appearance, this.base});
  final Map<String,dynamic> appearance;
  final Color? base;
  @override Widget build(BuildContext context) {
    final rank=prestigeRank(appearance['rank']);
    final title=appearanceMap(appearance['title']);
    if(rank==null&&title.isEmpty)return const SizedBox.shrink();
    final p=MandakhPalette.of(context);
    return Padding(padding:const EdgeInsets.only(top:6),child:Wrap(spacing:6,runSpacing:5,children:[
      if(rank!=null) _chip(context,rank==1?Icons.emoji_events_outlined:Icons.military_tech_outlined,'Шилдэг #$rank',prestigeBannerInk(context,appearance,base ?? p.surface,p.readable(_rankColors[rank-1].first))),
      if(title.isNotEmpty) _chip(context,Icons.star_outline,'${title['title']}',prestigeInk(context,appearance,base:base)),
    ]));
  }
}

Widget _chip(BuildContext context, IconData icon,String text,Color color) => Container(
  padding: const EdgeInsets.symmetric(vertical:4,horizontal:7),
  decoration:BoxDecoration(borderRadius:BorderRadius.circular(8),border:Border.all(color:color.withValues(alpha:.7))),
  child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:color,size:13),const SizedBox(width:4),
    Flexible(child:Text(text,style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.w700),overflow:TextOverflow.ellipsis))]));

class FeaturedAchievements extends StatelessWidget {
  const FeaturedAchievements({super.key,required this.appearance});
  final Map<String,dynamic> appearance;
  @override Widget build(BuildContext context) {
    final rewards=appearanceRows(appearance['featured']);
    if(rewards.isEmpty)return const SizedBox.shrink();
    final p=MandakhPalette.of(context);
    return Padding(padding:const EdgeInsets.only(top:16),child:Container(
      padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:p.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:p.outline)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Онцлох амжилтууд',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:10),
        for(final reward in rewards) Padding(padding:const EdgeInsets.only(bottom:6),child:PrestigeFrame(reward:reward,animate:false,radius:10,
          child:Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:p.background,borderRadius:BorderRadius.circular(10)),
            child:Row(children:[Icon(Icons.workspace_premium_outlined,color:p.readable(_rewardColors(reward).isEmpty?p.accent:_rewardColors(reward).first)),const SizedBox(width:9),Expanded(child:Text('${reward['title']}',style:const TextStyle(fontWeight:FontWeight.w600)))])))),
      ])));
  }
}

class ProfileCustomizationScreen extends StatefulWidget {
  const ProfileCustomizationScreen({super.key, required this.appearance,
    required this.username, this.profileSurface});
  final Map<String,dynamic> appearance;
  final String username;
  final Color? profileSurface;
  @override State<ProfileCustomizationScreen> createState() => _ProfileCustomizationState();
}

class _ProfileCustomizationState extends State<ProfileCustomizationScreen> {
  late final String? token;
  late Map<String,dynamic> prefs;
  late List<Map<String,dynamic>> rewards;
  bool unlockedOnly = true, busy = false;
  String? error;
  static const backgrounds = {'plain':'Энгийн', 'soft':'Нэг өнгө', 'gradient':'Gradient'};

  @override void initState() {
    super.initState();
    token = PracticeApi.token;
    final raw = appearanceMap(widget.appearance['preferences']);
    rewards = appearanceRows(widget.appearance['rewards']);
    prefs = {'frame':raw['frame']??'', 'accent':raw['accent']??'', 'title':raw['title']??'',
      'background': backgrounds.containsKey(raw['background']) ? raw['background'] : 'plain',
      'motion':raw['motion']!=false,
      'featured':(raw['featured'] is List ? (raw['featured'] as List).whereType<String>().toList():<String>[])};
  }
  List<String> get featured => (prefs['featured'] as List).cast<String>();
  List<Map<String,dynamic>> get unlocked => rewards.where((r) => r['unlocked']==true && r['id'] is String).toList();
  Map<String,dynamic> rewardFor(Object? id) => unlocked.firstWhere((r)=>r['id']==id,orElse:()=>{});
  Map<String,dynamic> get preview => {'rank':widget.appearance['rank'], 'frame':rewardFor(prefs['frame']),
    'accent':rewardFor(prefs['accent']), 'title':rewardFor(prefs['title']), 'background':prefs['background'],
    'motion':prefs['motion'], 'featured':featured.map(rewardFor).where((r)=>r.isNotEmpty).toList()};

  void chooseStyle(String id) {
    if (busy || (id.isNotEmpty && rewardFor(id).isEmpty)) return;
    setState(() {
      error = null;
      prefs['frame'] = id;
      prefs['accent'] = id;
      prefs['title'] = id;
    });
  }
  void toggleFeatured(String id) {
    if (busy || rewardFor(id).isEmpty) return;
    setState(() {
      error = null;
      final next = [...featured];
      if (next.contains(id)) { next.remove(id); }
      else if (next.length < 3) { next.add(id); }
      else { error = '3 хүртэлх амжилт сонгоно уу.'; return; }
      prefs['featured'] = next;
    });
  }

  Future<void> save() async {
    if (busy) return;
    if (token==null || PracticeApi.token!=token) { setState(()=>error='Дахин нэвтэрнэ үү.'); return; }
    setState(() {busy=true;error=null;});
    try {
      final result=await PracticeApi.request('profile/appearance/',body:Map<String,dynamic>.from(prefs));
      if(!mounted)return;
      if(token!=PracticeApi.token){setState(()=>error='Бүртгэл өөрчлөгдсөн. Дахин нэвтэрнэ үү.');return;}
      final saved=appearanceMap(result['appearance']);
      if(saved['preferences'] is! Map)throw const FormatException('Тохиргоо хадгалагдсангүй.');
      Navigator.pop(context,saved);
    }catch(e){if(mounted){setState(()=>error='$e');ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
    finally{if(mounted)setState(()=>busy=false);}
  }

  @override Widget build(BuildContext context) {
    final p=MandakhPalette.of(context);
    final a=preview;
    final base=widget.profileSurface ?? p.surface;
    final shown=unlockedOnly ? unlocked : [...unlocked, ...rewards.where((r)=>r['unlocked']!=true)];
    return Scaffold(
      appBar:AppBar(title:const Text('Профайл тохируулах')),
      bottomNavigationBar:SafeArea(child:Center(heightFactor:1,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760),
        child:Padding(padding:const EdgeInsets.fromLTRB(16,8,16,12),child:SizedBox(width:double.infinity,child:FilledButton.icon(
          key:const ValueKey('appearance-save'), onPressed:busy?null:save, icon:Icon(busy?Icons.hourglass_empty:Icons.check),
          label:Text(busy?'Хадгалж байна...':'Хадгалах'))))))),
      body:SafeArea(top:false,bottom:false,child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760),
        child:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,24),children:[
          _previewCard(context,a,base),
          const SizedBox(height:20),
          const Text('Дэвсгэр',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
          const SizedBox(height:8),
          Wrap(spacing:8,runSpacing:8,children:[for(final v in backgrounds.entries) _backgroundChip(context,v.key,v.value,a,base)]),
          const SizedBox(height:12),
          Wrap(spacing:8,runSpacing:6,children:[FilterChip(key:const ValueKey('appearance-motion'),
            avatar:const Icon(Icons.auto_awesome_outlined,size:17),label:const Text('Гэрэлтэх эффект'),selected:prefs['motion']==true,
            onSelected:busy?null:(v)=>setState(()=>prefs['motion']=v))]),
          const SizedBox(height:20),const Divider(),const SizedBox(height:8),
          const Text('Загвар сонгох',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
          const SizedBox(height:4),Text('${unlocked.length}/${rewards.length} загвар нээгдсэн',style:TextStyle(color:p.muted)),
          const SizedBox(height:10),
          Wrap(spacing:8,runSpacing:6,children:[
            ChoiceChip(key:const ValueKey('appearance-filter-unlocked'),label:Text('Нээсэн (${unlocked.length})'),
              selected:unlockedOnly,onSelected:busy?null:(_)=>setState(()=>unlockedOnly=true)),
            ChoiceChip(key:const ValueKey('appearance-filter-all'),label:Text('Бүгд (${rewards.length})'),
              selected:!unlockedOnly,onSelected:busy?null:(_)=>setState(()=>unlockedOnly=false)),
          ]),
          const SizedBox(height:10),
          LayoutBuilder(builder:(context,box){
            final columns=box.maxWidth>=600?3:box.maxWidth>=320?2:1;
            final width=(box.maxWidth-(columns-1)*10)/columns;
            return Wrap(spacing:10,runSpacing:10,children:[
              SizedBox(width:width,child:_rewardTile(context,const {},isDefault:true)),
              for(final r in shown) SizedBox(width:width,child:_rewardTile(context,r)),
            ]);
          }),
          if(unlockedOnly&&unlocked.isEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text('Амжилт нээж шинэ загвар аваарай.',style:TextStyle(color:p.muted))),
          const SizedBox(height:16),
          ExpansionTile(key:const ValueKey('appearance-featured'),tilePadding:EdgeInsets.zero,childrenPadding:const EdgeInsets.only(bottom:10),
            title:const Text('Онцлох амжилт'),subtitle:Text('${featured.length}/3'),children:[
              Align(alignment:Alignment.centerLeft,child:Wrap(spacing:7,runSpacing:6,children:[
                for(final r in unlocked) FilterChip(key:ValueKey('appearance-feature-${r['id']}'),label:Text('${r['title']}'),
                  selected:featured.contains(r['id']),onSelected:busy?null:(_)=>toggleFeatured(r['id'] as String)),
              ])),
              if(unlocked.isEmpty)const Text('Нээсэн амжилт алга.'),
            ]),
          ExpansionTile(key:const ValueKey('appearance-advanced'),tilePadding:EdgeInsets.zero,childrenPadding:const EdgeInsets.only(bottom:10),
            title:const Text('Нэмэлт тохиргоо'),subtitle:const Text('Өнгө, цолыг тусад нь сонгох'),children:[
              _dropdown('accent','Өнгө'),_dropdown('title','Цол'),
            ]),
          if(error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(error!,key:const ValueKey('appearance-error'),style:TextStyle(color:p.negative))),
        ])))));
  }

  Widget _previewCard(BuildContext context,Map<String,dynamic> a,Color base) {
    final p=MandakhPalette.of(context);
    final accent=prestigeInk(context,a,base:base);
    return PrestigeFrame(rank:prestigeRank(a['rank']),reward:appearanceMap(a['frame']),animate:a['motion']==true,
      child:Container(key:const ValueKey('appearance-preview'),width:double.infinity,padding:const EdgeInsets.all(18),
        decoration:BoxDecoration(color:prestigeBackgroundColor(context,a,base),gradient:prestigeBanner(context,a,base),
          border:Border.all(color:p.outline),borderRadius:BorderRadius.circular(16)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('УРЬДЧИЛАН ХАРАХ',style:TextStyle(color:prestigeBannerInk(context,a,base,p.muted),fontSize:11,fontWeight:FontWeight.w700,letterSpacing:1.2)),
          const SizedBox(height:14),
          Row(children:[Container(padding:const EdgeInsets.all(3),decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:accent,width:2)),
            child:CircleAvatar(radius:25,backgroundColor:p.surface,child:Icon(Icons.person_outline,color:p.accentInk,size:26))),
            const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(widget.username,style:TextStyle(color:accent,fontWeight:FontWeight.w800,fontSize:21),maxLines:2,overflow:TextOverflow.ellipsis),
              PrestigeIdentity(appearance:a,base:base),
              const SizedBox(height:5),Text('MandakhRank',style:TextStyle(color:prestigeBannerInk(context,a,base,p.muted))),
            ]))]),
          if(appearanceRows(a['featured']).isNotEmpty)...[const SizedBox(height:12),Wrap(spacing:6,runSpacing:5,children:[
            for(final r in appearanceRows(a['featured'])) _chip(context,Icons.star_outline,'${r['title']}',accent),
          ])],
        ])));
  }
  Widget _backgroundChip(BuildContext context,String id,String label,Map<String,dynamic> a,Color base) {
    final option={...a,'background':id};
    return ChoiceChip(key:ValueKey('appearance-background-$id'),label:Text(label),selected:prefs['background']==id,
      avatar:Container(width:20,height:20,decoration:BoxDecoration(shape:BoxShape.circle,
        color:prestigeBackgroundColor(context,option,base),gradient:prestigeBanner(context,option,base),
        border:Border.all(color:MandakhPalette.of(context).outline))),
      onSelected:busy?null:(_)=>setState(()=>prefs['background']=id));
  }
  Widget _dropdown(String key,String label) {
    final id=prefs[key];
    return Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[SizedBox(width:65,child:Text(label)),
      Expanded(child:DropdownButton<String>(key:ValueKey('appearance-$key'),isExpanded:true,
        value:rewardFor(id).isEmpty?'':id as String,
        items:[const DropdownMenuItem(value:'',child:Text('Энгийн')),for(final r in unlocked)DropdownMenuItem(value:r['id'] as String,child:Text('${r['title']}',overflow:TextOverflow.ellipsis))],
        onChanged:busy?null:(value){if(value!=null)setState(()=>prefs[key]=value);}))]));
  }
  Widget _rewardTile(BuildContext context,Map<String,dynamic> r,{bool isDefault=false}) {
    final p=MandakhPalette.of(context);
    final id=isDefault?'':r['id'] as String;
    final open=isDefault||r['unlocked']==true;
    final active=prefs['frame']==id;
    final colors=_rewardColors(r);
    final color=p.readable(colors.isEmpty?p.accent:colors.first);
    return Material(color:p.surface,borderRadius:BorderRadius.circular(14),clipBehavior:Clip.antiAlias,
      child:InkWell(key:ValueKey(isDefault?'appearance-default':'appearance-reward-$id'),onTap:busy||!open?null:()=>chooseStyle(id),
        child:Container(decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),border:Border.all(color:active?color:p.outline,width:active?2:1)),
          padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            PrestigeFrame(reward:r,animate:false,radius:10,child:Container(height:56,width:double.infinity,
              decoration:BoxDecoration(borderRadius:BorderRadius.circular(10),gradient:LinearGradient(colors:colors.isEmpty?[p.background,p.tint]:colors.map((c)=>Color.lerp(p.surface,c,.23)!).toList())),
              child:Icon(isDefault?Icons.person_outline:open?Icons.workspace_premium_outlined:Icons.lock_outline,color:open?color:p.muted,size:26))),
            const SizedBox(height:8),Text(isDefault?'Энгийн': '${r['title']}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
            const SizedBox(height:4),Row(children:[Expanded(child:Text(active?'Сонгосон':open?'Нээгдсэн':'${r['progress']} / ${r['target']}',
              maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:11,color:active?color:open?p.positive:p.muted))),
              Icon(active?Icons.check_circle:open?Icons.radio_button_unchecked:Icons.lock_outline,color:active?color:p.muted,size:16)]),
            if(!isDefault&&!open)Padding(padding:const EdgeInsets.only(top:5),child:Text('${r['description']}',maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:11,color:p.muted))),
          ]))));
  }
}
