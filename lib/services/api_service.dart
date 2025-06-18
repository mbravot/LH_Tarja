import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_services.dart';

class ApiService {
  //final String baseUrl = 'http://192.168.1.60:5000/api'; // Asegúrate de que esta URL sea la correcta
  final String baseUrl = 'https://apilhtarja.lahornilla.cl/api';

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

  // Obtener rendimientos por ID de actividad
  Future<Map<String, dynamic>> getRendimientos({String? idActividad}) async {
    try {
      if (idActividad == null) {
        throw Exception('Se requiere el ID de la actividad');
      }

      // Obtener rendimientos grupales
      final urlGrupal = '$baseUrl/rendimientos/$idActividad';
      print("🔍 Llamando a rendimientos grupales: $urlGrupal");

      final responseGrupal = await http.get(
        Uri.parse(urlGrupal),
        headers: await _getHeaders(),
      );

      print("📥 Respuesta rendimientos grupales: ${responseGrupal.statusCode} - ${responseGrupal.body}");
      await _manejarRespuesta(responseGrupal);

      if (responseGrupal.statusCode == 200) {
        final data = json.decode(responseGrupal.body);
        if (data['rendimientos'] != null) {
          final rendimientos = List<Map<String, dynamic>>.from(data['rendimientos']);
          data['rendimientos'] = rendimientos;
        }
        return data;
      } else {
        print("❌ Error al obtener rendimientos grupales: ${responseGrupal.statusCode} - ${responseGrupal.body}");
        throw Exception('Error al obtener rendimientos grupales: ${responseGrupal.statusCode}');
      }
    } catch (e) {
      print("❌ Error en getRendimientos: $e");
      throw Exception('Error al obtener rendimientos: $e');
    }
  }

