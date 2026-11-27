part of 'learning_screen.dart';

const _classKinds = <String,String>{'lesson':'Хичээл','course':'Сургалт','problem':'Бодлого','project':'Төсөл'};
const _classStatuses = <String,String>{'done':'Хугацаандаа дуусгасан','prior':'Өмнө нь дуусгасан','late':'Хоцорч дуусгасан','pending':'Хүлээгдэж буй','overdue':'Хугацаа хэтэрсэн','unavailable':'Материал байхгүй'};
const _classDone = {'done','prior','late'};

String _classDate(Object? value) {
  final date = DateTime.tryParse(learningText(value));
  if (date == null) return 'Хугацаагүй';
  final ub = date.toUtc().add(const Duration(hours:8));
  String pad(int n) => n.toString().padLeft(2,'0');
  return '${ub.year}.${pad(ub.month)}.${pad(ub.day)} ${pad(ub.hour)}:${pad(ub.minute)}';
}

Future<bool> _classConfirm(BuildContext context, String title, String text) async =>
    await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),content:Text(text),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Болих')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Батлах')),
    ])) ?? false;

void _classMessage(BuildContext context, Object message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message.toString())));
}

class ClassroomEntry extends StatelessWidget {
  const ClassroomEntry({super.key});
  @override
  Widget build(BuildContext context) {
    final p=MandakhPalette.of(context);
    return LearningPanel(highlight:true,onTap:() async {
      if (PracticeApi.token == null) {
        await Navigator.of(context).push(MaterialPageRoute<bool>(builder:(_)=>const AuthScreen()));
        if (!context.mounted || PracticeApi.token == null) return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const ClassroomHomeScreen()));
    },child:Row(children:[
      Container(width:46,height:46,decoration:BoxDecoration(color:p.surface,borderRadius:BorderRadius.circular(12)),child:Icon(Icons.groups_outlined,color:p.accentInk)),
      const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Миний ангиуд',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
        SizedBox(height:4),Text('Багш, ангийн даалгавар, суралцах ахиц',style:TextStyle(fontSize:12)),
      ])),const Icon(Icons.chevron_right),
    ]));
  }
}

class ClassroomHomeScreen extends StatefulWidget {
  const ClassroomHomeScreen({super.key});
  @override
  State<ClassroomHomeScreen> createState()=>_ClassroomHomeState();
}
class _ClassroomHomeState extends State<ClassroomHomeScreen> {
  late Future<Map<String,dynamic>> future;
  bool busy=false;
  @override
  void initState(){super.initState();future=PracticeApi.request('classrooms/');}
  void reload(){if(mounted)setState(()=>future=PracticeApi.request('classrooms/'));}
  Future<void> open(Map<String,dynamic> c) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>ClassroomDetailScreen(classroomId:learningInt(c['id']))));
    reload();
  }
  Future<void> change(bool create) async {
    if(busy)return;
    final result=await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder:(_)=>_ClassroomForm(create:create)));
    if(!mounted||result==null)return;
    setState(()=>busy=true);
    try {
      final r=await PracticeApi.request('classrooms/',body:result);
      if(!mounted)return;
      reload();await open(learningMap(r['classroom']));
    } catch(e){if(mounted)_classMessage(context,e);} finally {if(mounted)setState(()=>busy=false);}
  }
  Widget section(String title,List<Map<String,dynamic>> rows)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    if(rows.isEmpty)const Text('Одоогоор анги байхгүй.'),
    for(final c in rows)...[LearningPanel(onTap:()=>open(c),child:Row(children:[
      const Icon(Icons.groups_outlined,size:30),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(learningText(c['name']),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),
        Text('Багш: ${c['owner']}'),if(c['archived']==true)const Text('Хаалттай анги'),
      ])),const Icon(Icons.chevron_right),
    ])),const SizedBox(height:10)],
  ]);
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Миний ангиуд'),actions:[IconButton(onPressed:busy?null:reload,tooltip:'Шинэчлэх',icon:const Icon(Icons.refresh))]),body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,snapshot){
    if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
    if(snapshot.hasError)return learningError(snapshot.error,reload);
    final data=snapshot.data??{};
    return pageBody(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      learningHeading(context,'Хамтдаа суралцъя','Ангид нэгдэж, багшийн өгсөн даалгавраа гүйцэтгээрэй.'),const SizedBox(height:16),
      Wrap(spacing:8,runSpacing:8,children:[
        FilledButton.icon(onPressed:busy?null:()=>change(false),icon:const Icon(Icons.group_add_outlined),label:const Text('Ангид нэгдэх')),
        if(data['teacher']==true)OutlinedButton.icon(onPressed:busy?null:()=>change(true),icon:const Icon(Icons.add),label:const Text('Анги үүсгэх')),
      ]),const SizedBox(height:24),
      if(data['teacher']==true)...[section('Миний удирддаг анги',learningRows(data['owned'])),const SizedBox(height:20)],
      section('Нэгдсэн ангиуд',learningRows(data['joined'])),
    ]));
  }));
}

