import 'package:flutter/material.dart';
import 'data.dart';
import 'learning_screen.dart';
import 'theme_settings.dart';
import 'contest_live_screen.dart';

Color teacherAccent(BuildContext context) =>
    MandakhPalette.of(context).readable(const Color(0xFFD6A449));
Color teacherSurface(BuildContext context) => Color.lerp(
    MandakhPalette.of(context).surface, teacherAccent(context), .07)!;

class TeacherRoleChip extends StatelessWidget {
  const TeacherRoleChip({super.key});
  @override
  Widget build(BuildContext context) {
    final c = teacherAccent(context);
    return Container(
      key: const ValueKey('teacher-role'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: c), borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.school_outlined, size: 13, color: c),
        const SizedBox(width: 4),
        Text('Багш', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class TeacherWorkspaceEntry extends StatelessWidget {
  const TeacherWorkspaceEntry({super.key});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: teacherSurface(context), border: Border.all(color: teacherAccent(context)), borderRadius: BorderRadius.circular(16)),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const TeacherRoleChip(), const SizedBox(height: 10),
      const Text('Багшийн удирдлага', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Анги, даалгавар, тэмцээн болон оюутны ахицыг нэг дор удирдана.'),
      const SizedBox(height: 14),
      FilledButton.icon(key: const ValueKey('teacher-workspace-open'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TeacherWorkspaceScreen())),
        icon: const Icon(Icons.dashboard_customize_outlined), label: const Text('Багшийн самбар нээх')),
    ]),
  );
}

List<Map<String,dynamic>> _rows(Object? v) => v is List ? v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList() : [];
String _text(Object? v) => v?.toString() ?? '';
int _int(Object? v) => v is int ? v : 0;
String _date(Object? value) {
  final d=DateTime.tryParse(_text(value))?.toUtc().add(const Duration(hours:8));
  if(d==null)return '—';
  String pad(int n)=>n.toString().padLeft(2,'0');
  return '${d.year}.${pad(d.month)}.${pad(d.day)} ${pad(d.hour)}:${pad(d.minute)}';
}

Widget _panel(BuildContext context, Widget child) => Container(
  width:double.infinity,padding:const EdgeInsets.all(16),
  decoration:BoxDecoration(color:MandakhPalette.of(context).surface,
    border:Border.all(color:MandakhPalette.of(context).outline),borderRadius:BorderRadius.circular(14)),child:Material(type:MaterialType.transparency,child:child));

