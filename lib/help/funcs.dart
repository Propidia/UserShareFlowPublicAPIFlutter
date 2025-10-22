import 'package:useshareflowpublicapiflutter/models/form_models.dart';

/// ملف الدوال المساعدة والمتغيرات العامة
/// يحتوي على جميع الدوال والمتغيرات المستخدمة في التطبيق

class Funcs {
  Funcs._();
  
  // ========================================
  // إعدادات MinIO
  // ========================================
  
  /// عنوان خادم MinIO
  /// يمكن تغييره حسب البيئة (تطوير، إنتاج)
  // static String minio_end_point = "84.247.170.51";
  static const String minio_end_point = 'localhost';
  static const int minio_port = 9000;
  // static String minio_access_key = "1a1bb32db3ea8fcd31e1a99ef";
  // static String minio_secret_key = "2f999116ccd2da8a57781d661";
  static const String minio_access_key = 'eyad';
  static const String minio_secret_key = 'StrongPass#2025!';
  
  /// يجب تفعيله في بيئة الإنتاج
  static const bool minio_use_ssl = false;
  static int? form_id;
  static FormStructureModel? form_model;
  static int? user_id;
  
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
  
  /// التحقق من صحة بيانات MinIO
  static bool validateMinIOConfig() {
    return minio_end_point.isNotEmpty &&
           minio_port > 0 &&
           minio_access_key.isNotEmpty &&
           minio_secret_key.isNotEmpty;
  }
  
  /// طباعة إعدادات MinIO (بدون كشف المفاتيح السرية)
  static void printMinIOConfig() {
    print('🔧 إعدادات MinIO:');
    print('🌐 العنوان: $minio_end_point');
    print('🔌 المنفذ: $minio_port');
    print('🔐 استخدام SSL: $minio_use_ssl');
    print('🔑 مفتاح الوصول: ${minio_access_key.substring(0, 3)}***');
    print('🔒 المفتاح السري: ${minio_secret_key.substring(0, 3)}***');
  }
}

/// إنشاء مثيل عام من Funcs للاستخدام في جميع أنحاء التطبيق
// final funcs = Funcs();
