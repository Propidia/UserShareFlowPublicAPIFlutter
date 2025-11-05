import 'dart:convert';
import 'dart:io';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:useshareflowpublicapiflutter/config.dart';
import 'package:useshareflowpublicapiflutter/help/funcs.dart';
import 'package:useshareflowpublicapiflutter/models/form_models.dart';
import 'package:useshareflowpublicapiflutter/models/storage_models.dart';
// ملاحظة: لا حاجة حالياً لاستيراد نماذج النموذج/التخزين هنا
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
    useSSL: AppConfig.minio_use_ssl, // Set to true if you configured Nginx with SSL
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
  Future<(String,String)> uploadFileToMinIO(
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
      if(Platform.isAndroid){
        platform = 'and';
      }
      else if(Platform.isFuchsia){
        platform = 'web';
      }
      else if(Platform.isWindows){
        platform = 'win';
      }

      folder_name ='${DateTime.now().millisecondsSinceEpoch.toString()}z${platform}z${Funcs.form_id.toString()}';
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
      return (res , folder_name);
    }
  }

/* Future<(String, String)> uploadFormFilesToMinIOValues(
  Map<int, dynamic> formControlsValues,
  String folderName,
) async {
  String res = "success";
  String folder_name = 'noFolder';
  try {
    print('Using bucket: $bucketName, prefix: $folderName');

    // تحقق أو أنشئ الـ Bucket
    bool found = await _minio.bucketExists(bucketName);
    if (!found) {
      await _minio.makeBucket(bucketName);
      print('Bucket "$bucketName" created.');
    }

    // جمع الملفات من values مع تتبع الفهرس لضمان تعديل العنصر الصحيح عند وجود أكثر من ملف
    final List<Map<String, dynamic>> filesToUpload = <Map<String, dynamic>>[];
    formControlsValues.forEach((controlId, value) {
      if (value is! Map<String, dynamic>) {
        print('⚠️ Skipping controlId $controlId: value is not a Map (${value.runtimeType})');
        return;
      }

      final dynamic files = value['files'];
      if (files == null) {
        print('⚠️ Skipping controlId $controlId: no files key');
        return;
      }

      if (files is! List) {
        print('⚠️ Skipping controlId $controlId: files is not a List (${files.runtimeType})');
        return;
      }

      for (int i = 0; i < files.length; i++) {
        final dynamic f = files[i];
        if (f is! Map<String, dynamic>) {
          print('⚠️ Skipping file[$i]: not a Map (${f.runtimeType})');
          continue;
        }

        // التحقق من أن الملف لم يتم رفعه مسبقاً
        final String? base64Value = (f['base64'] as String?)?.trim();
        final bool alreadyUploaded = base64Value != null &&
            (base64Value.contains('-') || value['foldername'] != null);

        if (alreadyUploaded) {
          print('⏭️ Skipping already uploaded file: ${f['name']} (base64: $base64Value)');
          continue;
        }

        final String? candidate = (f['base64'] as String?)?.trim();
        final bool looksRemote = candidate != null &&
            (candidate.startsWith('http://') || candidate.startsWith('https://'));
        final bool isLocal = candidate != null && candidate.isNotEmpty && !looksRemote && File(candidate).existsSync();
        if (isLocal) {
          filesToUpload.add({'file': f, 'values': value, 'fileIndex': i});
        }
      }
    });

    print('Found ${filesToUpload.length} files to upload');

    // توليد اسم مجلد رئيسي واحد للدفعة
    String platform = 'win';
    if (Platform.isAndroid) platform = 'and';
    else if (Platform.isFuchsia) platform = 'web';
    else if (Platform.isWindows) platform = 'win';
    else if (Platform.isLinux) platform = 'lin';
    else if (Platform.isIOS) platform = 'ios';
    else if (Platform.isMacOS) platform = 'mac';
    folder_name = '${DateTime.now().millisecondsSinceEpoch}z${platform}z${Funcs.form_id}';

    int uploadedCount = 0;
    int errorCount = 0;
    final uuid = Uuid();

    // رفع الملفات
    for (final item in filesToUpload) {
      final Map<String, dynamic> file = item['file'] as Map<String, dynamic>;
      final Map<String, dynamic> values = item['values'] as Map<String, dynamic>;
      final int? fileIndex = item['fileIndex'] as int?;
      try {
        final String filePath = (file['base64'] as String).trim();
        final f = File(filePath);
        if (!f.existsSync()) {
          print('⚠️ File not found: ' + filePath);
          continue;
        }

        String fileExtension = 'bin';
        final String? originalName = file['name'] as String?;
        if (originalName != null && originalName.contains('.')) {
          fileExtension = originalName.split('.').last;
        }

        final String uniqueFileName = '${uuid.v4()}.$fileExtension';
        final String objectPath = folder_name + '/' + uniqueFileName;

        print('📤 Uploading: ${file['name']} as ' + uniqueFileName);

        await _minio.fPutObject(
          bucketName,
          objectPath,
          filePath,
        );

        final String uuidPath = uniqueFileName;

        final dynamic filesList = values['files'];
        if (fileIndex != null &&
            filesList is List &&
            fileIndex >= 0 &&
            fileIndex < filesList.length) {
          final dynamic entry = filesList[fileIndex];
          if (entry is Map<String, dynamic>) {
            entry['base64'] = uuidPath;
          }
        } else {
          file['base64'] = uuidPath;
        }

        file['path'] = objectPath;
        values['foldername'] = folder_name;

        uploadedCount += 1;
        print('  ✅ Uploaded successfully: ' + uuidPath);
      } catch (e) {
        print('  ❌ Failed to upload ${file['name']}: ' + e.toString());
        errorCount += 1;
      }
    }

    if (uploadedCount > 0) {
      res = 'success';
    } else if (errorCount > 0) {
      res = 'no files uploaded';
    }

    // إنشاء ملف JSON
    try {
      print('📝 إنشاء ملف JSON بالبيانات...');
      final cleanData = <String, dynamic>{};
      formControlsValues.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          cleanData[key.toString()] = _cleanMapForJson(value);
        } else {
          cleanData[key.toString()] = value;
        }
      });

      final jsonData = jsonEncode(cleanData);
      final tempDir = await getTemporaryDirectory();
      final jsonFile = File('${tempDir.path}/$folder_name.json');
      await jsonFile.writeAsString(jsonData, encoding: utf8);

      final jsonObjectPath = '$folder_name/$folder_name.json';
      await _minio.fPutObject(bucketName, jsonObjectPath, jsonFile.path);
      print('✅ تم رفع ملف JSON بنجاح: $jsonObjectPath');
      await jsonFile.delete();
    } catch (jsonError) {
      print('⚠️ تحذير: فشل إنشاء ملف JSON: $jsonError');
    }

    print('✅ All files uploaded successfully!');
  } catch (e) {
    print('❌ Error in uploadFormFilesToMinIOValues: ' + e.toString());
    res = e.toString();
  }

  return (res, folder_name);
}
 */
  /// نسخة تعتمد على values مباشرة لتجنب الاعتماد على ControlModel.files

