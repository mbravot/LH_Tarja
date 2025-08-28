import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  const String baseUrl = 'https://apilhtarja-927498545444.us-central1.run.app/api';
  
  // Obtener token
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  
  if (token == null) {
    print("❌ No se encontró token");
    return;
  }
  
  print("🔍 Token: ${token.substring(0, 20)}...");
  
  // Probar endpoint de cuarteles productivos
  print("\n🔍 Probando endpoint de cuarteles productivos...");
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/actividades_multiples/cuarteles-productivos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");
  } catch (e) {
    print("Error: $e");
  }
  
  // Probar endpoint de sectores de riego
  print("\n🔍 Probando endpoint de sectores de riego...");
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/actividades_multiples/sectores-riego'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");
  } catch (e) {
    print("Error: $e");
  }
  
  // Probar endpoint alternativo de cuarteles
  print("\n🔍 Probando endpoint alternativo de cuarteles...");
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/cuarteles/actividad/123'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");
  } catch (e) {
    print("Error: $e");
  }
  
  // Probar endpoint alternativo de sectores
  print("\n🔍 Probando endpoint alternativo de sectores...");
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/opciones/sectoresriego/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");
  } catch (e) {
    print("Error: $e");
  }
}
