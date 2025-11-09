// controllers/folder_processing_controller.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:useshareflowpublicapiflutter/core/folder_data.dart';
import 'package:useshareflowpublicapiflutter/help/funcs.dart';
import 'package:useshareflowpublicapiflutter/help/log.dart';
import 'package:useshareflowpublicapiflutter/help/poll_config.dart';
import 'package:useshareflowpublicapiflutter/models/folder_process.dart';
import 'package:useshareflowpublicapiflutter/models/process_task.dart';
import 'package:useshareflowpublicapiflutter/core/record_store.dart';
import 'package:useshareflowpublicapiflutter/core/submission_service.dart';
import 'package:useshareflowpublicapiflutter/services/folder_parser_service.dart';
import 'package:useshareflowpublicapiflutter/ui/widgets/dialog_first_match.dart';
import '../models/folder_parsing_models.dart';
import '../services/api_client.dart';



class FolderProcessingController extends GetxController {
  final _apiClient = ApiClient.instance;
  final _parserService = FolderParserService();
  // State
  final isProcessing = false.obs;
  final processedCount = 0.obs;
  final totalCount = 0.obs;
  final successCount = 0.obs;
  final failureCount = 0.obs;
  final department = 'default'.obs;
  // قائمة المهام (يمكن استخدامها للعرض اللحظي إن رغبت)
  final RxList<ProcessingTask> tasks = <ProcessingTask>[].obs;
  final TextEditingController  textEditingController = TextEditingController();
  // مؤشر لإدارة حالة الديالوج
  bool _dialogOpen = false;
  dynamic _formController;
  int startIndex = 0; // مؤشر بداية المعالجة
  String? _failuresFilePath;
  String? _successFilePath;
  String? _foldersFilePath;
  RecordStore? _recordStore;
  final queue = <FolderData>[];
  final usedPaths = <String>{};
  @override
  void onInit() {
    super.onInit();
  Future.delayed(const Duration(seconds: 2), () {
    _initFailuresFile();
    _initSuccessesFile();
    _initFoldersFile();
  });
  }

  void setFormController(dynamic controller) {
    _formController = controller;
  }

  // --- Files init
  Future<void> _initSuccessesFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${appDir.path}/ShareflowAPI');
      if (!await dataDir.exists()) await dataDir.create(recursive: true);

      _successFilePath = '${dataDir.path}/${Funcs.form_id}_successes.json';
      final successesFile = File(_successFilePath!);
      if (!await successesFile.exists()) {
        final emptyData = {'successes': []};
        await successesFile.writeAsString(jsonEncode(emptyData));
      }
      if (_failuresFilePath != null && _successFilePath != null) {
        _recordStore = RecordStore(
          failuresFilePath: _failuresFilePath!,
          successesFilePath: _successFilePath!,
        );
      }
    } catch (e) {
      print('Error initializing successes file: $e');
    }
  }
  Future<void> _initFoldersFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${appDir.path}/ShareflowAPI');
      if (!await dataDir.exists()) await dataDir.create(recursive: true);

      _foldersFilePath = '${dataDir.path}/${Funcs.form_id}folders.json';
      final foldersFile = File(_foldersFilePath!);
      if (!await foldersFile.exists()) {
        final emptyData = FoldersData(folders: []);
        await foldersFile.writeAsString(jsonEncode(emptyData.toJson()));
      }
    } catch (e) {
      print('Error initializing folders file: $e');
    }
  }
  Future<void> _initFailuresFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${appDir.path}/ShareflowAPI');
      if (!await dataDir.exists()) await dataDir.create(recursive: true);

      _failuresFilePath = '${dataDir.path}/${Funcs.form_id}failures.json';

      final failuresFile = File(_failuresFilePath!);
      if (!await failuresFile.exists()) {
        final emptyData = {'failures': []};
        await failuresFile.writeAsString(jsonEncode(emptyData));
      }
    } catch (e) {
      print('Error initializing failures file: $e');
    }
  }
  
  // --- Pick & Process
  Future<void> pickAndProcessFolder() async {
    try {
          // final result = await Get.defaultDialog(
          //   title: "الرجاء تحديد القسم",
          //   actions: [
          //     ElevatedButton(onPressed:(){
          //       department.value = textEditingController.text.trim();
          //       if(department.value =='default' || department.value ==''){
          //           _showSnackBar('الرجاء ادخال القسم', false);
          //         }else{   

          //           Get.back(result: true);
          //         }
          //       } , child: Text('موافق'))
          //   ],
          //   content:TextField(
          //     controller: textEditingController,
          //     keyboardType: TextInputType.text,
              
          //   ),
          // );
          // if(result == true){
             final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        _showSnackBar('لم يتم اختيار أي مجلد', false);
       await LogServices.write('[Folder Processing] لم يتم اختيار مجلد اب');
        return;
      }
      await LogServices.write('[Folder Processing] تم اختيار مجلد اب');
      await scanAndMergeFoldersToFile(Directory(selectedDirectory));
      await processFoldersFromFileSequential();
          // }
    } catch (e) {
       Funcs.errors.add('خطأ في اختيار المجلد: $e');
      _showSnackBar('خطأ في اختيار المجلد: $e', false);
       final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
      }
    }
  }


