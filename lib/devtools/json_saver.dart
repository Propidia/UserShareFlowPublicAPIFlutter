import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class JsonSaver {
  static Future<File> saveJson(String fileName, Object data) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = dir.path;
    final file = File('$path/$fileName');
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    return file.writeAsString(pretty, encoding: utf8);
  }
}
