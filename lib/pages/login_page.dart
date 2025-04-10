import 'package:app_lh_tarja/services/login_services.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService authService = AuthService();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController claveController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;

  void login() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      await authService.login(correoController.text, claveController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('¡Bienvenido!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Credenciales incorrectas'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateInputs() {
    if (correoController.text.isEmpty || claveController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Por favor complete todos los campos'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 📸 Fondo
          Positioned.fill(
            child: Image.asset(
              'assets/images/fondo.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // 🟤 Overlay oscuro
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
          ),
          // 🧾 Contenido principal
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  // 🟢 Logo con animación de escala
                  TweenAnimationBuilder(
                    duration: Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0.5, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/lh.jpg',
                        height: 80,
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  // 🟢 Título con animación de opacidad
                  TweenAnimationBuilder(
                    duration: Duration(milliseconds: 800),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          "Bienvenido a LH Tarja",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 3,
                                offset: Offset(1, 1),
                              )
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Inicia sesión para continuar 🌿",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 2,
                                offset: Offset(0.5, 0.5),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  // 📨 Campo correo con animación de slide
                  TweenAnimationBuilder(
                    duration: Duration(milliseconds: 1000),
                    tween: Tween<Offset>(
                      begin: Offset(-1, 0),
                      end: Offset.zero,
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, Offset offset, child) {
                      return FractionalTranslation(
                        translation: offset,
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: correoController,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.email, color: Colors.green),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Correo',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.green, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // 🔒 Campo clave con animación de slide
                  TweenAnimationBuilder(
                    duration: Duration(milliseconds: 1200),
                    tween: Tween<Offset>(
                      begin: Offset(1, 0),
                      end: Offset.zero,
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, Offset offset, child) {
                      return FractionalTranslation(
                        translation: offset,
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: claveController,
                        obscureText: _obscureText,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock, color: Colors.green),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Clave',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.green, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  // ✅ Botón login con animación de slide
                  TweenAnimationBuilder(
                    duration: Duration(milliseconds: 1400),
                    tween: Tween<Offset>(
                      begin: Offset(0, 1),
                      end: Offset.zero,
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, Offset offset, child) {
                      return FractionalTranslation(
                        translation: offset,
                        child: child,
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade700,
                            Colors.green.shade500,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : login,
                        icon: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.login),
                        label: Text(
                          _isLoading ? "Ingresando..." : "Ingresar",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  // Footer con animación de opacidad
                  TweenAnimationBuilder(
                    duration: Duration(milliseconds: 1600),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Text(
                      " 2025 La Hornilla - Departamento de TI",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
