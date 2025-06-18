import 'package:flutter/material.dart';

// Colores principales
const Color primaryColor = Colors.green; // Verde principal
const Color secondaryColor = Color(0xFF43A047); // Verde un poco más oscuro
const Color accentColor = Color(0xFF66BB6A); // Verde claro

// Colores de texto
const Color textPrimaryColor = Color(0xFF212121);
const Color textSecondaryColor = Color(0xFF757575);

// Colores de fondo
const Color backgroundColor = Color(0xFFF5F5F5);
const Color surfaceColor = Colors.white;

// Colores de estado
const Color errorColor = Color(0xFFD32F2F);
const Color successColor = Color(0xFF388E3C);
const Color warningColor = Color(0xFFF57C00);
const Color infoColor = Color(0xFF1976D2);

// Tema de la aplicación
ThemeData appTheme = ThemeData(
  primaryColor: primaryColor,
  colorScheme: ColorScheme.light(
    primary: primaryColor,
    secondary: secondaryColor,
    error: errorColor,
    background: backgroundColor,
    surface: surfaceColor,
  ),
  scaffoldBackgroundColor: backgroundColor,
  appBarTheme: const AppBarTheme(
    backgroundColor: primaryColor,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: primaryColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
); 