class TeacherWorkspaceScreen extends StatefulWidget {
  const TeacherWorkspaceScreen({super.key});
  @override State<TeacherWorkspaceScreen> createState()=>_TeacherWorkspaceState();
}
class _TeacherWorkspaceState extends State<TeacherWorkspaceScreen> {
  late Future<Map<String,dynamic>> future;
  bool busy=false;
  @override void initState(){super.initState();future=PracticeApi.request('teacher/workspace/');}
  void reload(){if(mounted)setState(()=>future=PracticeApi.request('teacher/workspace/'));}
  Future<void> send(Map<String,dynamic> body) async {
    if(busy)return;setState(()=>busy=true);
    try {
      await PracticeApi.request('teacher/workspace/',body:body);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Амжилттай хадгаллаа.')));
      reload();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> create(List<Map<String,dynamic>> problems) async {
    final data=await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder:(_)=>_ContestForm(problems:problems)));
    if(mounted&&data!=null)await send(data);
  }
  Future<void> change(Map<String,dynamic> c,String action) async {
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(action=='start'?'Тэмцээнийг одоо эхлүүлэх үү?':'Тэмцээнийг одоо дуусгах уу?'),
      content:Text(_text(c['title'])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Болих')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Батлах'))]));
    if(mounted&&yes==true)await send({'action':action,'contest_id':c['id']});
  }
  Future<void> result(Map<String,dynamic> c) async {
    final r=await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder:(_)=>_ResultForm(contest:c)));
    if(mounted&&r!=null)await send(r);
  }
  Widget metric(String title,Object? number,IconData icon)=>_panel(context,Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,color:teacherAccent(context)),const SizedBox(height:8),Text(_text(number),style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),Text(title)]));
  Widget contest(Map<String,dynamic> c)=>_panel(context,Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Icon(Icons.emoji_events_outlined,color:teacherAccent(context)),const SizedBox(width:8),Expanded(child:Text(_text(c['title']),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)))]),
    const SizedBox(height:6),Text(_text(c['status']),style:TextStyle(color:teacherAccent(context),fontWeight:FontWeight.w700)),
    Text('${_date(c['starts_at'])} — ${_date(c['ends_at'])} (УБ)'),
    Text('${_rows(c['problems']).length} бодлого · ${c['auto_judge']==true?'Автомат шүүлт':'Багшийн баталгаажуулсан дүн'}'),
    if(c['auto_judge']==true && c['participant_count'] is int) Padding(padding:const EdgeInsets.only(top:6),child:Text('${c['participant_count']} оролцогч · ${c['pending']} шалгах илгээлт')),
    const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[
      if(c['status']=='Удахгүй')FilledButton.icon(onPressed:busy?null:()=>change(c,'start'),icon:const Icon(Icons.play_arrow),label:const Text('Одоо эхлүүлэх')),
      if(c['status']=='Явагдаж байна')OutlinedButton.icon(onPressed:busy?null:()=>change(c,'end'),icon:const Icon(Icons.stop),label:const Text('Дуусгах')),
      if(c['auto_judge']==true)OutlinedButton.icon(onPressed:busy?null:()async{await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>ContestLiveScreen(contestId:_int(c['id']),title:_text(c['title']))));if(mounted)reload();},icon:const Icon(Icons.leaderboard_outlined),label:const Text('Шууд дүн')),
      if(c['auto_judge']!=true&&c['status']!='Удахгүй')OutlinedButton.icon(onPressed:busy?null:()=>result(c),icon:const Icon(Icons.edit_note),label:const Text('Дүн оруулах')),
    ]),
    ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('Бодлого ба дүн'),children:[
      for(final p in _rows(c['problems'])) ListTile(contentPadding:EdgeInsets.zero,title:Text('${p['label']}. ${p['title']}'),subtitle:Text(c['auto_judge']==true ? (p['accepted_count'] is int ? '${p['points']} оноо · ${p['accepted_count']}/${p['attempted_count']} оролцогч бодсон · ${p['pending_count']} шалгах илгээлт' : '${p['points']} оноо · Шууд дүнгээс харна уу') : '${p['points']} оноо · ${_rows(p['results']).length} дүн')),
      for(final p in _rows(c['problems']))for(final r in _rows(p['results'])) ListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text('${p['label']} · ${r['participant']}'),subtitle:c['auto_judge']==true?Text('${r['score']} / ${p['points']} оноо · ${r['penalty']} мин'):null,trailing:c['auto_judge']!=true?Text('${r['score']} / ${p['points']} · ${r['penalty']} мин'):null),
    ]),
  ]));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Багшийн самбар'),actions:[IconButton(onPressed:busy?null:reload,icon:const Icon(Icons.refresh),tooltip:'Шинэчлэх')]),body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,snapshot){
    if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
    if(snapshot.hasError)return Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[Text('${snapshot.error}',textAlign:TextAlign.center),TextButton(onPressed:reload,child:const Text('Дахин оролдох'))])));
    final data=snapshot.data??{};final contests=_rows(data['contests']);
    return pageBody(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:teacherSurface(context),border:Border.all(color:teacherAccent(context)),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const TeacherRoleChip(),const SizedBox(height:12),const Text('Сургалтыг удирдах',style:TextStyle(fontSize:26,fontWeight:FontWeight.w800)),const SizedBox(height:6),const Text('Анги, оюутан, даалгавар ба тэмцээний удирдлага.'),
      ])),const SizedBox(height:14),
      LayoutBuilder(builder:(context,b){final w=(b.maxWidth-10)/2;return Wrap(spacing:10,runSpacing:10,children:[
        SizedBox(width:w,child:metric('Идэвхтэй анги',data['classrooms'],Icons.groups_outlined)),
        SizedBox(width:w,child:metric('Оюутан',data['students'],Icons.people_outline)),
        SizedBox(width:w,child:metric('Даалгавар',data['assignments'],Icons.assignment_outlined)),
        SizedBox(width:w,child:metric('Явагдаж буй тэмцээн',contests.where((c)=>c['status']=='Явагдаж байна').length,Icons.emoji_events_outlined)),
      ]);}),const SizedBox(height:18),
      Wrap(spacing:10,runSpacing:10,children:[
        FilledButton.icon(onPressed:busy?null:()async{await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const ClassroomHomeScreen()));reload();},icon:const Icon(Icons.groups),label:const Text('Анги удирдах')),
        OutlinedButton.icon(key:const ValueKey('teacher-create-contest'),onPressed:busy?null:()=>create(_rows(data['problems'])),icon:const Icon(Icons.add),label:const Text('Тэмцээн үүсгэх')),
      ]),const SizedBox(height:24),const Text('Миний зохион байгуулсан тэмцээн',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:8),
      const Text('Тэмцээн нийтэд харагдана. Автомат эсвэл гараар дүгнэх төрлөө сонгоно.'),const SizedBox(height:12),
      if(contests.isEmpty)const Text('Одоогоор тэмцээн байхгүй.'),
      for(final c in contests)...[contest(c),const SizedBox(height:10)],
    ]));
  }));
}

