// Browser-only download; no external packages or server token in the URL.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

Future<String> exportClassroomCsv(String filename, String csv) async {
  final blob = html.Blob([utf8.encode(csv)], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final link = html.AnchorElement(href: url)..download = filename;
    html.document.body?.append(link);
    try { link.click(); } finally { link.remove(); }
    await Future<void>.delayed(const Duration(seconds: 1));
  } finally { html.Url.revokeObjectUrl(url); }
  return 'CSV файлыг татах хүсэлт илгээгдлээ.';
}
