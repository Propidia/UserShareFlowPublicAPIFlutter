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

  void registerConnectedDependencies(int connectedControlId, List<int> requiredControlIds) {
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

  bool isLockedByConnected(int controlId) {
    // إذا كانت هناك أداة ربط لديها قيمة حالية وتعتمد على هذا الحقل، اعتبره مقفولاً
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
      Get.snackbar('تنبيه',
          'لا يمكن تعديل هذا الحقل لأنه مرتبط بأداة ربط تحتوي قيمة$lockersText. قم بمسح قيمة أداة الربط أولاً.');
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
}
