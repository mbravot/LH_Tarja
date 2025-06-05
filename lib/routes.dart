import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/usuarios_page.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/home': (context) => HomePage(),
  '/login': (context) => LoginPage(),
  '/usuarios': (context) => UsuariosPage(),
}; 