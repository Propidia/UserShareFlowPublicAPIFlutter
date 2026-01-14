import 'dart:convert';
import 'dart:io';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'package:useshareflowpublicapiflutter/config.dart';
import 'package:useshareflowpublicapiflutter/help/funcs.dart';
import 'package:useshareflowpublicapiflutter/help/log.dart';
import 'package:useshareflowpublicapiflutter/models/form_models.dart';
import 'package:uuid/uuid.dart';

class MinIOClass {
  // -- الإعدادات الأساسية --
  // هذه هي معلومات الاتصال بخادم MinIO الخاص بك
  // (سواء كان على جهازك المحلي أو على خادم الإنتاج)
  Minio _minio = Minio(
    endPoint: AppConfig.minio_end_point, // e.g., 'localhost' or '192.168.1.10'
    port: AppConfig.minio_port,
    accessKey: AppConfig.minio_access_key,
    secretKey: AppConfig.minio_secret_key,
    useSSL:
        AppConfig.minio_use_ssl, // Set to true if you configured Nginx with SSL
  );
  final bucketName = "applys";

  /// ## الدالة الرئيسية لرفع الملفات بكفاءة
  ///
  /// هذه الدالة ترفع ملفًا من مسار معين إلى MinIO.
  /// إنها تستخدم `fPutObject` التي تقوم ببث الملف مباشرة من القرص،
  /// مما يجعلها مثالية للملفات الكبيرة جدًا.
  ///
  /// @param filePath المسار الكامل للملف على الجهاز (e.g., 'C:/path/to/your_large_file.json').
  /// @param objectName اسم الملف كما سيظهر في MinIO (e.g., 'migration/data_batch_1.json').
  /// @return String مفتاح الكائن (objectName) في حالة النجاح.
  Future<(String, String)> uploadFileToMinIO(
    String filePath,
    String objectName,
    String folderName,
  ) async {
    String res = "success";
    String folder_name = 'Folder Name';
    try {
      print('Checking if bucket "$bucketName" exists...');

      // تحقق من وجود الـ Bucket قبل الرفع (ممارسة جيدة)
      bool found = await _minio.bucketExists(bucketName);
      if (!found) {
        // إذا لم يكن موجودًا، يمكنك إنشاؤه أو إظهار خطأ
        await _minio.makeBucket(bucketName);
        print('Bucket "$bucketName" created.');
      }

      // تأكيد المسار المحلي الصحيح
      String localPath = (filePath).trim();
      if (!File(localPath).existsSync()) {
        // جرّب إلحاق مسار التخزين الخارجي
        try {
          final alt = localPath;
          if (File(alt).existsSync()) {
            localPath = alt;
          }
        } catch (_) {}
      }

      if (!File(localPath).existsSync()) {
        res = "Local file not found: " + localPath;
      }

      print('Starting upload for: ' + localPath);

      // -- هنا يكمن السر --
      // fPutObject => File Put Object
      // هذه الدالة تقرأ الملف كـ "بث" (stream) وترسله مباشرة.
      // استهلاك الذاكرة هنا شبه معدوم، حتى لو كان الملف بحجم 10 جيجابايت.
      String platform = 'win';
      if (Platform.isAndroid) {
        platform = 'and';
      } else if (Platform.isFuchsia) {
        platform = 'web';
      } else if (Platform.isWindows) {
        platform = 'win';
      }

      folder_name =
          '${DateTime.now().millisecondsSinceEpoch.toString()}z${platform}z${Funcs.form_id.toString()}';
      res = await _minio.fPutObject(
        bucketName,
        '{$folderName + "/" + $folder_name}',
        localPath,
      );
      print('✅ Upload successful! Res: $res');

      print('✅ Upload successful! Object name: $objectName');

      // أرجع اسم الكائن لأنه هو المعرف الذي سترسله إلى الـ API
      // res = "success";
    } catch (e) {
      print('❌ An error occurred during upload: $e');
      res = e.toString();
      // في تطبيق حقيقي، يجب عليك معالجة هذا الخطأ بشكل أفضل
      // (e.g., showing a message to the user, logging the error)
    } finally {
      return (res, folder_name);
    }
  }

