// controllers/folder_processing_controller.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
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
  final currentFolderPath = ''.obs;
  final totalCount = 0.obs;
  final successCount = 0.obs;
  final failureCount = 0.obs;
  final pendingCount = 0.obs; // عدد المعلقات
  final department = 'default'.obs;
  // قائمة المهام (يمكن استخدامها للعرض اللحظي إن رغبت)
  final RxList<ProcessingTask> tasks = <ProcessingTask>[].obs;
  final TextEditingController textEditingController = TextEditingController();
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
  
  // ملاحظة: startIndex يُستخدم فقط للعرض والإحصائيات
  // المعالجة الفعلية تبدأ دائماً من 0 لأن الـ queue يُعاد بناؤها في كل مرة
  
  @override
  void onInit() {
    super.onInit();
    Future.delayed(const Duration(seconds: 2), () async {
      _initFailuresFile();
      _initSuccessesFile();
      _initFoldersFile();
      // تحديث عدد المعلقات بعد تهيئة الملفات
      await Future.delayed(const Duration(milliseconds: 500));
      await _updatePendingCount();
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
    
    // إعادة تعيين startIndex عند اختيار مجلد جديد
    if (currentFolderPath.value != parentFolder.path) {
      startIndex = 0;
      await LogServices.write(
        '[Folder Processing] تم اختيار مجلد جديد - إعادة تعيين startIndex إلى 0',
      );
    }
    
    currentFolderPath.value = parentFolder.path;

    // اقرأ البيانات الحالية (قد تكون فارغة)
    final current = await _readFoldersData();
    final currentByPath = {for (var f in current.folders) f.path: f};

    // اجمع المجلدات الموجودة حالياً
    final foundPaths = <String, String>{}; // path -> name
    await for (final entity in parentFolder.list(
      recursive: false,
      followLinks: false,
    )) {
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
          Status: existing.Status == 'Success'
              ? existing.Status
              : existing.Status, // لا نغيّر النجاح
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
        merged.add(
          FolderData(
            name: name,
            path: path,
            Status: 'Pending',
            StatusMessage: 'Discovered',
            discoveredAt: DateTime.now(),
            attempts: 0,
            isDeleted: false,
          ),
        );
      }
    }

    // 2) لمعالجة السجلات القديمة التي لم تعد موجودة: عيّنها كـ Deleted (لا تمسح)
    // for (final old in current.folders) {
    //   if (!foundPaths.containsKey(old.path)) {
    //     // لو كانت بالفعل success فلا نغيرها (نحتفظ بالتاريخ) — لكن نعلم أنها محذوفة
    //     final updated = FolderData(
    //       name: old.name,
    //       path: old.path,
    //       Status: old.Status, // نحتفظ بالحالة (Success أو Error)
    //       StatusMessage: old.StatusMessage + ' | Marked as deleted on scan',
    //       discoveredAt: old.discoveredAt,
    //       processedAt: old.processedAt,
    //       attempts: old.attempts,
    //       taskId: old.taskId,
    //       isDeleted: true,
    //     );
    //     merged.add(updated);
    //   }
    // }

    // 2) معالجة السجلات القديمة التي لم تعد موجودة
    for (final old in current.folders) {
      if (!foundPaths.containsKey(old.path)) {
        // تحقق من أن المجلد غير موجود فعلياً في التخزين
        final exists = Directory(old.path).existsSync();

        if (!exists) {
          // المجلد محذوف فعلياً → نعلمه كـ Deleted
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
        } else {
          // موجود فعلياً → لا نعتبره محذوف
          merged.add(old);
        }
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
        // قراءة البيانات فقط، بدون استعادة أي indexes
        if (decoded.containsKey('folders') && decoded['folders'] is List) {
          final list = decoded['folders'] as List<dynamic>;
          return FoldersData(
            folders: list
                .map((e) => FolderData.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        }
        // single object -> wrap
        return FoldersData(folders: [FolderData.fromJson(decoded)]);
      }
      if (decoded is List) {
        return FoldersData(
          folders: decoded
              .map((e) => FolderData.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
      return FoldersData(folders: []);
    } catch (e) {
      Funcs.errors.add('خطأ في قراءة الملف: $e');
      // حاول NDJSON قراءة سطر-سطر
      final lines = content
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
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
    
    // إضافة metadata للإحصائيات فقط (بدون startIndex لأنه لم يعد مستخدماً)
    final dataToSave = {
      'folders': cleanedFolders.map((f) => f.toJson()).toList(),
      'metadata': {
        'lastProcessedAt': DateTime.now().toIso8601String(),
        'totalFolders': cleanedFolders.length,
        'currentFolderPath': currentFolderPath.value,
      }
    };
    
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(dataToSave),
    );
    if (await tmp.exists()) {
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
      await tmp.rename(f.path);
    }
    // تحديث عدد المعلقات بعد الكتابة
    await _updatePendingCount();
  }

  // دالة لتحديث عدد المعلقات
  Future<void> _updatePendingCount() async {
    try {
      final data = await _readFoldersData();
      // إذا كان currentFolderPath موجود، نحسب المعلقات في نفس مسار مجلد الأب فقط
      if (currentFolderPath.value.isNotEmpty) {
        final pendingFolders = data.folders
            .where(
              (fd) =>
                  !fd.isDeleted &&
                  fd.path.startsWith(currentFolderPath.value) &&
                  fd.path !=
                      currentFolderPath.value && // استبعاد مجلد الأب نفسه
                  fd.Status ==
                      ProcessingStatus.Processing.toString().split('.').last &&
                  (fd.taskId != null && fd.taskId!.isNotEmpty),
            )
            .toList();
        pendingCount.value = pendingFolders.length;
      } else {
        // إذا لم يكن هناك مسار محدد، نحسب جميع المعلقات
        final pendingFolders = data.folders
            .where(
              (fd) =>
                  fd.Status ==
                      ProcessingStatus.Processing.toString().split('.').last &&
                  (fd.taskId != null && fd.taskId!.isNotEmpty) &&
                  !fd.isDeleted,
            )
            .toList();
        pendingCount.value = pendingFolders.length;
      }
    } catch (e) {
      // في حالة الخطأ، نضع القيمة 0
      pendingCount.value = 0;
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
      refreshToken: shouldRemoveTokens
          ? null
          : (refreshToken ?? old.refreshToken),
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
        await LogServices.write(
          '[Folder Processing] لا توجد أداة ملف في النموذج',
        );
        return;
      }

      // قراءة البيانات (الـ queue ستُبنى من جديد وتحتوي فقط على المجلدات التي تحتاج معالجة)
      var data = await _readFoldersData();
      if (data.folders.isEmpty) {
        _showSnackBar('لا توجد مجلدات في ملف الفولدرات للمعالجة', false);
        return;
      }

      // تحديث عدد المعلقات عند بدء المعالجة
      await _updatePendingCount();

      // تجاهل المحذوفة مؤقتًا
      final all = data.folders.where((f) => !f.isDeleted).toList();

      // التحقق من أن currentFolderPath موجود
      if (currentFolderPath.value.isEmpty) {
        _showSnackBar('لم يتم تحديد مسار مجلد الأب', false);
        isProcessing.value = false;
        return;
      }

      // فلترة المجلدات التي في نفس مسار مجلد الأب فقط
      final foldersInParentPath = all
          .where(
            (f) =>
                f.path.startsWith(currentFolderPath.value) &&
                f.path != currentFolderPath.value, // استبعاد مجلد الأب نفسه
          )
          .toList();

      //  المعلقات (في نفس مسار مجلد الأب فقط)
      for (final f in foldersInParentPath.where(
        (f) =>
            f.Status == 'Processing' &&
            (f.taskId != null && f.taskId!.isNotEmpty),
      )) {
        addToQueue(f);
      }

      // 2) الجديد (في نفس مسار مجلد الأب فقط)
      for (final f in foldersInParentPath.where(
        (f) => f.Status == 'Pending' && f.attempts == 0,
      )) {
        addToQueue(f);
      }

      // 3) الفاشل / إعادة محاولة (في نفس مسار مجلد الأب فقط)
      for (final f in foldersInParentPath.where(
        (f) =>
            f.Status != 'Success' &&
            !(f.Status == 'Processing' && f.taskId != null),
      )) {
        addToQueue(f);
      }
      totalCount.value = queue.length;
      
      // ✅ الحل الصحيح: دائماً نبدأ من الصفر لأن الـ queue تحتوي فقط على المجلدات التي تحتاج معالجة
      // الـ queue يُعاد بناؤها في كل مرة وتستثني المجلدات الناجحة (Success)
      startIndex = 0;
      
      await LogServices.write(
        '[Folder Processing] 🚀 بدء المعالجة - عدد المجلدات المتبقية: ${queue.length}',
      );
      _showSnackBar('بدء المعالجة: ${queue.length} مجلد...', true);

      // معالجة المجلدات واحداً تلو الآخر - دائماً من البداية
      for (int i = 0; i < queue.length; i++) {
        // تحديث startIndex للعرض والإحصائيات فقط
        startIndex = i;
        // Check if stop was requested before processing each folder
        if (Funcs.isStopRequested) {
          updateUIAfterStopeing();
          return;
        }

        final f = queue[i]; // استخدام i بدلاً من startIndex
        final dir = Directory(f.path);
        
        if (!await dir.exists()) {
          // علم على المجلد كمحذوف بدل مسحه
          final idx = data.folders.indexWhere((d) => d.path == f.path);
          if (idx != -1) {
            data.folders[idx] = data.folders[idx].copyWith(
              isDeleted: true,
              Status: 'Error',
              StatusMessage: 'المجلد غير موجود',
            );
            await _writeFoldersDataAtomic(FoldersData(folders: data.folders));
          }
          failureCount.value++;
          processedCount.value++;
          
          await LogServices.write('[Folder Processing] ⏭️ تم تخطي المجلد ${f.name} (غير موجود) - التقدم: ${i + 1}/${queue.length}');
          continue;
        }

        await _updateFolderStatus(
          f.path,
          ProcessingStatus.Processing,
          'جاري المعالجة',
          attempts: f.attempts + 1,
        );

        final result = await _processSingleSubfolderWrapped(dir);

        // Check if stop was requested - either by flag or by result message
        if (Funcs.isStopRequested ||
            result.errorMessage == 'تم إيقاف المعالجة حسب الطلب') {
          updateUIAfterStopeing();
          return;
        }

        if (result.status == ProcessingStatus.Success) {
          await _updateFolderStatus(
            f.path,
            ProcessingStatus.Success,
            'تم الإرسال',
            processedAt: DateTime.now(),
          );
          successCount.value++;
        } else if (result.status == ProcessingStatus.Processing ||
            result.status == ProcessingStatus.Pending) {
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
          await _updateFolderStatus(
            f.path,
            ProcessingStatus.Error,
            result.errorMessage ?? 'خطأ غير معروف',
            processedAt: DateTime.now(),
          );
          failureCount.value++;
        }

        processedCount.value++;
        
        await LogServices.write(
          '[Folder Processing] ✅ تمت معالجة المجلد ${f.name} - التقدم: ${i + 1}/${queue.length}',
        );

        await Future.delayed(const Duration(seconds: 1));
      } // نهاية for loop

      // --- بعد المعالجة: إعادة فحص المعلقات والفاشلين مثل السابق تمامًا
      // Only retry if stop was not requested
      if (!Funcs.isStopRequested) {
        await LogServices.write('[Folder Processing] بداء معالجة الملعقات ');
        await _retryPendingFolders();
      }

      // Only show completion message if not stopped
      if (!Funcs.isStopRequested) {
        await LogServices.write(
          '[Folder Processing] 🎉 اكتملت المعالجة - نجح: ${successCount.value}, فشل: ${failureCount.value}',
        );
        
        _showSnackBar(
          'اكتملت المعالجة: ${successCount.value} نجح، ${failureCount.value} فشل',
          successCount.value > 0,
        );
        await _showResultsDialog();
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
      processedCount.value = 0;
      successCount.value = 0;
      failureCount.value = 0;
      pendingCount.value = 0;
      totalCount.value = 0;
      tasks.clear();
      queue.clear();
      usedPaths.clear();
      _formController?.clearFormData();
    }
  }

  // --- Wrapped single folder processing
  Future<ProcessingResult> _processSingleSubfolderWrapped(
    Directory subfolder,
  ) async {
    final folderName = subfolder.path.split(Platform.pathSeparator).last;
    //This Comment is so Important do not remove it
    await LogServices.write('[Folder Processing]✅ Step 1 ');
    await LogServices.write('[Folder Processing] بداء فصل الاسم ');

    final parsed = _parserService.parseFolderName(
      folderName,
      department: department.value,
    );
    // final parsed = folderName;
    print('parsed: $parsed');
    if (parsed == null) {
      // Parsing failed - invalid pattern
      await _saveFailure(
        Record(
          originalName: folderName,
          parsedName: null,
          errorMessage: 'اسم المجلد لا يتطابق مع النمط المطلوب',
          timestamp: DateTime.now(),
          folderPath: subfolder.path,
        ),
      );
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
      await Future.delayed(const Duration(seconds: 2));
      return ProcessingResult(
        ProcessingStatus.Error,
        errorMessage: 'اسم المجلد لا يتطابق مع النمط المطلوب',
      );
    }
    await LogServices.write(
      '[Folder Processing]  تم فصل الاسم بنجاح بداء المعالجة',
    );
    await LogServices.write('[Folder Processing]✅ Step 2 ');
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
        await LogServices.write(
          '[Folder Processing] تم ايقاف المعالجة حسب الطلب',
        );
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
        await LogServices.write(
          '[Folder Processing] تم ايقاف المعالجة حسب الطلب',
        );
        return ProcessingResult(
          ProcessingStatus.Error,
          errorMessage: 'تم إيقاف المعالجة حسب الطلب',
        );
      }
      // await LogServices.write('[Folder Processing]Get First Match response: $response');
      print('response received');
      final valueMap = _asValueMap(response['value']);
      if (valueMap == null || valueMap.isEmpty) {
        await LogServices.write(
          '[Folder Processing] لا توجد بيانات مطابقة للمجلد',
        );
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
        await LogServices.write('[Folder Processing]✅ Step 3 ');
        // await LogServices.write('[Folder Processing] بداء بناء payload ${jsonEncode(valueMap)}');
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
        // final sanitizedPayload = Funcs.sanitizeResponse(jsonEncode(payload));
        // print('payload: $sanitizedPayload');
        // await LogServices.write('[Folder Processing] submitForm payload: $sanitizedPayload');
        await LogServices.write('[Folder Processing]✅ Step 4 ');
        final submitResponse = await _apiClient.submitForm(payload);
        // final sanitizedResponse = Funcs.sanitizeResponse(jsonEncode(submitResponse));
        // print('submitResponse: $sanitizedResponse');

        // Check after submitting
        if (Funcs.isStopRequested) {
          await _closePreviewDialogIfAny();
          return ProcessingResult(
            ProcessingStatus.Error,
            errorMessage: 'تم إيقاف المعالجة حسب الطلب',
          );
        }
        final uploadedCount = _countUploadedFiles(payload['controls']);
        await LogServices.write('[Folder Processing]✅ Step 5 ');
        final initial = await SubmissionService.checkSubmissionStatus(
          submitResponse,
        );

        if (initial.status == SubmissionStatus.success) {
          final applyId = initial.applyId!;
          await LogServices.write(
            '[Folder Processing] تم الرفع والإرسال بنجاح للمجلد ${folderName}',
          );
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
          // تنظيف بيانات النموذج بعد نجاح الإرسال
          _formController?.clearFormData();
          return ProcessingResult(ProcessingStatus.Success, applyId: applyId);
        }

        if (initial.status == SubmissionStatus.pending) {
          // حساب حجم المجلد لتحديد مهلة السماح المناسبة
          await LogServices.write(
            '[Folder Processing] قيد الانتظار للمجلد ${folderName}',
          );
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
              // تنظيف بيانات النموذج بعد نجاح الإرسال
              _formController?.clearFormData();
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
            await LogServices.write(
              '[Folder Processing] خطأ أثناء نافذة السماح: $e',
            );
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
        await LogServices.write(
          '[Folder Processing] خطأ في الإرسال: $apiError',
        );
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
        // await LogServices.write('[Folder Processing]✅ Folder Processing Finally ');
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
      await LogServices.write('[Folder Processing]✅ Folder Processing Ended ');
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

  // --- Read JSON files
  Future<SuccessData?> _readSuccessesData() async {
    try {
      if (_successFilePath == null) return null;
      final file = File(_successFilePath!);
      if (!await file.exists()) return SuccessData(successes: []);
      final content = await file.readAsString();
      if (content.trim().isEmpty) return SuccessData(successes: []);
      final json = jsonDecode(content);
      return SuccessData.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      print('Error reading successes file: $e');
      return SuccessData(successes: []);
    }
  }

  Future<FailuresData?> _readFailuresData() async {
    try {
      if (_failuresFilePath == null) return null;
      final file = File(_failuresFilePath!);
      if (!await file.exists()) return FailuresData(failures: []);
      final content = await file.readAsString();
      if (content.trim().isEmpty) return FailuresData(failures: []);
      final json = jsonDecode(content);
      return FailuresData.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      print('Error reading failures file: $e');
      return FailuresData(failures: []);
    }
  }

  // --- Sanitize error message (remove tokens)
  String _sanitizeErrorMessage(String errorMessage) {
    // Remove access token patterns
    String sanitized = errorMessage.replaceAll(
      RegExp(
        r'access[_\s]*token[=:]\s*[a-zA-Z0-9\-_\.]+',
        caseSensitive: false,
      ),
      'access_token: مخفى',
    );
    // Remove refresh token patterns
    sanitized = sanitized.replaceAll(
      RegExp(
        r'refresh[_\s]*token[=:]\s*[a-zA-Z0-9\-_\.]+',
        caseSensitive: false,
      ),
      'refresh_token: مخفى',
    );
    // Remove any remaining token-like strings in JSON (long tokens)
    sanitized = sanitized.replaceAll(
      RegExp(
        r'(?:access|refresh)[_\s]*token[=:]\s*[a-zA-Z0-9\-_\.]{20,}',
        caseSensitive: false,
      ),
      'مخفى',
    );
    return sanitized;
  }

  // --- Helper: Extract parent folder path from full path
  String _getParentPath(String folderPath) {
    try {
      return p.dirname(folderPath);
    } catch (e) {
      // Fallback: try to extract manually
      final parts = folderPath.split(Platform.pathSeparator);
      if (parts.length > 1) {
        return parts.sublist(0, parts.length - 1).join(Platform.pathSeparator);
      }
      return folderPath;
    }
  }
/*
  // --- Show results dialog with tabs grouped by parent folder
  Future<void> _showResultsDialog() async {
    final successesData = await _readSuccessesData();
    final failuresData = await _readFailuresData();

    final successes = successesData?.successes ?? [];
    final failures = failuresData?.failures ?? [];

    // Group successes by parent folder
    final successesByParent = <String, List<Record>>{};
    for (final success in successes) {
      final parentPath = _getParentPath(success.folderPath);
      successesByParent.putIfAbsent(parentPath, () => []).add(success);
    }

    // Group failures by parent folder
    final failuresByParent = <String, List<Record>>{};
    for (final failure in failures) {
      final parentPath = _getParentPath(failure.folderPath);
      failuresByParent.putIfAbsent(parentPath, () => []).add(failure);
    }

    final successCount = successes.length;
    final failureCount = failures.length;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: Get.width * 0.9,
          height: Get.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Title
              Text(
                'النتائج',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Tab Bar
              DefaultTabController(
                length: 2,
                child: Expanded(
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('الناجحه'),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$successCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('الفاشله'),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$failureCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Success Tab - Grouped by parent folder
                            successes.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد عمليات ناجحة',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: successesByParent.length,
                                    itemBuilder: (context, index) {
                                      final parentPath = successesByParent.keys
                                          .elementAt(index);
                                      final parentSuccesses =
                                          successesByParent[parentPath]!;
                                      final parentName = p.basename(parentPath);

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: ExpansionTile(
                                          leading: Icon(
                                            Icons.folder,
                                            color: Colors.blue,
                                          ),
                                          title: Text(
                                            parentName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'عدد الناجحة: ${parentSuccesses.length}',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                        ),
                                                    child: Text(
                                                      'المسار: $parentPath',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ...parentSuccesses.map(
                                                    (success) => Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green[50],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .green[200]!,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.check_circle,
                                                            size: 16,
                                                            color: Colors.green,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  success
                                                                      .originalName,
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                                if (success
                                                                        .parsedName !=
                                                                    null)
                                                                  Text(
                                                                    'المحول: ${success.parsedName}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .green[700],
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                            // Failures Tab - Grouped by parent folder
                            failures.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد عمليات فاشلة',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: failuresByParent.length,
                                    itemBuilder: (context, index) {
                                      final parentPath = failuresByParent.keys
                                          .elementAt(index);
                                      final parentFailures =
                                          failuresByParent[parentPath]!;
                                      final parentName = p.basename(parentPath);

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: ExpansionTile(
                                          leading: Icon(
                                            Icons.folder,
                                            color: Colors.red,
                                          ),
                                          title: Text(
                                            parentName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'عدد الفاشلة: ${parentFailures.length}',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                        ),
                                                    child: Text(
                                                      'المسار: $parentPath',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ...parentFailures.map((
                                                    failure,
                                                  ) {
                                                    final sanitizedError =
                                                        _sanitizeErrorMessage(
                                                          failure.errorMessage,
                                                        );
                                                    final isLongError =
                                                        sanitizedError.length >
                                                        100;

                                                    return Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red[50],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              Colors.red[200]!,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          // Original Name
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons.folder,
                                                                size: 16,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  'الاسم الأصلي: ${failure.originalName}',
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (failure
                                                                  .parsedName !=
                                                              null) ...[
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.edit,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .orange,
                                                                ),
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    'الاسم المحول: ${failure.parsedName}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .orange[700],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          // Error Message
                                                          Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .error_outline,
                                                                size: 16,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Expanded(
                                                                child: GestureDetector(
                                                                  onTap:
                                                                      isLongError
                                                                      ? () {
                                                                          Get.dialog(
                                                                            Dialog(
                                                                              child: Container(
                                                                                width:
                                                                                    Get.width *
                                                                                    0.8,
                                                                                padding: const EdgeInsets.all(
                                                                                  16,
                                                                                ),
                                                                                child: Column(
                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                  children: [
                                                                                    Text(
                                                                                      'تفاصيل الخطأ',
                                                                                      style: TextStyle(
                                                                                        fontSize: 18,
                                                                                        fontWeight: FontWeight.bold,
                                                                                      ),
                                                                                    ),
                                                                                    const SizedBox(
                                                                                      height: 16,
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: SingleChildScrollView(
                                                                                        child: SelectableText(
                                                                                          sanitizedError,
                                                                                          style: TextStyle(
                                                                                            fontSize: 14,
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                    const SizedBox(
                                                                                      height: 16,
                                                                                    ),
                                                                                    ElevatedButton(
                                                                                      onPressed: () => Get.back(),
                                                                                      child: Text(
                                                                                        'إغلاق',
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }
                                                                      : null,
                                                                  child: Text(
                                                                    sanitizedError,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .red[700],
                                                                    ),
                                                                    maxLines:
                                                                        isLongError
                                                                        ? 2
                                                                        : null,
                                                                    overflow:
                                                                        isLongError
                                                                        ? TextOverflow
                                                                              .ellipsis
                                                                        : null,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (isLongError)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    top: 4,
                                                                  ),
                                                              child: Text(
                                                                'انقر لعرض التفاصيل الكاملة',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .blue,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Close Button
              ElevatedButton(
                onPressed: () => Get.back(),
                child: Text('موافق'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(Get.width * 0.5, 40),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }
*/
  // --- Show results dialog with tabs grouped by parent folder
  Future<void> _showResultsDialog() async {
    // التحقق من وجود مسار المجلد الأب
    if (currentFolderPath.value.isEmpty) {
      _showSnackBar('لم يتم تحديد مسار مجلد الأب', false);
      return;
    }

    final successesData = await _readSuccessesData();
    final failuresData = await _readFailuresData();

    // تصفية النتائج حسب مسار المجلد الأب الحالي فقط
    final allSuccesses = successesData?.successes ?? [];
    final allFailures = failuresData?.failures ?? [];
    
    final successes = allSuccesses.where((record) => 
      record.folderPath.startsWith(currentFolderPath.value) &&
      record.folderPath != currentFolderPath.value // استبعاد مجلد الأب نفسه
    ).toList();
    
    final failures = allFailures.where((record) => 
      record.folderPath.startsWith(currentFolderPath.value) &&
      record.folderPath != currentFolderPath.value // استبعاد مجلد الأب نفسه
    ).toList();

    // Group successes by parent folder
    final successesByParent = <String, List<Record>>{};
    for (final success in successes) {
      final parentPath = _getParentPath(success.folderPath);
      successesByParent.putIfAbsent(parentPath, () => []).add(success);
    }

    // Group failures by parent folder
    final failuresByParent = <String, List<Record>>{};
    for (final failure in failures) {
      final parentPath = _getParentPath(failure.folderPath);
      failuresByParent.putIfAbsent(parentPath, () => []).add(failure);
    }

    final successCount = successes.length;
    final failureCount = failures.length;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: Get.width * 0.9,
          height: Get.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Title
              Text(
                'النتائج',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Tab Bar
              DefaultTabController(
                length: 2,
                child: Expanded(
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('الناجحه'),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$successCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('الفاشله'),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$failureCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Success Tab - Grouped by parent folder
                            successes.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد عمليات ناجحة',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: successesByParent.length,
                                    itemBuilder: (context, index) {
                                      final parentPath = successesByParent.keys
                                          .elementAt(index);
                                      final parentSuccesses =
                                          successesByParent[parentPath]!;
                                      final parentName = p.basename(parentPath);

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: ExpansionTile(
                                          leading: Icon(
                                            Icons.folder,
                                            color: Colors.blue,
                                          ),
                                          title: Text(
                                            parentName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'عدد الناجحة: ${parentSuccesses.length}',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                        ),
                                                    child: Text(
                                                      'المسار: $parentPath',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ...parentSuccesses.map(
                                                    (success) => Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green[50],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .green[200]!,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.check_circle,
                                                            size: 16,
                                                            color: Colors.green,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  success
                                                                      .originalName,
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                                if (success
                                                                        .parsedName !=
                                                                    null)
                                                                  Text(
                                                                    'المحول: ${success.parsedName}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .green[700],
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                            // Failures Tab - Grouped by parent folder
                            failures.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد عمليات فاشلة',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: failuresByParent.length,
                                    itemBuilder: (context, index) {
                                      final parentPath = failuresByParent.keys
                                          .elementAt(index);
                                      final parentFailures =
                                          failuresByParent[parentPath]!;
                                      final parentName = p.basename(parentPath);

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: ExpansionTile(
                                          leading: Icon(
                                            Icons.folder,
                                            color: Colors.red,
                                          ),
                                          title: Text(
                                            parentName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'عدد الفاشلة: ${parentFailures.length}',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                        ),
                                                    child: Text(
                                                      'المسار: $parentPath',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ...parentFailures.map((
                                                    failure,
                                                  ) {
                                                    final sanitizedError =
                                                        _sanitizeErrorMessage(
                                                          failure.errorMessage,
                                                        );
                                                    final isLongError =
                                                        sanitizedError.length >
                                                        100;

                                                    return Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red[50],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              Colors.red[200]!,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          // Original Name
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons.folder,
                                                                size: 16,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  'الاسم الأصلي: ${failure.originalName}',
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (failure
                                                                  .parsedName !=
                                                              null) ...[
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.edit,
                                                                  size: 16,
                                                                  color: Colors
                                                                      .orange,
                                                                ),
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    'الاسم المحول: ${failure.parsedName}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .orange[700],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          // Error Message
                                                          Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .error_outline,
                                                                size: 16,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Expanded(
                                                                child: GestureDetector(
                                                                  onTap:
                                                                      isLongError
                                                                      ? () {
                                                                          Get.dialog(
                                                                            Dialog(
                                                                              child: Container(
                                                                                width:
                                                                                    Get.width *
                                                                                    0.8,
                                                                                padding: const EdgeInsets.all(
                                                                                  16,
                                                                                ),
                                                                                child: Column(
                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                  children: [
                                                                                    Text(
                                                                                      'تفاصيل الخطأ',
                                                                                      style: TextStyle(
                                                                                        fontSize: 18,
                                                                                        fontWeight: FontWeight.bold,
                                                                                      ),
                                                                                    ),
                                                                                    const SizedBox(
                                                                                      height: 16,
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: SingleChildScrollView(
                                                                                        child: SelectableText(
                                                                                          sanitizedError,
                                                                                          style: TextStyle(
                                                                                            fontSize: 14,
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                    const SizedBox(
                                                                                      height: 16,
                                                                                    ),
                                                                                    ElevatedButton(
                                                                                      onPressed: () => Get.back(),
                                                                                      child: Text(
                                                                                        'إغلاق',
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }
                                                                      : null,
                                                                  child: Text(
                                                                    sanitizedError,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .red[700],
                                                                    ),
                                                                    maxLines:
                                                                        isLongError
                                                                        ? 2
                                                                        : null,
                                                                    overflow:
                                                                        isLongError
                                                                        ? TextOverflow
                                                                              .ellipsis
                                                                        : null,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (isLongError)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    top: 4,
                                                                  ),
                                                              child: Text(
                                                                'انقر لعرض التفاصيل الكاملة',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .blue,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Close Button
              ElevatedButton(
                onPressed: () => Get.back(),
                child: Text('موافق'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(Get.width * 0.5, 40),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }
  // --- UI helpers
  void _showSnackBar(String message, bool isSuccess) {
    Get.rawSnackbar(
      title: isSuccess ? 'نجاح' : 'تنبيه',
      message: message,
      backgroundColor: (isSuccess ? Colors.green : Colors.orange).withOpacity(
        0.95,
      ),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: 10,
      duration: const Duration(seconds: 2),
      isDismissible: true,
    );
  }

  void _showPersistentInfo(String message) {
    if (Get.isSnackbarOpen == true) return;
    Get.showSnackbar(
      GetSnackBar(
        title: 'الرجاء الانتظار',
        message: message,
        backgroundColor: Colors.blueGrey.withOpacity(0.95),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: 10,
        duration: const Duration(days: 1),
        isDismissible: false,
      ),
    );
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
      final fileControl = Funcs.form_model!.controls.firstWhereOrNull(
        (c) => c.type == 7,
      );
      if (fileControl == null) return;
      final files = subfolder.listSync().whereType<File>().toList();
      if (files.isEmpty) return;
      final filesList = <Map<String, dynamic>>[];
      int Count = 1;
      for (final file in files) {
        final fullPath = file.path;
        // print(file);
        final fileName = p.basename(fullPath);
        final fileExt = p.extension(fullPath);
        // Get file size
        final int fileSize = await file.length();
        // print(fileName);
        // print(fileExt);
        filesList.add({
          'name': fileName,
          'path': fullPath,
          'base64': fullPath,
          'file_extension': fileExt,
          'row_num': Count,
          'file_realName': fileName,
          'size': fileSize,
        });
        Count++;
      }
      _formController.setValueWithoutValidation(fileControl.id, {
        'files': filesList,
      });
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
  Future<void> _processDateFieldsInValueMap(
    Map<String, dynamic> valueMap,
  ) async {
    // await LogServices.write('[Folder Processing] بدء معالجة valueMap (حذف type من جميع الحقول)');
    // int processedCount = 0;

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
            // processedCount++;

            await LogServices.write(
              '[Folder Processing] تم تحويل حقل التاريخ $key: $dateValue -> $convertedDate',
            );
          } else {
            // للحقول الأخرى، نحذف حقل type فقط ونحتفظ بالقيمة
            final fieldValue = value['value'];
            // استبدال الـ Map بالقيمة فقط (حذف type)
            valueMap[key] = fieldValue;
            // processedCount++;
          }
        }
      }
    }

    // await LogServices.write('[Folder Processing] تم معالجة $processedCount حقل (تم حذف type من جميع الحقول)');
    // await LogServices.write('[Folder Processing] valueMap بعد المعالجة: ${jsonEncode(valueMap)}');
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
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
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

  // دالة مساعدة للتحقق من أخطاء السيرفر في رسالة الخطأ
  bool _isServerError(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return false;
    }
    // التحقق من وجود أخطاء سيرفر شائعة (404, 405, 500, 502, 503, 504, إلخ)
    final serverErrorPattern = RegExp(r'\b(40[0-9]|50[0-9])\b');
    return serverErrorPattern.hasMatch(errorMessage);
  }

  //Retry Pending Folders
  Future<void> _retryPendingFolders() async {
    // Check if stop was requested before starting retry
    if (Funcs.isStopRequested) {
      return;
    }

    // التحقق من أن currentFolderPath موجود
    if (currentFolderPath.value.isEmpty) {
      return;
    }

    final data = await _readFoldersData();
    // فلترة المعلقات التي في نفس مسار مجلد الأب فقط
    final pendingFolders = data.folders
        .where(
          (fd) =>
              !fd.isDeleted &&
              fd.path.startsWith(currentFolderPath.value) &&
              fd.path != currentFolderPath.value && // استبعاد مجلد الأب نفسه
              fd.Status ==
                  ProcessingStatus.Processing.toString().split('.').last &&
              (fd.taskId != null && fd.taskId!.isNotEmpty),
        )
        .toList();

    if (pendingFolders.isEmpty) return;
    // await Get.defaultDialog(
    //   cancel: TextButton(
    //     onPressed: () {
    //       Get.back();
    //       return;
    //     },
    //     child: Text('إلغاء'),
    //   ),
    //   confirm: ElevatedButton(
    //     onPressed: () async {
    //       await _retryPendingFolders();

    //       Get.back();
    //     },
    //     child: Text('موافق'),
    //   ),
    //   title: 'إعادة فحص الملعقات',
    //   middleText: 'هل تريد إعادة فحص المهمات المعلقة؟',
    // );
    
    _showSnackBar('إعادة فحص ${pendingFolders.length} مهمة معلقة...', true);

    final retryDelays = <Duration>[
      const Duration(seconds: 5),
      const Duration(seconds: 15),
      const Duration(seconds: 30),
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
            perAttemptTimeout: Duration(
              seconds: 35 + (attempt * 10),
            ), // ازدياد المهلة مع المحاولات (35 ثانية كحد أدنى)
            shouldStop: () => Funcs.isStopRequested,
          );

          // Check again after polling
          if (Funcs.isStopRequested) {
            return;
          }

          if (check.status == SubmissionStatus.success &&
              check.applyId != null) {
            final applyId = check.applyId!;
            await _updateFolderStatus(
              pf.path,
              ProcessingStatus.Success,
              'تمت المعالجة بعد إعادة الفحص',
              processedAt: DateTime.now(),
            );
            await _saveSuccess(
              Record(
                originalName: pf.name,
                parsedName: pf.name,
                errorMessage: 'تم الرفع والإرسال بنجاح (applyId: $applyId)',
                timestamp: DateTime.now(),
                folderPath: pf.path,
              ),
            );
            successCount.value++;
            resolved = true;
            break;
          }

          if (check.status == SubmissionStatus.pending) {
            lastErrorMessage = 'ما زال قيد الانتظار (attempt ${attempt + 1})';
            await _updateFolderStatus(
              pf.path,
              ProcessingStatus.Processing,
              lastErrorMessage,
              attempts: pf.attempts + 1,
              taskId: pf.taskId,
            );
            continue;
          }

          if (check.status == SubmissionStatus.error) {
            lastErrorMessage =
                check.errorMessage ?? 'خطأ غير معروف أثناء الفحص';
            
            // التحقق من وجود خطأ سيرفر وإعادة الإرسال
            if (_isServerError(check.errorMessage)) {
              try {
                _showSnackBar(
                  'تم اكتشاف خطأ سيرفر (${check.errorMessage}) - إعادة إرسال المجلد ${pf.name}...',
                  true,
                );
                
                // التحقق من وجود المجلد
                final folderDir = Directory(pf.path);
                if (!await folderDir.exists()) {
                  lastErrorMessage = 'المجلد غير موجود: ${pf.path}';
                  continue;
                }
                
                // إعادة معالجة المجلد من جديد
                final result = await _processSingleSubfolderWrapped(folderDir);
                
                // التحقق من النتيجة
                if (result.status == ProcessingStatus.Success) {
                  final applyId = result.applyId;
                  await _updateFolderStatus(
                    pf.path,
                    ProcessingStatus.Success,
                    'تمت المعالجة بعد إعادة الإرسال بسبب خطأ سيرفر',
                    processedAt: DateTime.now(),
                  );
                  await _saveSuccess(
                    Record(
                      originalName: pf.name,
                      parsedName: pf.name,
                      errorMessage: 'تم الرفع والإرسال بنجاح بعد إعادة الإرسال بسبب خطأ سيرفر${applyId != null ? " (applyId: $applyId)" : ""}',
                      timestamp: DateTime.now(),
                      folderPath: pf.path,
                    ),
                  );
                  successCount.value++;
                  resolved = true;
                  break; // نجحت المعالجة، اخرج من الحلقة
                } else if (result.status == ProcessingStatus.Processing ||
                    result.status == ProcessingStatus.Pending) {
                  // تم إرسال الطلب بنجاح ولكن ما زال قيد الانتظار
                  lastErrorMessage = 'تم إعادة الإرسال - قيد الانتظار';
                  await _updateFolderStatus(
                    pf.path,
                    ProcessingStatus.Processing,
                    lastErrorMessage,
                    attempts: pf.attempts + 1,
                  );
                  // استمر في المحاولات للتحقق من النتيجة
                  continue;
                } else {
                  // فشلت إعادة المعالجة
                  lastErrorMessage =
                      'فشلت إعادة الإرسال: ${result.errorMessage ?? "خطأ غير معروف"}';
                  continue;
                }
              } catch (e) {
                Funcs.errors.add('خطأ في إعادة إرسال المجلد بسبب خطأ سيرفر: $e');
                lastErrorMessage = 'خطأ في إعادة الإرسال: $e';
                continue;
              }
            } else {
              // ليس خطأ سيرفر، استمر في المحاولات العادية
              continue;
            }
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
        Funcs.errors.add(
          'لم تصل نتيجة بعد ${maxAttempts} محاولات؛ يتم ختم المعالجة بتاريخ الآن',
        );
        final msg =
            'لم تصل نتيجة بعد ${maxAttempts} محاولات؛ يتم ختم المعالجة بتاريخ الآن';
        await _updateFolderStatus(
          pf.path,
          ProcessingStatus.Error,
          msg,
          processedAt: DateTime.now(),
        );
        failureCount.value++;
        await _saveFailure(
          Record(
            originalName: pf.name,
            parsedName: pf.name,
            errorMessage:
                msg +
                (lastErrorMessage.isNotEmpty
                    ? ' — last: $lastErrorMessage'
                    : ''),
            timestamp: DateTime.now(),
            folderPath: pf.path,
          ),
        );
        final stop = await Funcs.checkRepeatingErrors();
        if (stop) {
          updateUIAfterStopeing();
          return; // Exit early when stop is requested
        }
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    // تحديث عدد المعلقات بعد إعادة الفحص
    await _updatePendingCount();
  }

  void updateUIAfterStopeing() {
    // Don't reset stop flag here - it should remain set until a new process starts
    // This ensures any remaining checks will see the stop flag
    _hidePersistentSnack();
    _closePreviewDialogIfAny();
    isProcessing.value = false;
    
    _showSnackBar('تم إيقاف المعالجة حسب الطلب', false);
    //  Get.reloadAll(force: true);
  }
}
