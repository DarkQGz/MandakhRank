part of 'learning_screen.dart';

String projectVerdict(Object? value) {
  const labels = <String,String>{
    'Accepted':'Зөв бодолт', 'Approved':'Баталгаажсан', 'Queued':'Дараалалд байна',
    'Running':'Шалгаж байна', 'Review Pending':'Шалгуулахаар хүлээгдэж байна',
    'Needs Revision':'Засвар шаардлагатай', 'Wrong Answer':'Буруу хариулт',
    'Compilation Error':'Кодын бичиглэлийн алдаа', 'Runtime Error':'Ажиллах үеийн алдаа',
    'Time Limit Exceeded':'Хугацаа хэтэрсэн', 'Memory Limit Exceeded':'Санах ойн хязгаар хэтэрсэн',
    'Output Limit Exceeded':'Гаралтын хэмжээ хэтэрсэн', 'Judge Error':'Judge-ийн алдаа',
  };
  return labels[learningText(value)] ?? learningText(value);
}

class CourseProjectCard extends StatelessWidget {
  const CourseProjectCard({super.key, required this.courseId, required this.project, required this.onReturn});
  final int courseId;
  final Map<String,dynamic> project;
  final VoidCallback onReturn;
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final complete = project['completed'] == true;
    return LearningPanel(highlight: complete, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(complete ? Icons.verified_outlined : Icons.rocket_launch_outlined, size: 28, color: complete ? p.positive : p.accentInk), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Төгсгөлийн төсөл', style: TextStyle(color:p.muted, fontSize:12)), Text(learningText(project['title']), style: const TextStyle(fontSize:18, fontWeight:FontWeight.w800))]))]),
      const SizedBox(height: 12), Text(learningText(project['goal']), style: const TextStyle(height:1.5)),
      const SizedBox(height: 10), Text(complete ? 'Амжилттай дуусгасан · Профайлд бүртгэгдсэн' : project['unlocked'] == true ? 'Төслөө эхлэх боломжтой' : 'Нэгдсэн шалгалтад тэнцсэний дараа илгээнэ', style: TextStyle(color: complete ? p.positive : p.muted)),
      const SizedBox(height:12), SizedBox(width:double.infinity, child: FilledButton.icon(onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CourseProjectScreen(courseId: courseId)));
        onReturn();
      }, icon: Icon(complete ? Icons.visibility_outlined : Icons.arrow_forward), label: Text(complete ? 'Төслийг харах' : 'Төслийн дэлгэрэнгүй'))),
    ]));
  }
}

class CourseProjectScreen extends StatefulWidget {
  const CourseProjectScreen({super.key, required this.courseId});
  final int courseId;
  @override
  State<CourseProjectScreen> createState() => _CourseProjectScreenState();
}