// يُفترض استيراد Minio هنا
// يُفترض استيراد Uuid هنا
// يُفترض استيراد getTemporaryDirectory هنا

// ملاحظة: يجب تعريف bucketName و _minio و Funcs و SubmissionService
// و _cleanMapForJson في نطاق يمكن الوصول إليه.

// مثال تعريفي (يجب استبداله بالتعريف الفعلي في مشروعك)
// const String bucketName = 'your-bucket-name';
// final Minio _minio = Minio(endPoint: '...'); 
// Map<String, dynamic> _cleanMapForJson(Map<String, dynamic> map) => map; 

Future<(String, String)> uploadFormFilesToMinIOValues(
    Map<int, dynamic> formControlsValues,
    String folderName,
) async {
  String res = "success";
  String folder_name = 'noFolder';
  try {
    print('Using bucket: $bucketName, prefix: $folderName');

    // تحقق أو أنشئ الـ Bucket
    bool found = await _minio.bucketExists(bucketName);
    if (!found) {
      await _minio.makeBucket(bucketName);
      print('Bucket "$bucketName" created.');
    }

    // جمع الملفات من values مع تتبع الفهرس لضمان تعديل العنصر الصحيح
    final List<Map<String, dynamic>> filesToUpload = <Map<String, dynamic>>[];
    formControlsValues.forEach((controlId, value) {
      
      // 🚨 نقطة التصحيح الرئيسية: يجب أن تكون القيمة خريطة تحتوي على 'files'
      if (value is! Map<String, dynamic>) {
        print('⚠️ Skipping controlId $controlId: value is not a Map (${value.runtimeType})');
        return;
      }

      final dynamic files = value['files'];
      
      if (files == null) {
        print('⚠️ Skipping controlId $controlId: no files key');
        return;
      }

      if (files is! List) {
        // يتم تسجيل هذه الرسالة إذا كانت قيمة 'files' هي 'String' مثلاً
        print('⚠️ Skipping controlId $controlId: files is not a List (${files.runtimeType})');
        return;
      }

      for (int i = 0; i < files.length; i++) {
        final dynamic f = files[i];
        if (f is! Map<String, dynamic>) {
          print('⚠️ Skipping file[$i]: not a Map (${f.runtimeType})');
          continue;
        }

        // التحقق من أن الملف لم يتم رفعه مسبقاً (base64 لم يتم تحديثه إلى UUID أو foldername موجود)
        final String? base64Value = (f['base64'] as String?)?.trim();
        final bool alreadyUploaded = base64Value != null &&
            (base64Value.contains('-') || value['foldername'] != null);

        if (alreadyUploaded) {
          print('⏭️ Skipping already uploaded file: ${f['name']} (base64: $base64Value)');
          continue;
        }

        final String? candidate = (f['base64'] as String?)?.trim();
        final bool looksRemote = candidate != null &&
            (candidate.startsWith('http://') || candidate.startsWith('https://'));
        
        // التحقق من أن القيمة هي مسار محلي موجود للملف
        final bool isLocal = candidate != null && candidate.isNotEmpty && !looksRemote && File(candidate).existsSync();
        if (isLocal) {
          filesToUpload.add({'file': f, 'values': value, 'fileIndex': i});
        }
      }
    });

    print('Found ${filesToUpload.length} files to upload');

    // توليد اسم مجلد رئيسي واحد للدفعة
    String platform = 'win';
    if (Platform.isAndroid) platform = 'and';
    else if (Platform.isFuchsia) platform = 'web';
    else if (Platform.isWindows) platform = 'win';
    else if (Platform.isLinux) platform = 'lin';
    else if (Platform.isIOS) platform = 'ios';
    else if (Platform.isMacOS) platform = 'mac';
    // يُفترض أن Funcs.form_id مُعرّف ومتاح
    folder_name = '${DateTime.now().millisecondsSinceEpoch}z${platform}z${Funcs.form_id}';

    int uploadedCount = 0;
    int errorCount = 0;
    final uuid = Uuid(); // يُفترض أن Uuid مُعرف ومتاح

    // رفع الملفات
    for (final item in filesToUpload) {
      final Map<String, dynamic> file = item['file'] as Map<String, dynamic>;
      final Map<String, dynamic> values = item['values'] as Map<String, dynamic>;
      final int? fileIndex = item['fileIndex'] as int?;
      try {
        final String filePath = (file['base64'] as String).trim();
        final f = File(filePath);
        if (!f.existsSync()) {
          print('⚠️ File not found: ' + filePath);
          continue;
        }

        String fileExtension = 'bin';
        final String? originalName = file['name'] as String?;
        if (originalName != null && originalName.contains('.')) {
          fileExtension = originalName.split('.').last;
        }

        final String uniqueFileName = '${uuid.v4()}.$fileExtension';
        final String objectPath = folder_name + '/' + uniqueFileName;

        print('📤 Uploading: ${file['name']} as ' + uniqueFileName);

        await _minio.fPutObject(
          bucketName,
          objectPath,
          filePath,
        );

        final String uuidPath = uniqueFileName;

        // تحديث قيمة الملف في الخريطة الأصلية (formControlsValues)
        final dynamic filesList = values['files'];
        if (fileIndex != null &&
            filesList is List &&
            fileIndex >= 0 &&
            fileIndex < filesList.length) {
          final dynamic entry = filesList[fileIndex];
          if (entry is Map<String, dynamic>) {
            entry['base64'] = uuidPath; // تحديث المسار إلى UUID الجديد
            print('entry: $entry');
          }
        } else {
          file['base64'] = uuidPath; // تحديث المسار في حالته الفردية
          print('file: $file');
        }

        file['path'] = objectPath;
        values['foldername'] = folder_name; // حفظ اسم المجلد في بيانات التحكم
        print('file: $file');
        uploadedCount += 1;
        print('  ✅ Uploaded successfully: ' + uuidPath);
      } catch (e) {
        print('  ❌ Failed to upload ${file['name']}: ' + e.toString());
        errorCount += 1;
      }
    }

    if (uploadedCount > 0) {
      res = 'success';
    } else if (errorCount > 0) {
      res = 'no files uploaded';
    }

    // إنشاء ملف JSON
    try {
      print('📝 إنشاء ملف JSON بالبيانات...');
      final cleanData = <String, dynamic>{};
      formControlsValues.forEach((key, value) {
        // التأكد من أن قيمة value هي Map قبل محاولة تنظيفها
        if (value is Map<String, dynamic>) {
          cleanData[key.toString()] = _cleanMapForJson(value); 
        } else {
          cleanData[key.toString()] = value;
        }
      });

      final jsonData = jsonEncode(cleanData);
      final tempDir = await getTemporaryDirectory(); // يُفترض أن getTemporaryDirectory مُعرّف
      final jsonFile = File('${tempDir.path}/$folder_name.json');
      await jsonFile.writeAsString(jsonData, encoding: utf8);

      final jsonObjectPath = '$folder_name/$folder_name.json';
      await _minio.fPutObject(bucketName, jsonObjectPath, jsonFile.path);
      print('✅ تم رفع ملف JSON بنجاح: $jsonObjectPath');
      await jsonFile.delete();
    } catch (jsonError) {
      print('⚠️ تحذير: فشل إنشاء ملف JSON: $jsonError');
    }

    print('✅ All files processed successfully! Uploaded count: $uploadedCount');
  } catch (e) {
    print('❌ Error in uploadFormFilesToMinIOValues: ' + e.toString());
    res = e.toString();
  }

  return (res, folder_name);
}
 
