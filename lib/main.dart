import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:hub/config/config.dart';
import 'package:hub/pages/sign_in.dart';
import 'package:hub/pages/tenant_portal_auth_page.dart';
import 'package:hub/services/tenant_portal_service.dart';
import 'package:hub/widgets/widgets.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KejaHub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.nestBlue),
        useMaterial3: true,
      ),
      home: AppEntryPage()
    );
  }
}