class _CourseProjectScreenState extends State<CourseProjectScreen> {
  final editor = TextEditingController();
  late Future<Map<String,dynamic>> future;
  bool busy = false, initialized = false;
  int step = 0;
  String? error;
  String get route => 'learning/${widget.courseId}/project/';
  @override
  void initState() { super.initState(); future = load(); }
  Future<Map<String,dynamic>> load() async {
    final d = await PracticeApi.request(route);
    if (mounted && !initialized) {
      initialized = true;
      editor.text = learningText(d['latest_source'] ?? learningMap(d['project'])['starter']);
      if (learningRows(d['attempts']).isNotEmpty) step = 2;
    }
    return d;
  }
  void reload() { if (mounted) setState(() { future = load(); }); }
  @override
  void dispose() { editor.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (busy) return;
    if (editor.text.trim().isEmpty) {
      setState(() => error = 'Эх код эсвэл тайлангаа бичнэ үү.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await PracticeApi.request(route, body: {'source': editor.text});
      if (mounted) setState(() { step = 2; future = load(); });
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.toString() : 'Илгээж чадсангүй. Дахин оролдоно уу.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  Widget codeBlock(BuildContext context, String title, String value) {
    final p = MandakhPalette.of(context);
    return Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color:p.tint, borderRadius:BorderRadius.circular(12)), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      Row(children:[Expanded(child:Text(title, style:TextStyle(color:p.accentInk, fontWeight:FontWeight.w700))), IconButton(tooltip:'Хуулах', onPressed:() => Clipboard.setData(ClipboardData(text:value)), icon:const Icon(Icons.copy, size:18))]),
      SingleChildScrollView(scrollDirection:Axis.horizontal, child:SelectableText(value, style:const TextStyle(fontFamily:'monospace',height:1.5))),
    ]));
  }
  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    return Scaffold(appBar:AppBar(title:const Text('Төгсгөлийн төсөл'), actions:[IconButton(tooltip:'Дүн шинэчлэх', onPressed:busy?null:reload, icon:const Icon(Icons.refresh))]), body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,snapshot){
      if(snapshot.connectionState!=ConnectionState.done) return const Center(child:CircularProgressIndicator());
      if(snapshot.hasError||!snapshot.hasData) return learningError(snapshot.error,reload);
      final d=snapshot.data!, project=learningMap(d['project']), history=learningRows(d['attempts']);
      final python=project['mode']=='python', completed=d['completed']==true, unlocked=d['unlocked']==true;
      final pending=history.any((a)=>['Queued','Running','Review Pending'].contains(a['status']));
      final requirements=project['requirements'] is List ? (project['requirements'] as List).map(learningText).toList() : <String>[];
      final allowed=unlocked&&!completed&&!pending;
      return pageBody(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        LearningPanel(highlight:true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(python?'PYTHON · AUTOMATIC JUDGE':'ТӨСӨЛ · БАГШИЙН ҮНЭЛГЭЭ',style:TextStyle(color:p.accentInk,fontWeight:FontWeight.w700,fontSize:12)),const SizedBox(height:8),
          learningHeading(context,learningText(project['title']),learningText(project['goal'])),const SizedBox(height:12),
          Text(completed?'Амжилттай дуусгасан':pending?'Өмнөх илгээлтийг шалгаж байна':unlocked?'Илгээх боломжтой':'Бүх хичээл, нэгдсэн шалгалтад тэнцсэний дараа илгээнэ.',style:TextStyle(color:completed?p.positive:p.muted)),
        ])),const SizedBox(height:16),
        Wrap(spacing:8,runSpacing:8,children:[for(var i=0;i<3;i++) ChoiceChip(label:Text(['1. Даалгавар','2. Гүйцэтгэх','3. Үр дүн'][i]),selected:step==i,onSelected:busy?null:(_)=>setState(()=>step=i))]),const SizedBox(height:16),
        if(step==0)...[
          learningHeading(context,'Төслийн шаардлага','Дараах шаардлагуудыг хангасан шийдэл бүтээнэ.'),const SizedBox(height:12),
          for(var i=0;i<requirements.length;i++) Padding(padding:const EdgeInsets.only(bottom:8),child:LearningPanel(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(radius:15,backgroundColor:p.tint,child:Text('${i+1}',style:TextStyle(color:p.accentInk,fontSize:12))),const SizedBox(width:12),Expanded(child:Text(requirements[i],style:const TextStyle(height:1.5)))]))),
          const SizedBox(height:8),LearningPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(python?'Оролт ба гаралт':'Илгээх материал',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),const SizedBox(height:8),Text(learningText(project['contract']),style:const TextStyle(height:1.5)),if(python)...[const SizedBox(height:12),codeBlock(context,'Жишээ оролт',learningText(project['sample_input'])),const SizedBox(height:8),codeBlock(context,'Жишээ гаралт',learningText(project['sample_output'])),const SizedBox(height:8),Text('${project['test_count']} тестээр шалгана (жишээ орно).',style:TextStyle(color:p.muted))]])),
          const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>setState(()=>step=1),icon:const Icon(Icons.code),label:const Text('Гүйцэтгэх хэсэг'))),
        ],
        if(step==1)...[
          learningHeading(context,python?'Python код':'Эх код ба тайлан',python?'stdin-ээс уншиж, stdout-д зөвхөн шаардсан үр дүнг хэвлэнэ.':'Файлын нэр, эх код, туршилтын үр дүнг нэг текст болгон оруулна.'),const SizedBox(height:12),
          LearningPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text(python?'main.py':'Төслийн материал',style:const TextStyle(fontWeight:FontWeight.w700))),IconButton(tooltip:'Код хуулах',onPressed:()=>Clipboard.setData(ClipboardData(text:editor.text)),icon:const Icon(Icons.copy))]),
            TextField(controller:editor,enabled:!busy, minLines:10,maxLines:18,keyboardType:TextInputType.multiline,autocorrect:false,enableSuggestions:false,style:const TextStyle(fontFamily:'monospace',fontSize:14,height:1.5),decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'Энд бичнэ үү...')),
            const SizedBox(height:8),Text('20 KB хүртэл. Нууц үг, token, хувийн мэдээлэл бүү оруул.',style:TextStyle(color:p.muted,fontSize:12)),
          ])),const SizedBox(height:12),
          if(!allowed) Text(completed?'Төсөл дууссан байна.':pending?'Дүн гарахыг хүлээнэ үү.':'Төслөө илгээхийн тулд сургалтаа дуусгана уу.',style:TextStyle(color:p.muted)),
          if(error!=null) Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(error!,style:TextStyle(color:p.negative))),
          const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy||!allowed?null:submit,icon:const Icon(Icons.send_outlined),label:Text(busy?'Илгээж байна...':python?'Judge-д илгээх':'Шалгуулахаар илгээх'))),
        ],
        if(step==2)...[
          learningHeading(context,'Төслийн дүн',completed?'Профайлд баталгаажсан төсөл бүртгэгдлээ.':'Өмнөх илгээлтүүдийн төлөв болон санал хүсэлт.'),const SizedBox(height:12),
          if(pending) LearningPanel(highlight:true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(python?'Judge хариу өгөхийг хүлээж байна. Worker ажиллаж байгаа эсэхээс хугацаа хамаарна.':'Эрх бүхий админ шалгаж дүн оруулна.'),const SizedBox(height:8),OutlinedButton.icon(onPressed:reload,icon:const Icon(Icons.refresh),label:const Text('Дүн шинэчлэх'))])),
          if(history.isEmpty) const LearningPanel(child:Text('Одоогоор илгээлт алга.')),
          for(final a in history) Padding(padding:const EdgeInsets.only(top:10),child:LearningPanel(highlight:a['passed']==true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Icon(a['passed']==true?Icons.check_circle_outline:Icons.assignment_outlined,color:a['passed']==true?p.positive:p.accentInk),const SizedBox(width:10),Expanded(child:Text(projectVerdict(a['status']),style:const TextStyle(fontWeight:FontWeight.w700)))]),
            if(a['tests_total']!=null)...[const SizedBox(height:8),learningProgress(context,learningInt(a['tests_passed']),learningInt(a['tests_total'])),const SizedBox(height:6),Text('${a['tests_passed']} / ${a['tests_total']} тест')],
            if(learningText(a['feedback']).isNotEmpty)...[const SizedBox(height:8),Text(learningText(a['feedback']),style:const TextStyle(height:1.5))],
            const SizedBox(height:6),Text(learningText(a['created_at']).split('T').first,style:TextStyle(color:p.muted,fontSize:12)),
          ]))),
          if(allowed)...[const SizedBox(height:12),OutlinedButton.icon(onPressed:()=>setState(()=>step=1),icon:const Icon(Icons.edit_outlined),label:const Text('Шийдлээ засах'))],
        ],
      ]));
    }));
  }
}

class ProjectProfileSection extends StatelessWidget {
  const ProjectProfileSection({super.key,required this.data});
  final Map<String,dynamic> data;
  @override
  Widget build(BuildContext context) {
    final p=MandakhPalette.of(context), completed=learningRows(data['completed']);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const SizedBox(height:20),LearningPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(Icons.rocket_launch_outlined,color:p.accentInk,size:26),const SizedBox(width:10),const Expanded(child:Text('Төгсгөлийн төслүүд',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800))),Text('${data['count']??0} / ${data['total']??16}',style:TextStyle(color:p.accentInk,fontWeight:FontWeight.w700))]),const SizedBox(height:12),learningProgress(context,learningInt(data['count']),learningInt(data['total'])),
      if(completed.isEmpty)...[const SizedBox(height:10),Text('Баталгаажсан төсөл хараахан алга.',style:TextStyle(color:p.muted))],
      for(final item in completed)...[const Divider(),Row(children:[Icon(Icons.verified_outlined,color:p.positive),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(learningText(item['title']),style:const TextStyle(fontWeight:FontWeight.w700)),Text(learningText(item['course']),style:TextStyle(color:p.muted,fontSize:12))]))])],
    ]))]);
  }
}
