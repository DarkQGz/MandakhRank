import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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

class PracticeApi {
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
    if (response.statusCode >= 400)
      throw Exception(data['error'] ?? 'Алдаа ${response.statusCode}');
    return data;
  }
}
