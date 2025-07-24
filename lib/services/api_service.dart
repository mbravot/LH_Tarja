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
  //final String baseUrl = 'https://apilhtarja.lahornilla.cl/api';
  final String baseUrl = 'http://192.168.1.37:5000/api';

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

  //Metodo para actualizar la sucursal activa
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

  //Metodo para cambiar la clave
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

  //Metodo para obtener las opciones
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

  //Metodo para refrescar el token
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

}