//   Future<(String, String)> uploadFormFilesToMinIOValues(
//   Map<int, dynamic> formControlsValues,
//   String folderName,
// ) async {
//   String res = "success";
//   int uploadedCount = 0;
//   int errorCount = 0;

//   try {
//     // 1) التأكد من الـ Bucket
//     print('Using bucket: $bucketName, prefix: $folderName');
//     final bool found = await _minio.bucketExists(bucketName);
//     if (!found) {
//       await _minio.makeBucket(bucketName);
//       print('Bucket "$bucketName" created.');
//     }

//     // 2) تجميع الملفات المطلوب رفعها (اعتماداً على النموذج الأساسي كما طلبت)
//     final List<Map<String, dynamic>> filesToUpload = [];
//     for (final control in Funcs.form_model?.controls ?? []) {
//       if (control.type == 7 && control.files != null) {
//         for (final file in control.files!) {
//           final bool shouldUpload =
//               file.createdInThisSession == true ||
//               file.status == StorageStatus.added ||
//               file.status == StorageStatus.modified ||
//               file.status == StorageStatus.moved ||
//               file.status == StorageStatus.movedModeified ||
//               file.status == StorageStatus.movedRenamed ||
//               file.status == StorageStatus.renamed;

//           // تجاهل ما هو مرفوع سابقًا (المسار يبدأ بـ folderName)
//           final String? p = (file.path ?? '').toString();
//           final bool isAlreadyUrlOrInBucket =
//               p?.isNotEmpty ?? false &&
//               (p?.startsWith('http://') ?? false) ||
//               (p?.startsWith('https://') ?? false) ||
//               (p?.startsWith(folderName) ?? false);
//                (p?.startsWith('https://') ?? false) ||
//                (p?.startsWith(folderName) ?? false);