Future<void> scanAndMergeFoldersToFile(Directory parentFolder) async {
  await _initFoldersFile();

  // اقرأ البيانات الحالية (قد تكون فارغة)
  final current = await _readFoldersData();
  final currentByPath = {for (var f in current.folders) f.path: f};

  // اجمع المجلدات الموجودة حالياً
  final foundPaths = <String, String>{}; // path -> name
  await for (final entity in parentFolder.list(recursive: false, followLinks: false)) {
    if (entity is Directory) {
      final path = entity.path;
      final name = path.split(Platform.pathSeparator).last;
      foundPaths[path] = name;
    }
  }

  // 1) أضف/حدّث المكتشفين الجدد
  final merged = <FolderData>[];

  // أضف أو حدّث الموجودين في foundPaths
  for (final entry in foundPaths.entries) {
    final path = entry.key;
    final name = entry.value;
    final existing = currentByPath[path];
    if (existing != null) {
      // لو كان معلم محذوف سابقاً، أعد تفعيله (isDeleted=false) لأن المجلد عاد
      final updated = FolderData(
        name: existing.name,
        path: existing.path,
        Status: existing.Status == 'Success' ? existing.Status : existing.Status, // لا نغيّر النجاح
        StatusMessage: existing.StatusMessage,
        discoveredAt: existing.discoveredAt,
        processedAt: existing.processedAt,
        attempts: existing.attempts,
        taskId: existing.taskId,
        isDeleted: false, // عاد المجلد، أصبح غير محذوف
      );
      merged.add(updated);
    } else {
      // جديد - أضفه كـ Pending
      merged.add(FolderData(
        name: name,
        path: path,
        Status: 'Pending',
        StatusMessage: 'Discovered',
        discoveredAt: DateTime.now(),
        attempts: 0,
        isDeleted: false,
      ));
    }
  }

  // 2) لمعالجة السجلات القديمة التي لم تعد موجودة: عيّنها كـ Deleted (لا تمسح)
  for (final old in current.folders) {
    if (!foundPaths.containsKey(old.path)) {
      // لو كانت بالفعل success فلا نغيرها (نحتفظ بالتاريخ) — لكن نعلم أنها محذوفة
      final updated = FolderData(
        name: old.name,
        path: old.path,
        Status: old.Status, // نحتفظ بالحالة (Success أو Error)
        StatusMessage: old.StatusMessage + ' | Marked as deleted on scan',
        discoveredAt: old.discoveredAt,
        processedAt: old.processedAt,
        attempts: old.attempts,
        taskId: old.taskId,
        isDeleted: true,
      );
      merged.add(updated);
    }
  }

  // 3) احفظ النتيجة (لا تحذف أي عنصر)
  await _writeFoldersDataAtomic(FoldersData(folders: merged));
}
  // --- Read / Write flexible
  Future<FoldersData> _readFoldersData() async {
    final f = File(_foldersFilePath!);
    if (!await f.exists()) return FoldersData(folders: []);
    final content = await f.readAsString();
    if (content.trim().isEmpty) return FoldersData(folders: []);

    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('folders') && decoded['folders'] is List) {
          final list = decoded['folders'] as List<dynamic>;
          return FoldersData(folders: list.map((e) => FolderData.fromJson(e as Map<String, dynamic>)).toList());
        }
        // single object -> wrap
        return FoldersData(folders: [FolderData.fromJson(decoded)]);
      }
      if (decoded is List) {
        return FoldersData(folders: decoded.map((e) => FolderData.fromJson(e as Map<String, dynamic>)).toList());
      }
      return FoldersData(folders: []);
    } catch (e) {
       Funcs.errors.add('خطأ في قراءة الملف: $e');
      // حاول NDJSON قراءة سطر-سطر
      final lines = content.split(RegExp(r'\r?\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final parsed = <FolderData>[];
      for (final line in lines) {
        try {
          final obj = jsonDecode(line);
          if (obj is Map<String, dynamic>) parsed.add(FolderData.fromJson(obj));
        } catch (e) {
           Funcs.errors.add('خطأ في قراءة الملف: $e');
           final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
      }

        }
      }
       final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
      }
      return FoldersData(folders: parsed);
    }
  }

  Future<void> _writeFoldersDataAtomic(FoldersData data) async {
    final f = File(_foldersFilePath!);
    final tmp = File('${_foldersFilePath!}.tmp');
    // تنظيف الـ tokens من المجلدات التي حالتها Success قبل الكتابة
    final cleanedFolders = data.folders.map((folder) {
      if (folder.Status == 'Success') {
        return folder.copyWith(accessToken: null, refreshToken: null);
      }
      return folder;
    }).toList();
    final cleanedData = FoldersData(folders: cleanedFolders);
    await tmp.writeAsString( const JsonEncoder.withIndent('  ').convert(cleanedData.toJson()),);
    if (await tmp.exists()) {

      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
      await tmp.rename(f.path);
    }
  }

  // --- Update status with extras
  Future<void> _updateFolderStatus(
    String path,
    ProcessingStatus status,
    String message, {
    int? attempts,
    String? taskId,
    String? accessToken,
    String? refreshToken,
    DateTime? processedAt,
  }) async {
    final data = await _readFoldersData();
    final idx = data.folders.indexWhere((f) => f.path == path);
    if (idx == -1) return;
    final old = data.folders[idx];
    // إذا كانت الحالة Success، أزل الـ tokens من الملف
    final bool shouldRemoveTokens = status == ProcessingStatus.Success;
    final updated = FolderData(
      name: old.name,
      path: old.path,
      Status: status.toString().split('.').last,
      StatusMessage: message,
      discoveredAt: old.discoveredAt,
      processedAt: processedAt ?? old.processedAt,
      attempts: attempts ?? old.attempts,
      taskId: taskId ?? old.taskId,
      accessToken: shouldRemoveTokens ? null : (accessToken ?? old.accessToken),
      refreshToken: shouldRemoveTokens ? null : (refreshToken ?? old.refreshToken),
    );
    final newList = List<FolderData>.from(data.folders);
    newList[idx] = updated;
    await _writeFoldersDataAtomic(FoldersData(folders: newList));
  }

  // --- Main processing logic (two passes)
 /*
  Future<void> processFoldersFromFileSequential() async {
    isProcessing.value = true;
    processedCount.value = 0;
    successCount.value = 0;
    failureCount.value = 0;

    try {
      var data = await _readFoldersData();
      if (data.folders.isEmpty) {
        _showSnackBar('لا توجد مجلدات في ملف الفولدرات للمعالجة', false);
        return;
      }

      totalCount.value = data.folders.length;
      _showSnackBar('بدء المعالجة من ملف: ${data.folders.length} مجلد...', true);

      // المرور الأول: معالجة وتخزين taskId لو وُجد
      for (final f in data.folders) {
        final dir = Directory(f.path);
        if (!await dir.exists()) {
          await _updateFolderStatus(f.path, ProcessingStatus.Error, 'المجلد غير موجود في المسار',
              processedAt: DateTime.now(), attempts: f.attempts + 1);
          failureCount.value++;
          processedCount.value++;
          continue;
        }

        await _updateFolderStatus(f.path, ProcessingStatus.Processing, 'جاري المعالجة', attempts: f.attempts + 1);

        final result = await _processSingleSubfolderWrapped(dir);

        if (result.status == ProcessingStatus.Success) {
          await _updateFolderStatus(f.path, ProcessingStatus.Success, 'تم الإرسال', processedAt: DateTime.now());
          successCount.value++;
        } else if (result.status == ProcessingStatus.Processing || result.status == ProcessingStatus.Pending) {
          // in case some code returns Processing or Pending, handle as pending
          await _updateFolderStatus(
            f.path,
            ProcessingStatus.Processing,
            'قيد الانتظار (تم إرسال الطلب، بانتظار نتيجة)',
            attempts: f.attempts + 1,
            taskId: result.taskId,
            accessToken: result.accessToken,
          );
          // لا نزيد success/failure الآن
        } else if (result.status == ProcessingStatus.Empty) {
          await _updateFolderStatus(f.path, ProcessingStatus.Error, result.errorMessage ?? 'لا توجد بيانات مطابقة',
              processedAt: DateTime.now());
          failureCount.value++;
        } else {
          await _updateFolderStatus(f.path, ProcessingStatus.Error, result.errorMessage ?? 'خطأ غير معروف',
              processedAt: DateTime.now());
          failureCount.value++;
        }

        processedCount.value++;
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // المرور الثاني: إعادة فحص المعلقين الذين لديهم taskId
      data = await _readFoldersData();
      final pendingFolders = data.folders.where((fd) =>
          fd.Status == ProcessingStatus.Processing.toString().split('.').last &&
          (fd.taskId != null && fd.taskId!.isNotEmpty)).toList();

      if (pendingFolders.isNotEmpty) {
        _showSnackBar('إعادة فحص ${pendingFolders.length} مهمة معلقة...', true);

        if (pendingFolders.isNotEmpty) {
  _showSnackBar('هناك ${pendingFolders.length} مهمة معلقة لإعادة الفحص...', true);

  // إعدادات إعادة الفحص: تأخيرات تصاعدية وعدد محاولات
  final retryDelays = <Duration>[const Duration(seconds: 5), const Duration(seconds: 15), const Duration(seconds: 20)];
  final maxAttempts = retryDelays.length;

  for (final pf in pendingFolders) {
        // طباعة تشخيصية
        try {
          print('Retrying pending folder: ${pf.path}, taskId=${pf.taskId}, attempts=${pf.attempts}');
        } catch (_) {}

        bool resolved = false;
        String lastErrorMessage = '';
        int attempt = 0;

        // حاول عدة محاولات متزايدة
        for (; attempt < maxAttempts; attempt++) {
          // قبل كل محاولة: انتظر المدة المحددة (لا تنتظر قبل المحاولة الأولى)
          if (attempt > 0) await Future.delayed(retryDelays[attempt]);

          // كل محاولة تستخدم نافذة grace صغيرة نسبياً لكن مع perAttemptTimeout أكبر
          final grace = const Duration(seconds: 5); // نافذة داخلية لكل pollForGracePeriod
          final pollInterval = const Duration(seconds: 1);
          final perAttemptTimeout =  Duration(seconds: 35 + (attempt * 10)); // ازدياد المهلة مع المحاولات (35 ثانية كحد أدنى)

          try {
            // سجل بداية المحاولة
            print('Checking taskId=${pf.taskId} (attempt ${attempt + 1}/$maxAttempts)');

            final check = await SubmissionService.pollForGracePeriod(
              taskId: pf.taskId!,
              grace: grace,
              pollInterval: pollInterval,
              perAttemptTimeout: perAttemptTimeout,
            );

            // لو رجع نجاح خزن applyId وحدّث الحالة
            if (check.status == SubmissionStatus.success && check.applyId != null) {
              final applyId = check.applyId!;
              await _updateFolderStatus(pf.path, ProcessingStatus.Success, 'تمت المعالجة بعد إعادة الفحص', processedAt: DateTime.now());
              await _saveSuccess(Record(
                originalName: pf.name,
                parsedName: pf.name,
                errorMessage: 'تم الرفع والإرسال بنجاح (applyId: $applyId)',
                timestamp: DateTime.now(),
                folderPath: pf.path,
              ));
              successCount.value++;
              resolved = true;
              break;
            }

            // لو ظل pending نعطي فرصة أخرى (لا نسرع ونقول فشل)
            if (check.status == SubmissionStatus.pending) {
              // سجّل لوج وأكمل المحاولات
              print('Still pending for ${pf.path} (attempt ${attempt + 1})');
              lastErrorMessage = 'ما زال قيد الانتظار (attempt ${attempt + 1})';
              // تحديث attempts في الملف (اختياري)
              await _updateFolderStatus(pf.path, ProcessingStatus.Processing, 'قيد الانتظار (attempt ${attempt + 1})', attempts: (pf.attempts ?? 0) + 1, taskId: pf.taskId);
              continue;
            }

            // لو رجع خطأ من الخادم أثناء poll
            if (check.status == SubmissionStatus.error) {
              lastErrorMessage = check.errorMessage ?? 'خطأ غير معروف أثناء الفحص';
              print('Error checking task for ${pf.path}: $lastErrorMessage');
              // يمكن محاولة مرة أخرى بحسب الخطة
              continue;
            }
          } catch (e) {
            lastErrorMessage = e.toString();
            print('Exception when polling for ${pf.path}: $e');
            // استمر للمحاولة التالية
            continue;
          }
        } // end retry loop

        if (!resolved) {
          // بعد نفاد المحاولات: ختم المهمة كـ final error أو pendingFinal (تحدده انت)
          final msg = 'لم تصل نتيجة بعد ${maxAttempts} محاولات؛ يتم ختم المعالجة بتاريخ الآن';
          await _updateFolderStatus(pf.path, ProcessingStatus.Error, msg, processedAt: DateTime.now());
          failureCount.value++;
          // سجل فشل للاطلاع لاحقًا
          await _saveFailure(Record(
            originalName: pf.name,
            parsedName: pf.name,
            errorMessage: msg + (lastErrorMessage.isNotEmpty ? ' — last: $lastErrorMessage' : ''),
            timestamp: DateTime.now(),
            folderPath: pf.path,
          ));
        }

        // فاصل بسيط بين المعالجات لتخفيف الضغط
        await Future.delayed(const Duration(seconds: 2));
      } // end for pendingFolders
    }

      }

      _showSnackBar('اكتملت المعالجة: ${successCount.value} نجح، ${failureCount.value} فشل', successCount.value > 0);
    } catch (e, st) {
      _showSnackBar('خطأ في المعالجة: $e', false);
      print(st);
    } finally {
      isProcessing.value = false;
    }
  }
*/