class _ContestForm extends StatefulWidget {
  const _ContestForm({required this.problems});final List<Map<String,dynamic>> problems;
  @override State<_ContestForm> createState()=>_ContestFormState();
}
class _ContestFormState extends State<_ContestForm> {
  final title=TextEditingController(),description=TextEditingController(),delay=TextEditingController(text:'0'),duration=TextEditingController(text:'90');
  final selected=<int>{};String search='';
  bool automatic=true;
  @override void dispose(){title.dispose();description.dispose();delay.dispose();duration.dispose();super.dispose();}
  void submit(){
    final a=int.tryParse(delay.text),b=int.tryParse(duration.text);
    if(title.text.trim().isEmpty||a==null||a<0||a>43200||b==null||b<5||b>1440||selected.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Нэр, хугацаа, 1–12 бодлогоо шалгана уу.')));return;}
    Navigator.pop(context,{'action':'create','title':title.text.trim(),'description':description.text.trim(),'delay_minutes':a,'duration_minutes':b,'problem_ids':selected.toList(),'auto_judge':automatic});
  }
  @override Widget build(BuildContext context){final filtered=widget.problems.where((p)=>'${p['title']} ${p['difficulty']}'.toLowerCase().contains(search)).toList();return Scaffold(appBar:AppBar(title:const Text('Шинэ тэмцээн')),body:pageBody(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Тэмцээний тохиргоо',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),const SizedBox(height:12),
    TextField(controller:title,maxLength:200,decoration:const InputDecoration(labelText:'Тэмцээний нэр')),
    TextField(controller:description,maxLength:2000,maxLines:3,decoration:const InputDecoration(labelText:'Тайлбар')),
    TextField(controller:delay,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Хэдэн минутын дараа эхлэх (0 = одоо)')),
    const SizedBox(height:8),TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Үргэлжлэх минут (5–1440)')),
    const SizedBox(height:12),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Автомат шүүлт'),subtitle:const Text('Одоо байгаа нууц тестүүдийг хуулж, кодыг Docker шүүгчээр шалгана.'),value:automatic,onChanged:(v)=>setState(()=>automatic=v)),
    const SizedBox(height:20),Text('Бодлого сонгох · ${selected.length}/12',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:18)),
    TextField(onChanged:(v)=>setState(()=>search=v.toLowerCase()),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Бодлого хайх')),
    const SizedBox(height:8),
    if(selected.isNotEmpty)Wrap(spacing:6,runSpacing:6,children:[for(final p in widget.problems.where((p)=>selected.contains(p['id']))) InputChip(label:Text(_text(p['title']),overflow:TextOverflow.ellipsis),onDeleted:()=>setState(()=>selected.remove(p['id'])))]),
    SizedBox(height:330,child:ListView.builder(itemCount:filtered.length,itemBuilder:(context,i){final p=filtered[i];final id=_int(p['id']);return CheckboxListTile(value:selected.contains(id),onChanged:selected.length>=12&&!selected.contains(id)?null:(v)=>setState((){if(v==true){selected.add(id);}else{selected.remove(id);}}),title:Text(_text(p['title'])),subtitle:Text('${p['difficulty']} · ${p['points']} оноо'));})),
    const SizedBox(height:12),Text(automatic?'Сонгосон бодлогууд дадлагын санд өмнө нь нийтлэгдсэн тул цоо шинэ нууц бодлого биш. Дүн автоматаар гарна.':'Үүсгэснээр тэмцээн нийтэд харагдана. Дүнг гараар баталгаажуулна.'),const SizedBox(height:10),
    SizedBox(width:double.infinity,child:FilledButton(onPressed:submit,child:const Text('Нийтлэх'))),
  ])));}
}

class _ResultForm extends StatefulWidget {
  const _ResultForm({required this.contest});final Map<String,dynamic> contest;
  @override State<_ResultForm> createState()=>_ResultFormState();
}
class _ResultFormState extends State<_ResultForm> {
  final name=TextEditingController(),score=TextEditingController(),penalty=TextEditingController(text:'0');int? problem;
  @override void dispose(){name.dispose();score.dispose();penalty.dispose();super.dispose();}
  @override Widget build(BuildContext context){final problems=_rows(widget.contest['problems']);return Scaffold(appBar:AppBar(title:const Text('Дүн баталгаажуулах')),body:pageBody(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(_text(widget.contest['title']),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    DropdownButtonFormField<int>(isExpanded:true,value:problem,decoration:const InputDecoration(labelText:'Бодлого'),items:[for(final p in problems)DropdownMenuItem(value:_int(p['id']),child:Text('${p['label']}. ${p['title']}',overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>problem=v)),
    TextField(controller:name,maxLength:80,decoration:const InputDecoration(labelText:'Оюутны username')),
    TextField(controller:score,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Баталгаажуулсан оноо')),
    TextField(controller:penalty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Торгуулийн минут')),
    const SizedBox(height:12),const Text('Өмнөх дүн байвал шинэчилнэ. Зөвхөн шалгаж баталгаажуулсан дүнг оруулна уу.'),
    const SizedBox(height:12),FilledButton(onPressed:(){final s=int.tryParse(score.text),p=int.tryParse(penalty.text);if(problem==null||name.text.trim().isEmpty||s==null||p==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Бүх талбарыг бөглөнө үү.')));return;}Navigator.pop(context,{'action':'result','contest_id':widget.contest['id'],'problem_id':problem,'username':name.text.trim(),'score':s,'penalty':p});},child:const Text('Хадгалах')),
  ])));}
}
