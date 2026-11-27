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

Color prestigeInk(BuildContext context, Map<String, dynamic> appearance) {
  final p = MandakhPalette.of(context);
  final colors = _rewardColors(appearanceMap(appearance['accent']));
  return colors.isEmpty ? p.accentInk : p.readable(colors.first);
}

LinearGradient? prestigeBanner(BuildContext context, Map<String, dynamic> appearance, Color base) {
  final style = appearance['background'];
  if (style != 'gradient' && style != 'soft') return null;
  final p = MandakhPalette.of(context);
  final colors = _rewardColors(appearanceMap(appearance['accent']));
  final first = colors.isEmpty ? p.accentInk : colors.first;
  final last = colors.isEmpty ? p.accentInk : colors.last;
  Color safeTint(Color c, double strength) {
    for (var i = 0; i <= 10; i++) {
      final candidate = Color.lerp(base, c, strength * (10-i)/10)!;
      if (MandakhPalette.contrast(p.text, candidate) >= 4.5) return candidate;
    }
    return base;
  }
  return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: style == 'gradient' ? [safeTint(first, .12), base, safeTint(last, .08)]
      : [safeTint(first, .07), safeTint(first, .035)]);
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
  const PrestigeIdentity({super.key, required this.appearance});
  final Map<String,dynamic> appearance;
  @override Widget build(BuildContext context) {
    final rank=prestigeRank(appearance['rank']);
    final title=appearanceMap(appearance['title']);
    if(rank==null&&title.isEmpty)return const SizedBox.shrink();
    final p=MandakhPalette.of(context);
    return Padding(padding:const EdgeInsets.only(top:6),child:Wrap(spacing:6,runSpacing:5,children:[
      if(rank!=null) _chip(context,rank==1?Icons.emoji_events_outlined:Icons.military_tech_outlined,'Шилдэг #$rank',p.readable(_rankColors[rank-1].first)),
      if(title.isNotEmpty) _chip(context,Icons.star_outline,'${title['title']}',prestigeInk(context,appearance)),
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
  const ProfileCustomizationScreen({super.key,required this.appearance, required this.username});
  final Map<String,dynamic> appearance;
  final String username;
  @override State<ProfileCustomizationScreen> createState()=>_ProfileCustomizationState();
}
class _ProfileCustomizationState extends State<ProfileCustomizationScreen> {
  late final String? token;
  late Map<String,dynamic> prefs;
  late List<Map<String,dynamic>> rewards;
  String tab='frame';
  bool unlockedOnly=false,busy=false;
  String? error;
  static const tabs={'frame':'Хүрээ','accent':'Өнгө','title':'Цол','featured':'Онцлох'};
  static const backgrounds={'plain':'Энгийн','gradient':'Өнгөний шилжилт','soft':'Зөөлөн өнгө'};
  @override void initState(){super.initState();token=PracticeApi.token;final raw=appearanceMap(widget.appearance['preferences']);
    prefs={'frame':raw['frame']??'','accent':raw['accent']??'','title':raw['title']??'',
      'background':raw['background']??'plain','motion':raw['motion']??true,
      'featured':(raw['featured'] is List ? (raw['featured'] as List).whereType<String>().toList():<String>[])};
    rewards=appearanceRows(widget.appearance['rewards']);
  }
  List<String> get featured => (prefs['featured'] as List).cast<String>();
  Map<String,dynamic> rewardFor(Object? id)=>rewards.firstWhere((r)=>r['id']==id&&r['unlocked']==true,orElse:()=>{});
  Map<String,dynamic> get preview=>{'rank':widget.appearance['rank'],'frame':rewardFor(prefs['frame']),
    'accent':rewardFor(prefs['accent']),'title':rewardFor(prefs['title']),'background':prefs['background'],'motion':prefs['motion']};
  bool selected(Map<String,dynamic> r)=>tab=='featured'?featured.contains(r['id']):prefs[tab]==r['id'];
  void select(Map<String,dynamic> r){if(busy||r['unlocked']!=true||r['id'] is! String)return;final id=r['id'] as String;
    setState((){error=null;if(tab=='featured'){
      final next=[...featured];if(next.contains(id)){next.remove(id);}else if(next.length<3){next.add(id);}else{error='3 хүртэлх амжилт сонгоно уу.';return;}prefs['featured']=next;
    }else{prefs[tab]=selected(r)?'':id;}});
  }
  Future<void> save()async{
    if(busy||token==null||PracticeApi.token!=token){setState(()=>error='Дахин нэвтэрнэ үү.');return;}
    setState((){busy=true;error=null;});
    try{
      final result=await PracticeApi.request('profile/appearance/',body:Map<String,dynamic>.from(prefs));
      if(!mounted)return;
      if(token!=PracticeApi.token){setState(()=>error='Бүртгэл өөрчлөгдсөн. Дахин нэвтэрнэ үү.');return;}
      final saved=appearanceMap(result['appearance']);
      if(saved['preferences'] is! Map)throw const FormatException('Тохиргоо хадгалагдсангүй.');
      Navigator.pop(context,saved);
    }catch(e){if(mounted){setState(()=>error='$e');ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final p=MandakhPalette.of(context);final a=preview;final accent=prestigeInk(context,a);
    final shown=rewards.where((r)=>!unlockedOnly||r['unlocked']==true).toList();
    return Scaffold(appBar:AppBar(title:const Text('Профайл тохируулах')),
      bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.all(14),child:FilledButton.icon(
        key:const ValueKey('appearance-save'),onPressed:busy?null:save,icon:Icon(busy?Icons.hourglass_empty:Icons.save_outlined),label:Text(busy?'Хадгалж байна...':'Хадгалах')))),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        const Text('Урьдчилан харах',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:10),
        PrestigeFrame(rank:prestigeRank(a['rank']),reward:appearanceMap(a['frame']),animate:a['motion']==true,
          child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:p.surface,gradient:prestigeBanner(context,a,p.surface),border:Border.all(color:p.outline),borderRadius:BorderRadius.circular(16)),
            child:Row(children:[CircleAvatar(backgroundColor:p.tint,child:Icon(Icons.person_outline,color:accent)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.username,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:19)),PrestigeIdentity(appearance:a),const SizedBox(height:5),Text('MandakhRank',style:TextStyle(color:accent))]))]))),
        const SizedBox(height:18),const Text('Дэвсгэр',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:6),
        Wrap(spacing:8,runSpacing:6,children:[for(final v in backgrounds.entries) ChoiceChip(label:Text(v.value),selected:prefs['background']==v.key,onSelected:busy?null:(_)=>setState(()=>prefs['background']=v.key))]),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Хөдөлгөөнт эффект'),subtitle:const Text('Профайлын хүрээний гэрэлтэх хөдөлгөөн'),value:prefs['motion']==true,onChanged:busy?null:(v)=>setState(()=>prefs['motion']=v)),
        const Divider(),const Text('Амжилтаар нээгдэх загварууд',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
        const SizedBox(height:4),Text('${rewards.where((r)=>r['unlocked']==true).length} / ${rewards.length} нээгдсэн',style:TextStyle(color:p.muted)),const SizedBox(height:10),
        Wrap(spacing:8,runSpacing:6,children:[for(final e in tabs.entries)ChoiceChip(label:Text(e.value),selected:tab==e.key,onSelected:busy?null:(_)=>setState(()=>tab=e.key))]),
        Row(children:[Expanded(child:Text(tab=='featured'?'Сонгосон ${featured.length}/3':'Нэг загвар сонгоно уу.')),TextButton(onPressed:busy?null:()=>setState((){prefs[tab]=tab=='featured'?<String>[]:'';error=null;}),child:const Text('Анхны төлөв'))]),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Зөвхөн нээсэн загварууд'),value:unlockedOnly,onChanged:busy?null:(v)=>setState(()=>unlockedOnly=v)),
        if(error!=null) Padding(padding:const EdgeInsets.only(bottom:8),child:Text(error!,key:const ValueKey('appearance-error'),style:TextStyle(color:p.negative))),
        if(shown.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('Одоогоор нээсэн загвар алга. Амжилт цуглуулаарай.')),
        for(final r in shown) Padding(padding:const EdgeInsets.only(bottom:9),child:_rewardTile(context,r)),
      ]));
  }
  Widget _rewardTile(BuildContext context,Map<String,dynamic> r){
    final p=MandakhPalette.of(context);final open=r['unlocked']==true,active=selected(r);
    final colors=_rewardColors(r);final color=p.readable(colors.isEmpty?p.accent:colors.first);
    return PrestigeFrame(reward:r,animate:false,radius:12,child:Material(color:p.surface,borderRadius:BorderRadius.circular(12),
      child:InkWell(key:ValueKey('appearance-reward-${r['id']}'),borderRadius:BorderRadius.circular(12),onTap:busy||!open?null:()=>select(r),
        child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
          Container(width:42,height:42,decoration:BoxDecoration(borderRadius:BorderRadius.circular(9),gradient:LinearGradient(colors: colors.isEmpty ? [p.accent,p.accent] : colors)),child:Icon(open?Icons.workspace_premium_outlined:Icons.lock_outline,color:Colors.black87)),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${r['title']}',style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:3),Text('${r['description']}',style:TextStyle(color:p.muted,fontSize:12)),const SizedBox(height:3),Text(open?'Нээгдсэн':'${r['progress']} / ${r['target']}',style:TextStyle(fontSize:12,color:open?p.positive:p.muted))])),
          Icon(active?Icons.check_circle:open?Icons.radio_button_unchecked:Icons.lock_outline,color:active?color:p.muted),
        ])))));
  }
}
