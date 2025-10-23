import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:useshareflowpublicapiflutter/help/funcs.dart';
import '../config.dart';
import '../models/form_models.dart';
import '../models/request_payloads.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    'API-KEY': AppConfig.apiKey, // <--- تغيير هنا
    'password': AppConfig.password,
    'phone-user': AppConfig.username, // <--- تغيير هنا
    'user-key': AppConfig.licenseKey, // <--- تغيير هنا
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${AppConfig.baseUrl}$path',
    ).replace(queryParameters: query);
  }

  Future<List<Map<String, dynamic>>> fetchForms() async {
    print('Headers being sent: $_headers');

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
      final result = FormStructureModel.fromJson(data);
      Funcs.form_model = result;
      Funcs.form_id = result.id ;
      return result; 
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

    final res = await http
        .post(uri, body: jsonEncode(payload), headers: _headers)
        .timeout(AppConfig.httpTimeout);

    print('   Response Status: ${res.statusCode}');

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data;
    }
    throw Exception('فشل إرسال النموذج (${res.statusCode}): ${res.body}');
  }
  /// التحقق من حالة المهمة باستخدام task_id أو correlation_id
  Future<String> checkTaskStatus(String taskId) async {
    try {
      final uri = _uri('/and_sch/check_task_status', {
        'task_id': taskId,
      });
      final res = await http
          .get(uri, headers: _headers)
          .timeout(AppConfig.httpTimeout);
      
      if (res.statusCode == 200) {
        return utf8.decode(res.bodyBytes);
      }
      throw Exception('فشل التحقق من حالة المهمة (${res.statusCode})');
    } catch (e) {
      throw Exception('خطأ في التحقق من حالة المهمة: ${e.toString()}');
    }
  }
}
