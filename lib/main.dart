import 'package:app_lh_tarja/pages/usuarios_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Agregamos el observer para detectar cierre de la app
  WidgetsBinding.instance.addObserver(LifecycleEventHandler());

  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token');

  runApp(MyApp(startPage: token == null ? LoginPage() : HomePage()));
}

class MyApp extends StatelessWidget {
  final Widget startPage;

  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LH Tarja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: startPage,
      routes: {
        '/home': (context) => HomePage(), // ✅ Agregamos la ruta correctamente
        '/login': (context) =>
            LoginPage(), // ✅ También agregamos la ruta del login
        '/usuarios': (context) => UsuariosPage()
      },
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
