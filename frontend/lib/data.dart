import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Repository {
  static const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mandakhrank-api.onrender.com/api',
  );
  Future<Map<String, dynamic>> load() async {
    if (base.isEmpty) {
      return jsonDecode(await rootBundle.loadString('assets/demo.json'))
          as Map<String, dynamic>;
    }
    final result = <String, dynamic>{};
    for (final kind in ['rankings', 'problems', 'courses', 'contests']) {
      final response = await PracticeApi.client
          .get(
            Uri.parse('${base.replaceFirst(RegExp(r'/+$'), '')}/$kind/'),
            headers: {
              if (PracticeApi.token != null)
                'Authorization': 'Bearer ${PracticeApi.token}',
            },
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != 200)
        throw Exception('API ${response.statusCode}');
      result[kind] = (jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>)['results'];
    }
    return result;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final Map<String, dynamic> data;
  ApiException(this.statusCode, this.data);

  @override
  String toString() => data['error']?.toString() ?? 'API алдаа $statusCode';
}

class PracticeApi {
  static const _tokenKey = 'mandakhrank.session.token';
  static const _usernameKey = 'mandakhrank.session.username';

  static Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);
      final savedName = prefs.getString(_usernameKey);
      if (savedToken != null && savedToken.length == 64 && savedName != null) {
        token = savedToken;
        username = savedName;
      }
    } catch (_) {
      // Storage might be blocked in private browsing. Login still works in memory.
    }
  }

  static Future<void> signIn(Map<String, dynamic> data) async {
    final newToken = data['token'] as String;
    final newUsername = data['username'] as String;
    token = newToken;
    username = newUsername;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newToken);
      await prefs.setString(_usernameKey, newUsername);
    } catch (_) {
      // A storage failure must not block a valid sign-in.
    }
  }

  static Future<void> signOut() async {
    token = null;
    username = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_usernameKey);
    } catch (_) {
      // The in-memory session has been cleared regardless.
    }
  }

  static http.Client client = http.Client();
  static String? token;
  static String? username;
  static Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (Repository.base.isEmpty) throw Exception('API горимоор ажиллуулна уу.');
    final uri = Uri.parse(
      '${Repository.base.replaceFirst(RegExp(r'/+$'), '')}/$path',
    );
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final response =
        await (body == null
                ? client.get(uri, headers: headers)
                : client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 90));
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, data);
    }
    return data;
  }
}