//           // لازم يكون عندي path محلي صالح للرفع
//           if (shouldUpload && !isAlreadyUrlOrInBucket && file.path != null) {
//             filesToUpload.add({'file': file});
//           }
//         }
//       }
//     }

//     print('Found ${filesToUpload.length} files to upload');
//     final uuid = Uuid();

//     // 3) الرفع وتعديل الحقول المطلوبة فقط (base64, path, folder)
//     for (final item in filesToUpload) {
//       final dynamic file = item['file'];

//       try {
//         // استخراج مسار محلي صالح
//         final String pathCandidate = (file.path ?? '').toString().trim();
//         if (pathCandidate.isEmpty ||
//             pathCandidate.startsWith('http://') ||
//             pathCandidate.startsWith('https://') ||
//             pathCandidate.startsWith(folderName)) {
//           // تخطّي الملف إذا لم يكن مسارًا محليًا
//           continue;
//         }

//         final f = File(pathCandidate);
//         if (!f.existsSync()) {
//           throw 'Local file not found: $pathCandidate';
//         }

//         // توليد اسم كائن فريد
//         final String fileExtension =
//             (file.fileExtension?.toString().trim().isNotEmpty ?? false)
//                 ? file.fileExtension.toString().trim()
//                 : (file.name?.toString().split('.').last ?? 'bin');

