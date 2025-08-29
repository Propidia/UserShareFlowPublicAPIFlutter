import 'package:get/get.dart';
import '../models/request_payloads.dart';
import '../services/api_client.dart';

class ConnectedOptionsController extends GetxController {
  final items = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final q = ''.obs;
  final filters = <String, dynamic>{}.obs;
  final hasMore = false.obs;

  Future<void> load({
    required int table_id,
    required int controlId,
    Map<String, dynamic> controlValues = const {},
    Map<String, dynamic>? quickUsageMeta,
    Map<String, dynamic>? filters,
    Map<String, dynamic>? formData,
    List<Map<String, dynamic>>? currentRowControls,
  }) async {
    final flitter = filters;
    Map<String, dynamic> readyFlitter = {};
    final dynamic quick = flitter?['quick_usage'];
    if (quick != null) {
      final dynamic getDataForm = quick['get_data_form'];
      if (getDataForm is Map) {
        final dynamic params = getDataForm['params'];
        if (params is Map) {
          final dynamic filtersJson = params['filters'];
          if (filtersJson is Map) {
            final replaced = replaceFilters(
              Map<String, dynamic>.from(filtersJson),
              controlValues,
              formData: formData,
              currentRowControls: currentRowControls,
            );
            readyFlitter.clear();
            readyFlitter.addAll(replaced);
          }
        }
      }
    }
    try {
      isLoading.value = true;
      final req = ConnectedOptionsRequest(
        table_id: table_id,
        controlId: controlId,
        fields: 'default',
        q: q.value,
        flitter: readyFlitter,
        controlValues: controlValues,
      );
      final res = await ApiClient.instance.getConnectedOptions(req);
      items.assignAll(List<Map<String, dynamic>>.from(res));
    } catch (e) {
      Get.snackbar('خطأ', 'فشل جلب الخيارات');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> search(
    String query, {
    required int table_id,
    required int controlId,
    Map<String, dynamic>? flitter,
    Map<String, dynamic> controlValues = const {},
    Map<String, dynamic>? quickUsageMeta,
    Map<String, dynamic>? formData,
    List<Map<String, dynamic>>? currentRowControls,
  }) async {
    q.value = query;

    items.clear();
    await load(
      table_id: table_id,
      controlId: controlId,
      controlValues: controlValues,
      quickUsageMeta: quickUsageMeta,
      filters: flitter,
      formData: formData,
      currentRowControls: currentRowControls,
    );
  }

  Future<void> nextPage({
    required int table_id,
    required int controlId,
    Map<String, dynamic> controlValues = const {},
    Map<String, dynamic>? quickUsageMeta,
    Map<String, dynamic>? flitter,
    Map<String, dynamic>? formData,
    List<Map<String, dynamic>>? currentRowControls,
  }) async {
    if (!hasMore.value || isLoading.value) return;

    await load(
      table_id: table_id,
      controlId: controlId,
      controlValues: controlValues,
      quickUsageMeta: quickUsageMeta,
      filters: flitter,
      formData: formData,
      currentRowControls: currentRowControls,
    );
  }
}

extension _ConnectedOptionsHelpers on ConnectedOptionsController {
  Map<String, dynamic> replaceFilters(
    Map<String, dynamic> filtersJson,
    Map<String, dynamic> controlValues, {
    Map<String, dynamic>? formData,
    List<Map<String, dynamic>>? currentRowControls,
  }) {
    dynamic processNode(dynamic node) {
      if (node is Map) {
        // إذا كان مفتاح null نحذفه مباشرة
        if (node.containsKey("null")) return null;

        // معالجة الحاويات ($and / $or)
        if (node.keys.length == 1 &&
            (node.containsKey("\$and") || node.containsKey("\$or"))) {
          String op = node.keys.first;
          List<dynamic> processedList = (node[op] as List)
              .map(processNode)
              .where((e) => e != null)
              .toList();

          if (processedList.length == 1) {
            // إذا كان شرط واحد فقط → إرجعه مباشرة بدون الحاوية
            return processedList.first;
          } else if (processedList.isEmpty) {
            return null;
          } else {
            return {op: processedList};
          }
        }

        // البحث عن "right" التي تحتوي على "type"
        if (node.containsKey('right') && node['right'] is Map) {
          final rightNode = Map<String, dynamic>.from(node['right']);

          if (rightNode.containsKey('type') &&
              rightNode.containsKey('control_id')) {
            final controlType = rightNode['type']?.toString() ?? '';
            final controlId = rightNode['control_id'];

            dynamic replacementValue;

            if (controlType == 'connected control') {
              // للـ connected control نحتاج control_id و key
              final key = rightNode['key']?.toString();
              replacementValue = _findControlValue(
                controlId: controlId,
                key: key,
                formData: formData,
                currentRowControls: currentRowControls,
              );
            } else if (controlType == 'normal control') {
              // للـ normal control نحتاج control_id فقط
              replacementValue = _findControlValue(
                controlId: controlId,
                formData: formData,
                currentRowControls: currentRowControls,
              );
            }

            if (replacementValue != null) {
              print(
                '   ✅ تم الاستبدال: ${rightNode['value']} → $replacementValue',
              );
              rightNode['value'] = replacementValue;
            } else {
              print('   ❌ لم يتم العثور على قيمة للاستبدال');
            }

            return node.map(
              (key, value) => key == 'right'
                  ? MapEntry(key, rightNode)
                  : MapEntry(key, processNode(value)),
            );
          }
        }

        // معالجة باقي المفاتيح
        return node.map((key, value) => MapEntry(key, processNode(value)));
      } else if (node is List) {
        return node.map(processNode).where((e) => e != null).toList();
      }

      return node;
    }

    final result = processNode(filtersJson);
    return result == null ? {} : Map<String, dynamic>.from(result);
  }

  /// البحث عن قيمة الأداة أولاً في نفس الصف ثم خارج الجدول
  dynamic _findControlValue({
    required dynamic controlId,
    String? key,
    Map<String, dynamic>? formData,
    List<Map<String, dynamic>>? currentRowControls,
  }) {
    final targetId = controlId.toString();

    print('\n🔍 _findControlValue بحث عن:');
    print('   controlId: $targetId');
    print('   key: $key');
    print(
      '   currentRowControls متوفر: ${currentRowControls?.length ?? 0} أدوات',
    );
    print('   formData متوفر: ${formData != null}');

    // البحث أولاً في نفس الصف
    if (currentRowControls != null) {
      print('   🔍 البحث في الصف الحالي...');
      for (final control in currentRowControls) {
        if (control['id'].toString() == targetId) {
          print('   ✅ وُجدت في الصف الحالي: ${control['name']}');
          final value = _extractValueFromControl(control, key);
          print('   📤 القيمة المُستخرجة: $value');
          return value;
        }
      }
      print('   ❌ لم توجد في الصف الحالي');
    }

    // البحث خارج الجدول في المستوى الرئيسي
    if (formData != null && formData.containsKey('controls')) {
      print('   🔍 البحث خارج الجدول...');
      final mainControls = formData['controls'] as List?;
      if (mainControls != null) {
        for (final control in mainControls) {
          if (control is Map && control['id'].toString() == targetId) {
            print('   ✅ وُجدت خارج الجدول: ${control['name']}');
            final value = _extractValueFromControl(
              Map<String, dynamic>.from(control),
              key,
            );
            print('   📤 القيمة المُستخرجة: $value');
            return value;
          }
        }
      }
      print('   ❌ لم توجد خارج الجدول');
    }

    print('   ❌ لم توجد الأداة نهائياً');
    return null;
  }

  /// استخراج القيمة من الأداة حسب النوع
  dynamic _extractValueFromControl(Map<String, dynamic> control, String? key) {
    final value = control['value'];

    print('   📋 _extractValueFromControl:');
    print('     control name: ${control['name']}');
    print('     control value: $value');
    print('     requested key: $key');

    if (key != null && value is Map) {
      // للـ connected control نبحث عن المفتاح المحدد
      final valueMap = Map<String, dynamic>.from(value);
      final result = valueMap[key];
      print('     ✅ نوع connected control، القيمة للمفتاح "$key": $result');
      return result;
    } else {
      // للـ normal control نرجع القيمة مباشرة
      print('     ✅ نوع normal control، القيمة المُرجعة: $value');
      return value;
    }
  }
}
