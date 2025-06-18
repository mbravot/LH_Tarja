import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'https://apilhtarja.lahornilla.cl/api';
  //final String baseUrl = 'http://192.168.1.60:5000/api';

  Future<void> login(String usuario, String clave) async {
    try {
      print("🔄 Intentando login con URL: $baseUrl/auth/login");
      print("📤 Datos de login - Usuario: $usuario");

      final Map<String, String> body = {
        "usuario": usuario,
        "clave": clave,
      };

      print("📦 Body de la petición: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(body),
      );

      print("📡 Código de respuesta: ${response.statusCode}");
      print("📝 Respuesta del servidor: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final token = data['access_token'];
        final nombreUsuario = data['usuario'];
        final idSucursal = data['id_sucursal'];
        final nombreSucursal = data['sucursal_nombre'];
        final idRol = data['id_rol'];
        final idPerfil = data['id_perfil'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('user_name', nombreUsuario);
        await prefs.setString('id_sucursal', idSucursal.toString());
        await prefs.setString('user_sucursal', nombreSucursal);
        await prefs.setString('id_rol', idRol.toString());
        await prefs.setString('id_perfil', idPerfil.toString());

        print(
            "✅ Login exitoso - Usuario: $nombreUsuario, Sucursal: $idSucursal ($nombreSucursal)");
      } else {
        print("❌ Error en login - Código: ${response.statusCode}");
        print("❌ Detalle del error: ${response.body}");
        
        // Extraer el mensaje de error del JSON
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Error desconocido';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("🚨 Error de conexión: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// 🔥 Método para renovar el token si expira
  Future<bool> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) {
      return false;
    }

    final response = await http.post(
      Uri.parse("$baseUrl/auth/refresh"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $refreshToken",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await prefs.setString('token', data['token']); // ✅ Actualizar el token
      return true;
    } else {
      return false;
    }
  }
}