  /// 📌 Crear un nuevo rendimiento
  Future<bool> createRendimientos(List<Map<String, dynamic>> rendimientos) async {
    final response = await http.post(
      Uri.parse("$baseUrl/rendimientos/"),
      headers: await _getHeaders(),
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
  Future<bool> editarRendimiento(String id, Map<String, dynamic> rendimiento) async {
    final response = await http.put(
      Uri.parse("$baseUrl/rendimientos/$id"),
      headers: await _getHeaders(),
      body: jsonEncode(rendimiento),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return true;
    } else {
      print("❌ Error en la API: ${response.body}");
      return false;
    }
  }

  /// 📌 Eliminar un rendimiento
  Future<bool> eliminarRendimiento(String id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/rendimientos/$id"),
      headers: await _getHeaders(),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return true;
    } else {
      print("❌ Error en la API: ${response.body}");
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
      Uri.parse('$baseUrl/opciones/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['labores'] ?? []);
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
      Uri.parse('$baseUrl/opciones/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['unidades'] ?? []);
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
  Future<List<Map<String, dynamic>>> getContratistas(String idSucursal) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/contratistas?id_sucursal=$idSucursal'),
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

  /// 🔹 Obtener la lista de contratistas
  Future<List<Map<String, dynamic>>> getContratistasPorSucursal() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');

    final response = await http.get(
      Uri.parse('$baseUrl/contratistas'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los contratistas');
    }
  }

  /// 🔹 Crear un nuevo contratista
  Future<Map<String, dynamic>> createContratista(Map<String, dynamic> contratistaData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');

    final response = await http.post(
      Uri.parse('$baseUrl/contratistas'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(contratistaData),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al crear el contratista');
    }
  }

  /// Actualiza un contratista existente
  Future<Map<String, dynamic>> updateContratista(String id, Map<String, dynamic> contratistaData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');

    final response = await http.put(
      Uri.parse('$baseUrl/contratistas/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(contratistaData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al actualizar el contratista');
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

  /// Obtiene las sucursales disponibles
  Future<List<Map<String, dynamic>>> getSucursales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/opciones/sucursales'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

    if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['sucursales'] ?? []);
    } else {
          throw Exception(data['error'] ?? 'Error al obtener las sucursales');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al obtener las sucursales');
    }
    } catch (e) {
      print('❌ Error al cargar sucursales disponibles: $e');
      throw Exception('Error al obtener las sucursales: $e');
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

  Future<List<Map<String, dynamic>>> getTipoCecos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/opciones/tiposceco'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];
          return data.cast<Map<String, dynamic>>();
        } else {
          throw Exception(responseData['message'] ?? 'Error al obtener tipos de CECO');
        }
      } else {
        throw Exception('Error al obtener tipos de CECO');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> getOpciones() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/opciones/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Error al obtener opciones');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Crea un nuevo CECO Administrativo
  Future<Map<String, dynamic>> crearCecoAdministrativo(Map<String, dynamic> cecoData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

    if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/opciones/cecosadministrativos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(cecoData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear el CECO Administrativo');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Crea un nuevo CECO Productivo
  Future<Map<String, dynamic>> crearCecoProductivo(Map<String, dynamic> cecoData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/opciones/cecosproductivos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(cecoData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear el CECO Productivo');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Crea un nuevo CECO Maquinaria
  Future<Map<String, dynamic>> crearCecoMaquinaria(Map<String, dynamic> cecoData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/opciones/cecosmaquinaria'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(cecoData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear el CECO Maquinaria');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Crea un nuevo CECO Inversión
  Future<Map<String, dynamic>> crearCecoInversion(Map<String, dynamic> cecoData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/opciones/cecosinversion'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(cecoData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear el CECO Inversión');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Crea un nuevo CECO Riego
  Future<Map<String, dynamic>> crearCecoRiego(Map<String, dynamic> cecoData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/opciones/cecosriego'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(cecoData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear el CECO Riego');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Crea una nueva actividad
  Future<Map<String, dynamic>> crearActividad(Map<String, dynamic> actividadData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/actividades/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(actividadData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear la actividad');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCecosAdministrativos() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/administrativos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener CECOs administrativos');
    }
  }

  Future<List<Map<String, dynamic>>> getCecosProductivos() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/productivos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener CECOs productivos');
    }
  }

  Future<List<Map<String, dynamic>>> getCecosMaquinaria() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/maquinaria'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener CECOs maquinaria');
    }
  }

  Future<List<Map<String, dynamic>>> getCecosInversion() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/inversion'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener CECOs inversión');
    }
  }

