import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_lh_tarja/pages/login_page.dart';
import 'package:app_lh_tarja/pages/home_page.dart';
import 'package:app_lh_tarja/theme/app_theme.dart';
import 'package:app_lh_tarja/providers/theme_provider.dart';
import 'package:app_lh_tarja/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('access_token');
  
  final startPage = token == null ? LoginPage() : HomePage();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(startPage: startPage),
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
      title: 'LH Tarjas',
      debugShowCheckedModeBanner: false,
      navigatorKey: ApiService.navigatorKey,
      theme: themeProvider.currentTheme,
      home: startPage,
    );
  }
}
