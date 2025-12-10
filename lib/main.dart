import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/forms_list_screen.dart';
import 'devtools/dev_panel_screen.dart';
import 'package:flutter/services.dart';

class MyHttpOverrides extends HttpOverrides {
  final SecurityContext context;

  MyHttpOverrides(this.context);

  @override
  HttpClient createHttpClient(SecurityContext? _) {
    return super.createHttpClient(context);
  }
}

Future<void> setupHttpOverrides() async {
  // final certData = await rootBundle.load('assets/certificates/ShareFlowCA.pem');
  //SecurityContext context = SecurityContext(withTrustedRoots: false);
  final context = SecurityContext.defaultContext;

  final certData = await rootBundle.load('assets/certificates/ShareFlowCA.pem');
  context.setTrustedCertificatesBytes(certData.buffer.asUint8List());
  HttpOverrides.global = MyHttpOverrides(context);

  // HttpOverrides.global = MyHttpOverrides(context);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Use ShareFlow Public API',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      locale: const Locale('ar'),
      translations: null,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: FormsListScreen(),
      ),
      routes: {
        '/dev': (_) => const Directionality(
          textDirection: TextDirection.rtl,
          child: DevPanelScreen(),
        ),
      },
    );
  }
}

// الشاشة الرئيسية سيتم استبدالها بقائمة النماذج