void addToQueue(FolderData f) {
  if (!usedPaths.contains(f.path)) {
    queue.add(f);
    usedPaths.add(f.path);
  }
}
  Future<void> processFoldersFromFileSequential() async {
  // Reset stop flag at the start of new process
  Funcs.resetStopRequest();
  isProcessing.value = true;
  processedCount.value = 0;
  successCount.value = 0;
  failureCount.value = 0;

  const int batchSize = 100; 

  try {
    // التحقق من وجود أداة ملف في النموذج قبل بدء المعالجة
    if (Funcs.form_model == null) {
      isProcessing.value = false;
      _showSnackBar('لم يتم تحميل النموذج', false);
      await LogServices.write('[Folder Processing] لم يتم تحميل النموذج');
      return;
    }

    final fileControl = Funcs.form_model!.controls.firstWhereOrNull(
      (c) => c.type == 7,
    );

    if (fileControl == null) {
      isProcessing.value = false;
      _showSnackBar('لا توجد أداة ملف في النموذج', false);
      await LogServices.write('[Folder Processing] لا توجد أداة ملف في النموذج');
      return;
    }

    var data = await _readFoldersData();
    if (data.folders.isEmpty) {
      _showSnackBar('لا توجد مجلدات في ملف الفولدرات للمعالجة', false);
      return;
    }

    // تجاهل المحذوفة مؤقتًا
    final all = data.folders.where((f) => !f.isDeleted).toList();

    //  المعلقات
    for (final f in all.where((f) => f.Status == 'Processing' && (f.taskId != null && f.taskId!.isNotEmpty))) {
      addToQueue(f);
    }

    // 2) الجديد
    for (final f in all.where((f) => f.Status == 'Pending' && (f.attempts == 0))) {
      addToQueue(f);
    }

    // 3) الفاشل / إعادة محاولة
    for (final f in all.where((f) => f.Status != 'Success' && !(f.Status == 'Processing' && f.taskId != null))) {
      addToQueue(f);
    }
    totalCount.value = queue.length;
    _showSnackBar('بدء المعالجة من ملف: ${queue.length} مجلد...', true);

    while (startIndex < queue.length) {
      // Check if stop was requested before processing batch
      if (Funcs.isStopRequested) {
        updateUIAfterStopeing();
        return;
      }

      final end = (startIndex + batchSize < queue.length) ? startIndex + batchSize : queue.length;
      final batch = queue.sublist(startIndex, end);

      for (final f in batch) {
        // Check if stop was requested before processing each folder
        // This prevents starting a new folder if stop was requested during previous folder
        if (Funcs.isStopRequested) {
          updateUIAfterStopeing();
          return; // Exit immediately, don't process this or any remaining folders
        }

        final dir = Directory(f.path);
        if (!await dir.exists()) {
          // علم على المجلد كمحذوف بدل مسحه
          final idx = data.folders.indexWhere((d) => d.path == f.path);
          if (idx != -1) {
            data.folders[idx] = data.folders[idx].copyWith(
              isDeleted: true,
              Status: 'Error',
              StatusMessage: 'المجلد غير موجود'
            );
            await _writeFoldersDataAtomic(FoldersData(folders: data.folders));
          }
          failureCount.value++;
          processedCount.value++;
          continue;
        }

        await _updateFolderStatus(f.path, ProcessingStatus.Processing, 'جاري المعالجة',
            attempts: f.attempts + 1);

        final result = await _processSingleSubfolderWrapped(dir);

        // Check if stop was requested - either by flag or by result message
        if (Funcs.isStopRequested || result.errorMessage == 'تم إيقاف المعالجة حسب الطلب') {
          updateUIAfterStopeing();
          return;
        }

        if (result.status == ProcessingStatus.Success) {
          await _updateFolderStatus(f.path, ProcessingStatus.Success, 'تم الإرسال', processedAt: DateTime.now());
          successCount.value++;
        } else if (result.status == ProcessingStatus.Processing || result.status == ProcessingStatus.Pending) {
          // معالجتها مثل المعلقات القديمة بالضبط
          await _updateFolderStatus(
            f.path,
            ProcessingStatus.Processing,
            'قيد الانتظار (تم إرسال الطلب، بانتظار نتيجة)',
            attempts: f.attempts + 1,
            taskId: result.taskId,
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
          );
        } else {
          await _updateFolderStatus(f.path, ProcessingStatus.Error, result.errorMessage ?? 'خطأ غير معروف',
              processedAt: DateTime.now());
          failureCount.value++;
        }

        processedCount.value++;
       await LogServices.write('[Folder Processing] تمت معالجه المجلد الابن ${f.name}');

        await Future.delayed(const Duration(seconds: 1));
      }

      // Check before moving to next batch
      if (Funcs.isStopRequested) {
        updateUIAfterStopeing();
        return;
      }

      startIndex += batchSize;
      await Future.delayed(const Duration(seconds: 1)); // فاصل لتخفيف الضغط
    }

    // --- بعد المعالجة: إعادة فحص المعلقات والفاشلين مثل السابق تمامًا
    // Only retry if stop was not requested
    if (!Funcs.isStopRequested) {
      await LogServices.write('[Folder Processing] بداء معالجة الملعقات ');
      await _retryPendingFolders();
    }

    // Only show completion message if not stopped
    if (!Funcs.isStopRequested) {
      _showSnackBar('اكتملت المعالجة: ${successCount.value} نجح، ${failureCount.value} فشل', successCount.value > 0);
      Get.defaultDialog(
       actions: [
        ElevatedButton(onPressed: (){Get.back();}, child: Text('موافق'))
       ],
       title: 'النتجية',
       middleText: 'العمليات الناجحه:${successCount}\ العمليات الفاشله: ${failureCount}\n',

      );
    }

  } catch (e, st) {
    Funcs.errors.add('خطأ في المعالجة: $e');
    _showSnackBar('خطأ في المعالجة: $e', false);
    print(st);
    final stop = await Funcs.checkRepeatingErrors();
    if (stop) {
      updateUIAfterStopeing();
      return; // Exit early when stop is requested
    }
  } finally {
    // Only clear errors and reset processing state if not stopped
    if (!Funcs.isStopRequested) {
      Funcs.errors.clear();
      isProcessing.value = false;
    }
  }
}

  
  // --- Wrapped single folder processing
  Future<ProcessingResult> _processSingleSubfolderWrapped(
    Directory subfolder,
  ) async {

    final folderName = subfolder.path.split(Platform.pathSeparator).last;
    //This Comment is so Important do not remove it
    // Step 1: Parse folder name
    await LogServices.write('[Folder Processing] بداء فصل الاسم ');
    
    final parsed = _parserService.parseFolderName(folderName,department: department.value);
    // final parsed = folderName;
    print('parsed: $parsed');
    if (parsed == null) {
    // Parsing failed - invalid pattern
    await _saveFailure(Record( originalName: folderName, parsedName: null, errorMessage: 'اسم المجلد لا يتطابق مع النمط المطلوب', timestamp: DateTime.now(), folderPath: subfolder.path, ));
    await LogServices.write('[Folder Processing]فشل في فصل اسم المجلد');
    // Add error first
    Funcs.errors.add('اسم المجلد لا يتطابق مع النمط المطلوب: $folderName');
    
    // Check for repeating errors BEFORE showing snackbar
    final stop = await Funcs.checkRepeatingErrors();
    if (stop) {
      // Stop was requested - don't show snackbar, don't process further
      // Just return with stop status so main loop can break immediately
      return ProcessingResult(
        ProcessingStatus.Error,
        errorMessage: 'تم إيقاف المعالجة حسب الطلب',
      );
      
    }
    
    // Only show snackbar if stop was NOT requested
    if (!Funcs.isStopRequested) {
      _showSnackBar('⚠️ نمط غير صحيح: $folderName', false);
    }
    failureCount.value++;
    // Wait 1 second before moving to next folder 
    await Future.delayed(const Duration(seconds: 1));
    return ProcessingResult(
          ProcessingStatus.Error,
          errorMessage: 'اسم المجلد لا يتطابق مع النمط المطلوب',
        );
    
    }
    await LogServices.write('[Folder Processing]  تم فصل الاسم بنجاح بداء المعالجة');
    try {
      final connectedControl = Funcs.form_model?.controls.firstWhereOrNull(
        (c) => c.type == 16,
      );
      if (connectedControl == null) {
        return ProcessingResult(
          ProcessingStatus.Error,
          errorMessage: 'لا توجد أداة ربط (نوع 16) في النموذج',
        );
      }

      // Check if stop was requested before starting API calls
      if (Funcs.isStopRequested) {
        await LogServices.write('[Folder Processing] تم ايقاف المعالجة حسب الطلب');
        return ProcessingResult(
          ProcessingStatus.Error,
          errorMessage: 'تم إيقاف المعالجة حسب الطلب',
        );
      }
          
      final response = await _apiClient.getFirstMatch(
        formId: Funcs.form_id!,
        controlId: connectedControl.id,
        value: parsed.formatted,
      );

      // Check again after API call
      if (Funcs.isStopRequested) {
        await LogServices.write('[Folder Processing] تم ايقاف المعالجة حسب الطلب');
        return ProcessingResult(
          ProcessingStatus.Error,
          errorMessage: 'تم إيقاف المعالجة حسب الطلب',
        );
      }
      await LogServices.write('[Folder Processing]Get First Match response: $response');
       print('response received');
      final valueMap = _asValueMap(response['value']);
      if (valueMap == null || valueMap.isEmpty) {
        
        await LogServices.write('[Folder Processing] لا توجد بيانات مطابقة للمجلد');
        return ProcessingResult(
          ProcessingStatus.Empty,
          errorMessage: 'لا توجد بيانات مطابقة للمجلد',
        );
      }

      // معالجة الحقول التي type == 5 (تحويل التاريخ وإزالة type)
      await _processDateFieldsInValueMap(valueMap);

      await _openPreviewDialog(valueMap);

      // Check before form operations
      if (Funcs.isStopRequested) {
        await _closePreviewDialogIfAny();
        return ProcessingResult(
          ProcessingStatus.Error,
          errorMessage: 'تم إيقاف المعالجة حسب الطلب',
        );
      }

      try {
        _formController?.setConnectedValue(connectedControl.id, valueMap);
        await _fillFormFromData(valueMap);
        await _addFilesToFileControl(subfolder);
        _formController?.forceUpdate();

        // Check before building payload
        if (Funcs.isStopRequested) {
          await _closePreviewDialogIfAny();
          return ProcessingResult(
            ProcessingStatus.Error,
            errorMessage: 'تم إيقاف المعالجة حسب الطلب',
          );
        }
        await LogServices.write('[Folder Processing] بداء بناء payload ${jsonEncode(valueMap)}');
        final payload = await _formController?.buildSubmitPayload();
        if (payload == null) {
          await LogServices.write('[Folder Processing] فشل بناء payload');
          print('فشل بناء payload');
          await _closePreviewDialogIfAny();
          return ProcessingResult(
            ProcessingStatus.Error,
            errorMessage: 'فشل بناء payload',
          );
        } else {
          await LogServices.write('[Folder Processing] تم بناء payload بنجاح');
        }
        // Check before submitting
        if (Funcs.isStopRequested) {
          await _closePreviewDialogIfAny();
          return ProcessingResult(
            ProcessingStatus.Error,
            errorMessage: 'تم إيقاف المعالجة حسب الطلب',
          );
        }

        final uploadFolderName = payload['foldername'] ?? 'unknown';
        final sanitizedPayload = Funcs.sanitizeResponse(jsonEncode(payload));
        print('payload: $sanitizedPayload');
        await LogServices.write('[Folder Processing] submitForm payload: $sanitizedPayload');
        final submitResponse = await _apiClient.submitForm(payload);
        final sanitizedResponse = Funcs.sanitizeResponse(jsonEncode(submitResponse));
        print('submitResponse: $sanitizedResponse');

        // Check after submitting
        if (Funcs.isStopRequested) {
          await _closePreviewDialogIfAny();
          return ProcessingResult(
            ProcessingStatus.Error,
            errorMessage: 'تم إيقاف المعالجة حسب الطلب',
          );
        }
        final uploadedCount = _countUploadedFiles(payload['controls']);

        final initial = await SubmissionService.checkSubmissionStatus(submitResponse);

        if (initial.status == SubmissionStatus.success) {
          final applyId = initial.applyId!;
          await LogServices.write('[Folder Processing] تم الرفع والإرسال بنجاح للمجلد ${folderName}');
          await _saveSuccess(
            Record(
              originalName: folderName,
              parsedName: parsed.formatted,
              errorMessage:
                  'تم الرفع والإرسال بنجاح (folder: $uploadFolderName, files: $uploadedCount)',
              timestamp: DateTime.now(),
              folderPath: subfolder.path,
            ),
          );
          return ProcessingResult(ProcessingStatus.Success, applyId: applyId);
        }

        if (initial.status == SubmissionStatus.pending) {
          // حساب حجم المجلد لتحديد مهلة السماح المناسبة
          await LogServices.write('[Folder Processing] قيد الانتظار للمجلد ${folderName}');
          final folderBytes = await _directorySize(subfolder);
          final cfg = pollConfigForSizeBytes(folderBytes);

          // عرض رسالة دائمة توضح أن التطبيق ينتظر وخمن المدة
          final humanSize = (folderBytes / (1024 * 1024)).toStringAsFixed(1);
          _showPersistentInfo(
            'جاري التحقق من حالة الإرسال — حجم المجلد ~ ${humanSize} MB. الانتظار حتى ${cfg.grace.inSeconds} ثانية...',
          );

          try {
            // Check before polling
            if (Funcs.isStopRequested) {
              _hidePersistentSnack();
              await _closePreviewDialogIfAny();
              return ProcessingResult(
                ProcessingStatus.Error,
                errorMessage: 'تم إيقاف المعالجة حسب الطلب',
              );
            }

            final check = await SubmissionService.pollForGracePeriod(
              taskId: initial.taskId ?? '',
              accessToken: initial.accessToken,
              refreshToken: initial.refreshToken,
              grace: cfg.grace,
              pollInterval: cfg.pollInterval,
              perAttemptTimeout: cfg.perAttemptTimeout,
              shouldStop: () => Funcs.isStopRequested,
            );

            // Check after polling
            if (Funcs.isStopRequested) {
              _hidePersistentSnack();
              await _closePreviewDialogIfAny();
              return ProcessingResult(
                ProcessingStatus.Error,
                errorMessage: 'تم إيقاف المعالجة حسب الطلب',
              );
            }

            if (check.status == SubmissionStatus.success &&
                check.applyId != null) {
              final applyId = check.applyId!;
              await _saveSuccess(
                Record(
                  originalName: folderName,
                  parsedName: parsed.formatted,
                  errorMessage: 'تم الرفع والإرسال بنجاح (applyId: $applyId)',
                  timestamp: DateTime.now(),
                  folderPath: subfolder.path,
                ),
              );
              // حدّث ملف الفولدرات
              await _updateFolderStatus(
                subfolder.path,
                ProcessingStatus.Success,
                'تم الإرسال',
                processedAt: DateTime.now(),
              );
              return ProcessingResult(
                ProcessingStatus.Success,
                applyId: applyId,
              );
            }

            // بقي Pending بعد نافذة السماح أو لم نتمكن من استخلاص applyId
            // سجّل taskId/accessToken/refreshToken (إن وُجدت) ليعاد فحصها في المرور الثاني
            await _updateFolderStatus(
              subfolder.path,
              ProcessingStatus.Processing,
              'قيد الانتظار (تم إرسال الطلب، بانتظار نتيجة بعد نافذة السماح)',
              attempts: null, // سيزيد attempts في النداء الأعلى
              taskId: initial.taskId,
              accessToken: initial.accessToken,
              refreshToken: initial.refreshToken,
            );

            return ProcessingResult(
              ProcessingStatus.Processing,
              taskId: initial.taskId,
              accessToken: initial.accessToken,
              refreshToken: initial.refreshToken,
            );
          } catch (e) {
            // خطأ خلال الاستعلام — سجّله كفشل موقّت
            await LogServices.write('[Folder Processing] خطأ أثناء نافذة السماح: $e');
            Funcs.errors.add('خطأ أثناء نافذة السماح: $e');
            await _saveFailure(
              Record(
                originalName: folderName,
                parsedName: parsed.formatted,
                errorMessage: 'خطأ أثناء نافذة السماح: $e',
                timestamp: DateTime.now(),
                folderPath: subfolder.path,
              ),
            );
            await _updateFolderStatus(
              subfolder.path,
              ProcessingStatus.Error,
              'خطأ أثناء نافذة السماح: $e',
              processedAt: DateTime.now(),
            );
            final stop = await Funcs.checkRepeatingErrors();
            if (stop) {
              // Don't call updateUIAfterStopeing() here - let the main loop handle it
              return ProcessingResult(
                ProcessingStatus.Error,
                errorMessage: 'تم إيقاف المعالجة حسب الطلب',
              );
            }

            return ProcessingResult(
              ProcessingStatus.Error,
              errorMessage: e.toString(),
            );
          } finally {
            _hidePersistentSnack();
          }
        }

        return ProcessingResult(
          ProcessingStatus.Error,
          errorMessage: initial.errorMessage ?? 'فشل الإرسال',
        );
      } catch (apiError) {
        await LogServices.write('[Folder Processing] خطأ في الإرسال: $apiError');
        Funcs.errors.add('خطأ في الإرسال: $apiError');
        await _saveFailure(
          Record(
            originalName: folderName,
            parsedName: parsed.formatted,
            errorMessage: apiError.toString(),
            timestamp: DateTime.now(),
            folderPath: subfolder.path,
          ),
        );
        final stop = await Funcs.checkRepeatingErrors();
        if (stop) {
          // Don't call updateUIAfterStopeing() here - let the main loop handle it
          return ProcessingResult(
            ProcessingStatus.Error,
            errorMessage: 'تم إيقاف المعالجة حسب الطلب',
          );
        }
        return ProcessingResult(
          ProcessingStatus.Error,
          errorMessage: apiError.toString(),
        );
      } finally {
        _hidePersistentSnack();
        await _closePreviewDialogIfAny();
      }
    } catch (searchError) {
      await LogServices.write('[Folder Processing] خطأ في البحث: $searchError');
      Funcs.errors.add('خطأ في البحث: $searchError');
      await _saveFailure(
        Record(
          originalName: folderName,
          parsedName: parsed.formatted,
          errorMessage: searchError.toString(),
          timestamp: DateTime.now(),
          folderPath: subfolder.path,
        ),
      );
      final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        // Don't call updateUIAfterStopeing() here - let the main loop handle it
        return ProcessingResult(
          ProcessingStatus.Error,
          errorMessage: 'تم إيقاف المعالجة حسب الطلب',
        );
      }
      return ProcessingResult(
        ProcessingStatus.Error,
        errorMessage: searchError.toString(),
      );
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      await _closePreviewDialogIfAny();
    }
  }

  // --- Save to JSON (delegated to RecordStore)
  Future<void> _saveFailure(Record record) async {
    try {
      await _recordStore?.saveFailure(record);
    } catch (e) {
       Funcs.errors.add('خطأ في حفظ الفشل: $e');
      print('Error saving failure: $e');
       final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
      }
    }
  }

  Future<void> _saveSuccess(Record record) async {
    try {
      await _recordStore?.saveSuccess(record);
    } catch (e) {
       Funcs.errors.add('خطأ في حفظ النجاح: $e');
      print('Error saving success: $e');
       final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
      }
    }
  }

  // --- UI helpers
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

  void _showPersistentInfo(String message) {
    if (Get.isSnackbarOpen == true) return;
    Get.showSnackbar(GetSnackBar(
      title: 'الرجاء الانتظار',
      message: message,
      backgroundColor: Colors.blueGrey.withOpacity(0.95),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: 10,
      duration: const Duration(days: 1),
      isDismissible: false,
    ));
  }

  void _hidePersistentSnack() {
    if (Get.isSnackbarOpen == true) {
      try {
        Get.closeCurrentSnackbar();
      } catch (_) {}
    }
  }

  // --- Form helpers (unchanged)
  Future<void> _fillFormFromData(Map<String, dynamic> data) async {
    try {
      if (_formController == null) return;
      for (final control in Funcs.form_model!.controls) {
        if (control.type == 16) continue;
        if (control.type == 7) continue;
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
       Funcs.errors.add('خطأ في تعبئة الفورم: $e');
      print('خطأ في تعبئة الفورم: $e');
       final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
      }
    }
  }

  // Future<void> _addFilesToFileControl(Directory subfolder) async {
  //   try {
  //     if (_formController == null) return;
  //     final fileControl = Funcs.form_model!.controls.firstWhereOrNull((c) => c.type == 7);
  //     if (fileControl == null) return;
  //     final files = subfolder.listSync().whereType<File>().toList();
  //     if (files.isEmpty) return;
      
  //     final folderName = subfolder.path.split(Platform.pathSeparator).last;
      
  //     final foldersList = <Map<String, dynamic>>[
  //       {
  //         'id': null,
  //         'folder_name': folderName,
  //         'id_in_code': 1,
  //         'child_of': null,
  //         'created_user': Funcs.user_id ?? 0,
  //         'f_id': Funcs.form_id ?? 0,
  //         'w_id': 0,
  //         'status': 'added',
  //         'obj_id': 0,
  //         'apply_id': 0,
  //         'control_id': fileControl.id,
  //         'apply_form_id': 0,
  //         'parent_path_t': null,
  //         'created_in_this_session': true,
  //         'folder_path': folderName, 
  //       }
  //     ];
      
  //     final filesList = <Map<String, dynamic>>[];
  //     int rowNum = 1;
  //     for (final file in files) {
  //       final fullPath = file.path;
  //       final fileName = fullPath.split(Platform.pathSeparator).last;
  //       final fileExtension = fileName.contains('.') ? fileName.split('.').last : '';
  //       final fileSize = await file.length();
  //       final fileNameWithoutExt = fileName.contains('.') ? fileName.split('.').first : fileName;
        
  //       filesList.add({
  //         'id': null,
  //         'file': fullPath, 
  //         'path': fullPath, 
  //         'version': 1,
  //         'user_id': Funcs.user_id ?? 0,
  //         'size': fileSize,
  //         'row_num': rowNum,
  //         'parent_path_t': '0', 
  //         'path_t': '0.$rowNum', 
  //         'original_file_id': null,
  //         'file_name': fileNameWithoutExt, 
  //         'file_extension': fileExtension,
  //         'pages_count': 1,
  //         'folder_path': folderName,
  //         'folder_id': 1,
  //         'status': 'added',
  //         'old_path': null,       
  //         'name': fileName,
  //         'base64': fullPath, 
  //         'picked_inn_this_session': true,
  //       });
  //       rowNum++;
  //     }
      
  //     _formController.setValueWithoutValidation(fileControl.id, {
  //       'files': filesList,
  //       'folders': foldersList,
  //     });
  //   } catch (e) {
  //      Funcs.errors.add('خطأ في إضافة الملفات: $e');
  //     print('خطأ في إضافة الملفات: $e');
  //      final stop = await Funcs.checkRepeatingErrors();
  //     if (stop) {
  //       updateUIAfterStopeing();
  //     }
  //   }
  // }

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
        filesList.add({
          'path': fullPath,
          'base64': fullPath,
        });
      }
      _formController.setValueWithoutValidation(fileControl.id, {'files': filesList});
    } catch (e) {
       Funcs.errors.add('خطأ في إضافة الملفات: $e');
      print('خطأ في إضافة الملفات: $e');
       final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
      }
    }
  }


  Map<String, dynamic>? _asValueMap(dynamic raw) {
    return SubmissionService.asValueMap(raw);
  }

  /// تحويل التاريخ إلى صيغة YYYY-MM-DD HH24:MI:SS
  String _convertDateToFormat(String? dateValue) {
    if (dateValue == null || dateValue.isEmpty) {
      return '';
    }

    try {
      // محاولة تحويل التاريخ من صيغ مختلفة
      DateTime? dateTime;
      
      // محاولة تحويل من ISO format
      try {
        dateTime = DateTime.parse(dateValue);
      } catch (e) {
        // محاولة صيغ أخرى شائعة
        // يمكن إضافة المزيد من الصيغ حسب الحاجة
        final commonFormats = [
          'yyyy-MM-dd HH:mm:ss',
          'yyyy-MM-dd HH:mm',
          'yyyy-MM-dd',
          'dd/MM/yyyy HH:mm:ss',
          'dd/MM/yyyy HH:mm',
          'dd/MM/yyyy',
          'MM/dd/yyyy HH:mm:ss',
          'MM/dd/yyyy HH:mm',
          'MM/dd/yyyy',
        ];

        for (final format in commonFormats) {
          try {
            dateTime = DateFormat(format).parse(dateValue);
            break;
          } catch (e) {
            continue;
          }
        }
      }

      if (dateTime != null) {
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
      }
      
      // إذا فشل التحويل، إرجاع القيمة الأصلية
      return dateValue;
    } catch (e) {
      // في حالة الخطأ، إرجاع القيمة الأصلية
      return dateValue;
    }
  }

  /// معالجة valueMap: تحويل الحقول التي type == 5 وإزالة حقل type من جميع الحقول
  Future<void> _processDateFieldsInValueMap(Map<String, dynamic> valueMap) async {
    await LogServices.write('[Folder Processing] بدء معالجة valueMap (حذف type من جميع الحقول)');
    int processedCount = 0;
    
    // البحث عن جميع الحقول في valueMap
    for (final entry in valueMap.entries.toList()) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is Map<String, dynamic>) {
        // التحقق من وجود حقل type
        if (value.containsKey('type')) {
          final type = value['type'];
          
          if (type == 5) {
            // تحويل قيمة التاريخ
            final dateValue = value['value'];
            final convertedDate = _convertDateToFormat(dateValue?.toString());
            
            // تحديث القيمة وتحويل الـ Map إلى قيمة بسيطة (إزالة type)
            valueMap[key] = convertedDate;
            processedCount++;
            
            await LogServices.write('[Folder Processing] تم تحويل حقل التاريخ $key: $dateValue -> $convertedDate');
          } else {
            // للحقول الأخرى، نحذف حقل type فقط ونحتفظ بالقيمة
            final fieldValue = value['value'];
            // استبدال الـ Map بالقيمة فقط (حذف type)
            valueMap[key] = fieldValue;
            processedCount++;
          }
        }
      }
    }
    
    await LogServices.write('[Folder Processing] تم معالجة $processedCount حقل (تم حذف type من جميع الحقول)');
    await LogServices.write('[Folder Processing] valueMap بعد المعالجة: ${jsonEncode(valueMap)}');
  }

  int _countUploadedFiles(dynamic controls) {
    return SubmissionService.countUploadedFiles(controls);
  }

  Future<void> _openPreviewDialog(Map<String, dynamic> valueMap) async {
    await _closePreviewDialogIfAny();
    await Future.delayed(const Duration(milliseconds: 30));
    _dialogOpen = true;
    try {
      showFirstMatchDialog(valueMap);
    } catch (e) {
       Funcs.errors.add('خطأ في فتح النافذة: $e');
      _dialogOpen = false;
       final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
      }
      rethrow;
    }
  }

  Future<void> _closePreviewDialogIfAny() async {
    if (!_dialogOpen) return;
    Get.until((route) => route.settings.name != 'first_match_dialog');
    _dialogOpen = false;
    await Future.delayed(const Duration(milliseconds: 20));
  }
  // --- utility: clear failures
  Future<void> clearFailures() async {
    try {
      if (_recordStore == null) return;
      await _recordStore!.clearFailures();
      _showSnackBar('تم مسح سجل الفشل', true);
    } catch (e) {
       Funcs.errors.add('خطأ في مسح سجل الفشل: $e');
      _showSnackBar('خطأ في مسح سجل الفشل: $e', false);
       final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
      }
    }
  }

