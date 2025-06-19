import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_lh_tarja/pages/login_page.dart';
import 'package:app_lh_tarja/pages/home_page.dart';
import 'package:app_lh_tarja/theme/app_theme.dart';
import 'package:app_lh_tarja/providers/theme_provider.dart';
import 'package:app_lh_tarja/routes.dart';
import 'package:app_lh_tarja/widgets/token_checker.dart';
import 'package:app_lh_tarja/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(startPage: token == null ? LoginPage() : HomePage()),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget startPage;

  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'LH Gestión Tarjas',
      debugShowCheckedModeBanner: false,
      navigatorKey: ApiService.navigatorKey,
      theme: themeProvider.currentTheme,
      home: startPage is HomePage 
          ? TokenChecker(child: startPage) // Solo verificar token si está logueado
          : startPage,
      routes: appRoutes,
    );
  }
}

// 🔐 Manejador de ciclo de vida para borrar el token cuando se cierra la app
class LifecycleEventHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Solo eliminar token si la app se cierra completamente
    if (state == AppLifecycleState.detached) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('id_sucursal'); // si también quieres esto
      print("🔐 Token eliminado al cerrar la app");
    }
  }
}
