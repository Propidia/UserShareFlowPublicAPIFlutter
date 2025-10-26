import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:useshareflowpublicapiflutter/help/funcs.dart';
import 'package:useshareflowpublicapiflutter/models/process_task.dart';
import 'package:useshareflowpublicapiflutter/services/task_status_service.dart';
import 'package:useshareflowpublicapiflutter/ui/widgets/dialog_first_match.dart';

import '../models/folder_parsing_models.dart';
import '../services/api_client.dart';

class FolderProcessingController extends GetxController {
  final _apiClient = ApiClient.instance;

  // State
  final isProcessing = false.obs;
  final processedCount = 0.obs;
  final totalCount = 0.obs;
  final successCount = 0.obs;
  final failureCount = 0.obs;

  // قائمة المهام (يبقى فيها فقط الـ Pending/Null)
  final RxList<ProcessingTask> tasks = <ProcessingTask>[].obs;

  // مؤشر لإدارة حالة الديالوج
  bool _dialogOpen = false; // يُستخدم لضبط حالة الديالوج أثناء الفتح/الإغلاق
  bool _isClosingDialogs = false;
  // SnackbarController? _persistentSnack;
  dynamic _formController;

  String? _failuresFilePath;
  String? _successFilePath;

  @override
  void onInit() {
    super.onInit();
    _initFailuresFile();
    _initSuccessesFile();
  }

  void setFormController(dynamic controller) {
    _formController = controller;
  }

  // --- Files init
  Future<void> _initFailuresFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${appDir.path}/data');
      if (!await dataDir.exists()) await dataDir.create(recursive: true);

      _failuresFilePath = '${dataDir.path}/failures.json';
      _successFilePath = '${dataDir.path}/successes.json';

