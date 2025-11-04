class AppConfig {
  AppConfig._();

  // static const String baseUrl = 'http://10.103.70.67/';
  static const String baseUrl = 'http://localhost:8001/';
  // static const String baseUrl = 'http://84.247.170.51/';
  static const String apiKey = 'a9198549a3b00949355a09d2a';
  // static const String apiKey = '6c6a839ffbcee9709d873056e';
  static const String password = '123456';
  static const String username = '777800777';
  // static const String username = '770555246';
  static const String licenseKey = 'c9a3c5e0easdasd1f42377350b073ab';
  // static const String licenseKey = '84d3e13d81061b2c747fd5f17';

 // ========================================
  // إعدادات MinIO
  // ========================================
  
  /// عنوان خادم MinIO
  /// يمكن تغييره حسب البيئة (تطوير، إنتاج)
  // static String minio_end_point = "84.247.170.51";
  // static const String minio_end_point = '10.103.70.67';
  static const String minio_end_point = 'localhost';

  static const int minio_port = 9000;
  static String minio_access_key = "1a1bb32db3ea8fcd31e1a99ef";
  static String minio_secret_key = "2f999116ccd2da8a57781d661";
  // static const String minio_access_key = 'eyad';
  // static const String minio_secret_key = 'StrongPass#2025!';
  
  /// يجب تفعيله في بيئة الإنتاج
  static const bool minio_use_ssl = false;


  static const String submitFormEndpoint = 'api/POST_FORM_DATA';

  static const Duration httpTimeout = Duration(seconds: 600);
}
