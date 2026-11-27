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
        'recent':[],'appearance':{...appearance(owner:owner), 'background':owner?'soft':'gradient'},'can_comment':true,'comments':[],'next_before':null}),200,headers:{'content-type':'application/json; charset=utf-8'}));
      tester.view.physicalSize=const Size(360,850);tester.view.devicePixelRatio=1;
      addTearDown((){PracticeApi.client.close();PracticeApi.client=old;PracticeApi.token=token;PracticeApi.avatarUrl=avatar;tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();});
      await tester.pumpWidget(MaterialApp(theme:MandakhPalette.light.themeData(),home:Scaffold(body:SingleChildScrollView(child:StudentDashboard(
        userId:owner?null:1,catalog:const {'courses':[]},onNavigate:(_){},onLogin:()async{},onAvatarChanged:(){},onOpenProfile:(_){},
      )))));await tester.pumpAndSettle();
      expect(find.byType(TeacherRoleChip),findsWidgets);
      expect(find.text('Шилдэг #1'),findsOneWidget);
      expect(find.byKey(const ValueKey('appearance-open')),owner?findsOneWidget:findsNothing);
      expect(find.text('Онцлох амжилтууд'),findsOneWidget);
      final header=tester.widget<Container>(find.byKey(const ValueKey('profile-appearance-header')));
      final decoration=header.decoration! as BoxDecoration;
      final context=tester.element(find.byKey(const ValueKey('profile-appearance-header')));
      final base=teacherSurface(context);
      if(owner){expect(decoration.gradient,isNull);expect(decoration.color,isNot(base));}
      else {expect(decoration.gradient,isA<LinearGradient>());expect((decoration.gradient! as LinearGradient).colors.toSet().length,greaterThan(1));}
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
    Future<void> tapVisible(Finder target) async {
      await tester.ensureVisible(target);await tester.pumpAndSettle();
      await tester.tap(target);await tester.pumpAndSettle();
    }
    final lockedTile=find.byKey(const ValueKey('appearance-reward-solve_5'));
    final all=find.byKey(const ValueKey('appearance-filter-all'));
    final unlocked=find.byKey(const ValueKey('appearance-filter-unlocked'));
    final openTile=find.byKey(const ValueKey('appearance-reward-solve_1'));
    final reset=find.byKey(const ValueKey('appearance-default'));
    await tester.scrollUntilVisible(all,100,scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(lockedTile,findsNothing);
    await tapVisible(all);
    // The gallery is one Wrap, so all visible filter results are built together.
    await tester.scrollUntilVisible(lockedTile,100,scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(lockedTile).onTap,isNull);
    await tapVisible(unlocked);
    expect(lockedTile,findsNothing);
    await tester.scrollUntilVisible(reset,80,scrollable:find.byType(Scrollable).first);
    await tapVisible(reset);
    await tapVisible(openTile);
    // A preset equips frame, accent and title together; the default clears all three.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('appearance-background-gradient')),-100,scrollable:find.byType(Scrollable).first);
    await tapVisible(find.byKey(const ValueKey('appearance-background-soft')));
    final preview=find.byKey(const ValueKey('appearance-preview'));
    await tester.scrollUntilVisible(preview,-100,scrollable:find.byType(Scrollable).first);
    final solid=tester.widget<Container>(preview).decoration! as BoxDecoration;
    expect(solid.gradient,isNull);
    expect(solid.color,isNot(MandakhPalette.original.surface));
    await tapVisible(find.byKey(const ValueKey('appearance-background-gradient')));
    await tester.scrollUntilVisible(preview,-100,scrollable:find.byType(Scrollable).first);
    final decoration=tester.widget<Container>(preview).decoration! as BoxDecoration;
    expect(decoration.gradient,isA<LinearGradient>());
    expect((decoration.gradient! as LinearGradient).colors.toSet().length,greaterThan(1));
    await tester.tap(find.byKey(const ValueKey('appearance-save')));await tester.pumpAndSettle();
    for(final key in ['frame','accent','title'])expect(posted![key],'solve_1');
    expect(posted!['background'],'gradient');
    expect(posted!.keys.toSet(),{'frame','accent','title','background','motion','featured'});
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
  for(final palette in [MandakhPalette.original,MandakhPalette.light,MandakhPalette.orange]){
    testWidgets('plain, solid and gradient backgrounds are visibly distinct and readable: ${palette.background}',(tester)async{
      await tester.pumpWidget(MaterialApp(theme:palette.themeData(),home:Builder(builder:(context){
        final plain={'background':'plain'};
        final solid={'background':'soft','accent':reward};
        final gradient={'background':'gradient','accent':reward};
        expect(prestigeBackgroundColor(context,plain,palette.surface),palette.surface);
        expect(prestigeBanner(context,plain,palette.surface),isNull);
        final color=prestigeBackgroundColor(context,solid,palette.surface);
        expect(color,isNot(palette.surface));
        expect(prestigeBanner(context,solid,palette.surface),isNull);
        expect(MandakhPalette.contrast(color,palette.text),greaterThanOrEqualTo(4.5));
        final stops=prestigeBanner(context,gradient,palette.surface)!.colors;
        expect(stops.toSet().length,greaterThan(1));
        for(final stop in stops)expect(MandakhPalette.contrast(stop,palette.text),greaterThanOrEqualTo(4.5));
        return const SizedBox.shrink();
      })));
      expect(tester.takeException(),isNull);
    });
  }
}