//         final String objectName = '${uuid.v4()}.$fileExtension';
//         final String objectPath = '$folderName/$objectName';

//         print('Uploading: ${file.name} as $objectName');

//         await _minio.fPutObject(
//           bucketName,
//           objectPath,
//           pathCandidate,
//         );

//         // ✅ التعديل المطلوب فقط:
//         //  - base64: نخزّن اسم الملف (UUID.ext) لاستخدامه لاحقاً
//         //  - path  : نخزّن المسار داخل الـ bucket (folder/object)
//         file.base64 = objectName;
//         file.path = objectPath;

//         uploadedCount += 1;
//         print('  ✅ Uploaded successfully: $objectPath');
//       } catch (e) {
//         // لا نوقف العملية؛ فقط نسجّل الخطأ
//         print('  ❌ Failed to upload ${file['name'] ?? ''}: $e');
//         errorCount += 1;
//       }
//     }

//     // 4) ضبط قيمة الـ folder داخل values (بدون تغيير أي منطق آخر)
//     //    نضيف الحقل لكل عنصر يحتوي على files.
//     try {
//       formControlsValues.forEach((_, value) {
//         if (value is Map<String, dynamic>) {
//           if (value.containsKey('files')) {
//             // الحقل الذي تعتمدون عليه
//             value['folder'] = folderName;
//             // ولو كنتم تستخدمون 'foldername' في أماكن أخرى نحافظ عليه أيضاً
//             value['foldername'] = folderName;
//           }
//         }
//       });
//     } catch (_) {
//       // تجاهل أي استثناء هنا كي لا نغيّر سير الدالة
//     }

//     if (uploadedCount > 0) {
//       res = 'success';
//     } else if (errorCount > 0) {
//       res = 'no files uploaded';
//     }

//     print('✅ All files processed. Uploaded: $uploadedCount, Errors: $errorCount');
//   } catch (e) {
//     print('❌ Error in uploadFormFilesToMinIOValues: $e');
//     res = e.toString();
//     if (Platform.isLinux) {
//       throw Exception("TaskParsingException: ${e.toString()}");
//     }
//   }

//   // نعيد نفس folderName الذي استلمناه (حسب توقيع الدالة)
//   return (res, folderName);
// }

  /// رفع ملفات النموذج إلى MinIO
  /// @param form نموذج النموذج الذي يحتوي على الأدوات والملفات
  /// @param folderName اسم المجلد (prefix) الذي سيتم الرفع إليه
  /// @return String حالة الرفع ("success" أو رسالة الخطأ)
 
  /// تنظيف Map لجعله قابل للتحويل إلى JSON
  /// يزيل local_path والبيانات غير القابلة للتحويل
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

//   /// ## دالة اختبار الاتصال بخادم MinIO
//   ///
//   /// هذه الدالة تختبر الاتصال الأساسي بخادم MinIO
//   /// وتتحقق من صحة بيانات الاعتماد وإمكانية الوصول للـ Bucket
//   ///
//   /// @return String رسالة توضح حالة الاتصال
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

//   /// بناء الرابط العلني للملف
// }

// class SendFormClass {
//   String folderName = "";
//   String fileName = "";
//   int user_id = 0;
//   int apply_id = 0;
//   String end_point_name = "";
//   int? public_api_req_id = 0;
//   SendFormClass({
//     required this.folderName,
//     required this.fileName,
//     required this.user_id,
//     required this.apply_id,
//     required this.end_point_name,
//     this.public_api_req_id,
//   });
//   factory SendFormClass.fromJson(Map<String, dynamic> json) => SendFormClass(
//     folderName: json['folderName'],
//     fileName: json['fileName'],
//     user_id: json['user_id'],
//     apply_id: json['apply_id'],
//     end_point_name: json['end_point_name'],
//     public_api_req_id: json['public_api_req_id'],
//   );
//   Map<String, dynamic> toJson() => {
//     'folderName': folderName,
//     'fileName': fileName,
//     'user_id': user_id,
//     'apply_id': apply_id,
//     'end_point_name': end_point_name,
//     'public_api_req_id': public_api_req_id,
//   };
// }
}