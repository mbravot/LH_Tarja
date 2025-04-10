import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_services.dart';

class ApiService {
  final String baseUrl = 'http://192.168.1.69:5000/api';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Future<void> _manejarTokenExpirado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // Método para obtener el token almacenado en SharedPreferences
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token'); // Obtener el token almacenado
  }

  // ✅ Obtener headers con token
  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _manejarRespuesta(http.Response response) async {
    if (response.statusCode == 401 &&
        response.body.contains('Token has expired')) {
      await _manejarTokenExpirado();
    }
    return response;
  }

  /// 🔹 Método para reintentar la petición si el token expira
  // ignore: unused_element
  Future<http.Response> _retryRequest(http.Request request) async {
    bool refreshed =
        await AuthService().refreshToken(); // ✅ Llamada correcta a AuthService
    if (refreshed) {
      final newHeaders = await _getHeaders();
      request.headers.clear();
      request.headers.addAll(newHeaders);
      return await http.Response.fromStream(await request.send());
    }
    throw Exception('Sesión expirada, inicia sesión nuevamente.');
  }

  //

  // Método para listar actividades con autenticación
  Future<List<dynamic>> getActividades() async {
    final response = await http.get(
      Uri.parse('$baseUrl/actividades/'),
      headers: await _getHeaders(),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener las actividades');
    }
  }

  // Método para crear una nueva actividad con autenticación
  Future<bool> createActividad(Map<String, dynamic> actividad) async {
    final response = await http.post(
      Uri.parse('$baseUrl/actividades/'),
      headers: await _getHeaders(),
      body: jsonEncode(actividad),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Error al crear la actividad');
    }
  }

  // Metodo para editar una actividad
  Future<Map<String, dynamic>> editarActividad(
      String actividadId, Map<String, dynamic> datos) async {
    final token = await getToken(); // Obtener el token almacenado
    if (token == null) {
      return {"error": "No se encontró un token. Inicia sesión nuevamente."};
    }

    final response = await http.put(
      Uri.parse('$baseUrl/actividades/$actividadId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer $token', // 🔹 Ahora se envía el token correctamente
      },
      body: jsonEncode(datos),
    );

    await _manejarRespuesta(response);

    print(
        "🔍 Respuesta de editar actividad: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {"error": "No se pudo actualizar la actividad: ${response.body}"};
    }
  }

  /// 📌 Obtener rendimientos por usuario y sucursal
  Future<List<dynamic>> getRendimientos({String? idActividad}) async {
    try {
      String? token = await getToken();
      if (token == null) {
        throw Exception('No se encontró un token. Inicia sesión nuevamente.');
      }

      Uri url = idActividad != null
          ? Uri.parse('$baseUrl/rendimientos?idActividad=$idActividad')
          : Uri.parse('$baseUrl/rendimientos/');

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      await _manejarRespuesta(response);

      print("🔍 Respuesta API Rendimientos: ${response.statusCode}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 308) {
        throw Exception("⚠ Redirección detectada (308). Verifica la API.");
      } else {
        throw Exception("Error al obtener rendimientos: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error en getRendimientos(): $e");
    }
  }

  /// 📌 Crear un nuevo rendimiento
  Future<bool> createRendimientos(
      List<Map<String, dynamic>> rendimientos) async {
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse("$baseUrl/rendimientos/"),
      headers: headers,
      body: jsonEncode(rendimientos),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 201) {
      return true;
    } else {
      print("❌ Error en la API: ${response.body}");
      return false;
    }
  }

  /// 📌 Editar un rendimiento existente
  Future<bool> editarRendimiento(
      String id, Map<String, dynamic> rendimiento) async {
    final headers = await _getHeaders(); // ✅ Obtiene los headers con el token

    final response = await http.put(
      Uri.parse("$baseUrl/rendimientos/$id"),
      headers: headers, // ✅ Envía el token correctamente
      body: jsonEncode(rendimiento),
    );

    await _manejarRespuesta(response);

    print(
        "🔍 Respuesta API Editar Rendimiento: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      return true;
    } else {
      print("❌ Error al editar rendimiento: ${response.body}");
      return false;
    }
  }

  // 🔹 Obtener sucursal activa del usuario logueado
  Future<String?> getSucursalActiva() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/sucursal-activa'), // ← este es el correcto
      headers: headers,
    );

    await _manejarRespuesta(response);

    print(
        "🔍 Respuesta API Sucursal Activa: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      print("✅ Sucursal activa obtenida: ${data["sucursal_activa"]}");
      return data["sucursal_activa"].toString();
    } else {
      print("❌ Error al obtener sucursal activa: ${response.body}");
      return null;
    }
  }

  Future<bool> actualizarSucursalActiva(String nuevaSucursalId) async {
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/sucursal-activa'),
      headers: headers,
      body: jsonEncode({"id_sucursal": nuevaSucursalId}),
    );

    await _manejarRespuesta(response);

    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> cambiarClave(
      String claveActual, String nuevaClave) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.post(
      Uri.parse("$baseUrl/auth/cambiar-clave"), // ✅ URL corregida
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },

      body:
          jsonEncode({"clave_actual": claveActual, "nueva_clave": nuevaClave}),
    );

    await _manejarRespuesta(response);

    return jsonDecode(response.body);
  }

  //Metodo para obtener especies
  Future<List<Map<String, dynamic>>> getEspecies() async {
    final token = await getToken();
    if (token == null)
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/especies'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => {"id": item['id'], "nombre": item['nombre']})
          .toList();
    } else {
      throw Exception('Error al obtener las especies');
    }
  }

  // Método para obtener variedades según especie y sucursal
  Future<List<Map<String, dynamic>>> getVariedades(
      String idEspecie, String idSucursal) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse(
          '$baseUrl/opciones/variedades?id_especie=$idEspecie&id_sucursal=$idSucursal'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener las variedades');
    }
  }

  //Metodo para obtener cecos
  Future<List<Map<String, dynamic>>> getCecos(
      String idEspecie, String idVariedad, String idSucursal) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    // 🔹 Validar los parámetros antes de hacer la petición
    if (idEspecie.isEmpty || idVariedad.isEmpty || idSucursal.isEmpty) {
      throw Exception(
          "⚠ Parámetros inválidos en getCecos() -> idEspecie: $idEspecie, idVariedad: $idVariedad, idSucursal: $idSucursal");
    }

    final response = await http.get(
      Uri.parse(
          '$baseUrl/opciones/cecos?id_especie=$idEspecie&id_variedad=$idVariedad&id_sucursal=$idSucursal'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    print("🔍 Respuesta API CECOs: ${response.body}");

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener los CECOs: ${response.body}');
    }
  }

  //Metodo para obtener labores
  Future<List<Map<String, dynamic>>> getLabores() async {
    final token = await getToken();
    if (token == null)
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/labores'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => {"id": item['id'], "nombre": item['nombre']})
          .toList();
    } else {
      throw Exception('Error al obtener las labores');
    }
  }

  //Metodo para obtener unidades
  Future<List<Map<String, dynamic>>> getUnidades() async {
    final token = await getToken();
    if (token == null)
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/unidades'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => {"id": item['id'], "nombre": item['nombre']})
          .toList();
    } else {
      throw Exception('Error al obtener las unidades');
    }
  }

  //Metodo para obtener tipo trabajadores
  Future<List<Map<String, dynamic>>> getTipoTrabajadores() async {
    final token = await getToken();
    if (token == null)
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/tipotrabajadores'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => {"id": item['id'], "desc_tipo": item['desc_tipo']})
          .toList();
    } else {
      throw Exception('Error al obtener los tipos de trabajadores');
    }
  }

  Future<List<Map<String, dynamic>>> getPorcentajes() async {
    final token = await getToken();
    if (token == null)
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/porcentajes'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => {"id": item['id'], "porcentaje": item['porcentaje']})
          .toList();
    } else {
      throw Exception('Error al obtener los porcentajes');
    }
  }

  // Método para obtener contratistas filtrados por sucursal
  Future<List<Map<String, dynamic>>> getContratistas(
      String idSucursal, String idTipoTrab) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse(
          '$baseUrl/opciones/contratistas?id_sucursal=$idSucursal&id_tipo_trab=$idTipoTrab'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener los contratistas');
    }
  }

  // ✅ Obtener todos los contratistas de la sucursal del usuario logueado
  Future<List<Map<String, dynamic>>> getContratistasPorSucursal() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    // ✅ Obtener la sucursal del usuario logueado
    String? idSucursal = await getSucursalActiva();
    if (idSucursal == null) {
      throw Exception('No se pudo obtener la sucursal del usuario logueado.');
    }

    print("📌 Buscando contratistas para id_sucursal: $idSucursal");

    final response = await http.get(
      Uri.parse(
          '$baseUrl/contratistas/?id_sucursal=$idSucursal'), // 🔹 Solo filtra por sucursal
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    print(
        "🔍 Respuesta API Contratistas: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data
          .cast<Map<String, dynamic>>(); // ✅ Asegurar conversión correcta
    } else {
      throw Exception('Error al obtener los contratistas');
    }
  }

  /// 🔹 Editar un contratista existente
  Future<bool> editarContratista(String id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse("$baseUrl/contratistas/$id"),
      headers: headers,
      body: jsonEncode(data),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return true;
    } else {
      print("❌ Error al editar contratista: ${response.body}");
      return false;
    }
  }

  // 🔹 Obtener trabajadores filtrados por sucursal y contratista
  Future<List<dynamic>> getTrabajadores(
      String idSucursal, String idContratista) async {
    if (idSucursal.isEmpty || idContratista.isEmpty) {
      throw Exception("⚠ Parámetros inválidos en getTrabajadores()");
    }

    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
          '$baseUrl/trabajadores?id_sucursal=$idSucursal&id_contratista=$idContratista'),
      headers: headers,
    );

    await _manejarRespuesta(response);

    print(
        "🔍 Respuesta API Trabajadores: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener los trabajadores: ${response.body}');
    }
  }

  /// 🔹 Crear un nuevo trabajador
  Future<bool> crearTrabajador(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse("$baseUrl/trabajadores"),
      headers: headers,
      body: jsonEncode(data),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 201) {
      return true;
    } else {
      print("❌ Error al crear trabajador: ${response.body}");
      return false;
    }
  }

  /// 🔹 Editar un trabajador existente
  Future<bool> editarTrabajador(String id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse("$baseUrl/trabajadores/$id"),
      headers: headers,
      body: jsonEncode(data),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return true;
    } else {
      print("❌ Error al editar trabajador: ${response.body}");
      return false;
    }
  }

  /// ✅ Obtener trabajadores de la sucursal del usuario logueado
  Future<List<Map<String, dynamic>>> getTrabajadoresPorSucursal() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    // ✅ Obtener la sucursal del usuario logueado
    String? idSucursal = await getSucursalActiva();
    if (idSucursal == null) {
      throw Exception('No se pudo obtener la sucursal del usuario logueado.');
    }

    print("📌 Buscando trabajadores para id_sucursal: $idSucursal");

    final response = await http.get(
      Uri.parse('$baseUrl/trabajadores?id_sucursal=$idSucursal'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    print(
        "🔍 Respuesta API Trabajadores: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al obtener los trabajadores');
    }
  }

  /// 🔹 Crear un nuevo contratista
  Future<bool> crearContratista(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final idSucursal = prefs.getString('id_sucursal');

    if (token == null || idSucursal == null) {
      print("⚠️ Token o sucursal activa no disponibles.");
      return false;
    }

    final body = {
      "rut": data['rut'],
      "nombre": data['nombre'],
      "id_sucursal": idSucursal,
      "id_tipo_trab": 2,
      "id_estado": 1,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/contratistas/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 201) {
      print("✅ Contratista creado correctamente");
      return true;
    } else {
      print("❌ Error al crear contratista: ${response.body}");
      return false;
    }
  }

  //Metodo para obtener tipo rendimiento
  Future<List<Map<String, dynamic>>> getTipoRendimientos() async {
    final token = await getToken();
    if (token == null)
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/tiporendimientos'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => {"id": item['id'], "tipo": item['tipo']})
          .toList();
    } else {
      throw Exception('Error al obtener los tipo de rendimiento');
    }
  }

  //Metodo para obtener sucursales
  Future<List<Map<String, dynamic>>> getSucursales() async {
    final token = await getToken();
    if (token == null)
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/sucursales'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => {"id": item['id'], "nombre": item['nombre']})
          .toList();
    } else {
      throw Exception('Error al obtener las sucursales');
    }
  }

  // Metodo para obtener usuarios
  Future<List<dynamic>> getUsuarios() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token", // Enviar token JWT en el header
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Acceso no autorizado. Inicia sesión nuevamente.');
    } else {
      throw Exception('Error al obtener los usuarios');
    }
  }

  Future<bool> crearUsuario({
    required String nombre,
    required String correo,
    required String clave,
    required int idSucursal,
    required int idRol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'nombre': nombre,
        'correo': correo,
        'clave': clave,
        'id_Sucursal': idSucursal,
        'id_estado': 1, // Activo
        'id_rol': idRol,
      }),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 201) {
      return true;
    } else {
      print("❌ Error al crear usuario: ${response.body}");
      return false;
    }
  }

  Future<bool> editarUsuario(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      print("✅ Usuario editado correctamente");
      return true;
    } else {
      print("❌ Error al editar usuario: ${response.body}");
      return false;
    }
  }
}
