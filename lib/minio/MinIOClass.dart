import 'dart:convert';
import 'dart:io';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'package:path_provider/path_provider.dart';
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
    endPoint: Funcs.minio_end_point, // e.g., 'localhost' or '192.168.1.10'
    port: Funcs.minio_port,
    accessKey: Funcs.minio_access_key,
    secretKey: Funcs.minio_secret_key,
    useSSL: Funcs.minio_use_ssl, // Set to true if you configured Nginx with SSL
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

  /// رفع جميع ملفات النموذج من values (Map<int, dynamic>)
  /// @param formControlsValues الخريطة التي تحتوي على قيم الأدوات من FormController
  /// @param folderName اسم المجلد الرئيسي (e.g., 'api_applys')
  /// @return (status, folder_name) - حالة الرفع واسم المجلد
  // Future<(String,String)> uploadFormFilesToMinIO(
  //   Map<int, dynamic> formControlsValues,
  //   String folderName,
  // ) async {
  //   String res = "success";
  //   String folder_name = 'noFolder';
    
  //   try {
  //     print('Using bucket: $bucketName, prefix: $folderName');

  //     // التحقق من وجود الـ Bucket الثابت وإنشاؤه إن لزم
  //     bool found = await _minio.bucketExists(bucketName);
  //     if (!found) {
  //       await _minio.makeBucket(bucketName);
  //       print('Bucket "$bucketName" created.');
  //     }

  //     // حصر الملفات من values
  //     List<Map<String, dynamic>> filesToUpload = [];

  //     for (var entry in formControlsValues.entries) {
  //       final controlId = entry.key;
  //       final value = entry.value;
        
  //       // التحقق من أن القيمة تحتوي على ملفات
  //       if (value is Map<String, dynamic> && value['files'] is List) {
  //         final files = value['files'] as List;
          
  //         for (var i = 0; i < files.length; i++) {
  //           final file = files[i];
  //           if (file is Map<String, dynamic>) {
  //             final localPath = file['base64'] as String?;
              
  //             // التحقق من أن المسار محلي وليس URL
  //             if (localPath != null && 
  //                 localPath.isNotEmpty &&
  //                 !localPath.startsWith('http://') &&
  //                 !localPath.startsWith('https://') &&
  //                 !localPath.contains('z') && // ليس مرفوع مسبقاً
  //                 !localPath.startsWith(folderName)) {
                
  //               filesToUpload.add({
  //                 'file': file,
  //                 'controlId': controlId,
  //                 'fileIndex': i,
  //                 'values': value,
  //               });
  //             }
  //           }
  //         }
  //       }
  //     }

  //     print('Found ${filesToUpload.length} files to upload');

  //     // تحديد المنصة
  //     String platform = 'win';
  //     if(Platform.isAndroid){
  //       platform = 'and';
  //     }
  //     else if(Platform.isFuchsia){
  //       platform = 'web';
  //     }
  //     else if(Platform.isWindows){
  //       platform = 'win';
  //     }

  //     // توليد اسم المجلد مرة واحدة لجميع الملفات
  //     folder_name = '${DateTime.now().millisecondsSinceEpoch.toString()}z${platform}z${Funcs.form_id.toString()}';

  //     // رفع كل ملف مع UUID فريد
  //     final uuid = Uuid();
  //     for (var fileData in filesToUpload) {
  //       var file = fileData['file'] as Map<String, dynamic>;
  //       var values = fileData['values'] as Map<String, dynamic>;
  //       var fileIndex = fileData['fileIndex'] as int;

  //       try {
  //         final localPath = (file['base64'] as String).trim();
          
  //         // التحقق من وجود الملف
  //         final f = File(localPath);
  //         if (!f.existsSync()) {
  //           print('⚠️ Local file not found: $localPath');
  //           continue;
  //         }

  //         // الحصول على امتداد الملف
  //         String fileExtension = 'bin';
  //         final fileName = file['name'] as String?;
  //         if (fileName != null && fileName.contains('.')) {
  //           fileExtension = fileName.split('.').last;
  //         }

  //         // توليد UUID فريد لكل ملف
  //         String uniqueFileName = '${uuid.v4()}.$fileExtension';
  //         String fullObjectPath = '$folderName/$folder_name/$uniqueFileName';

  //         print('📤 Uploading: ${file['name']} as $uniqueFileName');

  //         // رفع الملف
  //         await _minio.fPutObject(
  //           bucketName,
  //           fullObjectPath,
  //           localPath,
  //         );

  //         // المسار النهائي: folder_name/uuid.ext
  //         String uuidPath = '$folder_name/$uniqueFileName';

  //         // تحديث base64 و path في الملف (فقط هذين الحقلين)
  //         (values['files'] as List)[fileIndex]['base64'] = uuidPath;
  //         (values['files'] as List)[fileIndex]['path'] = uuidPath;

  //         print('  ✅ Uploaded successfully: $uuidPath');
  //       } catch (e) {
  //         if (Platform.isLinux) {
  //           throw Exception("TaskParsingException: ${e.toString()}");
  //         }
  //         print('  ❌ Failed to upload ${file['name']}: $e');
  //         res = e.toString();
  //       }
  //     }

  //     print('✅ All files uploaded successfully!');
  //   } catch (e) {
  //     print('❌ Error in uploadFormFilesToMinIO: $e');
  //     res = e.toString();
  //     if (Platform.isLinux) {
  //       throw Exception("TaskParsingException: ${e.toString()}");
  //     }
  //   }

  //   return (res, folder_name);
  // }
 /// نسخة تعتمد على values مباشرة لتجنب الاعتماد على ControlModel.files
  // Future<(String, String)> uploadFormFilesToMinIOValues(
  //   Map<int, dynamic> formControlsValues,
  //   String folderName,
  // ) async {
  //   String res = "success";
  //   String folder_name = 'noFolder';
  //   try {
  //     print('Using bucket: ' + bucketName + ', prefix: ' + folderName);

  //     // تحقق أو أنشئ الـ Bucket
  //     bool found = await _minio.bucketExists(bucketName);
  //     if (!found) {
  //       await _minio.makeBucket(bucketName);
  //       print('Bucket "' + bucketName + '" created.');
  //     }

  //     // جمع الملفات من values مع تتبع الفهرس لضمان تعديل العنصر الصحيح عند وجود أكثر من ملف
  //     final List<Map<String, dynamic>> filesToUpload = <Map<String, dynamic>>[];
  //     formControlsValues.forEach((controlId, value) {
  //       if (value is Map<String, dynamic>) {
  //         final dynamic files = value['files'];
  //         if (files is List) {
  //           for (int i = 0; i < files.length; i++) {
  //             final dynamic f = files[i];
  //             if (f is Map<String, dynamic>) {
  //               final String? candidate = (f['base64'] as String?)?.trim();
  //               final bool looksRemote = candidate != null &&
  //                   (candidate.startsWith('http://') || candidate.startsWith('https://'));
  //               final bool isLocal = candidate != null && candidate.isNotEmpty && !looksRemote && File(candidate).existsSync();
  //               if (isLocal) {
  //                 filesToUpload.add({'file': f, 'values': value, 'fileIndex': i});
  //               }
  //             }
  //           }
  //         }
  //       }
  //     });

  //     print('Found ${filesToUpload.length} files to upload');
  //     if (filesToUpload.isEmpty) {
  //       return (res, folder_name);
  //     }

  //     // توليد اسم مجلد رئيسي واحد للدفعة
  //     String platform = 'win';
  //     if (Platform.isAndroid) platform = 'and';
  //     else if (Platform.isFuchsia) platform = 'web';
  //     else if (Platform.isWindows) platform = 'win';
  //     else if (Platform.isLinux) platform = 'lin';
  //     else if (Platform.isIOS) platform = 'ios';
  //     else if (Platform.isMacOS) platform = 'mac';
  //     folder_name = '${DateTime.now().millisecondsSinceEpoch}z${platform}z${Funcs.form_id}';

  //     int uploadedCount = 0;
  //     int errorCount = 0;
  //     final uuid = Uuid();

  //     for (final item in filesToUpload) {
  //       final Map<String, dynamic> file = item['file'] as Map<String, dynamic>;
  //       final Map<String, dynamic> values = item['values'] as Map<String, dynamic>;
  //       final int? fileIndex = item['fileIndex'] as int?;
  //       try {
  //         final String localPath = (file['base64'] as String).trim();
  //         final f = File(localPath);
  //         if (!f.existsSync()) {
  //           print('⚠️ Local file not found: ' + localPath);
  //           continue; // لا توقف العملية
  //         }

  //         String fileExtension = 'bin';
  //         final String? originalName = file['name'] as String?;
  //         if (originalName != null && originalName.contains('.')) {
  //           fileExtension = originalName.split('.').last;
  //         }

  //         final String uniqueFileName = '${uuid.v4()}.$fileExtension';
  //         // احفظ داخل نفس الـ bucket مباشرة تحت folder_name
  //         final String objectPath = folder_name + '/' + uniqueFileName;

  //         print('📤 Uploading: ${file['name']} as ' + uniqueFileName);

  //         await _minio.fPutObject(
  //           bucketName,
  //           objectPath,
  //           localPath,
  //         );

  //         final String uuidPath = uniqueFileName;
  //         // عدّل العنصر المحدد في القائمة إن أمكن لضمان عدم تداخل التعديلات عند تعدد الملفات
  //         final dynamic filesList = values['files'];
  //         if (fileIndex != null && filesList is List && fileIndex >= 0 && fileIndex < filesList.length) {
  //           final dynamic entry = filesList[fileIndex];
  //           if (entry is Map<String, dynamic>) {
  //             entry['base64'] = uuidPath;
  //             // entry['path'] = uuidPath;
  //           }
  //         } else {
  //           file['base64'] = uuidPath;
  //           // file['path'] = uuidPath;
  //         }
  //         values['foldername'] = folder_name;

  //         uploadedCount += 1;
  //         print('  ✅ Uploaded successfully: ' + uuidPath);
  //       } catch (e) {
  //         print('  ❌ Failed to upload ${file['name']}: ' + e.toString());
  //         errorCount += 1;
  //       }
  //     }

  //     if (uploadedCount > 0) {
  //       res = 'success';
  //     } else if (errorCount > 0) {
  //       res = 'no files uploaded';
  //     }

  //     print('✅ All files uploaded successfully!');
  //   } catch (e) {
  //     print('❌ Error in uploadFormFilesToMinIOValues: ' + e.toString());
  //     res = e.toString();
  //   }

  //   return (res, folder_name);
  // }
  /// نسخة تعتمد على values مباشرة لتجنب الاعتماد على ControlModel.files
  Future<(String, String)> uploadFormFilesToMinIOValues(
    Map<int, dynamic> formControlsValues,
    String folderName,
  ) async {
    String res = "success";
    String folder_name = 'noFolder';
    try {
      print('Using bucket: ' + bucketName + ', prefix: ' + folderName);

      // تحقق أو أنشئ الـ Bucket
      bool found = await _minio.bucketExists(bucketName);
      if (!found) {
        await _minio.makeBucket(bucketName);
        print('Bucket "' + bucketName + '" created.');
      }

      // جمع الملفات من values مع تتبع الفهرس لضمان تعديل العنصر الصحيح عند وجود أكثر من ملف
      final List<Map<String, dynamic>> filesToUpload = <Map<String, dynamic>>[];
      formControlsValues.forEach((controlId, value) {
        if (value is Map<String, dynamic>) {
          final dynamic files = value['files'];
          if (files is List) {
            for (int i = 0; i < files.length; i++) {
              final dynamic f = files[i];
              if (f is Map<String, dynamic>) {
                final String? candidate = ((f['local_path'] ?? f['base64']) as String?)?.trim();
                final bool looksRemote = candidate != null &&
                    (candidate.startsWith('http://') || candidate.startsWith('https://'));
                final bool isLocal = candidate != null && candidate.isNotEmpty && !looksRemote && File(candidate).existsSync();
                if (isLocal) {
                  filesToUpload.add({'file': f, 'values': value, 'fileIndex': i});
                }
              }
            }
          }
        }
      });

      print('Found ${filesToUpload.length} files to upload');

      // توليد اسم مجلد رئيسي واحد للدفعة (حتى لو لم تكن هناك ملفات)
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

      // رفع الملفات إن وُجدت
      for (final item in filesToUpload) {
        final Map<String, dynamic> file = item['file'] as Map<String, dynamic>;
        final Map<String, dynamic> values = item['values'] as Map<String, dynamic>;
        final int? fileIndex = item['fileIndex'] as int?;
        try {
          final String localPath = ((file['local_path'] ?? file['base64']) as String).trim();
          final f = File(localPath);
          if (!f.existsSync()) {
            print('⚠️ Local file not found: ' + localPath);
            continue; // لا توقف العملية
          }

          String fileExtension = 'bin';
          final String? originalName = file['name'] as String?;
          if (originalName != null && originalName.contains('.')) {
            fileExtension = originalName.split('.').last;
          }

          final String uniqueFileName = '${uuid.v4()}.$fileExtension';
          // احفظ داخل نفس الـ bucket مباشرة تحت folder_name
          final String objectPath = folder_name + '/' + uniqueFileName;

          print('📤 Uploading: ${file['name']} as ' + uniqueFileName);

          await _minio.fPutObject(
            bucketName,
            objectPath,
            localPath,
          );

          final String uuidPath = uniqueFileName;
          // عدّل العنصر المحدد في القائمة إن أمكن لضمان عدم تداخل التعديلات عند تعدد الملفات
          final dynamic filesList = values['files'];
          if (fileIndex != null && filesList is List && fileIndex >= 0 && fileIndex < filesList.length) {
            final dynamic entry = filesList[fileIndex];
            if (entry is Map<String, dynamic>) {
              entry['base64'] = uuidPath;
              // احتفظ بـ local_path لإعادة الرفع لاحقاً
              if (entry['local_path'] == null) {
                entry['local_path'] = localPath;
              }
              // entry['path'] = uuidPath;
            }
          } else {
            file['base64'] = uuidPath;
            if (file['local_path'] == null) {
              file['local_path'] = localPath;
            }
            // file['path'] = uuidPath;
          }
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

      // إنشاء ملف JSON بالبيانات حتى لو لم تكن هناك ملفات
      try {
        print('📝 إنشاء ملف JSON بالبيانات...');
        
        // تحويل البيانات إلى JSON
        final jsonData = jsonEncode(formControlsValues);
        
        // إنشاء ملف مؤقت
        final tempDir = await getTemporaryDirectory();
        final jsonFile = File('${tempDir.path}/form_data_$folder_name.json');
        await jsonFile.writeAsString(jsonData, encoding: utf8);
        
        // رفع ملف JSON إلى MinIO
        final jsonObjectPath = '$folder_name/form_data.json';
        await _minio.fPutObject(
          bucketName,
          jsonObjectPath,
          jsonFile.path,
        );
        
        print('✅ تم رفع ملف JSON بنجاح: $jsonObjectPath');
        
        // حذف الملف المؤقت
        await jsonFile.delete();
      } catch (jsonError) {
        print('⚠️ تحذير: فشل إنشاء ملف JSON: $jsonError');
        // لا نرمي خطأ هنا لأننا لا نريد إيقاف العملية
      }

      print('✅ All files uploaded successfully!');
    } catch (e) {
      print('❌ Error in uploadFormFilesToMinIOValues: ' + e.toString());
      res = e.toString();
    }

    return (res, folder_name);
  }
  // Future<(String, String)> uploadFormFilesToMinIO(
  //   Map<int, dynamic> formControlsValues,
  //   String folderName,
  // ) async {
  //   String res = "success";
  //   String folder_name = 'noFolder';

  //   try {
  //     print('Using bucket: $bucketName, prefix: $folderName');

  //     // التحقق من وجود الـ Bucket الثابت وإنشاؤه إن لزم
  //     bool found = await _minio.bucketExists(bucketName);
  //     if (!found) {
  //       await _minio.makeBucket(bucketName);
  //       print('Bucket "$bucketName" created.');
  //     }

  //     // حصر الملفات من values
  //     List<Map<String, dynamic>> filesToUpload = [];

  //     for (final entry in formControlsValues.entries) {
  //       final dynamic value = entry.value;
  //       if (value is Map<String, dynamic> && value['files'] is List) {
  //         final List files = value['files'] as List;
  //         for (int i = 0; i < files.length; i++) {
  //           final dynamic f = files[i];
  //           if (f is Map<String, dynamic>) {
  //             final String? candidate = (f['base64'] as String?)?.trim();
  //             if (candidate != null &&
  //                 candidate.isNotEmpty &&
  //                 !candidate.startsWith('http://') &&
  //                 !candidate.startsWith('https://') &&
  //                 !candidate.startsWith(folderName) &&
  //                 !candidate.contains('z')) {
  //               filesToUpload.add({
  //                 'file': f,
  //                 'values': value,
  //                 'fileIndex': i,
  //               });
  //             }
  //           }
  //         }
  //       }
  //     }

  //     print('Found ${filesToUpload.length} files to upload');

  //     if (filesToUpload.isEmpty) {
  //       // لا توجد ملفات للرفع
  //       return (res, folder_name); // سيبقى 'noFolder'
  //     }

  //     // تحديد المنصة وتوليد اسم المجلد الأساسي
  //     String platform = 'win';
  //     if (Platform.isAndroid) {
  //       platform = 'and';
  //     } else if (Platform.isFuchsia) {
  //       platform = 'web';
  //     } else if (Platform.isWindows) {
  //       platform = 'win';
  //     } else if (Platform.isLinux) {
  //       platform = 'lin';
  //     } else if (Platform.isIOS) {
  //       platform = 'ios';
  //     } else if (Platform.isMacOS) {
  //       platform = 'mac';
  //     }
  //     folder_name = '${DateTime.now().millisecondsSinceEpoch}z${platform}z${Funcs.form_id ?? 0}';

  //     int uploadedCount = 0;
  //     int errorCount = 0;

  //     // رفع كل ملف مع UUID فريد وتعديل JSON
  //     final uuid = Uuid();
  //     for (final fileData in filesToUpload) {
  //       final Map<String, dynamic> file = fileData['file'] as Map<String, dynamic>;
  //       final Map<String, dynamic> values = fileData['values'] as Map<String, dynamic>;

  //       try {
  //         final String localPath = (file['base64'] as String).trim();
  //         final f = File(localPath);
  //         if (!f.existsSync()) {
  //           print('⚠️ Local file not found: $localPath');
  //           continue;
  //         }

  //         String fileExtension = 'bin';
  //         final fileName = file['name'] as String?;
  //         if (fileName != null && fileName.contains('.')) {
  //           fileExtension = fileName.split('.').last;
  //         }

  //         final String uniqueFileName = '${uuid.v4()}.$fileExtension';
  //         final String fullObjectPath = '$folderName/$folder_name/$uniqueFileName';

  //         print('📤 Uploading: ${file['name']} as $uniqueFileName');

  //         await _minio.fPutObject(
  //           bucketName,
  //           fullObjectPath,
  //           localPath,
  //         );

  //         // المسار النهائي داخل المجلد: folder_name/uuid.ext
         

  //         // تعديل JSON مباشرة على نفس خريطة الملف
  //         file['base64'] = uniqueFileName;
  //         // file['path'] = uuidPath; // مفعّل فقط إذا رغبت بتحديث path أيضاً

  //         // إضافة foldername على مستوى قيمة الأداة
  //         values['foldername'] = folder_name;

  //         uploadedCount += 1;
  //         print('  ✅ Uploaded successfully: $uniqueFileName');
  //       } catch (e) {
  //         if (Platform.isLinux) {
  //           throw Exception("TaskParsingException: ${e.toString()}");
  //         }
  //         print('  ❌ Failed to upload ${file['name']}: $e');
  //         errorCount += 1;
  //       }
  //     }

  //     // تعليق: مكان إنشاء/حفظ ملف JSON النهائي إن أردت لاحقاً.
  //     // لإيقاف إنشاء JSON، اترك هذا القسم معطلاً.

  //     // اجعل الحالة نجاح إذا رفعنا أي ملف حتى لو حصلت أخطاء ببعضها
  //     if (uploadedCount > 0) {
  //       res = 'success';
  //     } else if (errorCount > 0) {
  //       res = 'no files uploaded';
  //     }

  //     print('✅ All files uploaded successfully!');
  //   } catch (e) {
  //     print('❌ Error in uploadFormFilesToMinIO: $e');
  //     res = e.toString();
  //     if (Platform.isLinux) {
  //       throw Exception("TaskParsingException: ${e.toString()}");
  //     }
  //   }

  //   return (res, folder_name);
  // }

  Future<(String,String)> uploadFormFilesToMinIO(
    FormStructureModel form,
    String folderName,
  ) async {
    String res = "success";
    String folder_name = '';
    try {
      // الحصول على اسم مجلد (prefix) داخل نفس الـ bucket الثابت
      //final folderName = form.SetAndGetBucketNameForMinIO();
      print('Using bucket: ' + bucketName + ', prefix: ' + folderName);

      // التحقق من وجود الـ Bucket الثابت وإنشاؤه إن لزم
      bool found = await _minio.bucketExists(bucketName);
      if (!found) {
        await _minio.makeBucket(bucketName);
        print('Bucket "' + bucketName + '" created.');
      }

      // حصر الملفات الجديدة/المعدلة من جميع عناصر التحكم
      List<Map<String, dynamic>> filesToUpload = [];

      for (var control in form.controls) {
        if (control.type == 7 && control.files != null) {
          for (var file in control.files!) {
            // تحديد الملفات التي تحتاج رفع
            bool shouldUpload =
                file.createdInThisSession == true ||
                file.status == StorageStatus.added ||
                file.status == StorageStatus.modified ||
                file.status == StorageStatus.moved ||
                file.status == StorageStatus.movedModeified ||
                file.status == StorageStatus.movedRenamed ||
                file.status == StorageStatus.renamed;

            // تجاهل الروابط الموجودة بالفعل
            bool isAlreadyUrl =
                file.path != null && (file.path!.startsWith(folderName));

            if (shouldUpload && !isAlreadyUrl && file.path != null) {
              filesToUpload.add({'file': file, 'control': control});
            }
          }
        }
      }

      print('Found ${filesToUpload.length} files to upload');

      // رفع كل ملف
      final uuid = Uuid();
      for (var fileData in filesToUpload) {
        var file = fileData['file'];

        try {
          // توليد اسم UUID فريد
          String fileExtension = file.fileExtension ?? 'bin';
          String objectName = '${uuid.v4()}.$fileExtension';

          print('Uploading: ${file.name} as $objectName');

          // تحديد المسار المحلي الفعلي للملف (تجنب URL)
          String pathCandidate = (file.path ?? '').trim();
          if (pathCandidate.isEmpty ||
              pathCandidate.startsWith('http://') ||
              pathCandidate.startsWith('https://') ||
              pathCandidate.startsWith(folderName)) {
            continue;
          }
          if (pathCandidate.isEmpty ||
              pathCandidate.startsWith('http://') ||
              pathCandidate.startsWith('https://') ||
              pathCandidate.startsWith(folderName)) {
            throw 'Local file path is missing or is a URL for ${file.name}';
          }
          final f = File(pathCandidate);
          if (!f.existsSync()) {
            throw 'Local file not found: ' + pathCandidate;
          }

          // رفع الملف
          await _minio.fPutObject(
            bucketName,
            folderName + "/" + objectName,
            pathCandidate,
          );

          // بناء الرابط العلني
          String publicUrl = folderName + "/" + objectName;

          // تحديث بيانات الملف
          file.fileBytes = publicUrl;
          file.path = publicUrl;
          folder_name = folderName;

          print('✅ Uploaded successfully: $objectName -> $publicUrl');
        } catch (e) {
          if (Platform.isLinux) {
            throw Exception("TaskParsingException: ${e.toString()}");
          }
          print('❌ Failed to upload ${file.name}: $e');
          res = e.toString();
        }
      }

      print('✅ All files uploaded successfully!');
    } catch (e) {
      print('❌ Error in uploadFormFilesToMinIO: $e');
      res = e.toString();
     if (Platform.isLinux) {
        throw Exception("TaskParsingException: ${e.toString()}");
      }
    }

    return (res,folder_name);
  }
//   /// ## دالة اختبار الاتصال بخادم MinIO
//   ///
//   /// هذه الدالة تختبر الاتصال الأساسي بخادم MinIO
//   /// وتتحقق من صحة بيانات الاعتماد وإمكانية الوصول للـ Bucket
//   ///
//   /// @return String رسالة توضح حالة الاتصال
//   Future<String> testConnection() async {
//     try {
//       print('🔄 بدء اختبار الاتصال بخادم MinIO...');

//       // محاولة الاتصال والتحقق من وجود الـ Bucket
//       bool bucketExists = await _minio.bucketExists(bucketName);

//       if (bucketExists) {
//         print('✅ تم العثور على الـ Bucket: $bucketName');
//         return 'success';
//       } else {
//         print('⚠️ الـ Bucket غير موجود، محاولة إنشاؤه...');

//         // محاولة إنشاء الـ Bucket للتأكد من صلاحيات الكتابة
//         await _minio.makeBucket(bucketName);
//         print('✅ تم إنشاء الـ Bucket بنجاح: $bucketName');
//         return 'success';
//       }
//     } catch (e) {
//       print('❌ فشل الاتصال: $e');

//       // تحديد نوع الخطأ وإرجاع رسالة مناسبة
//       String errorMessage = e.toString().toLowerCase();
//       if (Platform.isLinux) {
//         throw Exception("TaskParsingException: ${e.toString()}");
//       }
//       if (errorMessage.contains('connection') ||
//           errorMessage.contains('network') ||
//           errorMessage.contains('timeout')) {
//         return errorMessage;
//       } else if (errorMessage.contains('access') ||
//           errorMessage.contains('credential') ||
//           errorMessage.contains('unauthorized') ||
//           errorMessage.contains('forbidden')) {
//         return errorMessage;
//       } else if (errorMessage.contains('bucket')) {
//         return errorMessage;
//       } else {
//         return errorMessage;
//       }
//     }
//   }

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