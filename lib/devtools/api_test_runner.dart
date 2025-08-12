import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../models/request_payloads.dart';
import 'json_saver.dart';

class ApiTestRunner {
  static Future<Map<String, dynamic>> testFormsList() async {
    final forms = await ApiClient.instance.fetchForms();
    await JsonSaver.saveJson('Get_IDs_Names_Of_Released_Entry.json', forms);
    return {'ok': true, 'count': forms.length};
  }

  static Future<Map<String, dynamic>> testFormStructure(int formId) async {
    final form = await ApiClient.instance.fetchFormStructure(formId);
    await JsonSaver.saveJson('Bring_TheControls_$formId.json', {
      'id': form.id,
      'name': form.name,
      'controls': form.controls
          .map(
            (e) => {
              'id': e.id,
              'type': e.type,
              'name': e.name,
              'required': e.requiredField,
              'table_id': e.tableId,
              'meta': e.meta,
            },
          )
          .toList(),
    });
    return {'ok': true, 'controls': form.controls.length};
  }

  static Future<Map<String, dynamic>> testConnectedOptions({
    required int formId,
    required int controlId,
  }) async {
    final res = await ApiClient.instance.getConnectedOptions(
      ConnectedOptionsRequest(
        formId: formId,
        controlId: controlId,
        pageSize: 500,
      ),
    );
    await JsonSaver.saveJson('GetConnectedOptions_${formId}_$controlId.json', {
      'schema': res.schema,
      'items': res.items
          .map(
            (e) => {
              'value': e.value,
              'label': e.label,
              'display': e.display,
              'fks': e.fks,
            },
          )
          .toList(),
      'pagination': res.pagination,
    });
    return {'ok': true, 'items': res.items.length, 'schema': res.schema};
  }
}
