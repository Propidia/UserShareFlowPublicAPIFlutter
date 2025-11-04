import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:useshareflowpublicapiflutter/help/funcs.dart';
import 'package:useshareflowpublicapiflutter/help/log.dart';
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
    await LogServices.write('[ApiClient] بدء جلب النماذج');
    try {
      final uri = _uri('api/Get_IDs_Names_Of_Released_Entry');
      await LogServices.write('[ApiClient] URI: $uri');
      final res = await http
          .get(uri, headers: _headers)
          .timeout(AppConfig.httpTimeout);
      await LogServices.write('[ApiClient] Response Status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        await LogServices.write('[ApiClient] ✅ تم جلب النماذج بنجاح - العدد: ${data.length}');
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      await LogServices.write('[ApiClient] ❌ فشل جلب النماذج - Status: ${res.statusCode}');
      throw Exception('فشل جلب النماذج (${res.statusCode})');
    } catch (e) {
      await LogServices.write('[ApiClient] ❌ Exception في fetchForms: $e');
      throw Exception('فشل جلب النماذج: $e');
    }
  }

  Future<FormStructureModel> fetchFormStructure(int formId) async {
    await LogServices.write('[ApiClient] بدء جلب هيكل النموذج - form_id: $formId');
    try {
      final uri = _uri('api/Bring_TheControls_Of_Released_EntryForm', {
        'form_id': formId.toString(),
      });
      final res = await http
          .get(uri, headers: _headers)
          .timeout(AppConfig.httpTimeout);
      await LogServices.write('[ApiClient] Response Status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        final result = FormStructureModel.fromJson(data);
        Funcs.form_model = result;
        Funcs.form_id = result.id;
        await LogServices.write('[ApiClient] ✅ تم جلب هيكل النموذج بنجاح - form_id: ${result.id}, عدد الأدوات: ${result.controls.length}');
        return result;
      }
      await LogServices.write('[ApiClient] ❌ فشل جلب هيكل النموذج - Status: ${res.statusCode}');
      throw Exception('فشل جلب هيكل النموذج (${res.statusCode})');
    } catch (e) {
      await LogServices.write('[ApiClient] ❌ Exception في fetchFormStructure: $e');
      throw Exception('فشل جلب هيكل النموذج: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getConnectedOptions(
    ConnectedOptionsRequest req,
  ) async {
    await LogServices.write('[ApiClient] بدء جلب خيارات أداة الربط');
    try {
      List<Map<String, dynamic>> items = [];

      final query = req.toQuery();
      final uri = _uri('api/GetDataForm', query);
      final res = await http
          .get(uri, headers: _headers)
          .timeout(AppConfig.httpTimeout);

      await LogServices.write('[ApiClient] GetConnectedOptions Response Status: ${res.body}');
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
            await LogServices.write('[ApiClient] ✅ تم جلب خيارات أداة الربط - العدد: ${items.length}');
          } else {
            await LogServices.write('[ApiClient] ⚠️ قائمة خيارات أداة الربط فارغة');
          }
        } catch (e) {
          await LogServices.write('[ApiClient] ❌ خطأ في تحليل خيارات أداة الربط: $e');
        }
        return items;
      }
      await LogServices.write('[ApiClient] ❌ فشل جلب خيارات أداة الربط - Status: ${res.statusCode}');
      throw Exception('فشل جلب خيارات أداة الربط (${res.statusCode})');
    } catch (e) {
      await LogServices.write('[ApiClient] ❌ Exception في getConnectedOptions: $e');
      throw Exception('فشل جلب خيارات أداة الربط: $e');
    }
  }

  Future<Map<String, dynamic>> getDataForm(GetDataFormRequest req) async {
    await LogServices.write('[ApiClient] بدء جلب بيانات النموذج');
    try {
      final query = req.toQuery();
      final uri = _uri('api/GetDataForm', query);
      final res = await http
          .get(uri, headers: _headers)
          .timeout(AppConfig.httpTimeout);
      await LogServices.write('[ApiClient] getDataForm Response Status: ${res.body}');
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        await LogServices.write('[ApiClient] ✅ تم جلب بيانات النموذج بنجاح');
        return data;
      }
      await LogServices.write('[ApiClient] ❌ فشل جلب البيانات - Status: ${res.statusCode}');
      throw Exception('فشل جلب البيانات (${res.statusCode})');
    } catch (e) {
      await LogServices.write('[ApiClient] ❌ Exception في getDataForm: $e');
      throw Exception('فشل جلب البيانات: $e');
    }
  }

  /// إرسال بيانات النموذج
  Future<Map<String, dynamic>> submitForm(Map<String, dynamic> payload) async {
    await LogServices.write('[ApiClient] بدء إرسال بيانات النموذج');
    try {
      final uri = _uri(AppConfig.submitFormEndpoint);
      await LogServices.write('[ApiClient] URI: $uri');

      final res = await http
          .post(uri, body: jsonEncode(payload), headers: _headers)
          .timeout(AppConfig.httpTimeout);

      await LogServices.write('[ApiClient] submitForm Response Status: ${res.body}');

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        await LogServices.write('[ApiClient] ✅ تم إرسال النموذج بنجاح');
        return data;
      }
      await LogServices.write('[ApiClient] ❌ فشل إرسال النموذج - Status: ${res.statusCode}, Body: ${res.body}');
      throw Exception('فشل إرسال النموذج (${res.statusCode}): ${res.body}');
    } catch (e) {
      await LogServices.write('[ApiClient] ❌ Exception في submitForm: $e');
      throw Exception('فشل إرسال النموذج: $e');
    }
  }

  /// التحقق من حالة المهمة باستخدام task_id أو correlation_id
  Future<String> checkTaskStatus(String taskId, {String? accessToken}) async {
    await LogServices.write('[ApiClient] بدء التحقق من حالة المهمة - task_id: $taskId');
    try {
      final uri = _uri('and_sch/check_task_status', {'task_id': taskId});

      // دمج Authorization header مع _headers الأساسية عند توفر accessToken
      Map<String, String> headers;
      if (accessToken != null && accessToken.isNotEmpty) {
        headers = Map<String, String>.from(_headers);
        headers['Authorization'] = 'Bearer $accessToken';
        await LogServices.write('[ApiClient] 🔑 استخدام accessToken للمصادقة - task_id: $taskId');
      } else {
        headers = _headers;
        await LogServices.write('[ApiClient] ⚠️ accessToken غير موجود، استخدام الـ headers الأساسية فقط - task_id: $taskId');
      }

      final res = await http
          .get(uri, headers: headers)
          .timeout(AppConfig.httpTimeout);

      await LogServices.write('[ApiClient] checkTaskStatus Response Status: ${res.body} - task_id: $taskId');

      if (res.statusCode == 200) {
        await LogServices.write('[ApiClient] ✅ تم التحقق من حالة المهمة بنجاح - task_id: $taskId');
        return utf8.decode(res.bodyBytes);
      }
      await LogServices.write('[ApiClient] ❌ فشل التحقق من حالة المهمة - Status: ${res.statusCode}, task_id: $taskId');
      throw Exception('فشل التحقق من حالة المهمة (${res.statusCode})');
    } catch (e) {
      await LogServices.write('[ApiClient] ❌ Exception في checkTaskStatus - task_id: $taskId, الخطأ: $e');
      throw Exception('خطأ في التحقق من حالة المهمة: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getFirstMatch({
  required int formId,
  required int controlId,
  required String value,
  String? colName,
}) async {
  await LogServices.write('[ApiClient] بدء البحث عن أول تطابق - form_id: $formId, control_id: $controlId, value: $value');
  try {
    final uri = _uri(
      'api/GetFirstMatch',
       {
        'form_id': formId.toString(),
        'control_id': controlId.toString(),
        'value': '%$value%',           
        if (colName != null && colName.isNotEmpty) 'col_name': colName,
      },
    );

    // POST بدون body (يكفي الهيدر)
    final res = await http.post(uri, headers: _headers).timeout(AppConfig.httpTimeout);

    await LogServices.write('[ApiClient] getFirstMatch Response Status: ${res.body} - getFirstMatch');

    if (res.statusCode == 200) {
      await LogServices.write('[ApiClient] ✅ تم العثور على تطابق بنجاح - form_id: $formId, control_id: $controlId');
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    if (res.statusCode == 400) {
      final errorData = jsonDecode(res.body);
      await LogServices.write('[ApiClient] ❌ خطأ 400 في البحث - form_id: $formId, الخطأ: ${errorData['error'] ?? 'خطأ في البحث'}');
      throw Exception(errorData['error'] ?? 'خطأ في البحث');
    }
    if (res.statusCode == 401) {
      await LogServices.write('[ApiClient] ❌ خطأ 401 - API KEY غير صالح - form_id: $formId');
      throw Exception('API KEY غير صالح');
    }
    if (res.statusCode == 404) {
      await LogServices.write('[ApiClient] ⚠️ لم يتم العثور على تطابق - form_id: $formId, control_id: $controlId, value: $value');
      throw Exception('لم يتم العثور على تطابق');
    }
    await LogServices.write('[ApiClient] ❌ فشل البحث عن تطابق - Status: ${res.statusCode}, form_id: $formId');
    Funcs.errors.add('فشل البحث عن تطابق (${res.statusCode}): ${res.body}');
    await Funcs.checkRepeatingErrors();
    throw Exception('فشل البحث عن تطابق (${res.statusCode}): ${res.body}');
  } catch (e) {
    await LogServices.write('[ApiClient] ❌ Exception في getFirstMatch - form_id: $formId, control_id: $controlId, الخطأ: $e');
    throw Exception('خطأ في البحث عن تطابق: $e');
  }
}
}