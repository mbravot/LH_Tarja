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
  // Comentado para mejorar rendimiento
  // print("🔍 $message");
}

void logError(String message) {
  // Solo mostrar errores críticos en producción
  // if (kDebugMode) {
  //   print("❌ $message");
  // }
}

void logInfo(String message) {
  // Comentado para mejorar rendimiento
  // print("ℹ️ $message");
}

class ApiService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  final String baseUrl = 'https://apilhtarja-927498545444.us-central1.run.app/api';
  //final String baseUrl = 'http://192.168.1.52:5000/api';

  // ===== CACHES EN MEMORIA PARA REDUCIR LLAMADAS =====
  Map<String, bool>? _cacheIdsConRendimientos;
  List<Map<String, dynamic>>? _cacheActividades;
  DateTime? _cacheRendimientosAt;
  DateTime? _cacheActividadesAt;
  final Duration _cacheTTL = Duration(minutes: 2);
  Future<List<Map<String, dynamic>>>? _ongoingActividadesConRendOptimized;
  
  void _invalidateActividadesRendimientosCache() {
    _cacheIdsConRendimientos = null;
    _cacheActividades = null;
    _cacheRendimientosAt = null;
    _cacheActividadesAt = null;
  }

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

  /// 🔹 Método para verificar y manejar token expirado al inicio de la app
  Future<bool> verificarTokenAlInicio() async {
    try {
      final token = await getToken();
      if (token == null) {
        return false;
      }

      // Verificar si el token es válido haciendo una petición simple
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/sucursal-activa'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 401) {
        await manejarTokenExpirado();
        return false;
      }

      return response.statusCode == 200;
    } catch (e) {
      logError('Error al verificar token al inicio: $e');
      // Si hay error de conexión, no cerrar sesión automáticamente
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable')) {
        return true; // Mantener la sesión si es error de red
      }
      
      // Para otros errores, asumir que el token no es válido
      await manejarTokenExpirado();
      return false;
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
    // Manejar errores de token expirado
    if (response.statusCode == 401 || 
        (response.body.isNotEmpty && 
         (response.body.toLowerCase().contains('token has expired') ||
          response.body.toLowerCase().contains('token expired') ||
          response.body.toLowerCase().contains('unauthorized')))) {
      await manejarTokenExpirado();
      throw Exception('Sesión expirada. Por favor, inicia sesión nuevamente.');
    }
    return response;
  }

  /// 🔹 Método helper para hacer peticiones HTTP con manejo automático de tokens expirados
  Future<http.Response> _makeRequest(Future<http.Response> Function() requestFunction) async {
    try {
      final response = await requestFunction();
      
      // Log solo en caso de error para debugging
      
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

  // Método para verificar si una actividad tiene rendimientos
  Future<bool> actividadTieneRendimientos(String idActividad) async {
    try {
      // Verificar rendimientos individuales propios
      final urlPropio = '$baseUrl/rendimientos/individual/propio?id_actividad=$idActividad';
      final responsePropio = await _makeRequest(() async {
        return await http.get(
          Uri.parse(urlPropio),
          headers: await _getHeaders(),
        );
      });

      if (responsePropio.statusCode == 200) {
        final rendimientosPropios = responsePropio.body.isEmpty ? [] : jsonDecode(responsePropio.body);
        
        // Verificar que los rendimientos correspondan a la actividad específica
        if (rendimientosPropios is List) {
          final rendimientosFiltrados = rendimientosPropios.where((r) {
            if (r is Map && r.containsKey('id_actividad')) {
              return r['id_actividad'].toString() == idActividad;
            }
            return false;
          }).toList();
          
          if (rendimientosFiltrados.isNotEmpty) {
            return true;
          }
        }
      }

      // Verificar rendimientos individuales de contratistas
      final urlContratista = '$baseUrl/rendimientos/individual/contratista?id_actividad=$idActividad';
      final responseContratista = await _makeRequest(() async {
        return await http.get(
          Uri.parse(urlContratista),
          headers: await _getHeaders(),
        );
      });

      if (responseContratista.statusCode == 200) {
        final rendimientosContratistas = responseContratista.body.isEmpty ? [] : jsonDecode(responseContratista.body);
        
        // Verificar que los rendimientos correspondan a la actividad específica
        if (rendimientosContratistas is List) {
          final rendimientosFiltrados = rendimientosContratistas.where((r) {
            if (r is Map && r.containsKey('id_actividad')) {
              return r['id_actividad'].toString() == idActividad;
            }
            return false;
          }).toList();
          
          if (rendimientosFiltrados.isNotEmpty) {
            return true;
          }
        }
      }

      // Verificar rendimientos grupales
      final urlGrupal = '$baseUrl/rendimientos/$idActividad';
      final responseGrupal = await _makeRequest(() async {
        return await http.get(
          Uri.parse(urlGrupal),
          headers: await _getHeaders(),
        );
      });

      if (responseGrupal.statusCode == 200) {
        final dataGrupal = responseGrupal.body.isEmpty ? {} : jsonDecode(responseGrupal.body);
        
        if (dataGrupal is Map && dataGrupal.containsKey('rendimientos')) {
          final rendimientosGrupales = dataGrupal['rendimientos'];
          
          if (rendimientosGrupales is List && rendimientosGrupales.isNotEmpty) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      // logError("❌ Error al verificar rendimientos para actividad $idActividad: $e");
      return false;
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

            // logDebug("🔍 Respuesta de editar actividad: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {"error": "No se pudo actualizar la actividad: ${response.body}"};
    }
  }

  // Metodo para editar una actividad múltiple
  Future<Map<String, dynamic>> editarActividadMultiple(
      dynamic actividadId, Map<String, dynamic> datos) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/actividades_multiples/$actividadId'),
        headers: await _getHeaders(),
        body: jsonEncode(datos),
      );
    });

          // print("🔍 Respuesta de editar actividad múltiple: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {"error": "No se pudo actualizar la actividad múltiple: ${response.body}"};
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
              // logDebug("🔍 Llamando a rendimientos grupales: $urlGrupal");

      final responseGrupal = await _makeRequest(() async {
        return await http.get(
          Uri.parse(urlGrupal),
          headers: await _getHeaders(),
        );
      });

              // logDebug("📥 Respuesta rendimientos grupales: ${responseGrupal.statusCode} - ${responseGrupal.body}");

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
      // Invalida cache para que las actividades reflejen el nuevo estado de rendimientos
      _invalidateActividadesRendimientosCache();
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
      _invalidateActividadesRendimientosCache();
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
      _invalidateActividadesRendimientosCache();
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

            // logDebug("🔍 Respuesta API Sucursal Activa: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
              // logInfo("✅ Sucursal activa obtenida: ${data["sucursal_activa"]}");
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

            // logDebug("🔍 Respuesta API CECOs: ${response.body}");

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
  Future<bool> crearContratista(Map<String, dynamic> contratistaData) async {
    try {
      final url = '$baseUrl/contratistas/';
      final response = await _makeRequest(() async {
        return await http.post(
          Uri.parse(url),
          headers: await _getHeaders(),
          body: jsonEncode(contratistaData),
        );
      });

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        // logInfo("✅ Contratista creado exitosamente: $responseData");
        return true;
      } else {
        logError("❌ Error al crear contratista: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      logError("❌ Error en crearContratista: $e");
      return false;
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
              // logInfo("✅ Usuario editado correctamente");
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

  /// Obtiene todos los cuarteles disponibles para una actividad
  Future<List<Map<String, dynamic>>> getCuartelesPorActividad(String idActividad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cuarteles/actividad/$idActividad'),
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
      throw Exception(error['error'] ?? 'Error al obtener los cuarteles por actividad');
    }
  }

  /// Obtiene los CECOs productivos disponibles para un cuartel específico
  Future<List<Map<String, dynamic>>> getCecosProductivosPorCuartel(String idActividad, String idCuartel) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/productivos/cuartel/$idActividad/$idCuartel'),
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
      throw Exception(error['error'] ?? 'Error al obtener los CECOs productivos por cuartel');
    }
  }

  /// Obtiene las variedades disponibles para un cuartel específico
  Future<List<Map<String, dynamic>>> getVariedadesPorCuartel(String idActividad, String idCuartel) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/variedades/cuartel/$idActividad/$idCuartel'),
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
      throw Exception(error['error'] ?? 'Error al obtener las variedades por cuartel');
    }
  }

  /// Obtiene las especies disponibles para un cuartel específico
  Future<List<Map<String, dynamic>>> getEspeciesPorCuartel(String idActividad, String idCuartel) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/especies/cuartel/$idActividad/$idCuartel'),
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
      throw Exception(error['error'] ?? 'Error al obtener las especies por cuartel');
    }
  }

  /// Obtiene todos los equipos de riego disponibles para una actividad
  Future<List<Map<String, dynamic>>> getEquiposRiegoPorActividad(String idActividad) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/equipos_riego/actividad/$idActividad'),
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
      throw Exception(error['error'] ?? 'Error al obtener los equipos de riego por actividad');
    }
  }

  /// Obtiene todos los sectores de riego disponibles
  Future<List<Map<String, dynamic>>> getSectoresRiego() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/sectoresriego/'),
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
      throw Exception(error['error'] ?? 'Error al obtener los sectores de riego');
    }
  }

  /// Obtiene los sectores de riego disponibles para una actividad múltiple
  Future<List<Map<String, dynamic>>> getSectoresRiegoPorActividad(String idActividad) async {
    try {
          // print("🔍 Intentando obtener sectores de riego para actividad múltiple: $idActividad");
    // print("🔍 URL del endpoint: $baseUrl/actividades_multiples/sectores-riego");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw Exception('No se encontró el token');
      
      // print("🔍 Token obtenido: ${token.substring(0, 20)}...");
      
      // Intentar primero con el nuevo endpoint específico para actividades múltiples
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/actividades_multiples/sectores-riego'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        // print("🔍 Status code de la respuesta: ${response.statusCode}");
        // print("🔍 Body de la respuesta: ${response.body}");
        
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          // print("✅ Sectores de riego obtenidos del nuevo endpoint: ${data.length}");
          // for (var sector in data) {
          //   print("  - ${sector['nombre_sector']} (ID: ${sector['id_sectorriego']})");
          // }
          return data.cast<Map<String, dynamic>>();
        } else {
          // print("❌ Nuevo endpoint falló, intentando con endpoint alternativo...");
          throw Exception('Endpoint no disponible');
        }
      } catch (e) {
        // print("❌ Error con nuevo endpoint: $e");
        // print("🔄 Intentando con endpoint alternativo...");
        
        // Si el nuevo endpoint falla, usar el endpoint existente como fallback
        final response = await http.get(
          Uri.parse('$baseUrl/opciones/sectoresriego/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        // print("🔍 Status code del endpoint alternativo: ${response.statusCode}");
        // print("🔍 Body del endpoint alternativo: ${response.body}");
        
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          // print("✅ Sectores de riego obtenidos del endpoint alternativo: ${data.length}");
          // for (var sector in data) {
          //   print("  - ${sector['nombre']} (ID: ${sector['id']})");
          // }
          return data.cast<Map<String, dynamic>>();
        } else {
          final error = jsonDecode(response.body);
          // print("❌ Error del servidor: ${error['error'] ?? 'Error desconocido'}");
          throw Exception(error['error'] ?? 'Error al obtener los sectores de riego');
        }
      }
    } catch (e) {
      // print("❌ Error al obtener sectores de riego: $e");
      throw Exception('Error al obtener los sectores de riego por actividad: $e');
    }
  }

  /// Crea un CECO de riego para una actividad múltiple usando el nuevo endpoint
  Future<Map<String, dynamic>> crearCecoRiegoMultiple(Map<String, dynamic> cecoData) async {
    try {
      // print("🔍 Creando CECO de riego para actividad múltiple: ${cecoData['id_actividad']}");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw Exception('No se encontró el token');
      
      // Usar el nuevo endpoint específico para actividades múltiples
      final response = await http.post(
        Uri.parse('$baseUrl/actividades_multiples/ceco-riego'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(cecoData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        // print("✅ CECO de riego creado exitosamente: ${result['message']}");
        return result;
      } else {
        final error = jsonDecode(response.body);
        // print("❌ Error del servidor: ${error['error'] ?? 'Error desconocido'}");
        throw Exception(error['error'] ?? 'Error al crear el CECO de riego');
      }
    } catch (e) {
      // print("❌ Error al crear CECO de riego: $e");
      throw Exception('Error al crear el CECO de riego: $e');
    }
  }

  /// Obtiene los CECOs de riego disponibles para un sector específico
  Future<List<Map<String, dynamic>>> getCecosRiegoPorSector(String idActividad, String idSector) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cecos/riego/sector/$idActividad/$idSector'),
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
      throw Exception(error['error'] ?? 'Error al obtener los CECOs de riego por sector');
    }
  }

  /// Obtiene las casetas disponibles para un sector específico
  Future<List<Map<String, dynamic>>> getCasetasPorSector(String idActividad, String idSector) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/casetas/sector/$idActividad/$idSector'),
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
      throw Exception(error['error'] ?? 'Error al obtener las casetas por sector');
    }
  }

  /// Obtiene los equipos de riego disponibles para un sector específico
  Future<List<Map<String, dynamic>>> getEquiposRiegoPorSector(String idActividad, String idSector) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/equipos_riego/sector/$idActividad/$idSector'),
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
      throw Exception(error['error'] ?? 'Error al obtener los equipos de riego por sector');
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
      // Invalida cache para que la actividad refleje el nuevo estado
      _invalidateActividadesRendimientosCache();
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

  Future<List<Map<String, dynamic>>> getRendimientosGrupalesPorActividad(int idActividad) async {
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
      
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

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
      
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

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
      final response = await _makeRequest(() async {
        return await http.post(
          Uri.parse('$baseUrl/rendimientos/individual/contratista'),
          headers: await _getHeaders(),
          body: jsonEncode(rendimiento),
        );
      });

      if (response.statusCode == 201) {
        return true;
      } else {
        logError("❌ Error al crear rendimiento contratista: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      logError("❌ Error al crear rendimiento: $e");
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
            // logDebug('Respuesta tipos de inversión: \\${response.body}');
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
            // logDebug('Respuesta inversiones: \\${response.body}');
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
            // logDebug('Respuesta cecos: \\${response.body}');
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
    try {
      final url = '$baseUrl/trabajadores/';
      final response = await _makeRequest(() async {
        return await http.post(
          Uri.parse(url),
          headers: await _getHeaders(),
          body: jsonEncode(data),
        );
      });

      if (response.statusCode == 201) {
        // logInfo("✅ Trabajador creado exitosamente");
        return true;
      } else {
        logError("❌ Error al crear trabajador: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      logError("❌ Error en crearTrabajador: $e");
      return false;
    }
  }

  /// Edita un trabajador existente
  Future<bool> editarTrabajador(String id, Map<String, dynamic> data) async {
    try {
      final url = '$baseUrl/trabajadores/$id';
      final response = await _makeRequest(() async {
        return await http.put(
          Uri.parse(url),
          headers: await _getHeaders(),
          body: jsonEncode(data),
        );
      });

      if (response.statusCode == 200) {
        // logInfo("✅ Trabajador editado exitosamente");
        return true;
      } else {
        logError("❌ Error al editar trabajador: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      logError("❌ Error en editarTrabajador: $e");
      return false;
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

  Future<List<Map<String, dynamic>>> getActividadesPermisos([String? fecha]) async {
    final token = await getToken();
    if (token == null) throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    
    String url = '$baseUrl/permisos/actividades';
    if (fecha != null) {
      url += '?fecha=$fecha';
    }
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    await _manejarRespuesta(response);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener las actividades para permisos');
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
        
        // logDebug("🔄 Token puede estar expirado, intentando refresh proactivo...");
        try {
          bool refreshed = await AuthService().refreshToken();
          
          if (refreshed) {
            // logDebug("✅ Refresh proactivo exitoso");
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
                // logInfo("⚠️ Error no relacionado con autenticación, asumiendo token válido");
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

              // logDebug("🔄 Intentando refrescar token...");
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );

              // logDebug("📡 Código de respuesta refresh: ${response.statusCode}");
        // logDebug("📝 Respuesta del servidor refresh: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        // logInfo("✅ Token refrescado exitosamente");
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
        // logInfo("ℹ️ Endpoint de unidad por defecto no disponible para labor $idLabor");
        return null;
      } else {
        logError("❌ Error al obtener unidad por defecto: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      // Si es un error de conexión, asumir que el endpoint no existe
      if (e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')) {
        // logInfo("ℹ️ Endpoint de unidad por defecto no disponible para labor $idLabor");
        return null;
      }
      logError("❌ Error en getUnidadDefaultLabor: $e");
      return null;
    }
  }

  // Método optimizado para obtener todas las actividades con información de rendimientos
  Future<List<Map<String, dynamic>>> getActividadesConRendimientosOptimizado() async {
    // De-duplicar llamadas concurrentes
    if (_ongoingActividadesConRendOptimized != null) {
      return _ongoingActividadesConRendOptimized!;
    }

    // Si caches son válidos, devolver desde memoria
    final now = DateTime.now();
    final cacheActividadesValida = _cacheActividades != null && _cacheActividadesAt != null && now.difference(_cacheActividadesAt!) < _cacheTTL;
    final cacheRendimientosValida = _cacheIdsConRendimientos != null && _cacheRendimientosAt != null && now.difference(_cacheRendimientosAt!) < _cacheTTL;
    if (cacheActividadesValida && cacheRendimientosValida) {
      final actividades = _cacheActividades!.map((a) => Map<String, dynamic>.from(a)).toList();
      for (var actividad in actividades) {
        actividad['tiene_rendimientos_cache'] = _cacheIdsConRendimientos![actividad['id'].toString()] ?? false;
      }
      return actividades;
    }

    _ongoingActividadesConRendOptimized = (() async {
      try {
        // Lanzar ambas peticiones en paralelo
        final headers = await _getHeaders();
        final actividadesFuture = http.get(Uri.parse('$baseUrl/actividades/'), headers: headers);
        final rendTodosFuture = http.get(Uri.parse('$baseUrl/rendimientos/todos'), headers: headers);

        final actividadesResponse = await actividadesFuture;
        if (actividadesResponse.statusCode != 200) {
          throw Exception('Error al cargar actividades');
        }
        final actividades = (jsonDecode(actividadesResponse.body) as List).cast<Map<String, dynamic>>();

        Map<String, bool> actividadesConRendimientos = {};
        final rendimientosResponse = await rendTodosFuture;
        if (rendimientosResponse.statusCode == 200) {
          final dynamic data = jsonDecode(rendimientosResponse.body);
          // Recolector genérico de ids
          void collectIds(dynamic node) {
            if (node is Map) {
              if (node.containsKey('id_actividad') && node['id_actividad'] != null) {
                actividadesConRendimientos[node['id_actividad'].toString()] = true;
              }
              for (final v in node.values) collectIds(v);
            } else if (node is List) {
              for (final item in node) collectIds(item);
            }
          }
          collectIds(data);
          _cacheIdsConRendimientos = actividadesConRendimientos;
          _cacheRendimientosAt = now;

          // Paso adicional: para actividades que aún no aparecen con rendimientos,
          // consultar rendimientos grupales específicos (minimiza llamadas)
          for (final actividad in actividades) {
            final id = actividad['id'].toString();
            if (!actividadesConRendimientos.containsKey(id)) {
              try {
                final respGrupal = await http.get(
                  Uri.parse('$baseUrl/rendimientos/$id'),
                  headers: headers,
                );
                if (respGrupal.statusCode == 200 && respGrupal.body.isNotEmpty) {
                  final dataGrupal = jsonDecode(respGrupal.body);
                  if (dataGrupal is Map && dataGrupal['rendimientos'] is List) {
                    final list = dataGrupal['rendimientos'] as List;
                    if (list.isNotEmpty) {
                      actividadesConRendimientos[id] = true;
                    }
                  }
                }
              } catch (_) {
                // Silencioso; continuamos con siguiente actividad
              }
            }
          }
        } else {
          // Fallback barato: consultar solo rendimientos individuales (2 endpoints) en paralelo
          try {
            final propiosFuture = http.get(Uri.parse('$baseUrl/rendimientos/individual/propio'), headers: headers);
            final contratistasFuture = http.get(Uri.parse('$baseUrl/rendimientos/individual/contratista'), headers: headers);
            final propiosResp = await propiosFuture;
            final contratistasResp = await contratistasFuture;

            if (propiosResp.statusCode == 200) {
              final list = propiosResp.body.isEmpty ? [] : jsonDecode(propiosResp.body);
              if (list is List) {
                for (final r in list) {
                  if (r is Map && r['id_actividad'] != null) {
                    actividadesConRendimientos[r['id_actividad'].toString()] = true;
                  }
                }
              }
            }
            if (contratistasResp.statusCode == 200) {
              final list = contratistasResp.body.isEmpty ? [] : jsonDecode(contratistasResp.body);
              if (list is List) {
                for (final r in list) {
                  if (r is Map && r['id_actividad'] != null) {
                    actividadesConRendimientos[r['id_actividad'].toString()] = true;
                  }
                }
              }
            }
            _cacheIdsConRendimientos = actividadesConRendimientos;
            _cacheRendimientosAt = now;
          } catch (_) {
            // Si todo falla, mantener mapa vacío y continuar sin etiquetar
            _cacheIdsConRendimientos = {};
            _cacheRendimientosAt = now;
          }
        }

        // Guardar cache de actividades
        _cacheActividades = actividades.map((a) => Map<String, dynamic>.from(a)).toList();
        _cacheActividadesAt = now;

        // Mezclar flag en las actividades a devolver
        for (var actividad in actividades) {
          actividad['tiene_rendimientos_cache'] = _cacheIdsConRendimientos![actividad['id'].toString()] ?? false;
        }

        return actividades;
      } catch (e) {
        logError('❌ Error al cargar actividades con rendimientos optimizado: $e');
        rethrow;
      } finally {
        _ongoingActividadesConRendOptimized = null;
      }
    })();

    return _ongoingActividadesConRendOptimized!;
  }

  // Método alternativo que usa endpoints existentes pero de manera más eficiente
  Future<List<Map<String, dynamic>>> getActividadesConRendimientosEficiente() async {
    try {
      // Obtener actividades
      final actividadesResponse = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/actividades/'),
          headers: await _getHeaders(),
        );
      });

      if (actividadesResponse.statusCode != 200) {
        throw Exception('Error al cargar actividades');
      }

      final actividades = jsonDecode(actividadesResponse.body) as List;
      
      // Obtener todos los rendimientos individuales propios en una sola llamada
      final rendimientosPropiosResponse = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/rendimientos/individual/propio'),
          headers: await _getHeaders(),
        );
      });

      // Obtener todos los rendimientos individuales de contratistas en una sola llamada
      final rendimientosContratistasResponse = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/rendimientos/individual/contratista'),
          headers: await _getHeaders(),
        );
      });

      // Crear un set de IDs de actividades que tienen rendimientos
      Set<String> actividadesConRendimientos = {};
      
      // Procesar rendimientos propios
      if (rendimientosPropiosResponse.statusCode == 200) {
        final rendimientosPropios = rendimientosPropiosResponse.body.isEmpty ? [] : jsonDecode(rendimientosPropiosResponse.body);
        if (rendimientosPropios is List) {
          for (var rendimiento in rendimientosPropios) {
            if (rendimiento['id_actividad'] != null) {
              actividadesConRendimientos.add(rendimiento['id_actividad'].toString());
            }
          }
        }
      }

      // Procesar rendimientos de contratistas
      if (rendimientosContratistasResponse.statusCode == 200) {
        final rendimientosContratistas = rendimientosContratistasResponse.body.isEmpty ? [] : jsonDecode(rendimientosContratistasResponse.body);
        if (rendimientosContratistas is List) {
          for (var rendimiento in rendimientosContratistas) {
            if (rendimiento['id_actividad'] != null) {
              actividadesConRendimientos.add(rendimiento['id_actividad'].toString());
            }
          }
        }
      }

      // Procesar rendimientos grupales (hacer llamadas solo para las actividades que no tienen rendimientos individuales)
      for (var actividad in actividades) {
        String actividadId = actividad['id'].toString();
        if (!actividadesConRendimientos.contains(actividadId)) {
          try {
            final rendimientosGrupalesResponse = await _makeRequest(() async {
              return await http.get(
                Uri.parse('$baseUrl/rendimientos/$actividadId'),
                headers: await _getHeaders(),
              );
            });

            if (rendimientosGrupalesResponse.statusCode == 200) {
              final dataGrupal = rendimientosGrupalesResponse.body.isEmpty ? {} : jsonDecode(rendimientosGrupalesResponse.body);
              if (dataGrupal is Map && dataGrupal.containsKey('rendimientos')) {
                final rendimientosGrupales = dataGrupal['rendimientos'];
                if (rendimientosGrupales is List && rendimientosGrupales.isNotEmpty) {
                  actividadesConRendimientos.add(actividadId);
                }
              }
            }
          } catch (e) {
            // Si hay error, continuar con la siguiente actividad
            continue;
          }
        }
      }

      // Agregar información de rendimientos a cada actividad
      for (var actividad in actividades) {
        actividad['tiene_rendimientos_cache'] = actividadesConRendimientos.contains(actividad['id'].toString());
      }

      return actividades.cast<Map<String, dynamic>>();
    } catch (e) {
      // logError("❌ Error al cargar actividades con rendimientos eficiente: $e");
      rethrow;
    }
  }

  // Método para obtener todos los rendimientos en una sola llamada
  Future<Map<String, dynamic>> getAllRendimientos() async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/rendimientos/todos'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al cargar rendimientos');
      }
    } catch (e) {
      logError("❌ Error al obtener todos los rendimientos: $e");
      rethrow;
    }
  }

  // Método para obtener indicadores de control de horas por colaborador
  Future<List<Map<String, dynamic>>> getIndicadoresControlHoras({
    String? fechaInicio,
    String? fechaFin,
    String? idColaborador,
  }) async {
    try {
      // Construir URL con parámetros opcionales
      String url = '$baseUrl/indicadores/control-horas/resumen-diario-colaborador';
      List<String> params = [];
      
      if (fechaInicio != null) {
        params.add('fecha_inicio=$fechaInicio');
      }
      if (fechaFin != null) {
        params.add('fecha_fin=$fechaFin');
      }
      if (idColaborador != null) {
        params.add('id_colaborador=$idColaborador');
      }
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else {
          return [];
        }
      } else {
        logError("❌ Error al obtener indicadores de control de horas: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      logError("❌ Error al obtener indicadores de control de horas: $e");
      return [];
    }
  }

  // Método para obtener actividades de un colaborador específico
  Future<List<Map<String, dynamic>>> getActividadesColaborador({
    required String idColaborador,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    try {
      String url = '$baseUrl/indicadores/control-horas/actividades-colaborador';
      List<String> params = ['id_colaborador=$idColaborador'];
      
      if (fechaInicio != null) {
        params.add('fecha_inicio=$fechaInicio');
      }
      if (fechaFin != null) {
        params.add('fecha_fin=$fechaFin');
      }
      
      url += '?${params.join('&')}';

      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else {
          return [];
        }
      } else {
        logError("❌ Error al obtener actividades del colaborador: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      logError("❌ Error al obtener actividades del colaborador: $e");
      return [];
    }
  }

  // ================= INDICADORES: CONTROL DE RENDIMIENTOS =================
  
  // 1. Rendimientos Individuales (propios y contratistas)
  Future<List<Map<String, dynamic>>> getRendimientosIndividuales({
    String? fechaInicio,
    String? fechaFin,
    String? idTipoRendimiento,
    String? idLabor,
    String? idCeco,
    String? idTrabajador,
    String? idUnidad,
    String? tipoMo,
  }) async {
    try {
      String url = '$baseUrl/indicadores/control-rendimientos/individuales';
      final params = <String>[];
      if (fechaInicio != null) params.add('fecha_inicio=$fechaInicio');
      if (fechaFin != null) params.add('fecha_fin=$fechaFin');
      if (idTipoRendimiento != null) params.add('id_tiporendimiento=$idTipoRendimiento');
      if (idLabor != null) params.add('id_labor=$idLabor');
      if (idCeco != null) params.add('id_ceco=$idCeco');
      if (idTrabajador != null) params.add('id_trabajador=$idTrabajador');
      if (idUnidad != null) params.add('id_unidad=$idUnidad');
      if (tipoMo != null) params.add('tipo_mo=$tipoMo');
      if (params.isNotEmpty) url += '?'+params.join('&');

      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error rendimientos individuales: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error rendimientos individuales: $e');
      return [];
    }
  }

  // 2. Rendimientos Grupales (contratistas)
  Future<List<Map<String, dynamic>>> getRendimientosGrupales({
    String? fechaInicio,
    String? fechaFin,
    String? idTipoRendimiento,
    String? idLabor,
    String? idCeco,
    String? idUnidad,
    String? grupoMo,
  }) async {
    try {
      String url = '$baseUrl/indicadores/control-rendimientos/grupales';
      final params = <String>[];
      if (fechaInicio != null) params.add('fecha_inicio=$fechaInicio');
      if (fechaFin != null) params.add('fecha_fin=$fechaFin');
      if (idTipoRendimiento != null) params.add('id_tiporendimiento=$idTipoRendimiento');
      if (idLabor != null) params.add('id_labor=$idLabor');
      if (idCeco != null) params.add('id_ceco=$idCeco');
      if (idUnidad != null) params.add('id_unidad=$idUnidad');
      if (grupoMo != null) params.add('grupo_mo=$grupoMo');
      if (params.isNotEmpty) url += '?'+params.join('&');

      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error rendimientos grupales: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error rendimientos grupales: $e');
      return [];
    }
  }

  // 3. Resumen Agregado de todos los tipos
  Future<List<Map<String, dynamic>>> getResumenRendimientos({
    String? fechaInicio,
    String? fechaFin,
    String? idTipoRendimiento,
    String? idLabor,
    String? idCeco,
    String? idUnidad,
    String? tipoMo,
  }) async {
    try {
      String url = '$baseUrl/indicadores/control-rendimientos/resumen';
      final params = <String>[];
      if (fechaInicio != null) params.add('fecha_inicio=$fechaInicio');
      if (fechaFin != null) params.add('fecha_fin=$fechaFin');
      if (idTipoRendimiento != null) params.add('id_tiporendimiento=$idTipoRendimiento');
      if (idLabor != null) params.add('id_labor=$idLabor');
      if (idCeco != null) params.add('id_ceco=$idCeco');
      if (idUnidad != null) params.add('id_unidad=$idUnidad');
      if (tipoMo != null) params.add('tipo_mo=$tipoMo');
      if (params.isNotEmpty) url += '?'+params.join('&');

      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error resumen rendimientos: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error resumen rendimientos: $e');
      return [];
    }
  }

  // Método legacy (mantener por compatibilidad)
  Future<List<Map<String, dynamic>>> getIndicadoresControlRendimientos({
    String? fechaInicio,
    String? fechaFin,
    String? idTipoRendimiento,
    String? idLabor,
    String? idCeco,
    String? idTrabajador,
  }) async {
    try {
      String url = '$baseUrl/indicadores/control-horas/resumen-rendimientos';
      final params = <String>[];
      if (fechaInicio != null) params.add('fecha_inicio=$fechaInicio');
      if (fechaFin != null) params.add('fecha_fin=$fechaFin');
      if (idTipoRendimiento != null) params.add('id_tiporendimiento=$idTipoRendimiento');
      if (idLabor != null) params.add('id_labor=$idLabor');
      if (idCeco != null) params.add('id_ceco=$idCeco');
      if (idTrabajador != null) params.add('id_trabajador=$idTrabajador');
      if (params.isNotEmpty) url += '?'+params.join('&');

      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse(url),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error indicador control rendimientos: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error indicador control rendimientos: $e');
      return [];
    }
  }

  // ===== ACTIVIDADES MÚLTIPLES =====
  
  /// 🔹 Obtener actividades múltiples del usuario autenticado
  Future<List<Map<String, dynamic>>> getActividadesMultiples() async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/actividades_multiples/'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error obtener actividades múltiples: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error obtener actividades múltiples: $e');
      return [];
    }
  }

  /// 🔹 Crear nueva actividad múltiple
  Future<Map<String, dynamic>> crearActividadMultiple(Map<String, dynamic> datos) async {
    try {
      final response = await _makeRequest(() async {
        return await http.post(
          Uri.parse('$baseUrl/actividades_multiples/'),
          headers: await _getHeaders(),
          body: jsonEncode(datos),
        );
      });

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        logInfo('✅ Actividad múltiple creada exitosamente');
        return {
          'success': true,
          'id_actividad': responseData['id_actividad']?.toString() ?? '',
          'data': responseData,
        };
      }
      
      // Manejar errores específicos
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error'] ?? errorData['detail'] ?? 'Error al crear actividad múltiple';
      logError('❌ Error crear actividad múltiple: ${response.statusCode} - $errorMessage');
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      logError('❌ Error crear actividad múltiple: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 🔹 Eliminar actividad múltiple
  Future<bool> eliminarActividadMultiple(dynamic actividadId) async {
    try {
      // print("🔍 Intentando eliminar actividad múltiple con ID: $actividadId");
      // print("🔍 Tipo de ID: ${actividadId.runtimeType}");
      // print("🔍 URL del endpoint: $baseUrl/actividades_multiples/$actividadId");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw Exception('No se encontró el token');
      
      // print("🔍 Token obtenido: ${token.substring(0, 20)}...");
      
      final response = await http.delete(
        Uri.parse('$baseUrl/actividades_multiples/$actividadId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // print("🔍 Status code de la respuesta: ${response.statusCode}");
      // print("🔍 Body de la respuesta: ${response.body}");

      if (response.statusCode == 200) {
        // print("✅ Actividad múltiple eliminada exitosamente");
        return true;
      } else {
        final errorBody = response.body;
        // print("❌ Error eliminar actividad múltiple: ${response.statusCode} - $errorBody");
        return false;
      }
    } catch (e) {
      // print("❌ Error eliminar actividad múltiple: $e");
      return false;
    }
  }

  /// 🔹 Obtener tipos CECO para actividades múltiples
  Future<List<Map<String, dynamic>>> getTiposCeco() async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/tipos_ceco/'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error obtener tipos CECO: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error obtener tipos CECO: $e');
      return [];
    }
  }

  /// 🔹 Obtener cuarteles productivos disponibles para actividades múltiples
  Future<List<Map<String, dynamic>>> getCuartelesProductivosPorActividad(String idActividad) async {
    try {
      // print("🔍 Intentando obtener cuarteles productivos para actividad múltiple: $idActividad");
      // print("🔍 URL del endpoint: $baseUrl/actividades_multiples/cuarteles-productivos");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw Exception('No se encontró el token');
      
      // print("🔍 Token obtenido: ${token.substring(0, 20)}...");
      
      // Intentar primero con el nuevo endpoint específico para actividades múltiples
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/actividades_multiples/cuarteles-productivos'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        // print("🔍 Status code de la respuesta: ${response.statusCode}");
        // print("🔍 Body de la respuesta: ${response.body}");
        
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          // print("✅ Cuarteles productivos obtenidos del nuevo endpoint: ${data.length}");
          // for (var cuartel in data) {
          //   print("  - ${cuartel['nombre_cuartel']} (ID: ${cuartel['id_cuartel']})");
          // }
          return data.cast<Map<String, dynamic>>();
        } else {
          // print("❌ Nuevo endpoint falló, intentando con endpoint alternativo...");
          throw Exception('Endpoint no disponible');
        }
      } catch (e) {
        // print("❌ Error con nuevo endpoint: $e");
        // print("🔄 Intentando con endpoint alternativo...");
        
        // Si el nuevo endpoint falla, usar el endpoint existente como fallback
        final response = await http.get(
          Uri.parse('$baseUrl/opciones/cuarteles/actividad/$idActividad'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        // print("🔍 Status code del endpoint alternativo: ${response.statusCode}");
        // print("🔍 Body del endpoint alternativo: ${response.body}");
        
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          // print("✅ Cuarteles productivos obtenidos del endpoint alternativo: ${data.length}");
          // for (var cuartel in data) {
          //   print("  - ${cuartel['nombre']} (ID: ${cuartel['id']})");
          // }
          return data.cast<Map<String, dynamic>>();
        } else {
          final error = jsonDecode(response.body);
          // print("❌ Error del servidor: ${error['error'] ?? 'Error desconocido'}");
          throw Exception(error['error'] ?? 'Error al obtener los cuarteles productivos');
        }
      }
    } catch (e) {
      // print("❌ Error al obtener cuarteles productivos: $e");
      throw Exception('Error al obtener los cuarteles productivos por actividad: $e');
    }
  }

  /// 🔹 Crear un CECO productivo para una actividad múltiple (cuartel individual)
  Future<Map<String, dynamic>> crearCecoProductivoMultiple(Map<String, dynamic> cecoData) async {
    try {
      // print("🔍 Creando CECO productivo para actividad múltiple: ${cecoData['id_actividad']}");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw Exception('No se encontró el token');
      
      // Usar el nuevo endpoint específico para actividades múltiples
      final response = await http.post(
        Uri.parse('$baseUrl/actividades_multiples/ceco-productivo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(cecoData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        // print("✅ CECO productivo creado exitosamente: ${result['message']}");
        return result;
      } else {
        final error = jsonDecode(response.body);
        // print("❌ Error del servidor: ${error['error'] ?? 'Error desconocido'}");
        throw Exception(error['error'] ?? 'Error al crear el CECO productivo');
      }
    } catch (e) {
      // print("❌ Error al crear CECO productivo: $e");
      throw Exception('Error al crear el CECO productivo: $e');
    }
  }

  /// 🔹 Crear múltiples CECOs productivos para una actividad múltiple (múltiples cuarteles)
  Future<Map<String, dynamic>> crearCecoProductivoMultipleBulk(Map<String, dynamic> cecoData) async {
    try {
      // print("🔍 Creando múltiples CECOs productivos para actividad múltiple: ${cecoData['id_actividad']}");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw Exception('No se encontró el token');
      
      // Usar el nuevo endpoint específico para actividades múltiples
      final response = await http.post(
        Uri.parse('$baseUrl/actividades_multiples/ceco-productivo-multiple'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(cecoData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        // print("✅ Múltiples CECOs productivos creados exitosamente: ${result['message']}");
        return result;
      } else {
        final error = jsonDecode(response.body);
        // print("❌ Error del servidor: ${error['error'] ?? 'Error desconocido'}");
        throw Exception(error['error'] ?? 'Error al crear los CECOs productivos');
      }
    } catch (e) {
      // print("❌ Error al crear múltiples CECOs productivos: $e");
      throw Exception('Error al crear los CECOs productivos: $e');
    }
  }

  /// 🔹 Crear múltiples CECOs de riego para una actividad múltiple (múltiples sectores)
  Future<Map<String, dynamic>> crearCecoRiegoMultipleBulk(Map<String, dynamic> cecoData) async {
    try {
      // print("🔍 Creando múltiples CECOs de riego para actividad múltiple: ${cecoData['id_actividad']}");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw Exception('No se encontró el token');
      
      // Usar el nuevo endpoint específico para actividades múltiples
      final response = await http.post(
        Uri.parse('$baseUrl/actividades_multiples/ceco-riego-multiple'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(cecoData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        // print("✅ Múltiples CECOs de riego creados exitosamente: ${result['message']}");
        return result;
      } else {
        final error = jsonDecode(response.body);
        // print("❌ Error del servidor: ${error['error'] ?? 'Error desconocido'}");
        throw Exception(error['error'] ?? 'Error al crear los CECOs de riego');
      }
    } catch (e) {
      // print("❌ Error al crear múltiples CECOs de riego: $e");
      throw Exception('Error al crear los CECOs de riego: $e');
    }
  }

  /// 🔹 Obtener CECOs productivos asociados a una actividad múltiple
  Future<List<Map<String, dynamic>>> getCecosProductivosMultiple(String idActividad) async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/actividades_multiples/ceco-productivo/$idActividad'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error obtener CECOs productivos múltiples: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error obtener CECOs productivos múltiples: $e');
      return [];
    }
  }

  /// 🔹 Obtener CECOs de riego asociados a una actividad múltiple
  Future<List<Map<String, dynamic>>> getCecosRiegoMultiple(String idActividad) async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/actividades_multiples/ceco-riego/$idActividad'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error obtener CECOs de riego múltiples: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error obtener CECOs de riego múltiples: $e');
      return [];
    }
  }

  /// 🔹 Obtener actividades múltiples con CECOs y rendimientos asociados
  Future<List<Map<String, dynamic>>> getActividadesMultiplesConCecos() async {
    try {
      // Obtener actividades múltiples
      final actividades = await getActividadesMultiples();
      
      // Para cada actividad, obtener sus CECOs y rendimientos asociados
      for (var actividad in actividades) {
        final idActividad = actividad['id'].toString();
        
        try {
          // Obtener todos los CECOs de la actividad usando el método correcto
          final cecos = await getCecosActividadMultiple(idActividad);
          
          // Separar los CECOs por tipo
          final cecosProductivos = cecos.where((ceco) => 
            ceco['tipo_ceco']?.toString().toUpperCase() == 'PRODUCTIVO' ||
            ceco['nombre_tipoceco']?.toString().toUpperCase() == 'PRODUCTIVO'
          ).toList();
          
          final cecosRiego = cecos.where((ceco) => 
            ceco['tipo_ceco']?.toString().toUpperCase() == 'RIEGO' ||
            ceco['nombre_tipoceco']?.toString().toUpperCase() == 'RIEGO'
          ).toList();
          
          final cecosMaquinaria = cecos.where((ceco) => 
            ceco['tipo_ceco']?.toString().toUpperCase() == 'MAQUINARIA' ||
            ceco['nombre_tipoceco']?.toString().toUpperCase() == 'MAQUINARIA'
          ).toList();
          
          final cecosInversion = cecos.where((ceco) => 
            ceco['tipo_ceco']?.toString().toUpperCase() == 'INVERSION' ||
            ceco['nombre_tipoceco']?.toString().toUpperCase() == 'INVERSION'
          ).toList();
          
          final cecosAdministrativos = cecos.where((ceco) => 
            ceco['tipo_ceco']?.toString().toUpperCase() == 'ADMINISTRATIVO' ||
            ceco['nombre_tipoceco']?.toString().toUpperCase() == 'ADMINISTRATIVO'
          ).toList();
          
          // Asignar los CECOs a la actividad
          actividad['cecos_productivos'] = cecosProductivos;
          actividad['cecos_riego'] = cecosRiego;
          actividad['cecos_maquinaria'] = cecosMaquinaria;
          actividad['cecos_inversion'] = cecosInversion;
          actividad['cecos_administrativos'] = cecosAdministrativos;
          
        } catch (cecoError) {
          // Si hay error al obtener CECOs, inicializar como listas vacías
          logError('❌ Error obtener CECOs para actividad $idActividad: $cecoError');
          actividad['cecos_productivos'] = [];
          actividad['cecos_riego'] = [];
          actividad['cecos_maquinaria'] = [];
          actividad['cecos_inversion'] = [];
          actividad['cecos_administrativos'] = [];
        }
        
        // Obtener rendimientos múltiples
        try {
          final rendimientosMultiples = await getRendimientosMultiples(idActividad);
          actividad['rendimientos_multiples'] = rendimientosMultiples;
          actividad['tiene_rendimientos_multiples'] = rendimientosMultiples.isNotEmpty;
        } catch (rendimientoError) {
          logError('❌ Error obtener rendimientos para actividad $idActividad: $rendimientoError');
          actividad['rendimientos_multiples'] = [];
          actividad['tiene_rendimientos_multiples'] = false;
        }
      }
      
      return actividades;
    } catch (e) {
      logError('❌ Error obtener actividades múltiples con CECOs: $e');
      return [];
    }
  }

  // ===== ENDPOINTS PARA RENDIMIENTOS MÚLTIPLES =====

  /// 🔹 Obtener rendimientos múltiples de una actividad específica
  Future<List<Map<String, dynamic>>> getRendimientosMultiples(String idActividad) async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/rendimiento_multiple/actividad/$idActividad'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error obtener rendimientos múltiples: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error obtener rendimientos múltiples: $e');
      return [];
    }
  }

  /// 🔹 Obtener todos los rendimientos múltiples del usuario
  Future<List<Map<String, dynamic>>> getAllRendimientosMultiples() async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/rendimiento_multiple/'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error obtener todos los rendimientos múltiples: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error obtener todos los rendimientos múltiples: $e');
      return [];
    }
  }

  /// 🔹 Crear un nuevo rendimiento múltiple
  Future<Map<String, dynamic>> crearRendimientoMultiple(Map<String, dynamic> datos) async {
    try {
      // print('📤 Enviando datos para crear rendimientos múltiples: $datos');
      
      final response = await _makeRequest(() async {
        return await http.post(
          Uri.parse('$baseUrl/rendimiento_multiple/'),
          headers: await _getHeaders(),
          body: jsonEncode(datos),
        );
      });

      // print('📥 Respuesta del servidor: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear rendimientos múltiples');
      }
    } catch (e) {
      logError('❌ Error crear rendimientos múltiples: $e');
      throw Exception('Error al crear rendimientos múltiples: $e');
    }
  }

  /// 🔹 Editar un rendimiento múltiple existente
  Future<Map<String, dynamic>> editarRendimientoMultiple(String id, Map<String, dynamic> datos) async {
    try {
      final response = await _makeRequest(() async {
        return await http.put(
          Uri.parse('$baseUrl/rendimiento_multiple/$id'),
          headers: await _getHeaders(),
          body: jsonEncode(datos),
        );
      });

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al editar rendimiento múltiple');
      }
    } catch (e) {
      logError('❌ Error editar rendimiento múltiple: $e');
      throw Exception('Error al editar rendimiento múltiple: $e');
    }
  }

  /// 🔹 Eliminar un rendimiento múltiple
  Future<bool> eliminarRendimientoMultiple(String id) async {
    try {
      final response = await _makeRequest(() async {
        return await http.delete(
          Uri.parse('$baseUrl/rendimiento_multiple/$id'),
          headers: await _getHeaders(),
        );
      });

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      logError('❌ Error eliminar rendimiento múltiple: $e');
      return false;
    }
  }

  /// 🔹 Obtener colaboradores para rendimientos múltiples
  Future<List<Map<String, dynamic>>> getColaboradoresRendimientoMultiple() async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/rendimiento_multiple/colaboradores'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error obtener colaboradores rendimiento múltiple: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error obtener colaboradores rendimiento múltiple: $e');
      return [];
    }
  }

  /// 🔹 Obtener bonos para rendimientos múltiples
  Future<List<Map<String, dynamic>>> getBonosRendimientoMultiple() async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/rendimiento_multiple/bonos'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      }
      logError('❌ Error obtener bonos rendimiento múltiple: ${response.statusCode}');
      return [];
    } catch (e) {
      logError('❌ Error obtener bonos rendimiento múltiple: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCecosActividadMultiple(String idActividad) async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/rendimiento_multiple/cecos-actividad/$idActividad'),
          headers: await _getHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Error al obtener CECOs de la actividad: ${response.statusCode}');
      }
    } catch (e) {
      // print('❌ Error en getCecosActividadMultiple: $e');
      rethrow;
    }
  }

}