  Future<(String, String)> uploadFormFilesToMinIOValues(
    Map<int, dynamic> formControlsValues,
    String folderName, {
    Map<String, dynamic>? completePayload,
    FormStructureModel? formStructure,
  }) async {
    String res = "success";
    String folder_name = 'noFolder';
    try {
      // await LogServices.write('[MinIO] Using bucket: $bucketName, prefix: $folderName');
      print('Using bucket: $bucketName, prefix: $folderName');
      // await LogServices.write('[MinIO] formControlsValues keys: ${formControlsValues.keys.toList()}');
      print('formControlsValues keys: ${formControlsValues.keys.toList()}');

      // Log تفصيلي لكل control
      formControlsValues.forEach((controlId, value) {
        final valueType = value.runtimeType;
        final valueStr = value is Map ? jsonEncode(value) : value.toString();
        // LogServices.write('[MinIO] formControlsValues[$controlId]: type=$valueType, value=$valueStr');
        print(
          'formControlsValues[$controlId]: type=$valueType, value=$valueStr',
        );
      });

      // تحقق أو أنشئ الـ Bucket
      bool found = await _minio.bucketExists(bucketName);
      if (!found) {
        await _minio.makeBucket(bucketName);
        // await LogServices.write('[MinIO] Bucket "$bucketName" created.');
        print('Bucket "$bucketName" created.');
      }

      // جمع الملفات من values مع تتبع الفهرس لضمان تعديل العنصر الصحيح
      final List<Map<String, dynamic>> filesToUpload = <Map<String, dynamic>>[];
      for (final entry in formControlsValues.entries) {
        final controlId = entry.key;
        final value = entry.value;

        LogServices.write(
          '[MinIO] Processing controlId $controlId, value type: ${value.runtimeType}',
        );
        print(
          'Processing controlId $controlId, value type: ${value.runtimeType}',
        );

        // 🚨 نقطة التصحيح الرئيسية: يجب أن تكون القيمة خريطة تحتوي على 'files'
        if (value is! Map<String, dynamic>) {
          final msg =
              '⚠️ Skipping controlId $controlId: value is not a Map (${value.runtimeType})';
          // LogServices.write('[MinIO] $msg');
          print(msg);
          continue;
        }

        // LogServices.write('[MinIO] controlId $controlId value keys: ${(value as Map).keys.toList()}');
        print(
          'controlId $controlId value keys: ${(value as Map).keys.toList()}',
        );

        final dynamic files = value['files'];

        if (files == null) {
          final msg =
              '⚠️ Skipping controlId $controlId: no files key. Available keys: ${value.keys.toList()}';
          // LogServices.write('[MinIO] $msg');
          print(msg);
          continue;
        }

        LogServices.write(
          '[MinIO] controlId $controlId files type: ${files.runtimeType}, files length: ${files is List ? files.length : 'N/A'}',
        );
        print(
          'controlId $controlId files type: ${files.runtimeType}, files length: ${files is List ? files.length : 'N/A'}',
        );

        if (files is! List) {
          // يتم تسجيل هذه الرسالة إذا كانت قيمة 'files' هي 'String' مثلاً
          final msg =
              '⚠️ Skipping controlId $controlId: files is not a List (${files.runtimeType})';
          // LogServices.write('[MinIO] $msg');
          print(msg);
          continue;
        }

        LogServices.write(
          '[MinIO] Found ${files.length} files in controlId $controlId',
        );
        print('Found ${files.length} files in controlId $controlId');

        for (int i = 0; i < files.length; i++) {
          final dynamic f = files[i];
          LogServices.write(
            '[MinIO] Processing file[$i] in controlId $controlId, type: ${f.runtimeType}',
          );
          print(
            'Processing file[$i] in controlId $controlId, type: ${f.runtimeType}',
          );

          // تسجيل معلومات إضافية عن الملف
          if (f is Map<String, dynamic>) {
            final filePath = f['base64'] as String?;
            final fileName = f['name'] as String?;
            await LogServices.write(
              '[MinIO] File details - name: $fileName, path: $filePath',
            );
          }

          if (f is! Map<String, dynamic>) {
            final msg = '⚠️ Skipping file[$i]: not a Map (${f.runtimeType})';
            // LogServices.write('[MinIO] $msg');
            print(msg);
            continue;
          }

          // LogServices.write('[MinIO] file[$i] keys: ${(f as Map).keys.toList()}, base64: ${f['base64']}, name: ${f['name']}');
          print(
            'file[$i] keys: ${(f as Map).keys.toList()}, base64: ${f['base64']}, name: ${f['name']}',
          );

          // إضافة الملف مباشرة لقائمة الرفع
          filesToUpload.add({'file': f, 'values': value, 'fileIndex': i});
          print('✅ Added file to upload queue: ${f['name']}');
        }
      }

      await LogServices.write(
        '[MinIO] Found ${filesToUpload.length} files to upload',
      );
      print('Found ${filesToUpload.length} files to upload');

      // تسجيل تفاصيل الملفات التي سيتم رفعها
      if (filesToUpload.isEmpty) {
        await LogServices.write(
          '[MinIO] ⚠️ No files to upload - all files were either already uploaded or skipped',
        );
        print('⚠️ Warning: No files to upload');
      }

      // توليد اسم مجلد رئيسي واحد للدفعة
      String platform = 'win';
      if (Platform.isAndroid)
        platform = 'and';
      else if (Platform.isFuchsia)
        platform = 'web';
      else if (Platform.isWindows)
        platform = 'win';
      else if (Platform.isLinux)
        platform = 'lin';
      else if (Platform.isIOS)
        platform = 'ios';
      else if (Platform.isMacOS)
        platform = 'mac';
      // يُفترض أن Funcs.form_id مُعرّف ومتاح
      folder_name =
          '${DateTime.now().millisecondsSinceEpoch}z${platform}z${Funcs.form_id}';

      int uploadedCount = 1;
      int errorCount = 0;
      final uuid = Uuid(); // يُفترض أن Uuid مُعرف ومتاح

      // رفع الملفات
      for (final item in filesToUpload) {
        final Map<String, dynamic> file = item['file'] as Map<String, dynamic>;
        final Map<String, dynamic> values =
            item['values'] as Map<String, dynamic>;
        final int? fileIndex = item['fileIndex'] as int?;
        try {
          final String filePath = (file['base64'] as String).trim();
          final f = File(filePath);

          // التحقق من وجود الملف مع معالجة أفضل لمسارات الشبكة
          bool fileExists = false;
          try {
            fileExists = f.existsSync();
          } catch (e) {
            // محاولة بديلة للتحقق من مسارات الشبكة
            try {
              await f.length(); // إذا نجح، الملف موجود
              fileExists = true;
            } catch (_) {
              fileExists = false;
            }
          }

          if (!fileExists) {
            print('⚠️ File not found or inaccessible: $filePath');
            await LogServices.write('[MinIO] ⚠️ File not found: $filePath');
            continue;
          }

          // Get file size
          final int fileSize = await f.length();

          String fileExtension = 'bin';
          final String? originalName = file['name'] as String?;
          if (originalName != null && originalName.contains('.')) {
            fileExtension = originalName.split('.').last;
          }

          final String uniqueFileName = '${uuid.v4()}.$fileExtension';

          // دائماً نستخدم folder_name المولد (مثل 1762487151588zwinz161) كمسار أساسي
          // هذا هو نفس المجلد الذي سيحتوي على ملف JSON
          final String objectPath = '$folder_name/$uniqueFileName';

          await LogServices.write(
            '[MinIO] 📤 Uploading: ${file['name']} as $uniqueFileName to $objectPath',
          );
          print(
            '📤 Uploading: ${file['name']} as $uniqueFileName to $objectPath',
          );

          await _minio.fPutObject(bucketName, objectPath, filePath);

          // base64 يحتوي على اسم الملف UUID مع الصيغة فقط
          final String uuidPath = uniqueFileName;
          // file و path يحتويان على المسار الكامل في MinIO (folder_name/uuid.ext)
          final String fullMinIOPath = objectPath;

          // تحديث قيمة الملف في الخريطة الأصلية (formControlsValues)
          final dynamic filesList = values['files'];

          if (fileIndex != null &&
              filesList is List &&
              fileIndex >= 0 &&
              fileIndex < filesList.length) {
            final dynamic entry = filesList[fileIndex];
            if (entry is Map<String, dynamic>) {
              entry['base64'] = fullMinIOPath;
              entry['path'] = fullMinIOPath;
              entry['file_extension'] = fileExtension;
              entry['status'] = "added";
              entry['row_num'] = uploadedCount;
              entry['file_realName'] = file['file_realName'];
              entry['size'] = fileSize;

              print(
                'entry updated: base64=$fullMinIOPath, path=$fullMinIOPath, file_extension=$fileExtension, size=$fileSize',
              );
            }
          } else {
            file['base64'] = uuidPath;
            file['path'] = fullMinIOPath;
            file['file_extension'] = fileExtension;
            file['status'] = "added";
            file['row_num'] = uploadedCount;
            file['file_realName'] = file['file_realName'];
            file['size'] = fileSize;

            print(
              'entry updated: base64=$fullMinIOPath, path=$fullMinIOPath, file_extension=$fileExtension, size=$fileSize',
            );
          }

          // values['foldername'] = folder_name; // حفظ اسم المجلد في بيانات التحكم
          uploadedCount += 1;
          await LogServices.write(
            '[MinIO] ✅ Uploaded successfully: $uuidPath -> $objectPath',
          );
          print('  ✅ Uploaded successfully: $uuidPath -> $objectPath');
        } catch (e) {
          final String fileName = file['name'] ?? 'unknown';
          final String filePathForLog =
              (file['base64'] as String?)?.trim() ?? 'unknown path';
          final errorMsg =
              '❌ Failed to upload $fileName from path: $filePathForLog - Error: $e';
          await LogServices.write('[MinIO] $errorMsg');
          print('  $errorMsg');

          // تسجيل تفاصيل إضافية للتشخيص
          if (e.toString().contains('FileSystemException') ||
              e.toString().contains('not found')) {
            await LogServices.write(
              '[MinIO] 🔍 File access error - Path may be network share or inaccessible',
            );
            print(
              '  🔍 Hint: Check network path accessibility: $filePathForLog',
            );
          }

          errorCount += 1;
        }
      }

      if (uploadedCount > 0) {
        res = 'success';
      } else if (errorCount > 0) {
        res = 'no files uploaded';
      } else if (filesToUpload.isEmpty) {
        res = 'no files found to upload';
      }

      // إنشاء ملف JSON - بناء JSON كامل يشبه ما يتوقعه الـ worker
      try {
        //   print('📝 إنشاء ملف JSON بالبيانات...');
        Map<String, dynamic> jsonDataToSave;

        if (completePayload != null) {
          // استخدام الـ payload الكامل الممرر من buildSubmitPayload
          jsonDataToSave = Map<String, dynamic>.from(completePayload);
          // تحديث foldername في الـ payload
          jsonDataToSave['foldername'] = folder_name;
          // تنظيف البيانات قبل الحفظ
          jsonDataToSave = _cleanCompletePayloadForJson(jsonDataToSave);
        } else {
          // الطريقة القديمة: استخدام formControlsValues فقط
          final cleanData = <String, dynamic>{};
          formControlsValues.forEach((key, value) {
            // التأكد من أن قيمة value هي Map قبل محاولة تنظيفها
            if (value is Map<String, dynamic>) {
              cleanData[key.toString()] = _cleanMapForJson(value);
            } else {
              cleanData[key.toString()] = value;
            }
          });
          jsonDataToSave = cleanData;
        }
      } catch (jsonError) {
        print('⚠️ تحذير: فشل إنشاء ملف JSON: $jsonError');
      }

      print(
        '✅ All files processed successfully! Uploaded count: $uploadedCount',
      );
    } catch (e) {
      print('❌ Error in uploadFormFilesToMinIOValues: ' + e.toString());
      res = e.toString();
    }

    return (res, folder_name);
  }

