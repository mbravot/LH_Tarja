import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TokenChecker extends StatefulWidget {
  final Widget child;
  final Duration checkInterval;

  const TokenChecker({
    Key? key,
    required this.child,
    this.checkInterval = const Duration(minutes: 5), // Verificar cada 5 minutos
  }) : super(key: key);

  @override
  State<TokenChecker> createState() => _TokenCheckerState();
}

class _TokenCheckerState extends State<TokenChecker> {
  Timer? _timer;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Esperar 10 segundos antes de empezar a verificar el token
    // para evitar problemas inmediatos después del login
    Timer(Duration(seconds: 10), () {
      _startTokenChecking();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTokenChecking() {
    _timer = Timer.periodic(widget.checkInterval, (timer) async {
      try {
        final isValid = await _apiService.verificarYRefreshToken();
        if (!isValid) {
          // El token no es válido y el refresh falló, cerrar sesión automáticamente
          await _apiService.manejarTokenExpirado();
        }
      } catch (e) {
        print('Error al verificar token: $e');
        // En caso de error, también cerrar sesión por seguridad
        await _apiService.manejarTokenExpirado();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
} 