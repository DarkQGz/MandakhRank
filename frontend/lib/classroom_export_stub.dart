import 'package:flutter/services.dart';

Future<String> exportClassroomCsv(String filename, String csv) async {
  await Clipboard.setData(ClipboardData(text: csv));
  return 'CSV өгөгдлийг хууллаа. Excel-д буулгаж хадгална уу.';
}