class _ClassroomForm extends StatefulWidget {
  const _ClassroomForm({required this.create}); final bool create;
  @override State<_ClassroomForm> createState()=>_ClassroomFormState();
}
class _ClassroomFormState extends State<_ClassroomForm> {
  final name=TextEditingController(),desc=TextEditingController();
  @override void dispose(){name.dispose();desc.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.create?'Анги үүсгэх':'Ангид нэгдэх')),body:pageBody(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    learningHeading(context,widget.create?'Шинэ анги':'Ангийн код',widget.create?'Оюутнуудтай хуваалцах код үүснэ.':'Багшаас авсан кодоо бичнэ үү.'),const SizedBox(height:16),
    TextField(controller:name,maxLength:widget.create?100:24,decoration:InputDecoration(labelText:widget.create?'Ангийн нэр':'Ангийн код'),onChanged:(_)=>setState((){})),
    if(widget.create)TextField(controller:desc,maxLength:500,maxLines:3,decoration:const InputDecoration(labelText:'Тайлбар (заавал биш)')),
    const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:name.text.trim().isEmpty?null:()=>Navigator.pop(context,widget.create?{'action':'create','name':name.text.trim(),'description':desc.text.trim()}:{'action':'join','code':name.text.trim()}),child:Text(widget.create?'Үүсгэх':'Нэгдэх'))),
  ])));
}

