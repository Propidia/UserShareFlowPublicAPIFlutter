import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../models/form_models.dart';
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
          // debugPrint(filtersJson);
          final replaced = replaceFilters(filtersJson, controlValues);
          readyFlitter.clear();
          readyFlitter.addAll(replaced);
          debugPrint(filters.toString());
          debugPrint(replaced.toString());
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
        flitter: readyFlitter ?? {},
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

  dynamic _extractByColId(Map<String, dynamic> row, int? id) {
    if (id == null) return null;
    for (final key in row.keys) {
      final k = key.toString().replaceAll('"', '');
      if (k == id.toString()) return row[key];
      if (k.startsWith('$id ')) return row[key];
      final match = RegExp(r'^(\d+)').firstMatch(k);
      if (match != null && match.group(1) == id.toString()) return row[key];
      if (k.contains('SYS Field-$id ')) return row[key];
    }
    return null;
  }

  Future<void> search(
    String query, {
    required int table_id,
    required int controlId,
    Map<String, dynamic>? flitter,
    Map<String, dynamic> controlValues = const {},
    Map<String, dynamic>? quickUsageMeta,
  }) async {
    q.value = query;

    items.clear();
    await load(
      table_id: table_id,
      controlId: controlId,
      controlValues: controlValues,
      quickUsageMeta: quickUsageMeta,
      filters: flitter,
    );
  }

  Future<void> nextPage({
    required int table_id,
    required int controlId,
    Map<String, dynamic> controlValues = const {},
    Map<String, dynamic>? quickUsageMeta,
    Map<String, dynamic>? flitter,
  }) async {
    if (!hasMore.value || isLoading.value) return;

    await load(
      table_id: table_id,
      controlId: controlId,
      controlValues: controlValues,
      quickUsageMeta: quickUsageMeta,
      filters: flitter,
    );
  }
}

extension _ConnectedOptionsHelpers on ConnectedOptionsController {
  GetDataFormRequest _buildGetDataFormRequestFromQuickUsage({
    required Map<String, dynamic>? quickUsage,
    required int controlId,
    required Map<String, dynamic> controlValues,
    required int fallbackTableId,
    required String fields,
  }) {
    int tableId = fallbackTableId;
    String ordertype = 'DESC';
    String? orderfields = 'c501';
    String filtersJson = '';

    if (quickUsage != null) {
      final dynamic gdf = quickUsage['get_data_form'];
      if (gdf is Map) {
        final dynamic params = gdf['params'];
        if (params is Map) {
          if (params['table_id'] is int) tableId = params['table_id'] as int;
          if (params['ordertype'] is String) {
            final ot = (params['ordertype'] as String).trim();
            if (ot.isNotEmpty) ordertype = ot;
          }
          if (params['orderfields'] is String) {
            final of = (params['orderfields'] as String).trim();
            if (of.isNotEmpty) orderfields = of;
          }
          final List<dynamic> depends =
              (params['filtersDepends'] as List?) ?? const [];
          final dynamic filters = params['filters'];
          if (filters != null) {
            final replaced = _replacePlaceholdersDeep(
              filters,
              depends,
              controlValues,
            );
            try {
              filtersJson = jsonEncode(replaced);
            } catch (_) {
              filtersJson = '';
            }
          }
        }
      }
    }

    return GetDataFormRequest(
      tableId: tableId,
      maxRowNumber: 0,

      fields: fields,
      filters: filtersJson,
      ordertype: ordertype,
      connectedControlId: controlId,
      controlValues: controlValues,
      orderfields: orderfields,
    );
  }

  dynamic _replacePlaceholdersDeep(
    dynamic node,
    List<dynamic> depends,
    Map<String, dynamic> controlValues,
  ) {
    if (node is Map) {
      final out = <String, dynamic>{};
      node.forEach((k, v) {
        out[k.toString()] = _replacePlaceholdersDeep(v, depends, controlValues);
      });
      return out;
    }
    if (node is List) {
      return node
          .map((e) => _replacePlaceholdersDeep(e, depends, controlValues))
          .toList();
    }
    if (node is String) {
      if (node.contains('< Replace')) {
        final int? cid = _extractControlIdFromPlaceholder(node);
        if (cid != null) {
          final source = _sourceForControlId(depends, cid);
          final raw = controlValues[cid.toString()];
          final fieldName = _extractFieldNameFromPlaceholder(node);
          final val = _valueFromControl(
            raw,
            source: source,
            fieldName: fieldName,
          );
          return val ?? '';
        }
      }
      return node;
    }
    return node;
  }

  int? _extractControlIdFromPlaceholder(String s) {
    final re = RegExp(r'[Ii]d\s*:?\s*(\d+)');
    final m = re.firstMatch(s);
    if (m != null) {
      return int.tryParse(m.group(1)!);
    }
    return null;
  }

  String _sourceForControlId(List<dynamic> depends, int controlId) {
    for (final d in depends) {
      if (d is Map && d['control_id'] is int && d['control_id'] == controlId) {
        return (d['source']?.toString() ?? 'control').toLowerCase();
      }
    }
    return 'control';
  }

  String? _extractFieldNameFromPlaceholder(String s) {
    final re = RegExp(r'value of\s+(.+?)\s+in Control', caseSensitive: false);
    final m = re.firstMatch(s);
    if (m != null) {
      return m.group(1)?.trim();
    }
    return null;
  }

  dynamic _valueFromControl(
    dynamic raw, {
    required String source,
    String? fieldName,
  }) {
    if (source == 'connected') {
      try {
        Map<String, dynamic>? obj;
        if (raw is String && raw.trim().startsWith('{')) {
          obj = jsonDecode(raw) as Map<String, dynamic>;
        } else if (raw is Map) {
          obj = Map<String, dynamic>.from(raw);
        }
        // if (obj != null) {
        //   if (fieldName != null && obj['display'] is Map) {
        //     final disp = Map<String, dynamic>.from(obj['display'] as Map);
        //     if (disp.containsKey(fieldName)) return disp[fieldName];
        //   }
        //   if (obj['label'] != null && obj['label'].toString().isNotEmpty) {
        //     return obj['label'];
        //   }
        //   if (obj['value'] != null) return obj['value'];
        // }
      } catch (_) {}
      return null;
    }
    return raw;
  }

  Map<String, dynamic> replaceFilters(
    Map<String, dynamic> filtersJson,
    Map<String, dynamic> controlValues,
  ) {
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

        // معالجة باقي المفاتيح
        return node.map((key, value) => MapEntry(key, processNode(value)));
      } else if (node is List) {
        return node.map(processNode).where((e) => e != null).toList();
      } else if (node is String && node.contains('< Replace')) {
        // نمط عام لقراءة Id سواء Have id:X أو (Id: X)
        final idMatch = RegExp(
          r'Have id:(\d+)|\(Id:\s*(\d+)\)',
        ).firstMatch(node);
        if (idMatch != null) {
          // idGroup1 = حالة "Have id:X"
          // idGroup2 = حالة "(Id: X)"
          final controlId = idMatch.group(1) ?? idMatch.group(2);
          if (controlId != null && controlValues.containsKey(controlId)) {
            return controlValues[controlId];
          }
        }
        return '';
      }

      return node;
    }

    final result = processNode(filtersJson);
    return result == null ? {} : Map<String, dynamic>.from(result);
  }
}
