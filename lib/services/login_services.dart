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
        final refreshToken = data['refresh_token'];
        final nombreUsuario = data['usuario'];
        final idSucursal = data['id_sucursal'];
        final nombreSucursal = data['sucursal_nombre'];
        final idRol = data['id_rol'];
        final idPerfil = data['id_perfil'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
        }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      String? currentToken = prefs.getString('token');

      if (currentToken == null) {
        print("❌ No hay token actual para refresh");
        return false;
      }

      print("🔄 Intentando refresh token...");

      final response = await http.post(
        Uri.parse("$baseUrl/auth/refresh"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $currentToken",
        },
      );

      print("📡 Código de respuesta refresh: ${response.statusCode}");
      print("📝 Respuesta del servidor refresh: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Actualizar el token y otros datos si vienen en la respuesta
        await prefs.setString('token', data['access_token']);
        if (data['refresh_token'] != null) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }
        if (data['usuario'] != null) {
          await prefs.setString('user_name', data['usuario']);
        }
        if (data['id_sucursal'] != null) {
          await prefs.setString('id_sucursal', data['id_sucursal'].toString());
        }
        if (data['sucursal_nombre'] != null) {
          await prefs.setString('user_sucursal', data['sucursal_nombre']);
        }
        if (data['id_rol'] != null) {
          await prefs.setString('id_rol', data['id_rol'].toString());
        }
        if (data['id_perfil'] != null) {
          await prefs.setString('id_perfil', data['id_perfil'].toString());
        }

        print("✅ Token refresh exitoso");
        return true;
      } else {
        print("❌ Error en refresh token - Código: ${response.statusCode}");
        print("❌ Detalle del error refresh: ${response.body}");
        return false;
      }
    } catch (e) {
      print("🚨 Error de conexión en refresh: $e");
      return false;
    }
  }
}
