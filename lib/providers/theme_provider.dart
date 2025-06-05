import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  ThemeData get currentTheme {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  static final _lightTheme = ThemeData(
    colorScheme: ColorScheme.light(
      primary: Colors.green,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      background: Colors.grey,
      onBackground: Colors.black,
      secondary: Colors.greenAccent,
    ),
    primarySwatch: Colors.green,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.green,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  static final _darkTheme = ThemeData(
    colorScheme: ColorScheme.dark(
      primary: Colors.green,
      onPrimary: Colors.white,
      surface: Color(0xFF222222),
      onSurface: Colors.white,
      background: Color(0xFF121212),
      onBackground: Colors.white,
      secondary: Colors.greenAccent,
    ),
    primarySwatch: Colors.green,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.green[800],
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
} 