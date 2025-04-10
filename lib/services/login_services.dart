import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'http://192.168.1.69:5000/api';

  Future<void> login(String correo, String clave) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"correo": correo, "clave": clave}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final token = data['token'];
      final nombreUsuario = data['nombre'];
      final idSucursal = data['id_sucursal'];
      final nombreSucursal =
          data['nombre_sucursal']; // 🏢 Nombre de la sucursal activa
      final idRol = data['id_rol']; // 👈 Obtener el id_rol del usuario

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user_name', nombreUsuario);
      await prefs.setString('id_sucursal', idSucursal.toString());
      await prefs.setString('user_sucursal', nombreSucursal); // ✅ NUEVO
      await prefs.setString('id_rol', idRol.toString()); // 👈 Guardarlo

      print(
          "✅ Usuario: $nombreUsuario, Sucursal: $idSucursal ($nombreSucursal)");
    } else {
      throw Exception('Error en login: ${response.body}');
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