      final failuresFile = File(_failuresFilePath!);
      if (!await failuresFile.exists()) {
        final emptyData = FailuresData(failures: []);
        await failuresFile.writeAsString(jsonEncode(emptyData.toJson()));
      }
    } catch (e) {
      print('Error initializing failures file: $e');
    }
  }

  Future<void> _initSuccessesFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${appDir.path}/data');
      if (!await dataDir.exists()) await dataDir.create(recursive: true);

      _successFilePath = '${dataDir.path}/successes.json';
      final successesFile = File(_successFilePath!);
      if (!await successesFile.exists()) {
        final emptyData = SuccessData(successes: []);
        await successesFile.writeAsString(jsonEncode(emptyData.toJson()));
      }
    } catch (e) {
      print('Error initializing successes file: $e');
    }
  }

  // --- Pick & Process
  Future<void> pickAndProcessFolder() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        _showSnackBar('لم يتم اختيار أي مجلد', false);
        return;
      }
      await processFolder(Directory(selectedDirectory));
    } catch (e) {
      _showSnackBar('خطأ في اختيار المجلد: $e', false);
    }
  }

  /// خطوات المعالجة:
  /// 1) جلب المجلدات الفرعية
  /// 2) تجهيز قائمة المهام
  /// 3) معالجة كل مجلد بالتسلسل
  /// 4) عرض ملخص نهائي
  Future<void> processFolder(Directory folder) async {
    try {
      isProcessing.value = true;
      processedCount.value = 0;
      successCount.value = 0;
      failureCount.value = 0;

      final subdirs = folder.listSync().whereType<Directory>().toList();
      if (subdirs.isEmpty) {
        _showSnackBar('لا توجد مجلدات فرعية للمعالجة', false);
        isProcessing.value = false;
        return;
      }

      totalCount.value = subdirs.length;
      _showSnackBar('بدء معالجة ${subdirs.length} مجلد...', true);

      tasks.clear();
      for (final d in subdirs) {
        final name = d.path.split(Platform.pathSeparator).last;
        tasks.add(ProcessingTask(name: name, path: d.path));
      }

      for (final subdir in subdirs) {
        await processSingleSubfolder(subdir);
        processedCount.value++;
        await Future.delayed(const Duration(seconds: 1));
      }

      _showSnackBar(
        'اكتملت المعالجة: ${successCount.value} نجح، ${failureCount.value} فشل',
        successCount.value > 0,
      ); 
    } catch (e) {
      _showSnackBar('خطأ في معالجة المجلدات: $e', false);
    } finally {
      _hidePersistentSnack();
  await _closePreviewDialogIfAny();

      isProcessing.value = false;
    }
  }

  /// معالجة مجلد واحد:
  /// 1) البحث وجلب بيانات المطابقة
  /// 2) عرض Dialog للمعاينة
  /// 3) تعبئة الحقول + إضافة الملفات
  /// 4) بناء وإرسال الـ payload
  /// 5) التحقق من حالة الإرسال (مباشر/انتظار)
  /// 6) حفظ النتيجة وإدارة قائمة المهام
  Future<void> processSingleSubfolder(Directory subfolder) async {
    final folderName = subfolder.path.split(Platform.pathSeparator).last;
    // Step 1: Parse folder name
    // final parsed = _parserService.parseFolderName(folderName); 
    // if (parsed == null) { 
    // Parsing failed - invalid pattern 
    //await _saveFailure(FailureRecord( originalName: folderName, parsedName: null, errorMessage: 'اسم المجلد لا يتطابق مع النمط المطلوب', timestamp: DateTime.now(), folderPath: subfolder.path, ));
    // _showSnackBar('⚠️ نمط غير صحيح: $folderName', false); 
    //failureCount.value++;
      // Wait 1 second before moving to next folder await Future.delayed(const Duration(seconds: 1));
      // return; 
      //}
    try {
      // (1) البحث عن أداة الربط والبيانات
      final connectedControl = Funcs.form_model?.controls.firstWhereOrNull((c) => c.type == 16);
        if (connectedControl == null) {
        throw Exception('لا توجد أداة ربط (نوع 16) في النموذج');
        }

        final response = await _apiClient.getFirstMatch(
          formId: Funcs.form_id!,
        controlId: connectedControl.id,
          value: folderName,
        );

      final valueMap = _asValueMap(response['value']);
      if (valueMap == null || valueMap.isEmpty) {
        print('لا توجد بيانات مطابقة للمجلد: $folderName');
          return;
        }

      // (2) عرض/تحديث المعاينة
      await _openPreviewDialog(valueMap);

      try {
        // (3) تعبئة الحقول والملفات
        _formController?.setConnectedValue(connectedControl.id, valueMap);
        await _fillFormFromData(valueMap);
        await _addFilesToFileControl(subfolder);
        _formController?.forceUpdate();

        // (4) بناء وإرسال Payload
        final payload = await _formController?.buildSubmitPayload();
        if (payload == null) throw Exception('فشل بناء payload');

        final uploadFolderName = payload['foldername'] ?? 'unknown';
        final submitResponse = await _apiClient.submitForm(payload);
        final uploadedCount = _countUploadedFiles(payload['controls']);

        // (5) التحقق من الحالة
        final initial = await TaskStatusService.instance.checkSubmissionStatus(submitResponse);
        int? finalApplyId;

        if (initial.status == TaskStatus.success) {
          finalApplyId = initial.applyId;
        } else if (initial.status == TaskStatus.pending) {
          _showPersistentInfo('جاري التحقق من حالة الإرسال...');
          try {
            finalApplyId = await TaskStatusService.instance.pollTaskStatus(
              initial.taskId!,
              accessToken: initial.accessToken,
              pollInterval: const Duration(seconds: 1),
              overallTimeout: const Duration(seconds: 7),
              onStatusUpdate: null, // لا نحدّث الرسائل لتجنب الوميض
            );
          } catch (e) {
            print('لم تصل نتيجة خلال المهلة: $e');
          } finally {
            _hidePersistentSnack();
          }
        } else {
          throw Exception(initial.errorMessage ?? 'فشل الإرسال');
        }

        // (6) الحُكم النهائي وإدارة القائمة (وفق Result)
          TaskResult finalResult;

          if (finalApplyId != null && finalApplyId > 0) {
            // نجاح فوري
            finalResult = TaskResult.success(finalApplyId);
          } else {
            // لسا Pending: اسمح بنافذة 5 ثواني نستعلم كل ثانية
            finalResult = await _pollForGracePeriod(
              taskId: initial.taskId!,
              accessToken: initial.accessToken,
              grace: const Duration(seconds: 5),
            );
          }

          if (finalResult.status == TaskStatus.success && finalResult.applyId != null) {
            successCount.value++;
            tasks.removeWhere((t) => t.path == subfolder.path);
            _showSnackBar('تم الإرسال: $folderName', true);
            await _saveSuccess(Record(
              originalName: folderName,
              parsedName: folderName,
              errorMessage: 'تم الرفع والإرسال بنجاح (folder: $uploadFolderName, files: $uploadedCount)',
              timestamp: DateTime.now(),
              folderPath: subfolder.path,
            ));
          } else if (finalResult.status == TaskStatus.error) {
            failureCount.value++;
            tasks.removeWhere((t) => t.path == subfolder.path);
            _showSnackBar('فشل الإرسال: $folderName', false);
            await _saveFailure(Record(
              originalName: folderName,
              parsedName: folderName,
              errorMessage: finalResult.errorMessage ?? 'فشل غير محدد',
              timestamp: DateTime.now(),
              folderPath: subfolder.path,
            ));
          } else {
            // PENDING بعد نافذة السماح => نخليه في القائمة ولا نحذف
            _showSnackBar('بانتظار النتيجة: $folderName', false);
          }

      } catch (apiError) {
        failureCount.value++;
        tasks.removeWhere((t) => t.path == subfolder.path);
        await _saveFailure(Record(
          originalName: folderName,
          parsedName: folderName,
          errorMessage: apiError.toString(),
          timestamp: DateTime.now(),
          folderPath: subfolder.path,
        ));
        _showSnackBar('فشل الإرسال: $folderName', false);
        } finally {
          _hidePersistentSnack();
         await _closePreviewDialogIfAny();

        }
    } catch (searchError) {
        failureCount.value++;
      tasks.removeWhere((t) => t.path == subfolder.path);
      await _saveFailure(Record(
        originalName: folderName,
        parsedName: folderName,
        errorMessage: searchError.toString(),
        timestamp: DateTime.now(),
        folderPath: subfolder.path,
      ));
      _showSnackBar('فشل البحث: $folderName', false);
    } finally {
      await Future.delayed(const Duration(seconds: 1));
      await _closePreviewDialogIfAny();

    }
  }

  // --- Save to JSON
  Future<void> _saveFailure(Record record) async {
    try {
      if (_failuresFilePath == null) return;
      final file = File(_failuresFilePath!);

      FailuresData data;
      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          final json = jsonDecode(content);
          data = FailuresData.fromJson(json as Map<String, dynamic>);
        } catch (_) {
          data = FailuresData(failures: []);
        }
      } else {
        data = FailuresData(failures: []);
      }

      data.failures.add(record);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data.toJson()));
    } catch (e) {
      print('Error saving failure: $e');
    }
  }

  Future<void> _saveSuccess(Record record) async {
    try {
      if (_successFilePath == null) return;
      final file = File(_successFilePath!);

      SuccessData data;
      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          final json = jsonDecode(content);
          data = SuccessData.fromJson(json as Map<String, dynamic>);
        } catch (_) {
          data = SuccessData(successes: []);
        }
      } else {
        data = SuccessData(successes: []);
      }

      data.successes.add(record);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data.toJson()));
    } catch (e) {
      print('Error saving success: $e');
    }
  }

  // --- Snackbar (مختصر ومهم فقط)
  void _showSnackBar(String message, bool isSuccess) {
  Get.rawSnackbar(
    title: isSuccess ? 'نجاح' : 'تنبيه',
    message: message,
    backgroundColor: (isSuccess ? Colors.green : Colors.orange).withOpacity(0.95),
    snackPosition: SnackPosition.TOP,
    margin: const EdgeInsets.all(8),
    borderRadius: 10,
    duration: const Duration(seconds: 2),
    isDismissible: true,
  );
}

  
 // إظهار رسالة انتظار ثابتة (تظل ظاهرة)