class ClassroomDetailScreen extends StatefulWidget {
  const ClassroomDetailScreen({super.key,required this.classroomId}); final int classroomId;
  @override State<ClassroomDetailScreen> createState()=>_ClassroomDetailState();
}
class _ClassroomDetailState extends State<ClassroomDetailScreen> {
  late Future<Map<String,dynamic>> future;
  bool busy=false; int tab=0;
  String get route=>'classrooms/${widget.classroomId}/';
  @override void initState(){super.initState();future=PracticeApi.request(route);}
  void reload(){if(mounted)setState(()=>future=PracticeApi.request(route));}
  Future<void> action(Map<String,dynamic> body,{bool leave=false}) async {
    if(busy)return;setState(()=>busy=true);
    try{await PracticeApi.request(route,body:body);if(!mounted)return;if(leave){Navigator.pop(context);return;}reload();}
    catch(e){if(mounted)_classMessage(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> confirmAction(String title,String message,Map<String,dynamic> body,{bool leave=false}) async {
    if(busy)return;if(await _classConfirm(context,title,message)&&mounted)await action(body,leave:leave);
  }
  Future<void> add() async {
    final data=await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder:(_)=>const _AssignmentForm()));
    if(mounted&&data!=null)await action(data);
  }
  Future<void> export() async {
    if(busy)return;setState(()=>busy=true);
    try {final r=await PracticeApi.request('${route}report/');final msg=await exportClassroomCsv(learningText(r['filename']),learningText(r['csv']));if(mounted)_classMessage(context,msg);}
    catch(e){if(mounted)_classMessage(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> material(Map<String,dynamic> a) async {
    if(busy||a['available']!=true)return;setState(()=>busy=true);
    try {
      final kind=a['kind'];final id=learningInt(a['target_id']);final course=learningInt(a['course_id']);
      Widget screen;
      if(kind=='problem'){
        final r=await PracticeApi.request('problems/');
        final matches=learningRows(r['results']).where((x)=>x['id']==id);
        if(matches.isEmpty)throw Exception('Бодлого олдсонгүй.');
        screen=PracticeScreen(problem:matches.first);
      }else if(kind=='project'){
        screen=CourseProjectScreen(courseId:course);
      }else{
        final r=await PracticeApi.request('learning/$course/');
        final title=learningText(r['title']);
        if(kind=='lesson'){
          final rows=learningRows(r['lessons']);final index=rows.indexWhere((x)=>x['id']==id);
          if(index<0)throw Exception('Хичээл олдсонгүй.');
          screen=LearningLessonScreen(courseId:course,lesson:rows[index],index:index,total:rows.length);
        }else{screen=LearningCourseScreen(courseId:course,title:title);}
      }
      if(!mounted)return;await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>screen));reload();
    }catch(e){if(mounted)_classMessage(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  Widget status(String value){final p=MandakhPalette.of(context);return Text(_classStatuses[value]??value,style:TextStyle(color:_classDone.contains(value)?p.positive:value=='overdue'?Colors.orange:p.muted,fontWeight:FontWeight.w600,fontSize:12));}
  Widget assignment(Map<String,dynamic> a,bool managing){
    final results=learningRows(a['results']);final count=results.where((x)=>_classDone.contains(x['status'])).length;
    return LearningPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Text(learningText(a['title']),style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800))),if(managing)IconButton(tooltip:'Даалгаврыг архивлах',onPressed:busy?null:()=>confirmAction('Даалгаврыг архивлах','Суралцах ахиц устахгүй. Даалгавар идэвхтэй жагсаалтаас хасагдана.',{'action':'archive_assignment','assignment_id':a['id']}),icon:const Icon(Icons.archive_outlined))]),
      Text('${_classKinds[a['kind']]} · ${a['target_title']}'),const SizedBox(height:6),Text('Хугацаа: ${_classDate(a['due_at'])} (УБ)',style:TextStyle(color:MandakhPalette.of(context).muted,fontSize:12)),
      if(learningText(a['instructions']).isNotEmpty)...[const SizedBox(height:10),Text(learningText(a['instructions']))],
      const SizedBox(height:12),
      if(managing)...[learningProgress(context,count,results.length),const SizedBox(height:6),Text('$count / ${results.length} оюутан дуусгасан'),
        ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('Оюутны дүн'),children:[for(final r in results)ListTile(contentPadding:EdgeInsets.zero,title:Text(learningText(r['username'])),subtitle:status(learningText(r['status'])),trailing:r['completed_at']==null?null:Text(_classDate(r['completed_at']),style:const TextStyle(fontSize:11)))])
      ]else...[status(learningText(a['status'])),if(a['completed_at']!=null)Text('Дуусгасан: ${_classDate(a['completed_at'])}',style:const TextStyle(fontSize:12))],
      const SizedBox(height:10),OutlinedButton.icon(onPressed:busy||a['available']!=true?null:()=>material(a),icon:const Icon(Icons.arrow_forward),label:const Text('Материал нээх')),
    ]));
  }
  Widget members(List<Map<String,dynamic>> rows,List<Map<String,dynamic>> assignments)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Оюутнууд',style:TextStyle(fontWeight:FontWeight.w800,fontSize:19)),const SizedBox(height:10),
    if(rows.isEmpty)const Text('Оюутан хараахан нэгдээгүй.'),
    for(final m in rows)...[LearningPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.person_outline),const SizedBox(width:8),Expanded(child:Text(learningText(m['username']),style:const TextStyle(fontWeight:FontWeight.w700))),IconButton(tooltip:'Гишүүнийг хасах',onPressed:busy?null:()=>confirmAction('Гишүүнийг хасах','Ангийн гишүүнчлэл цуцлагдана. Суралцах ахиц хэвээр үлдэнэ.',{'action':'remove_member','user_id':m['user_id']}),icon:const Icon(Icons.person_remove_outlined))]),
      Builder(builder:(_){final done=assignments.where((a)=>learningRows(a['results']).any((r)=>r['user_id']==m['user_id']&&_classDone.contains(r['status']))).length;return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[learningProgress(context,done,assignments.length),const SizedBox(height:6),Text('$done / ${assignments.length} даалгавар')]);}),
    ])),const SizedBox(height:8)],
  ]);
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Ангийн самбар'),actions:[IconButton(onPressed:busy?null:reload,icon:const Icon(Icons.refresh),tooltip:'Шинэчлэх')]),body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,snapshot){
    if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
    if(snapshot.hasError)return learningError(snapshot.error,reload);
    final c=learningMap(snapshot.data?['classroom']);final managing=c['managing']==true;final archived=c['archived']==true;
    final rows=learningRows(c['assignments']), roster=learningRows(c['members']);
    final teacherName=learningText(c['owner']);
    final archiveLabel=archived?' · Хаалттай':'';
    final available=rows.where((a)=>a['available']==true).toList();
    final total=managing?available.length*roster.length:available.length;
    final done=managing?rows.fold<int>(0,(n,a)=>n+learningRows(a['results']).where((r)=>_classDone.contains(r['status'])).length):rows.where((r)=>_classDone.contains(r['status'])).length;
    return pageBody(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      learningHeading(context,learningText(c['name']),'Багш: $teacherName$archiveLabel'),if(learningText(c['description']).isNotEmpty)Text(learningText(c['description'])),const SizedBox(height:16),
      LearningPanel(highlight:true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(managing?'Ангийн гүйцэтгэл':'Миний гүйцэтгэл',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(height:10),
        Text('$done / $total',style:const TextStyle(fontSize:28,fontWeight:FontWeight.w800)),learningProgress(context,done,total),const SizedBox(height:8),
        Text(managing?'${roster.length} оюутан · ${rows.length} даалгавар':'${rows.length} даалгавар'),
      ])),const SizedBox(height:14),
      if(managing)...[LearningPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Ангийн код',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:8),SelectableText(learningText(c['join_code']),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,letterSpacing:1)),
        Wrap(spacing:8,runSpacing:8,children:[TextButton.icon(onPressed:busy?null:()async{await Clipboard.setData(ClipboardData(text:learningText(c['join_code'])));if(mounted)_classMessage(context,'Кодыг хууллаа.');},icon:const Icon(Icons.copy),label:const Text('Хуулах')),
          TextButton(onPressed:busy?null:()=>confirmAction('Код солих','Хуучин кодоор шинэ гишүүн нэгдэх боломжгүй болно.',{'action':'rotate'}),child:const Text('Код солих')),
          TextButton(onPressed:busy?null:()=>confirmAction(archived?'Ангийг нээх':'Ангийг хаах','Суралцах ахиц устахгүй. Хаалттай ангид шинээр нэгдэх болон даалгавар нэмэх боломжгүй.',{'action':archived?'reopen':'archive'}),child:Text(archived?'Нээх':'Хаах')),
        ]),
      ])),const SizedBox(height:14),Wrap(spacing:8,runSpacing:8,children:[
        FilledButton.icon(onPressed:busy||archived?null:add,icon:const Icon(Icons.add),label:const Text('Даалгавар нэмэх')),
        OutlinedButton.icon(onPressed:busy?null:export,icon:const Icon(Icons.download_outlined),label:const Text('CSV тайлан')),
      ]),const SizedBox(height:16),Wrap(spacing:8,children:[ChoiceChip(label:const Text('Даалгаврууд'),selected:tab==0,onSelected:(_)=>setState(()=>tab=0)),ChoiceChip(label:const Text('Оюутнууд'),selected:tab==1,onSelected:(_)=>setState(()=>tab=1))]),const SizedBox(height:14)]
      else...[TextButton.icon(onPressed:busy?null:()=>confirmAction('Ангиас гарах','Ангийн гишүүнчлэл цуцлагдана. Суралцах ахиц хэвээр үлдэнэ.',{'action':'leave'},leave:true),icon:const Icon(Icons.logout),label:const Text('Ангиас гарах')),const SizedBox(height:8)],
      if(managing&&tab==1)members(roster,available)else...[const Text('Даалгаврууд',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:10),if(rows.isEmpty)const Text('Одоогоор даалгавар байхгүй.'),for(final a in rows)...[assignment(a,managing),const SizedBox(height:12)]],
    ]));
  }));
}