  Future<List<Map<String, dynamic>>> getCecosRiego() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/riego'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener CECOs riego');
    }
  }

  /// Obtiene todos los tipos de inversión disponibles
  Future<List<Map<String, dynamic>>> getTiposInversion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/opciones/tiposinversion'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al obtener los tipos de inversión');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtiene las inversiones filtradas por el tipo seleccionado
  Future<List<Map<String, dynamic>>> getInversionesPorTipo(int idTipoInversion) async {
    try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/opciones/inversiones/$idTipoInversion'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al obtener las inversiones por tipo');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtiene los CECOs de inversión filtrados por el tipo seleccionado y la actividad
  Future<List<Map<String, dynamic>>> getCecosInversionPorTipoYActividad(int idTipoInversion, String idActividad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/inversion/$idTipoInversion/$idActividad'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los CECOs de inversión por tipo y actividad');
    }
  }

  /// Obtiene todos los tipos de maquinaria
  Future<List<Map<String, dynamic>>> getTiposMaquinaria(String idActividad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/tiposmaquinaria/actividad/$idActividad'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los tipos de maquinaria');
    }
  }

  /// Obtiene las maquinarias por tipo
  Future<List<Map<String, dynamic>>> getMaquinariasPorTipo(String idActividad, int idTipoMaquinaria) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/maquinarias/actividad/$idActividad/$idTipoMaquinaria'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener las maquinarias por tipo');
    }
  }

  /// Obtiene los CECOs de maquinaria filtrados por tipo, maquinaria y actividad
  Future<List<Map<String, dynamic>>> getCecosMaquinariaPorTipoMaquinariaYActividad(String idActividad, int idTipoMaquinaria, int idMaquinaria) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecosmaquinaria/actividad/$idActividad/$idTipoMaquinaria/$idMaquinaria'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los CECOs de maquinaria por tipo, maquinaria y actividad');
    }
  }

  /// Obtiene las casetas por sucursal de la actividad
  Future<List<Map<String, dynamic>>> getCasetasPorActividad(String idActividad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/casetas/actividad/$idActividad'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener las casetas por actividad');
    }
  }

  /// Obtiene los equipos de riego por caseta
  Future<List<Map<String, dynamic>>> getEquiposRiegoPorCaseta(String idCaseta) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/equiposriego/caseta/$idCaseta'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los equipos de riego por caseta');
    }
  }

  /// Obtiene los sectores de riego por equipo de riego
  Future<List<Map<String, dynamic>>> getSectoresRiegoPorEquipo(String idEquipoRiego) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/sectoresriego/equipo/$idEquipoRiego'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los sectores de riego por equipo');
    }
  }

  /// Obtiene los CECOs de riego por sucursal de la actividad
  Future<List<Map<String, dynamic>>> getCecosRiegoPorActividad(String idActividad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/riego/actividad/$idActividad'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los CECOs de riego por actividad');
    }
  }

  /// Obtiene las especies por sucursal de la actividad
  Future<List<Map<String, dynamic>>> getEspeciesPorActividad(String idActividad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/especies/actividad/$idActividad'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener las especies por actividad');
    }
  }

  /// Obtiene las variedades por especie y sucursal de la actividad
  Future<List<Map<String, dynamic>>> getVariedadesPorActividadYEspecie(String idActividad, String idEspecie) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/variedades/actividad/$idActividad/$idEspecie'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener las variedades por actividad y especie');
    }
  }

  /// Obtiene los cuarteles por actividad, especie y variedad
  Future<List<Map<String, dynamic>>> getCuartelesPorActividadYVariedad(String idActividad, String idEspecie, String idVariedad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cuarteles/actividad/$idActividad/$idEspecie/$idVariedad'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los cuarteles por actividad, especie y variedad');
    }
  }

  /// Obtiene los CECOs productivos por sucursal de la actividad
  Future<List<Map<String, dynamic>>> getCecosProductivosPorActividad(String idActividad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/productivos/actividad/$idActividad'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los CECOs productivos por actividad');
    }
  }

  Future<bool> eliminarActividad(String actividadId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/actividades/$actividadId'),
      headers: headers,
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return true;
    } else {
      print("❌ Error al eliminar actividad: ${response.body}");
      return false;
    }
  }

  // Crear rendimiento individual
  Future<Map<String, dynamic>> crearRendimientoIndividual(Map<String, dynamic> rendimiento) async {
    try {
    final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/rendimientos/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode([rendimiento]), // Enviar como lista
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al crear rendimiento individual: [31m${response.statusCode}[0m');
      }
    } catch (e) {
      throw Exception('Error al crear rendimiento individual: $e');
    }
  }

  // Crear rendimiento grupal
  Future<void> crearRendimientoGrupal(Map<String, dynamic> rendimiento) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/rendimientos/grupal'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id_actividad': rendimiento['id_actividad'],
          'rendimiento_total': rendimiento['rendimiento_total'],
          'cantidad_trab': rendimiento['cantidad_trab'],
          'id_porcentaje': rendimiento['id_porcentaje'],
        }),
      );
      if (response.statusCode != 201) {
        throw Exception('Error al crear rendimiento grupal: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al crear rendimiento grupal: $e');
    }
  }

  // Actualizar rendimiento individual
  Future<Map<String, dynamic>> actualizarRendimientoIndividual(String id, Map<String, dynamic> rendimiento) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/rendimientos/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(rendimiento),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al actualizar rendimiento individual: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al actualizar rendimiento individual: $e');
    }
  }

  // Actualizar rendimiento grupal
  Future<Map<String, dynamic>> actualizarRendimientoGrupal(String id, Map<String, dynamic> rendimiento) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/rendimientos/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(rendimiento),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al actualizar rendimiento grupal: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al actualizar rendimiento grupal: $e');
    }
  }

  // Obtener porcentajes de contratista
  Future<List<Map<String, dynamic>>> getPorcentajesContratista() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/porcentajescontratista'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Error al obtener los porcentajes de contratista');
    }
  }

  // Obtener un trabajador por su ID
  Future<Map<String, dynamic>?> getTrabajadorById(String idTrabajador) async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/trabajadores/$idTrabajador'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getRendimientosGrupales(int idActividad) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rendimientos_grupales?actividad_id=$idActividad'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Error al cargar rendimientos grupales: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al cargar rendimientos grupales: $e');
    }
  }

  Future<bool> eliminarRendimientoIndividual(String rendimientoId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/rendimientos/individual/$rendimientoId'),
        headers: await _getHeaders(),
      );
      await _manejarRespuesta(response);
      return response.statusCode == 200;
    } catch (e) {
      print('Error al eliminar rendimiento individual: $e');
      return false;
    }
  }

  Future<bool> eliminarRendimientoGrupal(String rendimientoId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/rendimientos/grupal/$rendimientoId'),
        headers: await _getHeaders(),
      );
      await _manejarRespuesta(response);
      return response.statusCode == 200;
    } catch (e) {
      print('Error al eliminar rendimiento grupal: $e');
      return false;
    }
  }

  // Rendimientos Individuales Propios
  Future<List<dynamic>> getRendimientosIndividualesPropios({String? idActividad}) async {
    try {
      final url = '$baseUrl/rendimientos/individual/propio${idActividad != null ? '?id_actividad=$idActividad' : ''}';
      print("🔍 Llamando a rendimientos individuales propios: $url");
      
      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      print("📥 Respuesta rendimientos individuales propios: ${response.statusCode} - ${response.body}");
    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
        final data = response.body.isEmpty ? [] : jsonDecode(response.body);
        // Remover la dependencia de bonos
        return data.map((item) {
          final map = Map<String, dynamic>.from(item);
          map.remove('id_bono');
          return map;
        }).toList();
    } else {
        print("❌ Error al obtener rendimientos individuales propios: ${response.statusCode} - ${response.body}");
        throw Exception('Error al obtener rendimientos individuales propios: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Error en getRendimientosIndividualesPropios: $e");
      throw Exception('Error al obtener rendimientos individuales propios: $e');
    }
  }

  // Crear rendimiento individual propio
  Future<bool> crearRendimientoIndividualPropio(Map<String, dynamic> rendimiento) async {
    final response = await http.post(
      Uri.parse("$baseUrl/rendimientos/individual/propio"),
      headers: await _getHeaders(),
      body: jsonEncode(rendimiento),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 201) {
      return true;
    } else {
      print("❌ Error en la API: ${response.body}");
      return false;
    }
  }

  Future<Map<String, dynamic>> actualizarRendimientoIndividualPropio(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/rendimientos/individual/propio/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      await _manejarRespuesta(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("❌ Error al actualizar rendimiento individual propio: ${response.statusCode} - ${response.body}");
        throw Exception('Error al actualizar rendimiento individual propio: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Error en actualizarRendimientoIndividualPropio: $e");
      throw Exception('Error al actualizar rendimiento individual propio: $e');
    }
  }

  // Eliminar rendimiento individual propio
  Future<bool> eliminarRendimientoIndividualPropio(String id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/rendimientos/individual/propio/$id"),
      headers: await _getHeaders(),
    );
    await _manejarRespuesta(response);
    return response.statusCode == 200;
  }

  // Rendimientos Individuales Contratistas
  Future<List<dynamic>> getRendimientosIndividualesContratistas() async {
    try {
      final url = '$baseUrl/rendimientos/individual/contratista';
      print("🔍 Llamando a rendimientos individuales contratistas: $url");

    final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      print("📥 Respuesta rendimientos individuales contratistas: ${response.statusCode} - ${response.body}");
      await _manejarRespuesta(response);

      if (response.statusCode == 200) {
        final data = response.body.isEmpty ? [] : jsonDecode(response.body);
        // Remover la dependencia de bonos
        return data.map((item) {
          final map = Map<String, dynamic>.from(item);
          map.remove('id_bono');
          return map;
        }).toList();
      } else {
        print("❌ Error al obtener rendimientos individuales contratistas: ${response.statusCode} - ${response.body}");
        throw Exception('Error al obtener rendimientos individuales contratistas: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Error en getRendimientosIndividualesContratistas: $e");
      throw Exception('Error al obtener rendimientos individuales contratistas: $e');
    }
  }

  // Crear rendimiento individual contratista
  Future<bool> crearRendimientoIndividualContratista(Map<String, dynamic> rendimiento) async {
    final response = await http.post(
      Uri.parse("$baseUrl/rendimientos/individual/contratista"),
      headers: await _getHeaders(),
      body: jsonEncode(rendimiento),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 201) {
      return true;
    } else {
      print("❌ Error en la API: ${response.body}");
      return false;
    }
  }

  Future<Map<String, dynamic>> actualizarRendimientoIndividualContratista(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/rendimientos/individual/contratista/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      await _manejarRespuesta(response);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("❌ Error al actualizar rendimiento individual contratista: ${response.statusCode} - ${response.body}");
        throw Exception('Error al actualizar rendimiento individual contratista: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Error en actualizarRendimientoIndividualContratista: $e");
      throw Exception('Error al actualizar rendimiento individual contratista: $e');
    }
  }

  // Eliminar rendimiento individual contratista
  Future<bool> eliminarRendimientoIndividualContratista(String id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/rendimientos/individual/contratista/$id"),
      headers: await _getHeaders(),
    );
    await _manejarRespuesta(response);
    return response.statusCode == 200;
  }

  // Tipos de inversión por actividad
  Future<List<Map<String, dynamic>>> getTiposInversionPorActividad(String idActividad) async {
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/tiposinversion/actividad/$idActividad'),
      headers: await _getHeaders(),
    );
    print('Respuesta tipos de inversión: \\${response.body}');
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener tipos de inversión');
    }
  }

  // Inversiones por actividad y tipo de inversión
  Future<List<Map<String, dynamic>>> getInversionesPorActividadYTipo(String idActividad, String idTipoInversion) async {
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/inversiones/actividad/$idActividad/$idTipoInversion'),
      headers: await _getHeaders(),
    );
    print('Respuesta inversiones: \\${response.body}');
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener inversiones');
    }
  }

  // Cecos por actividad, tipo de inversión e inversión
  Future<List<Map<String, dynamic>>> getCecosPorActividadTipoInversion(String idActividad, String idTipoInversion, String idInversion) async {
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecosinversion/actividad/$idActividad/$idTipoInversion/$idInversion'),
      headers: await _getHeaders(),
    );
    print('Respuesta cecos: \\${response.body}');
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener cecos');
    }
  }

  /// Obtiene los CECOs productivos por actividad, especie, variedad y cuartel
  Future<List<Map<String, dynamic>>> getCecosProductivosPorActividadEspecieVariedadYCuartel(String idActividad, String idEspecie, String idVariedad, String idCuartel) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecosproductivo/actividad/$idActividad/$idEspecie/$idVariedad/$idCuartel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los CECOs productivos por actividad, especie, variedad y cuartel');
    }
  }

  /// Obtiene trabajadores filtrados por sucursal y contratista
  Future<List<dynamic>> getTrabajadores(String idSucursal, String idContratista) async {
    if (idSucursal.isEmpty || idContratista.isEmpty) {
      throw Exception("⚠ Parámetros inválidos en getTrabajadores()");
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');

    final response = await http.get(
      Uri.parse('$baseUrl/trabajadores?id_sucursal=$idSucursal&id_contratista=$idContratista'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los trabajadores');
    }
  }

  /// Obtiene trabajadores de la sucursal del usuario logueado
  Future<List<Map<String, dynamic>>> getTrabajadoresPorSucursal() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');

    String? idSucursal = await getSucursalActiva();
    if (idSucursal == null) {
      throw Exception('No se pudo obtener la sucursal del usuario logueado.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/trabajadores?id_sucursal=$idSucursal'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los trabajadores');
    }
  }

  /// Crea un nuevo trabajador
  Future<bool> crearTrabajador(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');

    final response = await http.post(
      Uri.parse('$baseUrl/trabajadores'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al crear el trabajador');
    }
  }

  /// Edita un trabajador existente
  Future<bool> editarTrabajador(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('No se encontró el token');

    final response = await http.put(
      Uri.parse('$baseUrl/trabajadores/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al actualizar el trabajador');
    }
  }

  // ================= COLABORADORES =================
  Future<List<Map<String, dynamic>>> getColaboradores() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.get(
      Uri.parse('$baseUrl/colaboradores'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener los colaboradores');
    }
  }

  Future<Map<String, dynamic>> crearColaborador(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.post(
      Uri.parse('$baseUrl/colaboradores/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(data),
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al crear colaborador: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> editarColaborador(String id, Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.put(
      Uri.parse('$baseUrl/colaboradores/$id'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(data),
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al editar colaborador: ${response.body}');
    }
  }

  // ================= PERMISOS DE COLABORADORES =================
  Future<List<Map<String, dynamic>>> getPermisos() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.get(
      Uri.parse('$baseUrl/permisos'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener los permisos');
    }
  }

  Future<Map<String, dynamic>> crearPermiso(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.post(
      Uri.parse('$baseUrl/permisos/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(data),
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al crear permiso: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> editarPermiso(int id, Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.put(
      Uri.parse('$baseUrl/permisos/$id'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(data),
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al editar permiso: ${response.body}');
    }
  }

  Future<bool> eliminarPermiso(String id) async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.delete(
      Uri.parse('$baseUrl/permisos/$id'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Error al eliminar permiso: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getTiposPermiso() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.get(
      Uri.parse('$baseUrl/permisos/tipos'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener los tipos de permiso');
    }
  }

  Future<Map<String, dynamic>> getPermiso(String id) async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.get(
      Uri.parse('$baseUrl/permisos/$id'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener el permiso');
    }
  }

  Future<void> actualizarPermiso(String id, Map<String, dynamic> permiso) async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    final response = await http.put(
      Uri.parse('$baseUrl/permisos/$id'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(permiso),
    );
    await _manejarRespuesta(response);
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar el permiso');
    }
  }

  Future<Map<String, dynamic>> _get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) {
      throw Exception('No hay token de autenticación');
    }

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error en la petición: ${response.body}');
    }
  }

  Future<void> _put(String endpoint, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) {
      throw Exception('No hay token de autenticación');
    }

    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Error en la petición: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getRendimientosPropios(String idActividad) async {
    final response = await _get('/rendimientopropio/actividad/$idActividad');
    return response;
  }

  Future<void> editarRendimientoPropio(String idRendimiento, Map<String, dynamic> datos) async {
    await _put('/rendimientopropio/$idRendimiento', datos);
  }

  Future<List<Map<String, dynamic>>> getActividadesConRendimientos() async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');

    final response = await http.get(
      Uri.parse('$baseUrl/rendimientopropio/actividades'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('La respuesta del backend debe ser una lista, pero recibimos: $data');
      }
    } else {
      throw Exception('Error al obtener actividades: ${response.body}');
    }
  }
}