void _showPersistentInfo(String message) {
  if (Get.isSnackbarOpen == true) return; // فيه سناك شغّال
  Get.showSnackbar(GetSnackBar(
    title: 'الرجاء الانتظار',
    message: message,
    backgroundColor: Colors.blueGrey.withOpacity(0.95),
    snackPosition: SnackPosition.TOP,
    margin: const EdgeInsets.all(8),
    borderRadius: 10,
    duration: const Duration(days: 1), // تبقى مفتوحة
    isDismissible: false,
  ));
}

// إخفاؤها بأمان
void _hidePersistentSnack() {
  if (Get.isSnackbarOpen == true) {
    try {
      Get.closeCurrentSnackbar();
    } catch (_) {
      // تجاهل أي خطأ داخلي من GetX
    }
  }
}


  Future<void> clearFailures() async {
    try {
      if (_failuresFilePath == null) return;
      final file = File(_failuresFilePath!);
      final emptyData = FailuresData(failures: []);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(emptyData.toJson()));
      _showSnackBar('تم مسح سجل الفشل', true);
    } catch (e) {
      _showSnackBar('خطأ في مسح سجل الفشل: $e', false);
    }
  }

  // --- Data shaping
  Future<void> _fillFormFromData(Map<String, dynamic> data) async {
    try {
      if (_formController == null) return;

      for (final control in Funcs.form_model!.controls) {
        if (control.type == 16) continue; // connected
        if (control.type == 7) continue;  // files

        dynamic value;
        if (data.containsKey(control.name)) value = data[control.name];
        if (value == null && data.containsKey(control.id.toString())) {
          value = data[control.id.toString()];
        }
        if (value != null) {
          _formController.setValueWithoutValidation(control.id, value);
        }
      }
    } catch (e) {
      print('خطأ في تعبئة الفورم: $e');
    }
  }

  Future<void> _addFilesToFileControl(Directory subfolder) async {
    try {
      if (_formController == null) return;

      final fileControl = Funcs.form_model!.controls.firstWhereOrNull((c) => c.type == 7);
      if (fileControl == null) return;

      final files = subfolder.listSync().whereType<File>().toList();
      if (files.isEmpty) return;

      final filesList = <Map<String, dynamic>>[];
      for (final file in files) {
        final fullPath = file.path;
    final fileName = fullPath.split(Platform.pathSeparator).last;
        filesList.add({
      'path': fullPath,
      'name': fileName,
          'base64': fullPath,
        });
      }

      _formController.setValueWithoutValidation(fileControl.id, {'files': filesList});
    } catch (e) {
      print('خطأ في إضافة الملفات: $e');
    }
  }

  // --- Casting & counters
  Map<String, dynamic>? _asValueMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  int _countUploadedFiles(dynamic controls) {
    if (controls is List) {
      int cnt = 0;
      for (final item in controls) {
        if (item is Map &&
            item['value'] is Map &&
            (item['value'] as Map)['files'] != null) {
          cnt++;
        }
      }
      return cnt;
    }
    if (controls is Map) {
      int cnt = 0;
      for (final entry in controls.values) {
        if (entry is Map &&
            entry['value'] is Map &&
            (entry['value'] as Map)['files'] != null) {
          cnt++;
        }
      }
      return cnt;
    }
    return 0;
  }
