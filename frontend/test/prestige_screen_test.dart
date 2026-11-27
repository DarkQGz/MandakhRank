import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandakhrank/data.dart';
import 'package:mandakhrank/dashboard_screen.dart';
import 'package:mandakhrank/prestige_screen.dart';
import 'package:mandakhrank/teacher_screen.dart';
import 'package:mandakhrank/theme_settings.dart';

const reward={'id':'solve_1','title':'Анхны алхам','description':'1 бодлогыг зөв бодох','colors':['60A5FA','B8E7FF'],'motif':'prism','unlocked':true,'progress':1,'target':1};
const locked={'id':'solve_5','title':'Шинэ кодлогч','description':'5 бодлого','colors':['4385F4','38E5CF'],'motif':'orbit','unlocked':false,'progress':1,'target':5};
Map<String,dynamic> appearance({bool owner=true})=>{
  'rank':1,'motion':false,'background':'plain','frame':reward,'accent':reward,'title':reward,'featured':[reward],
  if(owner)'preferences':{'frame':'solve_1','accent':'solve_1','title':'solve_1','background':'plain','motion':false,'featured':['solve_1']},
  if(owner)'rewards':[reward,locked],
};

void main(){
  testWidgets('rank frame is tappable and settles; honors reduced motion',(tester)async{
    var taps=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:MediaQuery(data:const MediaQueryData(disableAnimations:true),
      child:PrestigeFrame(rank:1,reward:reward,child:Material(child:InkWell(key:const ValueKey('tappable'),onTap:()=>taps++,child:const SizedBox(width:180,height:100,child:Text('Rank')))))))));
    await tester.pumpAndSettle();await tester.tap(find.byKey(const ValueKey('tappable')));await tester.pumpAndSettle();
    expect(taps,1);expect(tester.takeException(),isNull);
    // Motion enabled uses a single finite entrance sweep.
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:PrestigeFrame(rank:2,child:const SizedBox(width:180,height:100)))));
    await tester.pumpAndSettle();expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for(final owner in [true,false]){
    testWidgets('profile prestige is public, customization owner-only: $owner',(tester)async{
      final old=PracticeApi.client,token=PracticeApi.token,avatar=PracticeApi.avatarUrl;
      PracticeApi.token='test';PracticeApi.avatarUrl=null;
      PracticeApi.client=MockClient((r)async=>http.Response(jsonEncode({'id':1,'username':'teacher','role':'teacher','is_owner':owner,
        'joined_at':'2026-01-01T00:00:00Z','avatar_url':null,'statistics':{'points':20,'solved':1,'submissions':1,'courses':16},
        'recent':[],'appearance':appearance(owner:owner),'can_comment':true,'comments':[],'next_before':null}),200,headers:{'content-type':'application/json; charset=utf-8'}));
      tester.view.physicalSize=const Size(360,850);tester.view.devicePixelRatio=1;
      addTearDown((){PracticeApi.client.close();PracticeApi.client=old;PracticeApi.token=token;PracticeApi.avatarUrl=avatar;tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
      await tester.pumpWidget(MaterialApp(theme:MandakhPalette.light.themeData(),home:Scaffold(body:SingleChildScrollView(child:StudentDashboard(
        userId:owner?null:1,catalog:const {'courses':[]},onNavigate:(_){},onLogin:()async{},onAvatarChanged:(){},onOpenProfile:(_){},
      )))));await tester.pumpAndSettle();
      expect(find.byType(TeacherRoleChip),findsWidgets);
      expect(find.text('Шилдэг #1'),findsOneWidget);
      expect(find.byKey(const ValueKey('appearance-open')),owner?findsOneWidget:findsNothing);
      expect(find.text('Онцлох амжилтууд'),findsOneWidget);
      expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('locked cosmetic cannot be selected and saving sends preferences only',(tester)async{
    final old=PracticeApi.client,token=PracticeApi.token;
    PracticeApi.token='test';Map<String,dynamic>? posted;
    PracticeApi.client=MockClient((r)async{
      posted=Map<String,dynamic>.from(jsonDecode(r.body) as Map);
      return http.Response(jsonEncode({'appearance':{...appearance(),'preferences':posted}}),200,headers:{'content-type':'application/json; charset=utf-8'});
    });
    tester.view.physicalSize=const Size(360,850);tester.view.devicePixelRatio=1;
    addTearDown((){PracticeApi.client.close();PracticeApi.client=old;PracticeApi.token=token;tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
    await tester.pumpWidget(MaterialApp(theme:MandakhPalette.original.themeData(),home:Scaffold(body:Builder(builder:(context)=>TextButton(
      onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ProfileCustomizationScreen(appearance:appearance(),username:'student'))),child:const Text('Open'))))));
    await tester.tap(find.text('Open'));await tester.pumpAndSettle();
    final lockedTile=find.byKey(const ValueKey('appearance-reward-solve_5'));
    await tester.scrollUntilVisible(lockedTile,150,scrollable:find.byType(Scrollable).first);await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(lockedTile).onTap,isNull);
    final openTile=find.byKey(const ValueKey('appearance-reward-solve_1'));
    await tester.scrollUntilVisible(openTile,-100,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(openTile);await tester.tap(openTile);await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-save')));await tester.pumpAndSettle();
    expect(posted!['frame'],'');expect(posted!.keys.toSet(),{'frame','accent','title','background','motion','featured'});
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
}
