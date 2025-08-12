import 'package:get/get.dart';
import '../models/form_models.dart';
import '../models/request_payloads.dart';
import '../services/api_client.dart';

class ConnectedOptionsController extends GetxController {
  final items = <ConnectedOptionItem>[].obs;
  final isLoading = false.obs;
  final q = ''.obs;
  int page = 1;
  int pageSize = 500; // زيادة الحجم الافتراضي لإظهار أكبر قدر ممكن من النتائج
  final hasMore = false.obs;

  Future<void> load({
    required int formId,
    required int controlId,
    Map<String, dynamic> controlValues = const {},
  }) async {
    try {
      isLoading.value = true;
      final req = ConnectedOptionsRequest(
        formId: formId,
        controlId: controlId,
        page: page,
        pageSize: pageSize,
        fields: 'default',
        q: q.value,
        controlValues: controlValues,
      );
      final res = await ApiClient.instance.getConnectedOptions(req);
      // تتبع للمساعدة في التشخيص
      // ignore: avoid_print
      print(
        '[ConnectedOptions] page=$page size=$pageSize q="${q.value}" items=${res.items.length}',
      );
      // إن كانت العناصر بلا label وdisplay، اجلبها عبر GetDataForm كحل بديل
      final bool allBlank = res.items.isEmpty
          ? true
          : res.items.every((e) => e.label.isEmpty && e.display.isEmpty);

      if (allBlank) {
        final schema = res.schema;
        final valId = (schema['value_key'] ?? {})['id'];
        final dispIds =
            (schema['display_cols'] as List?)
                ?.map((e) => (e as Map)['id'])
                .whereType<int>()
                .toList() ??
            <int>[];

        final List<String> idList = [];
        if (valId is int) idList.add(valId.toString());
        idList.addAll(dispIds.map((e) => e.toString()));
        final fields = idList.isNotEmpty
            ? 'ids:${idList.join(',')}'
            : 'default';

        final offset = (page - 1) * pageSize;
        final dataRes = await ApiClient.instance.getDataForm(
          GetDataFormRequest(
            tableId: res.tableId,
            maxRowNumber: offset,
            howManyRows: pageSize,
            fields: fields,
            ordertype: 'DESC',
            controlValues: controlValues,
            orderfields: 'c501',
          ),
        );

        final List<dynamic> rows = (dataRes['data'] as List?) ?? const [];
        final generated = <ConnectedOptionItem>[];
        for (final r in rows) {
          if (r is! Map) continue;
          final row = Map<String, dynamic>.from(r as Map);
          final valueStr =
              _extractByColId(row, valId is int ? valId : null)?.toString() ??
              '';
          final dispMap = <String, dynamic>{};
          for (final d in dispIds) {
            dispMap['c$d'] = _extractByColId(row, d);
          }
          final labelStr = dispMap.values
              .where((e) => e != null && e.toString().trim().isNotEmpty)
              .map((e) => e.toString())
              .join(' - ');
          generated.add(
            ConnectedOptionItem(
              value: valueStr.isNotEmpty ? valueStr : null,
              label: labelStr.isNotEmpty
                  ? labelStr
                  : (valueStr.isNotEmpty ? valueStr : ''),
              display: dispMap,
              fks: const {},
              controls: const {},
            ),
          );
        }

        if (page == 1) {
          items.assignAll(generated);
        } else {
          items.assignAll([...items, ...generated]);
        }
      } else {
        // اضمن دائماً توليد قائمة جديدة لتحفيز GetX على إعادة البناء
        if (page == 1) {
          items.assignAll(List.from(res.items));
        } else {
          items.assignAll([...items, ...res.items]);
        }
      }
      final pg = res.pagination;
      hasMore.value = pg['has_more'] == true;
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
    required int formId,
    required int controlId,
    Map<String, dynamic> controlValues = const {},
  }) async {
    q.value = query;
    page = 1;
    items.clear();
    await load(
      formId: formId,
      controlId: controlId,
      controlValues: controlValues,
    );
  }

  Future<void> nextPage({
    required int formId,
    required int controlId,
    Map<String, dynamic> controlValues = const {},
  }) async {
    if (!hasMore.value || isLoading.value) return;
    page += 1;
    await load(
      formId: formId,
      controlId: controlId,
      controlValues: controlValues,
    );
  }
}
