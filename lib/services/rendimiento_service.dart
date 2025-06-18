import 'package:app_lh_tarja/services/api_service.dart';
import 'package:app_lh_tarja/models/rendimiento_individual.dart';

class RendimientoService {
  final ApiService _apiService;

  RendimientoService(this._apiService);

  // Rendimientos Individuales Propios
  Future<List<RendimientoPropio>> getRendimientosIndividualesPropios() async {
    final data = await _apiService.getRendimientosIndividualesPropios();
    return data.map((json) => RendimientoPropio.fromJson(json)).toList();
  }

  Future<RendimientoPropio> crearRendimientoIndividualPropio(RendimientoPropio rendimiento) async {
    final data = await _apiService.crearRendimientoIndividualPropio(rendimiento.toJson());
    return RendimientoPropio.fromJson(data);
  }

  Future<RendimientoPropio> actualizarRendimientoIndividualPropio(String id, RendimientoPropio rendimiento) async {
    final data = await _apiService.actualizarRendimientoIndividualPropio(id, rendimiento.toJson());
    return RendimientoPropio.fromJson(data);
  }

  Future<bool> eliminarRendimientoIndividualPropio(String id) async {
    return await _apiService.eliminarRendimientoIndividualPropio(id);
  }

  // Rendimientos Individuales Contratistas
  Future<List<RendimientoContratista>> getRendimientosIndividualesContratistas() async {
    final data = await _apiService.getRendimientosIndividualesContratistas();
    return data.map((json) => RendimientoContratista.fromJson(json)).toList();
  }

  Future<RendimientoContratista> crearRendimientoIndividualContratista(RendimientoContratista rendimiento) async {
    final data = await _apiService.crearRendimientoIndividualContratista(rendimiento.toJson());
    return RendimientoContratista.fromJson(data);
  }

  Future<RendimientoContratista> actualizarRendimientoIndividualContratista(String id, RendimientoContratista rendimiento) async {
    final data = await _apiService.actualizarRendimientoIndividualContratista(id, rendimiento.toJson());
    return RendimientoContratista.fromJson(data);
  }

  Future<bool> eliminarRendimientoIndividualContratista(String id) async {
    return await _apiService.eliminarRendimientoIndividualContratista(id);
  }

  // Los métodos para rendimientos grupales se mantienen igual
} 