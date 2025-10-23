class AppConfig {
  AppConfig._();

  static const String baseUrl = 'http://localhost:7000';
  // static const String baseUrl = 'http://84.247.170.51/api';
  static const String apiKey = 'a9198549a3b00949355a09d2a';
  // static const String apiKey = '21761aa2457002e83953701a0';
  static const String password = '123456';
  static const String username = '777800777';
  // static const String username = '778007575';
  static const String licenseKey = 'c9a3c5e0e1f42377350b073ab';
  // static const String licenseKey = '9b303318500163a74363c43ef';

  static const String submitFormEndpoint = '/POST_FORM_DATA';

  static const Duration httpTimeout = Duration(seconds: 600);
}
