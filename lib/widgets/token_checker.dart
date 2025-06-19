import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../pages/login_page.dart';
import '../pages/home_page.dart';

// Sistema de logging condicional
void logInfo(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("ℹ️ $message");
  }
}

void logError(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("❌ $message");
  }
}

class TokenChecker extends StatefulWidget {
  final Widget child;

  const TokenChecker({Key? key, required this.child}) : super(key: key);

  @override
  State<TokenChecker> createState() => _TokenCheckerState();
}

class _TokenCheckerState extends State<TokenChecker> {
  bool _isChecking = true;
  bool _hasValidToken = false;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token != null && token.isNotEmpty) {
        // Verificar si el token es válido haciendo una petición al servidor
        try {
          await ApiService().getSucursales(); // Usar un endpoint simple para verificar
          setState(() {
            _hasValidToken = true;
            _isChecking = false;
          });
        } catch (e) {
          logError('Error al verificar token: $e');
          // Token inválido, redirigir al login
          setState(() {
            _hasValidToken = false;
            _isChecking = false;
          });
        }
      } else {
        setState(() {
          _hasValidToken = false;
          _isChecking = false;
        });
      }
    } catch (e) {
      logError('Error al verificar token: $e');
      setState(() {
        _hasValidToken = false;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasValidToken) {
      return widget.child;
    } else {
      return const LoginPage();
    }
  }
} 