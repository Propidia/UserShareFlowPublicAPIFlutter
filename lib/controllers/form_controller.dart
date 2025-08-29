import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/form_models.dart';
import '../services/api_client.dart';

class FormController extends GetxController {
  // القائمة المعروضة بعد الفلترة
  final forms = <Map<String, dynamic>>[].obs;
  // النسخة الأصلية لكامل النماذج
  final allForms = <Map<String, dynamic>>[].obs;
  // نص البحث الحالي
  final search = ''.obs;
  final isLoadingForms = false.obs;
  final isLoadingStructure = false.obs;

  final currentForm = Rxn<FormStructureModel>();

  // قيم الأدوات {controlId -> value}
  final values = RxMap<int, dynamic>({});
  // تبعيات بسيطة: {parentControlId -> [childControlIds]}
  final Map<int, List<int>> dependencies = {};
  // تبعيات أدوات الربط: {connectedControlId -> [requiredControlIds]}
  final Map<int, List<int>> connectedDependencies = {};
  // تتبع عدد صفوف الجداول {tableControlId -> rowCount}
  final Map<int, int> tableRowCounts = {};

  Future<void> loadForms() async {
    try {
      isLoadingForms.value = true;
      final data = await ApiClient.instance.fetchForms();
      allForms.assignAll(data);
      _applyFilter();
    } catch (e) {
      Get.snackbar('خطأ', 'فشل جلب النماذج');
    } finally {
      isLoadingForms.value = false;
    }
  }

  Future<void> loadFormStructure(int formId) async {
    try {
      isLoadingStructure.value = true;
      final form = await ApiClient.instance.fetchFormStructure(formId);
      currentForm.value = form;
      values.clear();
      dependencies.clear();
      connectedDependencies.clear();
      _indexDependencies(form.controls);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل جلب هيكل النموذج');
    } finally {
      isLoadingStructure.value = false;
    }
  }

  void filterForms(String term) {
    search.value = term.trim();
    _applyFilter();
  }

  void _applyFilter() {
    final q = search.value.toLowerCase();
    if (q.isEmpty) {
      forms.assignAll(allForms);
      return;
    }
    int? idQ;
    try {
      idQ = int.parse(q);
    } catch (_) {
      idQ = null;
    }
    final filtered = allForms.where((m) {
      final name = (m['name']?.toString() ?? '').toLowerCase();
      final idStr = (m['id']?.toString() ?? '').toLowerCase();
      final nameMatch = name.contains(q);
      final idMatch = idStr.contains(q) || (idQ != null && m['id'] == idQ);
      return nameMatch || idMatch;
    }).toList();
    forms.assignAll(filtered);
  }

  void _indexDependencies(List<ControlModel> controls, {int? parentId}) {
    for (final c in controls) {
      // بناء تبعية بسيطة: كل أبناء الجدول يعتمدون على الجدول؛ وأداة الربط قد تعتمد على غيرها مستقبلاً عبر meta
      if (parentId != null) {
        dependencies.putIfAbsent(parentId, () => <int>[]).add(c.id);
      }
      if (c.children.isNotEmpty) {
        _indexDependencies(c.children, parentId: c.id);
      }
    }
  }