/// Returns folder size in bytes (recursively). Fast but may take time on big folders.
Future<int> _directorySize(Directory dir) async {
  var total = 0;
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          final len = await entity.length();
          total += len;
        } catch (e) {
           Funcs.errors.add('خطأ في حساب حجم المجلد: $e');
          // تجاهل الملفات التي تعطي خطأ في الطول
        }
      }
    }
  } catch (e) {
    print('Error calculating directory size: $e');
  }
  return total;
}
//Retry Pending Folders
Future<void> _retryPendingFolders() async {
  // Check if stop was requested before starting retry
  if (Funcs.isStopRequested) {
    return;
  }

  final data = await _readFoldersData();
  final pendingFolders = data.folders.where((fd) =>
      fd.Status == ProcessingStatus.Processing.toString().split('.').last &&
      (fd.taskId != null && fd.taskId!.isNotEmpty)).toList();

  if (pendingFolders.isEmpty) return;

  _showSnackBar('إعادة فحص ${pendingFolders.length} مهمة معلقة...', true);

  final retryDelays = <Duration>[
    const Duration(seconds: 5),
    const Duration(seconds: 15),
    const Duration(seconds: 60)
  ];
  final maxAttempts = retryDelays.length;

  for (final pf in pendingFolders) {
    // Check if stop was requested before processing each pending folder
    if (Funcs.isStopRequested) {
      return;
    }

    bool resolved = false;
    String lastErrorMessage = '';

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // Check if stop was requested before each retry attempt
      if (Funcs.isStopRequested) {
        return;
      }

      if (attempt > 0) await Future.delayed(retryDelays[attempt]);

      try {
        final check = await SubmissionService.pollForGracePeriod(
          taskId: pf.taskId!,
          accessToken: pf.accessToken, // استخدام accessToken المحفوظ
          refreshToken: pf.refreshToken, // استخدام refreshToken المحفوظ
          grace: const Duration(seconds: 20),
          pollInterval: const Duration(seconds: 3),
          perAttemptTimeout: Duration(seconds: 35 + (attempt * 10)), // ازدياد المهلة مع المحاولات (35 ثانية كحد أدنى)
          shouldStop: () => Funcs.isStopRequested,
        );

        // Check again after polling
        if (Funcs.isStopRequested) {
          return;
        }

        if (check.status == SubmissionStatus.success && check.applyId != null) {
          final applyId = check.applyId!;
          await _updateFolderStatus(pf.path, ProcessingStatus.Success, 'تمت المعالجة بعد إعادة الفحص', processedAt: DateTime.now());
          await _saveSuccess(Record(
            originalName: pf.name,
            parsedName: pf.name,
            errorMessage: 'تم الرفع والإرسال بنجاح (applyId: $applyId)',
            timestamp: DateTime.now(),
            folderPath: pf.path,
          ));
          successCount.value++;
          resolved = true;
          break;
        }

        if (check.status == SubmissionStatus.pending) {
          lastErrorMessage = 'ما زال قيد الانتظار (attempt ${attempt + 1})';
          await _updateFolderStatus(pf.path, ProcessingStatus.Processing, lastErrorMessage, attempts: (pf.attempts ?? 0) + 1, taskId: pf.taskId);
          continue;
        }

        if (check.status == SubmissionStatus.error) {
          lastErrorMessage = check.errorMessage ?? 'خطأ غير معروف أثناء الفحص';
          continue;
        }
      } catch (e) {
        Funcs.errors.add('خطأ في إعادة فحص المهمة المعلقة: $e');
        lastErrorMessage = e.toString();
        final stop = await Funcs.checkRepeatingErrors();
        if (stop) {
          updateUIAfterStopeing();
          return; // Exit early when stop is requested
        }

        continue;
      }
    }

    // Check before finalizing this folder
    if (Funcs.isStopRequested) {
      return;
    }

    if (!resolved) {
       Funcs.errors.add('لم تصل نتيجة بعد ${maxAttempts} محاولات؛ يتم ختم المعالجة بتاريخ الآن');
      final msg = 'لم تصل نتيجة بعد ${maxAttempts} محاولات؛ يتم ختم المعالجة بتاريخ الآن';
      await _updateFolderStatus(pf.path, ProcessingStatus.Error, msg, processedAt: DateTime.now());
      failureCount.value++;
      await _saveFailure(Record(
        originalName: pf.name,
        parsedName: pf.name,
        errorMessage: msg + (lastErrorMessage.isNotEmpty ? ' — last: $lastErrorMessage' : ''),
        timestamp: DateTime.now(),
        folderPath: pf.path,
      ));
       final stop = await Funcs.checkRepeatingErrors();
      if (stop) {
        updateUIAfterStopeing();
        return; // Exit early when stop is requested
      }

    }

    await Future.delayed(const Duration(seconds: 2));
  }
}

void updateUIAfterStopeing(){
  // Don't reset stop flag here - it should remain set until a new process starts
  // This ensures any remaining checks will see the stop flag
  _hidePersistentSnack();
  _closePreviewDialogIfAny();
  isProcessing.value = false;
  _showSnackBar('تم إيقاف المعالجة حسب الطلب', false);
  //  Get.reloadAll(force: true);
  }

}
