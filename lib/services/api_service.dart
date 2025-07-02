import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'login_services.dart';
import '../pages/login_page.dart';

// 🔧 Sistema de logging condicional
void logDebug(String message) {
  if (kDebugMode) {
    print(message);
  }
}

void logError(String message) {
  if (kDebugMode) {
    print("❌ $message");
  }
}

void logInfo(String message) {
  if (kDebugMode) {
    print("ℹ️ $message");
  }
}

class ApiService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  final String baseUrl = 'https://apilhtarja.lahornilla.cl/api';
  //final String baseUrl = 'http://192.168.1.60:5000/api';

  /// 🔹 Método para manejar token expirado
  Future<void> manejarTokenExpirado() async {
    try {
      logDebug("🔄 Token expirado, limpiando datos y redirigiendo al login...");
      
      // Limpiar todas las preferencias almacenadas
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Mostrar mensaje de confirmación si hay contexto disponible
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sesión expirada. Por favor, inicia sesión nuevamente.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Navegar al login y limpiar el stack de navegación
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      logError('Error al manejar token expirado: $e');
      // Si hay algún error, intentar navegar al login de todas formas
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    }
  }

  // Método para obtener el token almacenado en SharedPreferences
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token'); // Obtener el token almacenado correctamente
  }

  // Método para obtener el refresh token almacenado en SharedPreferences
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token'); // Obtener el refresh token almacenado
  }

  // ✅ Obtener headers con token
  Future<Map<String, String>> _getHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        logError("❌ No hay token de acceso");
        throw Exception('No hay token de acceso disponible');
      }

      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } catch (e) {
      logError("❌ Error al obtener headers: $e");
      throw Exception('Error al obtener headers: $e');
    }
  }

  Future<http.Response> _manejarRespuesta(http.Response response) async {
    // Solo manejar errores específicos de token expirado en el body
    if (response.statusCode != 401 && 
        response.body.isNotEmpty && 
        (response.body.toLowerCase().contains('token has expired') ||
         response.body.toLowerCase().contains('token expired') ||
         response.body.toLowerCase().contains('unauthorized'))) {
      await manejarTokenExpirado();
      throw Exception('Sesión expirada. Por favor, inicia sesión nuevamente.');
    }
    return response;
  }

  /// 🔹 Método helper para hacer peticiones HTTP con manejo automático de tokens expirados
  Future<http.Response> _makeRequest(Future<http.Response> Function() requestFunction) async {
    try {
      final response = await requestFunction();
      
      logDebug("🔍 Response status: ${response.statusCode}");
      logDebug("🔍 Response headers: ${response.headers}");
      logDebug("🔍 Response body: ${response.body}");
      
      // Si la respuesta es una redirección (3xx)
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          logDebug("🔄 Siguiendo redirección a: $redirectUrl");
          final redirectResponse = await http.get(
            Uri.parse(redirectUrl),
            headers: await _getHeaders(),
          );
          return await _manejarRespuesta(redirectResponse);
        }
      }
      
      // Si la respuesta es 401, intentar refresh del token
      if (response.statusCode == 401) {
        logDebug("🔄 Detectado error 401, intentando refresh del token...");
        bool refreshed = await AuthService().refreshToken();
        
        if (refreshed) {
          logDebug("✅ Token refresh exitoso, reintentando petición original...");
          // Reintentar la petición original con el nuevo token
          final retryResponse = await requestFunction();
          return await _manejarRespuesta(retryResponse);
        } else {
          // Si el refresh falla, manejar como token expirado
          await manejarTokenExpirado();
          throw Exception('Sesión expirada. Por favor, inicia sesión nuevamente.');
        }
      }

      // Verificar si la respuesta es HTML en lugar de JSON
      if (response.headers['content-type']?.toLowerCase().contains('text/html') == true) {
        logError("❌ Error: Respuesta HTML recibida cuando se esperaba JSON");
        throw Exception('Error de servidor: Se recibió HTML cuando se esperaba JSON');
      }
      
      return await _manejarRespuesta(response);
    } catch (e) {
      logError("❌ Error en _makeRequest: $e");
      
      // Si es un error de red o conexión, no manejar como token expirado
      if (e.toString().contains('Sesión expirada')) {
        rethrow;
      }
      
      // Verificar si es un error de conexión
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable')) {
        throw Exception('Error de conexión. Verifica tu conexión a internet.');
      }
      
      throw Exception('Error de conexión: $e');
    }
  }

  /// 🔹 Método para verificar si el token está expirado
  Future<bool> verificarTokenValido() async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/usuarios/sucursal-activa'), // Usar endpoint que existe
          headers: await _getHeaders(),
        );
      });
      return response.statusCode == 200;
    } catch (e) {
      // Si hay cualquier error, asumir que el token no es válido
      return false;
    }
  }

  /// 🔹 Método para cerrar sesión manualmente
  Future<void> cerrarSesion() async {
    try {
      // Limpiar todas las preferencias almacenadas
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Esto incluye token, refresh_token, y todos los demás datos

      // Mostrar mensaje de confirmación si hay contexto disponible
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sesión cerrada exitosamente.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Navegar al login y limpiar el stack de navegación
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      logError('Error al cerrar sesión: $e');
      // Si hay algún error, intentar navegar al login de todas formas
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    }
  }

  /// 🔹 Método para reintentar la petición si el token expira
  Future<http.Response> _retryRequest(http.Request request) async {
    try {
      logDebug("🔄 Token expirado, intentando refresh...");
      bool refreshed = await AuthService().refreshToken();
      
      if (refreshed) {
        logDebug("✅ Token refresh exitoso, reintentando petición...");
        final newHeaders = await _getHeaders();
        request.headers.clear();
        request.headers.addAll(newHeaders);
        return await http.Response.fromStream(await request.send());
      } else {
        logError("❌ Falló el refresh del token");
        throw Exception('Sesión expirada, inicia sesión nuevamente.');
      }
    } catch (e) {
      logError("❌ Error en retry request: $e");
      throw Exception('Sesión expirada, inicia sesión nuevamente.');
    }
  }

  //

  // Método para listar actividades con autenticación
  Future<List<dynamic>> getActividades() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/actividades/'),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener las actividades');
    }
  }

  // Método para crear una nueva actividad con autenticación
  Future<bool> createActividad(Map<String, dynamic> actividad) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/actividades/'),
        headers: await _getHeaders(),
        body: jsonEncode(actividad),
      );
    });

    if (response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Error al crear la actividad');
    }
  }

  // Metodo para editar una actividad
  Future<Map<String, dynamic>> editarActividad(
      String actividadId, Map<String, dynamic> datos) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/actividades/$actividadId'),
        headers: await _getHeaders(),
        body: jsonEncode(datos),
      );
    });

    logDebug("🔍 Respuesta de editar actividad: ${response.statusCode} - ${response.body}");

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
      logDebug("🔍 Llamando a rendimientos grupales: $urlGrupal");

      final responseGrupal = await _makeRequest(() async {
        return await http.get(
          Uri.parse(urlGrupal),
          headers: await _getHeaders(),
        );
      });

      logDebug("📥 Respuesta rendimientos grupales: ${responseGrupal.statusCode} - ${responseGrupal.body}");

      if (responseGrupal.statusCode == 200) {
        final data = json.decode(responseGrupal.body);
        if (data['rendimientos'] != null) {
          final rendimientos = List<Map<String, dynamic>>.from(data['rendimientos']);
          data['rendimientos'] = rendimientos;
        }
        return data;
      } else {
        logError("❌ Error al obtener rendimientos grupales: ${responseGrupal.statusCode} - ${responseGrupal.body}");
        throw Exception('Error al obtener rendimientos grupales: ${responseGrupal.statusCode}');
      }
    } catch (e) {
      logError("❌ Error en getRendimientos: $e");
      throw Exception('Error al obtener rendimientos: $e');
    }
  }

  /// 📌 Crear un nuevo rendimiento
  Future<bool> createRendimientos(List<Map<String, dynamic>> rendimientos) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse("$baseUrl/rendimientos/"),
        headers: await _getHeaders(),
        body: jsonEncode(rendimientos),
      );
    });

    if (response.statusCode == 201) {
      return true;
    } else {
      logError("❌ Error en la API: ${response.body}");
      return false;
    }
  }

  /// 📌 Editar un rendimiento existente
  Future<bool> editarRendimiento(String id, Map<String, dynamic> rendimiento) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse("$baseUrl/rendimientos/$id"),
        headers: await _getHeaders(),
        body: jsonEncode(rendimiento),
      );
    });

    if (response.statusCode == 200) {
      return true;
    } else {
      logError("❌ Error en la API: ${response.body}");
      return false;
    }
  }

  /// 📌 Eliminar un rendimiento
  Future<bool> eliminarRendimiento(String id) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse("$baseUrl/rendimientos/$id"),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200) {
      return true;
    } else {
      logError("❌ Error en la API: ${response.body}");
      return false;
    }
  }

  // 🔹 Obtener sucursal activa del usuario logueado
  Future<String?> getSucursalActiva() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/usuarios/sucursal-activa'), // ← este es el correcto
        headers: await _getHeaders(),
      );
    });

    logDebug("🔍 Respuesta API Sucursal Activa: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      logInfo("✅ Sucursal activa obtenida: ${data["sucursal_activa"]}");
      return data["sucursal_activa"].toString();
    } else {
      logError("❌ Error al obtener sucursal activa: ${response.body}");
      return null;
    }
  }

  Future<bool> actualizarSucursalActiva(String nuevaSucursalId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/usuarios/sucursal-activa'),
        headers: await _getHeaders(),
        body: jsonEncode({"id_sucursal": nuevaSucursalId}),
      );
    });

    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> cambiarClave(
      String claveActual, String nuevaClave) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse("$baseUrl/auth/cambiar-clave"), // ✅ URL corregida
        headers: await _getHeaders(),
        body: jsonEncode({"clave_actual": claveActual, "nueva_clave": nuevaClave}),
      );
    });

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

    logDebug("🔍 Respuesta API CECOs: ${response.body}");

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
    final token = prefs.getString('access_token');
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
    logDebug("📤 Intentando crear contratista con datos: $contratistaData");
    
    try {
      // Asegurarnos que la URL termina con /
      final url = '$baseUrl/contratistas/';
      logDebug("🔍 URL de la petición: $url");
      
      final response = await _makeRequest(() async {
        return await http.post(
          Uri.parse(url),
          headers: {
            ...(await _getHeaders()),
            'Accept': 'application/json',
          },
          body: jsonEncode(contratistaData),
        );
      });

      logDebug("📥 Respuesta crear contratista - Status: ${response.statusCode}");
      logDebug("📥 Respuesta crear contratista - Headers: ${response.headers}");
      logDebug("📥 Respuesta crear contratista - Body: ${response.body}");

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        logInfo("✅ Contratista creado exitosamente: $responseData");
        return responseData;
      } else {
        logError("❌ Error al crear contratista: ${response.statusCode} - ${response.body}");
        throw Exception('Error al crear el contratista: ${response.body}');
      }
    } catch (e) {
      logError("❌ Excepción al crear contratista: $e");
      throw Exception('Error al crear el contratista: $e');
    }
  }

  /// Actualiza un contratista existente
  Future<Map<String, dynamic>> updateContratista(String id, Map<String, dynamic> contratistaData) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/contratistas/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(contratistaData),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      logError("❌ Error al actualizar contratista: ${response.statusCode} - ${response.body}");
      throw Exception('Error al actualizar el contratista: ${response.body}');
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
      final token = prefs.getString('access_token');

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
        
        // Si el backend devuelve un array directamente (caso especial)
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        
        // Manejar tanto boolean como string para el campo success
        final success = data['success'];
        if (success == true || success == "true" || success == 1) {
          return List<Map<String, dynamic>>.from(data['sucursales'] ?? []);
        } else {
          throw Exception(data['error'] ?? 'Error al obtener las sucursales');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al obtener las sucursales');
    }
    } catch (e) {
      logError('❌ Error al cargar sucursales disponibles: $e');
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

  Future<String?> crearUsuario({
    required String usuario,
    required String correo,
    required String clave,
    required int idSucursalActiva,
    String? idColaborador,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final Map<String, dynamic> userData = {
      'usuario': usuario,
      'correo': correo,
      'clave': clave,
      'id_sucursalactiva': idSucursalActiva,
    };

    if (idColaborador != null) {
      userData['id_colaborador'] = idColaborador;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(userData),
      );

      await _manejarRespuesta(response);

      if (response.statusCode == 201) {
        // Intentar obtener el ID del usuario creado de la respuesta
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map<String, dynamic> && responseData.containsKey('id')) {
            return responseData['id'].toString();
          }
        } catch (e) {
          logError('No se pudo obtener el ID del usuario creado: $e');
        }
        return null; // Si no se puede obtener el ID, retornar null
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear el usuario');
      }
    } catch (e) {
      logError("❌ Error al crear usuario: $e");
      rethrow;
    }
  }

  Future<bool> editarUsuario(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      logInfo("✅ Usuario editado correctamente");
      return true;
    } else {
      logError("❌ Error al editar usuario: ${response.body}");
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
        final responseData = jsonDecode(response.body);
        
        // Si el backend devuelve un array directamente (caso especial)
        if (responseData is List) {
          return List<Map<String, dynamic>>.from(responseData);
        }
        
        // Manejar tanto boolean como string para el campo success
        final success = responseData['success'];
        if (success == true || success == "true" || success == 1) {
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
      final token = prefs.getString('access_token');

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
      final token = prefs.getString('access_token');

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
      final token = prefs.getString('access_token');

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
      final token = prefs.getString('access_token');

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
      final token = prefs.getString('access_token');

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
      final token = prefs.getString('access_token');

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
      final token = prefs.getString('access_token');

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
    final token = prefs.getString('access_token');

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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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

  /// Obtiene los equipos de riego por actividad y caseta
  Future<List<Map<String, dynamic>>> getEquiposRiegoPorActividadYCaseta(String idActividad, String idCaseta) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/equiposriego/actividad/$idActividad/$idCaseta'),
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
      throw Exception(error['error'] ?? 'Error al obtener los equipos de riego por actividad y caseta');
    }
  }

  /// Obtiene los sectores de riego por actividad y equipo
  Future<List<Map<String, dynamic>>> getSectoresRiegoPorActividadYEquipo(String idActividad, String idEquipo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/sectoresriego/actividad/$idActividad/$idEquipo'),
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
      throw Exception(error['error'] ?? 'Error al obtener los sectores de riego por actividad y equipo');
    }
  }

  /// Obtiene el CECO de riego por actividad, caseta, equipo y sector
  Future<Map<String, dynamic>?> getCecoRiegoPorActividadYCasetaYEquipoYSector(String idActividad, String idCaseta, String idEquipo, String idSector) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecosriego/actividad/$idActividad/$idCaseta/$idEquipo/$idSector'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else if (response.statusCode == 404) {
      // Si no se encuentra el CECO, retornar null
      return null;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener el CECO de riego');
    }
  }

  /// Obtiene las especies por sucursal de la actividad
  Future<List<Map<String, dynamic>>> getEspeciesPorActividad(String idActividad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
      logError("❌ Error al eliminar actividad: ${response.body}");
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
      logError('Error al eliminar rendimiento individual: $e');
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
      logError('Error al eliminar rendimiento grupal: $e');
      return false;
    }
  }

  // Rendimientos Individuales Propios
  Future<List<dynamic>> getRendimientosIndividualesPropios({String? idActividad}) async {
    try {
      final url = '$baseUrl/rendimientos/individual/propio${idActividad != null ? '?id_actividad=$idActividad' : ''}';
      logDebug("🔍 Llamando a rendimientos individuales propios: $url");
      
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

      logDebug("📥 Respuesta rendimientos individuales propios: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final data = response.body.isEmpty ? [] : jsonDecode(response.body);
        return data;
      } else {
        logError("❌ Error al obtener rendimientos individuales propios: ${response.statusCode} - ${response.body}");
        throw Exception('Error al obtener rendimientos individuales propios: ${response.statusCode}');
      }
    } catch (e) {
      logError("❌ Error en getRendimientosIndividualesPropios: $e");
      throw Exception('Error al obtener rendimientos individuales propios: $e');
    }
  }

  // Rendimientos Individuales Contratistas
  Future<List<dynamic>> getRendimientosIndividualesContratistas({String? idActividad, String? idContratista}) async {
    try {
      if (idActividad == null || idActividad.isEmpty) {
        logError("❌ Error: ID de actividad es requerido");
        throw Exception('ID de actividad es requerido');
      }
      
      if (idContratista == null || idContratista.isEmpty) {
        logError("❌ Error: ID de contratista es requerido");
        throw Exception('ID de contratista es requerido');
      }

      String url = '$baseUrl/rendimientos/individual/contratista';
      List<String> params = [];
      
      params.add('id_actividad=$idActividad');
      params.add('id_contratista=$idContratista');
      
      url += '?' + params.join('&');
      
      logDebug("🔍 ====== OBTENIENDO RENDIMIENTOS CONTRATISTAS ======");
      logDebug("🔍 URL: $url");
      logDebug("🔍 ID Actividad: $idActividad");
      logDebug("🔍 ID Contratista: $idContratista");
      
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

      logDebug("📥 Status Code: ${response.statusCode}");
      logDebug("📥 Headers: ${response.headers}");
      logDebug("📥 Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = response.body.isEmpty ? [] : jsonDecode(response.body);
        
        // Solo validar que los rendimientos correspondan a la actividad
        final rendimientosFiltrados = (data as List).where((r) {
          final coincideActividad = r['id_actividad'].toString() == idActividad;
          
          if (!coincideActividad) {
            logError("⚠️ Rendimiento con ID actividad incorrecto: ${r['id_actividad']} != $idActividad");
          }
          
          return coincideActividad;
        }).toList();
        
        logInfo("✅ Rendimientos totales recibidos: ${data.length}");
        logInfo("✅ Rendimientos filtrados: ${rendimientosFiltrados.length}");
        logDebug("✅ ====== FIN OBTENCIÓN RENDIMIENTOS CONTRATISTAS ======");
        
        return rendimientosFiltrados;
      } else {
        logError("❌ Error al obtener rendimientos individuales contratistas: ${response.statusCode} - ${response.body}");
        throw Exception('Error al obtener rendimientos individuales contratistas: ${response.statusCode}');
      }
    } catch (e) {
      logError("❌ Error en getRendimientosIndividualesContratistas: $e");
      throw Exception('Error al obtener rendimientos individuales contratistas: $e');
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
      logError("❌ Error en la API: ${response.body}");
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
        logError("❌ Error al actualizar rendimiento individual propio: ${response.statusCode} - ${response.body}");
        throw Exception('Error al actualizar rendimiento individual propio: ${response.statusCode}');
      }
    } catch (e) {
      logError("❌ Error en actualizarRendimientoIndividualPropio: $e");
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

  // Crear rendimiento individual contratista
  Future<bool> crearRendimientoIndividualContratista(Map<String, dynamic> rendimiento) async {
    try {
      logDebug('📤 Creando rendimiento contratista: $rendimiento');
      
      final response = await _makeRequest(() async {
        return await http.post(
          Uri.parse("$baseUrl/rendimientos/individual/contratista"),
          headers: await _getHeaders(),
          body: jsonEncode(rendimiento),
        );
      });

      logDebug('📥 Respuesta: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201) {
        return true;
      } else {
        logError("❌ Error en la API: ${response.body}");
        throw Exception('Error al crear rendimiento: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      logError("❌ Error al crear rendimiento contratista: $e");
      throw Exception('Error al crear rendimiento: $e');
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
        logError("❌ Error al actualizar rendimiento individual contratista: ${response.statusCode} - ${response.body}");
        throw Exception('Error al actualizar rendimiento individual contratista: ${response.statusCode}');
      }
    } catch (e) {
      logError("❌ Error en actualizarRendimientoIndividualContratista: $e");
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
    logDebug('Respuesta tipos de inversión: \\${response.body}');
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
    logDebug('Respuesta inversiones: \\${response.body}');
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
    logDebug('Respuesta cecos: \\${response.body}');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    final token = prefs.getString('access_token');
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
    logDebug("📤 Intentando crear trabajador con datos: $data");
    
    try {
      final url = '$baseUrl/trabajadores/';
      logDebug("🔍 URL de la petición: $url");
      
      final response = await _makeRequest(() async {
        return await http.post(
          Uri.parse(url),
          headers: {
            ...(await _getHeaders()),
            'Accept': 'application/json',
          },
          body: jsonEncode(data),
        );
      });

      logDebug("📥 Respuesta crear trabajador - Status: ${response.statusCode}");
      logDebug("📥 Respuesta crear trabajador - Headers: ${response.headers}");
      logDebug("📥 Respuesta crear trabajador - Body: ${response.body}");

      if (response.statusCode == 201) {
        logInfo("✅ Trabajador creado exitosamente");
        return true;
      } else {
        logError("❌ Error al crear trabajador: ${response.statusCode} - ${response.body}");
        throw Exception('Error al crear el trabajador: ${response.body}');
      }
    } catch (e) {
      logError("❌ Excepción al crear trabajador: $e");
      throw Exception('Error al crear el trabajador: $e');
    }
  }

  /// Edita un trabajador existente
  Future<bool> editarTrabajador(String id, Map<String, dynamic> data) async {
    logDebug("📤 Intentando editar trabajador ${id} con datos: $data");
    
    try {
      final url = '$baseUrl/trabajadores/$id';
      logDebug("🔍 URL de la petición: $url");
      
      final response = await _makeRequest(() async {
        return await http.put(
          Uri.parse(url),
          headers: {
            ...(await _getHeaders()),
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(data),
        );
      });

      logDebug("📥 Respuesta editar trabajador - Status: ${response.statusCode}");
      logDebug("📥 Respuesta editar trabajador - Headers: ${response.headers}");
      logDebug("📥 Respuesta editar trabajador - Body: ${response.body}");

      if (response.statusCode == 200) {
        return true;
      } else {
        logError("❌ Error al actualizar trabajador: ${response.statusCode} - ${response.body}");
        throw Exception('Error al actualizar el trabajador: ${response.body}');
      }
    } catch (e) {
      logError("❌ Excepción al actualizar trabajador: $e");
      throw Exception('Error al actualizar el trabajador: $e');
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
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/colaboradores/'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      logError("❌ Error al crear colaborador: ${response.statusCode} - ${response.body}");
      throw Exception('Error al crear colaborador: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> editarColaborador(String id, Map<String, dynamic> data) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/colaboradores/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      logError("❌ Error al editar colaborador: ${response.statusCode} - ${response.body}");
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
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/permisos/'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      logError("❌ Error al crear permiso: ${response.statusCode} - ${response.body}");
      throw Exception('Error al crear permiso: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> editarPermiso(int id, Map<String, dynamic> data) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/permisos/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      logError("❌ Error al editar permiso: ${response.statusCode} - ${response.body}");
      throw Exception('Error al editar permiso: ${response.body}');
    }
  }

  Future<bool> eliminarPermiso(String id) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/permisos/$id'),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200) {
      return true;
    } else {
      logError("❌ Error al eliminar permiso: ${response.statusCode} - ${response.body}");
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
    final token = prefs.getString('access_token');
    
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
    final token = prefs.getString('access_token');
    
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

  /// 🔹 Método para verificar si el token está próximo a expirar y hacer refresh proactivo
  Future<bool> verificarYRefreshToken() async {
    try {
      // Primero verificar si hay token
      final token = await getToken();
      if (token == null) {
        logError("❌ No hay token disponible");
        return false;
      }

      // Usar un endpoint simple para verificar si el token es válido
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/usuarios/sucursal-activa'),
          headers: await _getHeaders(),
        );
      });
      
      // Si la petición fue exitosa, el token es válido
      return response.statusCode == 200;
    } catch (e) {
      logError("🔄 Error al verificar token: $e");
      
      // Solo intentar refresh si el error es de autenticación
      if (e.toString().contains('401') || 
          e.toString().contains('token') || 
          e.toString().contains('Token')) {
        
        logDebug("🔄 Token puede estar expirado, intentando refresh proactivo...");
        try {
          bool refreshed = await AuthService().refreshToken();
          
          if (refreshed) {
            logDebug("✅ Refresh proactivo exitoso");
            return true;
          } else {
            logError("❌ Refresh proactivo falló");
            return false;
          }
        } catch (refreshError) {
          logError("❌ Error en refresh: $refreshError");
          return false;
        }
      }
      
      // Si no es un error de autenticación, asumir que el token es válido
      // (puede ser un error de red o servidor)
      logInfo("⚠️ Error no relacionado con autenticación, asumiendo token válido");
      return true;
    }
  }

  // Obtener sucursales para usuarios (nuevo endpoint)
  Future<List<Map<String, dynamic>>> getSucursalesUsuarios() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/sucursales'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Error al obtener las sucursales para usuarios');
    }
  }

  // Obtener sucursales permitidas de un usuario específico
  Future<List<Map<String, dynamic>>> getSucursalesPermitidasUsuario(String usuarioId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/$usuarioId/sucursales-permitidas'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Error al obtener las sucursales permitidas del usuario');
    }
  }

  // Asignar sucursales permitidas a un usuario
  Future<void> asignarSucursalesPermitidas(String usuarioId, List<int> sucursalesIds) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/$usuarioId/sucursales-permitidas'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "sucursales_ids": sucursalesIds,
      }),
    );

    await _manejarRespuesta(response);

    if (response.statusCode != 200) {
      throw Exception('Error al asignar sucursales permitidas al usuario');
    }
  }

  // Eliminar todas las sucursales permitidas de un usuario
  Future<void> eliminarSucursalesPermitidas(String usuarioId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/usuarios/$usuarioId/sucursales-permitidas'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar las sucursales permitidas del usuario');
    }
  }

  // Obtener todas las aplicaciones disponibles
  Future<List<Map<String, dynamic>>> getAplicaciones() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/apps'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Error al obtener las aplicaciones disponibles');
    }
  }

  // Obtener aplicaciones permitidas de un usuario específico
  Future<List<Map<String, dynamic>>> getAplicacionesPermitidasUsuario(String usuarioId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/$usuarioId/apps-permitidas'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Error al obtener las aplicaciones permitidas del usuario');
    }
  }

  // Asignar aplicaciones permitidas a un usuario
  Future<void> asignarAplicacionesPermitidas(String usuarioId, List<int> aplicacionesIds) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/$usuarioId/apps-permitidas'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "apps_ids": aplicacionesIds,
      }),
    );

    await _manejarRespuesta(response);

    if (response.statusCode != 200) {
      throw Exception('Error al asignar aplicaciones permitidas al usuario');
    }
  }

  // Eliminar todas las aplicaciones permitidas de un usuario
  Future<void> eliminarAplicacionesPermitidas(String usuarioId) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/usuarios/$usuarioId/apps-permitidas'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar las aplicaciones permitidas del usuario');
    }
  }

  Future<void> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      
      if (refreshToken == null) {
        logError("❌ No hay refresh token almacenado");
        throw Exception('No hay refresh token disponible');
      }

      logDebug("🔄 Intentando refrescar token...");
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );

      logDebug("📡 Código de respuesta refresh: ${response.statusCode}");
      logDebug("📝 Respuesta del servidor refresh: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        logInfo("✅ Token refrescado exitosamente");
      } else {
        logError("❌ Error en refresh token - Código: ${response.statusCode}");
        logError("❌ Detalle del error refresh: ${response.body}");
        
        // Si el refresh token expiró, limpiar tokens y redirigir al login
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
        throw Exception('Sesión expirada. Por favor, inicia sesión nuevamente.');
      }
    } catch (e) {
      logError("❌ Error en refreshToken: $e");
      throw Exception('Error al refrescar el token: $e');
    }
  }

  /// 🔹 Obtener la unidad por defecto de una labor específica
  Future<Map<String, dynamic>?> getUnidadDefaultLabor(String idLabor) async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/opciones/labor/$idLabor/unidad-default'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Si no hay unidad por defecto, devolver null
        if (data['unidad_default'] == null) {
          return null;
        }
        return {
          'id_unidad_default': data['id_unidad_default'],
          'unidad_default': data['unidad_default'],
        };
      } else if (response.statusCode == 404) {
        // Endpoint no existe, devolver null silenciosamente
        logInfo("ℹ️ Endpoint de unidad por defecto no disponible para labor $idLabor");
        return null;
      } else {
        logError("❌ Error al obtener unidad por defecto: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      // Si es un error de conexión, asumir que el endpoint no existe
      if (e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')) {
        logInfo("ℹ️ Endpoint de unidad por defecto no disponible para labor $idLabor");
        return null;
      }
      logError("❌ Error en getUnidadDefaultLabor: $e");
      return null;
    }
  }

}