  bool canChangeValue(int controlId) {
    // إن كانت هناك تبعيات والقيم الحالية لتلك الأدوات غير فارغة، نمنع التغيير

    final dependents = dependencies[controlId] ?? const <int>[];
    for (final depId in dependents) {
      final v = values[depId];
      if (v != null && v.toString().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  void clearDependents(int controlId) {
    final dependents = dependencies[controlId] ?? const <int>[];
    final visited = <int>{};
    for (final depId in dependents) {
      _clearValueAndDescendants(depId, visited: visited);
    }
    update();
  }

  void registerConnectedDependencies(
    int connectedControlId,
    List<int> requiredControlIds,
  ) {
    // نسجّل الاعتمادية مرة واحدة، ونزيل التكرار لضمان نظافة البيانات
    final unique = <int>{...requiredControlIds}.toList();
    connectedDependencies[connectedControlId] = unique;
    // نحدّث خريطة dependencies بحيث يكون كل requiredControlId أباً لأداة الربط
    for (final parentId in unique) {
      dependencies.putIfAbsent(parentId, () => <int>[]);
      if (!dependencies[parentId]!.contains(connectedControlId)) {
        dependencies[parentId]!.add(connectedControlId);
      }
    }
  }

  /// تحديث عدد صفوف الجدول
  void updateTableRowCount(int tableControlId, int rowCount) {
    tableRowCounts[tableControlId] = rowCount;
    print('📊 تحديث عدد صفوف الجدول $tableControlId: $rowCount');
  }

  bool isLockedByConnected(int controlId) {
    // إذا كانت هناك أداة ربط لديها قيمة حالية وتعتمد على هذا الحقل، اعتبره مقفولاً
    // نصل إلى values.value لضمان أن GetX يراقب التغييرات

    for (final entry in connectedDependencies.entries) {
      final connectedId = entry.key;
      final requiredIds = entry.value;
      if (requiredIds.contains(controlId)) {
        final v = values[connectedId];
        if (v != null && v.toString().trim().isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  List<int> getLockingConnectedControls(int controlId) {
    final lockers = <int>[];

    for (final entry in connectedDependencies.entries) {
      final connectedId = entry.key;
      final requiredIds = entry.value;
      if (requiredIds.contains(controlId)) {
        final v = values[connectedId];
        if (v != null && v.toString().trim().isNotEmpty) {
          lockers.add(connectedId);
        }
      }
    }
    return lockers;
  }

  void setValue(int controlId, dynamic value) {
    // السماح بمسح القيمة دائماً، مع مسح جميع التابعين بشكل تلقائي
    final bool isClearing = value == null || value.toString().trim().isEmpty;
    if (isClearing) {
      _clearValueAndDescendants(controlId, visited: <int>{});
      update();
      return;
    }
    // منع تعديل الحقول المقفولة بسبب اختيار قيمة في أداة ربط تعتمد عليها
    if (isLockedByConnected(controlId)) {
      final lockers = getLockingConnectedControls(controlId);
      final lockersText = lockers.isEmpty ? '' : ' (${lockers.join(', ')})';
      Get.snackbar(
        'تنبيه',
        'لا يمكن تعديل هذا الحقل لأنه مرتبط بأداة ربط تحتوي قيمة$lockersText. قم بمسح قيمة أداة الربط أولاً.',
      );
      return;
    }
    // منع تغيير القيمة إن كانت هناك أدوات تابعة مملوءة (باستثناء حالة المسح التي تمت معالجتها أعلاه)
    if (!canChangeValue(controlId)) {
      Get.snackbar('تنبيه', 'لا يمكن تغيير القيمة قبل مسح قيم الأدوات التابعة');
      return;
    }
    values[controlId] = value;
    update();
  }

  /// تحديث قيمة أداة ربط بناءً على البيانات المختارة والـ fields_default
  void setConnectedValue(int controlId, Map<String, dynamic> selectedData) {
    print('\n🔄 setConnectedValue تم استدعاؤها:');
    print('   controlId: $controlId');
    print('   selectedData: $selectedData');

    // البحث عن الأداة في هيكل النموذج
    final control = _findControlById(controlId);
    if (control == null) {
      print('   ❌ لم يتم العثور على الأداة، حفظ البيانات كما هي');
      setValue(controlId, selectedData);
      return;
    }

    print('   ✅ تم العثور على الأداة: ${control.name}');

    // التحقق من وجود fields_default في meta.connected
    final meta = control.meta;
    if (meta == null ||
        meta['connected'] == null ||
        meta['connected']['fields_default'] == null) {
      print('   ❌ لا توجد fields_default، حفظ البيانات كما هي');
      setValue(controlId, selectedData);
      return;
    }

    final fieldsDefault = meta['connected']['fields_default'];
    final byName = fieldsDefault['by_name'] as List?;

    print('   📋 fields_default.by_name: $byName');

    if (byName == null || byName.isEmpty) {
      print('   ❌ by_name فارغة، حفظ البيانات كما هي');
      setValue(controlId, selectedData);
      return;
    }

    // إنشاء قيمة منظمة بناءً على fields_default
    final organizedValue = <String, dynamic>{};
    final byId = fieldsDefault['by_id'] as List?;

    print('   🔄 تنظيم البيانات بحسب المطابقة:');
    print('     by_name: $byName');
    print('     by_id: $byId');
    print('     selectedData: $selectedData');

    // ملء القيم بحسب مطابقة الـ ID أو اسم العمود
    for (int i = 0; i < byName.length; i++) {
      final fieldName = byName[i].toString();

      // البحث عن القيمة المطابقة
      dynamic matchedValue;

      // أولاً: محاولة البحث بـ ID
      if (byId != null && i < byId.length) {
        final fieldId = byId[i].toString();
        matchedValue = selectedData[fieldId];
        print('     محاولة البحث بـ ID "$fieldId": $matchedValue');
      }

      // ثانياً: إذا لم نجد، نبحث باسم العمود مباشرة
      if (matchedValue == null) {
        matchedValue = selectedData[fieldName];
        print('     محاولة البحث باسم العمود "$fieldName": $matchedValue');
      }

      organizedValue[fieldName] = matchedValue;
      print('     [$i] $fieldName (ID: ${byId?[i]}) = $matchedValue');
    }

    print('   💾 القيمة النهائية المُنظمة: $organizedValue');
    setValue(controlId, organizedValue);

    print('   ✅ تم حفظ القيمة بنجاح');
    print('   📤 القيمة في values[$controlId]: ${values[controlId]}');
  }

  /// البحث عن أداة بواسطة ID في هيكل النموذج
  ControlModel? _findControlById(int controlId) {
    final form = currentForm.value;
    if (form == null) return null;

    ControlModel? findInList(List<ControlModel> controls) {
      for (final control in controls) {
        if (control.id == controlId) return control;

        // البحث في الأطفال (للجداول)
        final found = findInList(control.children);
        if (found != null) return found;
      }
      return null;
    }

    return findInList(form.controls);
  }

  void _clearValueAndDescendants(int controlId, {required Set<int> visited}) {
    if (visited.contains(controlId)) return;
    visited.add(controlId);

    // امسح قيمة هذا الحقل
    values.remove(controlId);

    // امسح التابعين من شجرة الواجهة (dependencies)
    final dependents = dependencies[controlId] ?? const <int>[];
    for (final depId in dependents) {
      _clearValueAndDescendants(depId, visited: visited);
    }

    // امسح أدوات الربط التي تعتمد على هذا الحقل (connectedDependencies معكوساً)
    for (final entry in connectedDependencies.entries) {
      final int connectedId = entry.key;
      final List<int> requiredIds = entry.value;
      if (requiredIds.contains(controlId)) {
        _clearValueAndDescendants(connectedId, visited: visited);
      }
    }
  }

  void clearValue(int controlId) {
    _clearValueAndDescendants(controlId, visited: <int>{});
    update();
  }

  Map<String, dynamic> buildControlValuesPayload() {
    // تحويل القيم لإرسالها إلى GetConnectedOptions/GetDataForm
    final Map<String, dynamic> out = {};
    values.forEach((key, val) {
      out[key.toString()] = val;
    });
    return out;
  }

  /// بناء formData من البيانات الحالية للنموذج
  Map<String, dynamic>? buildFormData() {
    final form = currentForm.value;
    if (form == null) return null;

    // تحويل ControlModel إلى Map للاستخدام في replaceFilters
    List<Map<String, dynamic>> convertControls(List<ControlModel> controls) {
      return controls.map((control) {
        final controlMap = <String, dynamic>{
          'id': control.id,
          'name': control.name,
          'type': control.type,
          'required': control.requiredField,
          'value': values[control.id],
        };

        if (control.meta != null) {
          controlMap['meta'] = control.meta;
        }

        if (control.children.isNotEmpty) {
          controlMap['children'] = convertControls(control.children);
        }

        return controlMap;
      }).toList();
    }

    return {
      'id': form.id,
      'name': form.name,
      'controls': convertControls(form.controls),
    };
  }

  /// بناء payload للإرسال إلى POST_FORM_DATA
  Map<String, dynamic> buildSubmitPayload() {
    final form = currentForm.value;
    if (form == null) {
      throw Exception('لا يوجد نموذج محمل');
    }

    final controls = _buildControlsForSubmit(form.controls);

    final payload = {'id': form.id, 'controls': controls};

    return payload;
  }

  /// بناء بيانات الأدوات للإرسال (مع معالجة الجداول)
  List<Map<String, dynamic>> _buildControlsForSubmit(
    List<ControlModel> controls,
  ) {
    final result = <Map<String, dynamic>>[];

    for (final control in controls) {
      if (control.type == 8) {
        // معالجة الجداول
        result.add(_buildTableControlForSubmit(control));
      } else {
        // معالجة الأدوات العادية
        result.add(_buildRegularControlForSubmit(control));
      }
    }

    return result;
  }

  /// بناء أداة عادية للإرسال
  Map<String, dynamic> _buildRegularControlForSubmit(ControlModel control) {
    final controlValue = values[control.id];

    return {
      'id': control.id,
      'value': _processControlValue(controlValue, control),
    };
  }

  /// بناء أداة جدول للإرسال
  Map<String, dynamic> _buildTableControlForSubmit(ControlModel tableControl) {
    final rows = <Map<String, dynamic>>[];
    final rowCount = tableRowCounts[tableControl.id] ?? 1;

    print('📊 بناء جدول ${tableControl.id} بعدد صفوف: $rowCount');

    // إنشاء صف لكل عدد صفوف مسجل
    for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      final rowControls = <Map<String, dynamic>>[];

      for (final childControl in tableControl.children) {
        // للتبسيط، نستخدم نفس القيم لكل الصفوف
        // في التطبيق الكامل، ستحتاج لتتبع قيم كل صف منفصلة
        rowControls.add({
          'id': childControl.id,
          'value': _processControlValue(values[childControl.id], childControl),
        });
      }

      rows.add({'controls': rowControls});
      print('   صف ${rowIndex + 1}: ${rowControls.length} أدوات');
    }

    return {'id': tableControl.id, 'rows': rows};
  }

  /// معالجة قيمة الأداة للإرسال
  dynamic _processControlValue(dynamic value, ControlModel control) {
    if (value == null) return null;

    // معالجة أدوات الملفات
    if (control.type == 7) {
      if (value is Map<String, dynamic>) {
        return {
          'files': value['files'] ?? [],
          'folders': value['folders'] ?? [],
        };
      }
      return {'files': [], 'folders': []};
    }

    // معالجة أدوات الربط
    if (control.type == 16) {
      if (value is Map<String, dynamic>) {
        return Map<String, dynamic>.from(value);
      }
      return {};
    }

    // باقي الأدوات
    return value;
  }

  /// إرسال النموذج
  final isSubmitting = false.obs;

  Future<void> submitForm() async {
    try {
      isSubmitting.value = true;

      // بناء payload
      final payload = buildSubmitPayload();

      print('\n🚀 بدء إرسال النموذج:');
      print('📋 Payload: ${jsonEncode(payload)}');

      // إرسال للـ API
      final response = await ApiClient.instance.submitForm(payload);

      print('✅ تم الإرسال بنجاح: $response');
      Get.snackbar(
        'نجح الإرسال',
        'تم إرسال النموذج بنجاح',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    } catch (e) {
      print('❌ خطأ في الإرسال: $e');
      Get.snackbar(
        'خطأ في الإرسال',
        e.toString(),
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isSubmitting.value = false;
    }
  }
}
