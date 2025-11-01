import 'dart:async';

import 'package:useshareflowpublicapiflutter/models/form_models.dart';

/// ملف الدوال المساعدة والمتغيرات العامة
/// يحتوي على جميع الدوال والمتغيرات المستخدمة في التطبيق

class Funcs {
  Funcs._();
  
 
  static int? form_id;
  static FormStructureModel? form_model;
  static int? user_id;
  static final List<String> errors = <String>[];
  static bool _stopRequested = false;
  static Completer<void>? stopCompleter =Completer<void>();

  // ========================================
  // دوال المساعدة العامة
  // ========================================
  
  /// تحديد نوع المنصة الحالية
  /// يُستخدم لتحديد سلوك مختلف حسب المنصة
  static String getPlatForm() {
    // يمكن تحسين هذه الدالة لتحديد المنصة بدقة أكبر
    return "windows"; // افتراضياً Windows، يمكن تغييره حسب الحاجة
  }
  
  /// التحقق من صحة عنوان URL
  static bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// توليد معرف فريد
  static String generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  /// تنظيف اسم الملف من الأحرف غير المسموحة
  static String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
  
  /// التحقق من امتداد الملف
  static String getFileExtension(String fileName) {
    if (fileName.contains('.')) {
      return fileName.split('.').last.toLowerCase();
    }
    return '';
  }
  
  /// تحديد نوع الملف بناءً على الامتداد
  static String getFileType(String fileName) {
    String extension = getFileExtension(fileName);
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return 'image';
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return 'document';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
        return 'video';
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return 'audio';
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return 'archive';
      default:
        return 'unknown';
    }
  }
  
  /// تنسيق حجم الملف
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  /// طباعة رسالة منسقة
  static void printFormatted(String message, {String? prefix}) {
    String timestamp = DateTime.now().toString().substring(11, 19);
    String formattedMessage = prefix != null ? '[$timestamp] $prefix: $message' : '[$timestamp] $message';
    print(formattedMessage);
  }


  // /// التحقق من صحة بيانات MinIO
  // static bool validateMinIOConfig() {
  //   return minio_end_point.isNotEmpty &&
  //          minio_port > 0 &&
  //          minio_access_key.isNotEmpty &&
  //          minio_secret_key.isNotEmpty;
  // }
  
  // /// طباعة إعدادات MinIO (بدون كشف المفاتيح السرية)
  // static void printMinIOConfig() {
  //   print('🔧 إعدادات MinIO:');
  //   print('🌐 العنوان: $minio_end_point');
  //   print('🔌 المنفذ: $minio_port');
  //   print('🔐 استخدام SSL: $minio_use_ssl');
  //   print('🔑 مفتاح الوصول: ${minio_access_key.substring(0, 3)}***');
  //   print('🔒 المفتاح السري: ${minio_secret_key.substring(0, 3)}***');
  // }

// call this to request stop from anywhere (idempotent)
static void _requestStop() {
  if (_stopRequested) return;
  _stopRequested = true;
  stopCompleter ??= null;
  if (!stopCompleter!.isCompleted) stopCompleter!.complete();
}

// call this to reset before a new run
static void resetStopRequest() {
  _stopRequested = false;
  stopCompleter = Completer<void>();
}

// check if stop was requested
static bool get isStopRequested => _stopRequested || (stopCompleter?.isCompleted ?? false);
  static Future<bool> checkRepeatingErrors() async {
  final errorsList = Funcs.errors.toList();
  final firstError = errorsList.first;
  int count = 0;
  if (errorsList.isEmpty) return false;

  for (final error in errorsList) {
     if (error.contains(firstError)) {
      count++;
      
      }else{
         count = 0;
      }
    print('count: $count');
    if(count == 10){

      _requestStop();
      errors.clear();
      return true;
    }
    
  }

  return false;
}
}

/// إنشاء مثيل عام من Funcs للاستخدام في جميع أنحاء التطبيق
// final funcs = Funcs();
