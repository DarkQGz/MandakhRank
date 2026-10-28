import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final name = TextEditingController(), email = TextEditingController();
  final password = TextEditingController(), confirm = TextEditingController();
  final code = TextEditingController();
  bool register = false, verify = false, busy = false;
  String message = '';
  int cooldown = 0;
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    for (final c in [name, email, password, confirm, code]) {
      c.dispose();
    }
    super.dispose();
  }

  void startCooldown() {
    cooldown = 60;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => cooldown--);
      if (cooldown <= 0) t.cancel();
    });
  }

  void finish(Map<String, dynamic> data) {
    if (!mounted) return;
    PracticeApi.token = data['token'] as String;
    PracticeApi.username = data['username'] as String;
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> submit() async {
    if (busy) return;
    if (verify && code.text.length != 4) return;
    if (register && !verify && password.text != confirm.text) {
      setState(() => message = 'Нууц үг таарахгүй байна.');
      return;
    }
    setState(() {
      busy = true;
      message = '';
    });
    try {
      if (verify) {
        final r = await PracticeApi.request(
          'auth/verify/',
          body: {'email': email.text.trim(), 'code': code.text},
        );
        finish(r);
      } else if (register) {
        await PracticeApi.request(
          'auth/register/',
          body: {
            'username': name.text.trim(),
            'email': email.text.trim(),
            'password': password.text,
          },
        );
        if (mounted)
          setState(() {
            verify = true;
            code.clear();
            startCooldown();
            message = 'Код илгээгдлээ. Spam хавтсаа мөн шалгаарай.';
          });
      } else {
        finish(
          await PracticeApi.request(
            'auth/login/',
            body: {'username': name.text.trim(), 'password': password.text},
          ),
        );
      }
    } catch (e) {
      if (mounted)
        setState(() {
          message = e.toString();
          if (verify) code.clear();
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    if (busy || cooldown > 0) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await PracticeApi.request(
        'auth/resend/',
        body: {'email': email.text.trim(), 'password': password.text},
      );
      if (mounted)
        setState(() {
          startCooldown();
          code.clear();
          message = 'Шинэ код илгээгдлээ.';
        });
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('mandakhrank')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  verify ? Icons.mark_email_read_outlined : Icons.terminal,
                  color: const Color(0xFF4C86FF),
                  size: 60,
                ),
                const SizedBox(height: 24),
                Text(
                  verify
                      ? 'Имэйлээ баталгаажуулъя'
                      : register
                      ? 'Бүртгэл үүсгэх'
                      : 'Тавтай морил!',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (verify)
                  const Text(
                    '4 оронтой кодоо оруулахад автоматаар баталгаажуулж, нэвтрүүлнэ. Код 10 минут хүчинтэй.',
                  ),
                const SizedBox(height: 24),
                if (verify) ...[
                  TextField(
                    key: const Key('verification-email'),
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Бүртгүүлсэн имэйл',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('verification-code'),
                    controller: code,
                    autofocus: true,
                    enabled: !busy,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 36,
                      letterSpacing: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: '4 оронтой код',
                      counterText: '',
                    ),
                    onChanged: (value) {
                      if (value.length == 4) submit();
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: true,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Нууц үг (шинэ код авахад)',
                    ),
                  ),
                  TextButton(
                    onPressed: busy || cooldown > 0 ? null : resend,
                    child: Text(
                      cooldown > 0
                          ? 'Шинэ код авах • $cooldown сек'
                          : 'Шинэ код авах',
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: name,
                    enabled: !busy,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 14),
                  if (register) ...[
                    TextField(
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Имэйл хаяг',
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Нууц үг'),
                  ),
                  const SizedBox(height: 14),
                  if (register)
                    TextField(
                      controller: confirm,
                      enabled: !busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Нууц үг давтах',
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.amber),
                    ),
                  ),
                if (busy) const LinearProgressIndicator(),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      busy
                          ? 'Түр хүлээнэ үү…'
                          : verify
                          ? 'Баталгаажуулах'
                          : register
                          ? 'Бүртгүүлэх'
                          : 'Нэвтрэх',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          verify = false;
                          register = !register;
                          message = '';
                          code.clear();
                        }),
                  child: Text(
                    register ? 'Бүртгэлтэй бол нэвтрэх' : 'Шинэ бүртгэл үүсгэх',
                  ),
                ),
                if (!verify)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            verify = true;
                            message = '';
                            code.clear();
                          }),
                    child: const Text('Код оруулах / шинэ код авах'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
