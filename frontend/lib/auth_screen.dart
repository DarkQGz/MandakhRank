import 'package:flutter/material.dart';
import 'data.dart';
class AuthScreen extends StatefulWidget {
 const AuthScreen({super.key});
 @override State<AuthScreen> createState()=>_AuthState();
}
class _AuthState extends State<AuthScreen>{
 final name=TextEditingController(),email=TextEditingController(),password=TextEditingController(),confirm=TextEditingController(),token=TextEditingController();
 bool register=false,verify=false,busy=false;String message='';
 @override void dispose(){for(final c in [name,email,password,confirm,token]){c.dispose();}super.dispose();}
 Future<void> submit()async{
  if(register&&!verify&&password.text!=confirm.text){setState(()=>message='Нууц үг таарахгүй байна.');return;}
  setState((){busy=true;message='';});
  try{
   if(verify){await PracticeApi.request('auth/verify/',body:{'token':token.text.trim()});if(mounted)setState((){verify=false;register=false;message='Имэйл баталгаажлаа. Нэвтэрнэ үү.';});}
   else if(register){await PracticeApi.request('auth/register/',body:{'username':name.text.trim(),'email':email.text.trim(),'password':password.text});if(mounted)setState((){verify=true;message='Имэйлээр ирсэн кодыг оруулна уу. Spam хавтсаа мөн шалгаарай.';});}
   else {final r=await PracticeApi.request('auth/login/',body:{'username':name.text.trim(),'password':password.text});PracticeApi.token=r['token'];PracticeApi.username=r['username'];if(mounted)Navigator.pop(context,true);}
  }catch(e){if(mounted)setState(()=>message=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('mandakhrank')),body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 const Icon(Icons.terminal,color:Color(0xFF4C86FF),size:60),const SizedBox(height:24),Text(verify?'Имэйл баталгаажуулах':register?'Бүртгэл үүсгэх':'Тавтай морил!',style:const TextStyle(fontSize:30,fontWeight:FontWeight.bold)),const SizedBox(height:24),
 if(verify) TextField(controller:token,decoration:const InputDecoration(labelText:'Имэйлээр ирсэн баталгаажуулах код')) else ...[
 TextField(controller:name,decoration:const InputDecoration(labelText:'Username')),const SizedBox(height:14),
 if(register)...[TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Имэйл хаяг')),const SizedBox(height:14)],
 TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Нууц үг')),const SizedBox(height:14),
 if(register) TextField(controller:confirm,obscureText:true,decoration:const InputDecoration(labelText:'Нууц үг давтах'))],
 const SizedBox(height:20),if(message.isNotEmpty) Padding(padding:const EdgeInsets.only(bottom:16),child:Text(message,style:const TextStyle(color:Colors.amber))),
 FilledButton(onPressed:busy?null:submit,child:Padding(padding:const EdgeInsets.all(14),child:Text(busy?'Түр хүлээнэ үү…':verify?'Баталгаажуулах':register?'Бүртгүүлэх':'Нэвтрэх'))),
 TextButton(onPressed:busy?null:()=>setState((){verify=false;register=!register;message='';}),child:Text(register?'Бүртгэлтэй бол нэвтрэх':'Шинэ бүртгэл үүсгэх')),
 TextButton(onPressed:busy?null:()=>setState(()=>verify=true),child:const Text('Баталгаажуулах код оруулах'))
 ])))));
}