class _AssignmentForm extends StatefulWidget {
  const _AssignmentForm();
  @override State<_AssignmentForm> createState()=>_AssignmentFormState();
}
class _AssignmentFormState extends State<_AssignmentForm> {
  late Future<Map<String,dynamic>> future;final title=TextEditingController(),instructions=TextEditingController(),search=TextEditingController();
  String kind='lesson',query='';Map<String,dynamic>? selected;DateTime? due;
  @override void initState(){super.initState();future=PracticeApi.request('classrooms/targets/');}
  void reload()=>setState(()=>future=PracticeApi.request('classrooms/targets/'));
  @override void dispose(){title.dispose();instructions.dispose();search.dispose();super.dispose();}
  Future<void> deadline() async {
    final now=DateTime.now().toUtc().add(const Duration(hours:8));
    final date=await showDatePicker(context:context,firstDate:DateTime(now.year,now.month,now.day),lastDate:DateTime(now.year+5),initialDate:DateTime(now.year,now.month,now.day));
    if(date==null||!mounted)return;
    final time=await showTimePicker(context:context,initialTime:const TimeOfDay(hour:23,minute:59));
    if(time==null||!mounted)return;
    final value=DateTime.utc(date.year,date.month,date.day,time.hour,time.minute).subtract(const Duration(hours:8));
    if(!value.isAfter(DateTime.now())){_classMessage(context,'Ирээдүйн хугацаа сонгоно уу.');return;}
    setState(()=>due=value);
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Даалгавар нэмэх')),body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,snapshot){
    if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snapshot.hasError)return learningError(snapshot.error,reload);
    final rows=learningRows(learningMap(snapshot.data?['targets'])[kind]).where((x)=>learningText(x['title']).toLowerCase().contains(query)).toList();
    return pageBody(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      learningHeading(context,'Материал сонгох','Одоо байгаа хичээл, сургалт, бодлого эсвэл төслөөс сонгоно уу.'),const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[for(final k in _classKinds.entries)ChoiceChip(label:Text(k.value),selected:kind==k.key,onSelected:(_)=>setState((){kind=k.key;selected=null;search.clear();query='';}))]),const SizedBox(height:10),
      TextField(controller:search,onChanged:(v)=>setState(()=>query=v.toLowerCase().trim()),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Материал хайх')),
      const SizedBox(height:8),if(selected!=null)Text('Сонгосон: ${selected!['title']}',style:const TextStyle(fontWeight:FontWeight.w700)),
      SizedBox(height:220,child:ListView.builder(itemCount:rows.length,itemBuilder:(_,i){final r=rows[i];return ListTile(title:Text(learningText(r['title']),maxLines:2,overflow:TextOverflow.ellipsis),leading:Icon(selected?['id']==r['id']?Icons.radio_button_checked:Icons.radio_button_off),onTap:()=>setState((){selected=r;title.text=String.fromCharCodes(learningText(r['title']).runes.take(120));}));})),
      const SizedBox(height:12),TextField(controller:title,maxLength:120,decoration:const InputDecoration(labelText:'Даалгаврын нэр'),onChanged:(_)=>setState((){})),TextField(controller:instructions,maxLength:2000,maxLines:3,decoration:const InputDecoration(labelText:'Заавар (заавал биш)')),
      Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:deadline,icon:const Icon(Icons.event),label:Text(due==null?'Хугацаа сонгох (УБ)':_classDate(due!.toIso8601String()))),if(due!=null)TextButton(onPressed:()=>setState(()=>due=null),child:const Text('Хугацаагүй'))]),
      const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:selected==null||title.text.trim().isEmpty?null:()=>Navigator.pop(context,{'action':'assign','kind':kind,'target_id':selected!['id'],'title':title.text.trim(),'instructions':instructions.text.trim(),'due_at':due?.toIso8601String()}),child:const Text('Даалгавар үүсгэх'))),
    ]));
  }));
}