// افتح الديالوج (مرة واحدة) — بدون await
Future<void> _openPreviewDialog(Map<String, dynamic> valueMap) async {
  // اغلق أي حوار سابق من نفس النوع فقط
  await _closePreviewDialogIfAny();

  // مهلة خفيفة لتثبيت الـ overlay
  await Future.delayed(const Duration(milliseconds: 30));

  _dialogOpen = true;
  try {
    // لا تعمل await؛ خليه مفتوح أثناء المعالجة
    showFirstMatchDialog(valueMap); // لازم الديالوج نفسه يكون باسمه 'first_match_dialog'
  } catch (_) {
    _dialogOpen = false;
    rethrow;
  }
}

// يقفل فقط حوارات first_match_dialog إن كانت مفتوحة، ولا يلمس الصفحة
Future<void> _closePreviewDialogIfAny() async {
  if (!_dialogOpen) return;

  // Pop حتى يختفي آخر Route اسمه first_match_dialog
  Get.until((route) => route.settings.name != 'first_match_dialog');
  _dialogOpen = false;

  // انتظار فريم صغير بعد الإغلاق (تحسين استقرار)
  await Future.delayed(const Duration(milliseconds: 20));
}


/// نافذة سماح 5 ثواني: كل ثانية نستعلم حالة المهمة مرة واحدة.
/// النجاح → success، أي نص خطأ → error، الباقي → pending.
Future<TaskResult> _pollForGracePeriod({
  required String taskId,
  String? accessToken,
  Duration grace = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(grace);

  while (DateTime.now().isBefore(deadline)) {
    try {
      // هنا نستخدم خدمة الاستطلاع بوحدة زمنية قصيرة (1 ثانية)
      final applyId = await TaskStatusService.instance.pollTaskStatus(
        taskId,
        accessToken: accessToken,
        pollInterval: const Duration(seconds: 1),
        // نخلي التايم آوت صغير (1 ثانية) لكل دورة، لأننا إحنا عاملين الغلاف الزمني 5 ثواني
        overallTimeout: const Duration(seconds: 1),
        onStatusUpdate: null,
      );

      if (applyId != null && applyId > 0) {
        return TaskResult.success(applyId);
      }
      // null ⇒ لسه Pending لهذه الدورة؛ نكمّل الحلقة
    } catch (e) {
      // أي استثناء من الخدمة نعتبره فشل نهائي ونرجع Error
      return TaskResult.error(e.toString());
    }
    // نكمل مباشرة للدورة التالية (الـ pollTaskStatus نفسه فيه انتظار ثانية)
  }

  // انتهت نافذة السماح وما وصل قرار نهائي ⇒ Pending
  return TaskResult.pending(taskId, accessToken);
}




}
