import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/form_models.dart';
import '../models/request_payloads.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    'API_KEY': AppConfig.apiKey,
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${AppConfig.baseUrl}$path',
    ).replace(queryParameters: query);
  }

  Future<List<Map<String, dynamic>>> fetchForms() async {
    final uri = _uri('/Get_IDs_Names_Of_Released_Entry');
    final res = await http
        .get(uri, headers: _headers)
        .timeout(AppConfig.httpTimeout);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception('فشل جلب النماذج (${res.statusCode})');
  }

  Future<FormStructureModel> fetchFormStructure(int formId) async {
    final uri = _uri('/Bring_TheControls_Of_Released_EntryForm', {
      'form_id': formId.toString(),
    });
    final res = await http
        .get(uri, headers: _headers)
        .timeout(AppConfig.httpTimeout);
    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return FormStructureModel.fromJson(data);
    }
    throw Exception('فشل جلب هيكل النموذج (${res.statusCode})');
  }

  Future<List<Map<String, dynamic>>> getConnectedOptions(
    ConnectedOptionsRequest req,
  ) async {
    List<Map<String, dynamic>> items = [];

    final query = req.toQuery();
    final uri = _uri('/GetDataForm', query);
    final res = await http
        .get(uri, headers: _headers)
        .timeout(AppConfig.httpTimeout);

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));

      try {
        final rawList = data['data'];
        if (rawList is List) {
          items = rawList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (items.isNotEmpty) {
          print('[API] first connected option: ${items.first}');
        } else {
          print('[API] connected options empty');
        }
      } catch (e) {
        print('Parsing error: $e');
      }
      return items;
    }
    throw Exception('فشل جلب خيارات أداة الربط (${res.statusCode})');
  }

  Future<Map<String, dynamic>> getDataForm(GetDataFormRequest req) async {
    final query = req.toQuery();
    final uri = _uri('/GetDataForm', query);
    final res = await http
        .get(uri, headers: _headers)
        .timeout(AppConfig.httpTimeout);
    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data;
    }
    throw Exception('فشل جلب البيانات (${res.statusCode})');
  }

  /// إرسال بيانات النموذج
  Future<Map<String, dynamic>> submitForm(Map<String, dynamic> payload) async {
    final uri = _uri(AppConfig.submitFormEndpoint);

    print('\n📤 إرسال النموذج:');
    print('   URL: $uri');
    print('   Payload: ${jsonEncode(payload)}');

    final res = await http
        .post(uri, body: jsonEncode(payload), headers: _headers)
        .timeout(AppConfig.httpTimeout);

    print('   Response Status: ${res.statusCode}');
    print('   Response Body: ${res.body}');

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data;
    }
    throw Exception('فشل إرسال النموذج (${res.statusCode}): ${res.body}');
  }
}