  Map<String, dynamic> _cleanMapForJson(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};

    data.forEach((key, value) {
      // تخطي local_path لأنه مسار محلي
      if (key == 'local_path') return;

      if (value == null) {
        cleaned[key] = null;
      } else if (value is String || value is num || value is bool) {
        cleaned[key] = value;
      } else if (value is List) {
        cleaned[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _cleanMapForJson(item);
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        cleaned[key] = _cleanMapForJson(value);
      } else {
        // تحويل أي شيء آخر إلى String
        cleaned[key] = value.toString();
      }
    });

    return cleaned;
  }

  /// تنظيف الـ payload الكامل قبل رفعه إلى MinIO
  /// يزيل local_path والبيانات غير القابلة للتحويل
  Map<String, dynamic> _cleanCompletePayloadForJson(
    Map<String, dynamic> payload,
  ) {
    final cleaned = <String, dynamic>{};

    payload.forEach((key, value) {
      if (value == null) {
        cleaned[key] = null;
      } else if (value is String || value is num || value is bool) {
        cleaned[key] = value;
      } else if (value is List) {
        cleaned[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _cleanMapForJson(item);
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        cleaned[key] = _cleanMapForJson(value);
      } else {
        // تحويل أي شيء آخر إلى String
        cleaned[key] = value.toString();
      }
    });

    return cleaned;
  }

  Future<String> testConnection() async {
    try {
      print('🔄 بدء اختبار الاتصال بخادم MinIO...');

      // محاولة الاتصال والتحقق من وجود الـ Bucket
      bool bucketExists = await _minio.bucketExists(bucketName);

      if (bucketExists) {
        print('✅ تم العثور على الـ Bucket: $bucketName');
        return 'success';
      } else {
        print('⚠️ الـ Bucket غير موجود، محاولة إنشاؤه...');

        // محاولة إنشاء الـ Bucket للتأكد من صلاحيات الكتابة
        await _minio.makeBucket(bucketName);
        print('✅ تم إنشاء الـ Bucket بنجاح: $bucketName');
        return 'success';
      }
    } catch (e) {
      print('❌ فشل الاتصال: $e');

      // تحديد نوع الخطأ وإرجاع رسالة مناسبة
      String errorMessage = e.toString().toLowerCase();
      if (Platform.isLinux) {
        throw Exception("TaskParsingException: ${e.toString()}");
      }
      if (errorMessage.contains('connection') ||
          errorMessage.contains('network') ||
          errorMessage.contains('timeout')) {
        return errorMessage;
      } else if (errorMessage.contains('access') ||
          errorMessage.contains('credential') ||
          errorMessage.contains('unauthorized') ||
          errorMessage.contains('forbidden')) {
        return errorMessage;
      } else if (errorMessage.contains('bucket')) {
        return errorMessage;
      } else {
        return errorMessage;
      }
    }
  }
}
