import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';

class IndicadoresPage extends StatefulWidget {
  const IndicadoresPage({Key? key}) : super(key: key);

  @override
  _IndicadoresPageState createState() => _IndicadoresPageState();
}

class _IndicadoresPageState extends State<IndicadoresPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  // Variables para filtros
  String? _colaboradorSeleccionado;
  List<Map<String, dynamic>> _colaboradores = [];
  
  // Variables para datos
  bool _isLoading = false;
  List<Map<String, dynamic>> _indicadoresControlHoras = [];
  
  // Switch para mostrar solo diferencias en Control de Horas
  bool _mostrarSoloDiferencias = true;

  // ================= CONTROL RENDIMIENTOS =================
  // Variables para datos de rendimientos
  bool _isLoadingRend = false;
  List<Map<String, dynamic>> _rendimientosIndividuales = [];
  List<Map<String, dynamic>> _rendimientosGrupales = [];
  List<Map<String, dynamic>> _resumenRendimientos = [];
  
  // Filtros Control Rendimientos
  String? _rendTrabajador; // id_trabajador
  String? _rendTipoRendimiento; // tipo de rendimiento (Individual/Grupal)
  String? _rendTipoMo; // tipo_mo (Propio/Contratista)
  String? _rendLabor; // id_labor
  String? _rendCeco; // id_ceco
  String? _rendUnidad; // id_unidad
  String? _rendGrupoMo; // grupo_mo (para grupales)
  
  // Listas para filtros
  List<Map<String, dynamic>> _trabajadores = [];
  List<Map<String, dynamic>> _labores = [];
  List<Map<String, dynamic>> _cecos = [];
  List<Map<String, dynamic>> _unidades = [];
  List<Map<String, dynamic>> _gruposMo = [];
  
  // Variables para actividades expandibles
  String? _colaboradorExpandido;
  List<Map<String, dynamic>> _actividadesColaborador = [];
  bool _isLoadingActividades = false;
  
  // Variables para rendimientos expandibles
  String? _trabajadorExpandido;
  List<Map<String, dynamic>> _rendimientosDetalle = [];
  bool _isLoadingRendimientosDetalle = false;
  
  // Variables para el nuevo sistema de agrupación multi-nivel
  String? _grupoExpandido; // Para el primer nivel (dia-labor-tipo_mo)
  String? _cecoExpandido; // Para el segundo nivel (CECO)
  List<Map<String, dynamic>> _rendimientosPorCeco = [];
  List<Map<String, dynamic>> _rendimientosPorDetalleCeco = [];
  bool _isLoadingRendimientosPorCeco = false;
  bool _isLoadingRendimientosPorDetalleCeco = false;
  
  // Variables para el sistema de agrupación multi-nivel de rendimientos grupales
  String? _grupoGrupalExpandido; // Para el primer nivel (dia-labor-tipo_mo) de grupales
  String? _cecoGrupalExpandido; // Para el segundo nivel (CECO) de grupales
  List<Map<String, dynamic>> _rendimientosGrupalesPorCeco = [];
  List<Map<String, dynamic>> _rendimientosGrupalesPorDetalleCeco = [];
  bool _isLoadingRendimientosGrupalesPorCeco = false;
  bool _isLoadingRendimientosGrupalesPorDetalleCeco = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarColaboradores();
    _cargarIndicadores();
    _cargarDatosControlRendimientos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarColaboradores() async {
    try {
      final colaboradores = await _apiService.getColaboradores();
      setState(() {
        _colaboradores = colaboradores;
      });
    } catch (e) {
      setState(() {
        _colaboradores = [];
      });
    }
  }

  Future<void> _cargarIndicadores() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final indicadores = await _apiService.getIndicadoresControlHoras();
      setState(() {
        _indicadoresControlHoras = indicadores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _indicadoresControlHoras = [];
      });
    }
  }

  List<Map<String, dynamic>> _agruparRendimientosPorTrabajadorYDia() {
    Map<String, Map<String, dynamic>> grupos = {};
    
    // Combinar datos del resumen, individuales y grupales
    List<Map<String, dynamic>> todosLosRendimientos = [];
    todosLosRendimientos.addAll(_resumenRendimientos);
    
    for (var rendimiento in todosLosRendimientos) {
      final fecha = rendimiento['fecha']?.toString() ?? '';
      final tipoMo = rendimiento['tipo_mo']?.toString() ?? '';
      final labor = rendimiento['labor']?.toString() ?? '';
      final nombreCeco = rendimiento['nombre_ceco']?.toString() ?? '';
      final totalRendimiento = rendimiento['total_rendimiento'] ?? 0.0;
      final totalTrabajadoresIndividuales = rendimiento['total_trabajadores_individuales'] ?? 0;
      final totalGrupos = rendimiento['total_grupos'] ?? 0;
      final totalCantidadIndividuales = rendimiento['total_cantidad_individuales'] ?? 0;
      final totalCantidadGrupales = rendimiento['total_cantidad_grupales'] ?? 0;
      
      // Crear clave única por fecha, tipo_mo, labor y CECO
      String clave = '$fecha-$tipoMo-$labor-$nombreCeco';
      
      if (grupos.containsKey(clave)) {
        // Sumar rendimientos del mismo tipo en el mismo día
        grupos[clave]!['total_rendimiento'] = (grupos[clave]!['total_rendimiento'] ?? 0.0) + totalRendimiento;
        grupos[clave]!['total_trabajadores_individuales'] = (grupos[clave]!['total_trabajadores_individuales'] ?? 0) + totalTrabajadoresIndividuales;
        grupos[clave]!['total_grupos'] = (grupos[clave]!['total_grupos'] ?? 0) + totalGrupos;
        grupos[clave]!['total_cantidad_individuales'] = (grupos[clave]!['total_cantidad_individuales'] ?? 0) + totalCantidadIndividuales;
        grupos[clave]!['total_cantidad_grupales'] = (grupos[clave]!['total_cantidad_grupales'] ?? 0) + totalCantidadGrupales;
      } else {
        grupos[clave] = {
          'fecha': fecha,
          'tipo_mo': tipoMo,
          'labor': labor,
          'nombre_ceco': nombreCeco,
          'total_rendimiento': totalRendimiento,
          'total_trabajadores_individuales': totalTrabajadoresIndividuales,
          'total_grupos': totalGrupos,
          'total_cantidad_individuales': totalCantidadIndividuales,
          'total_cantidad_grupales': totalCantidadGrupales,
          'tiene_individuales': totalTrabajadoresIndividuales > 0,
          'tiene_grupales': totalGrupos > 0,
        };
      }
    }
    
    return grupos.values.toList();
  }

  // Método para obtener labores que tienen datos en la vista
  List<Map<String, dynamic>> _obtenerLaboresConDatos() {
    Set<String> laboresSet = <String>{};
    List<Map<String, dynamic>> laboresConDatos = [];
    
    // Obtener labores de rendimientos individuales
    for (var rendimiento in _rendimientosIndividuales) {
      final labor = rendimiento['labor']?.toString();
      final idLabor = rendimiento['id_labor']?.toString();
      if (labor != null && labor.isNotEmpty && !laboresSet.contains(labor)) {
        laboresSet.add(labor);
        laboresConDatos.add({
          'id': idLabor,
          'nombre': labor,
        });
      }
    }
    
    // Obtener labores de rendimientos grupales
    for (var rendimiento in _rendimientosGrupales) {
      final labor = rendimiento['labor']?.toString();
      final idLabor = rendimiento['id_labor']?.toString();
      if (labor != null && labor.isNotEmpty && !laboresSet.contains(labor)) {
        laboresSet.add(labor);
        laboresConDatos.add({
          'id': idLabor,
          'nombre': labor,
        });
      }
    }
    
    // Ordenar alfabéticamente por nombre
    laboresConDatos.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
    
    return laboresConDatos;
  }

  // Nuevo método para agrupar rendimientos individuales por dia, labor y tipo_mo
  List<Map<String, dynamic>> _agruparRendimientosIndividualesPorDiaLaborTipoMo() {
    Map<String, Map<String, dynamic>> grupos = {};
    
    // Solo procesar rendimientos individuales
    for (var rendimiento in _rendimientosIndividuales) {
      final fecha = rendimiento['fecha']?.toString() ?? '';
      final tipoMo = rendimiento['tipo_mo']?.toString() ?? '';
      final labor = rendimiento['labor']?.toString() ?? '';
      final rendimientoValor = rendimiento['rendimiento'] ?? 0.0;
      final unidad = rendimiento['unidad']?.toString() ?? '';
      
      // Crear clave única por fecha, labor y tipo_mo
      String clave = '$fecha-$labor-$tipoMo';
      
      if (grupos.containsKey(clave)) {
        // Sumar rendimientos del mismo tipo en el mismo día y labor
        grupos[clave]!['total_rendimiento'] = (grupos[clave]!['total_rendimiento'] ?? 0.0) + rendimientoValor;
        grupos[clave]!['cantidad_trabajadores'] = (grupos[clave]!['cantidad_trabajadores'] ?? 0) + 1;
      } else {
        grupos[clave] = {
          'fecha': fecha,
          'labor': labor,
          'tipo_mo': tipoMo,
          'total_rendimiento': rendimientoValor,
          'cantidad_trabajadores': 1,
          'unidad': unidad,
        };
      }
    }
    
    return grupos.values.toList();
  }

  // Nuevo método para agrupar rendimientos grupales por dia, labor y tipo_mo
  List<Map<String, dynamic>> _agruparRendimientosGrupalesPorDiaLaborTipoMo() {
    Map<String, Map<String, dynamic>> grupos = {};
    
    // Solo procesar rendimientos grupales
    for (var rendimiento in _rendimientosGrupales) {
      final fecha = rendimiento['fecha']?.toString() ?? '';
      final tipoMo = rendimiento['tipo_mo']?.toString() ?? '';
      final labor = rendimiento['labor']?.toString() ?? '';
      final rendimientoValor = rendimiento['rendimiento'] ?? 0.0;
      final unidad = rendimiento['unidad']?.toString() ?? '';
      final cantidadTrab = rendimiento['cantidad_trab'] ?? 0;
      
      // Crear clave única por fecha, labor y tipo_mo
      String clave = '$fecha-$labor-$tipoMo';
      
      if (grupos.containsKey(clave)) {
        // Sumar rendimientos del mismo tipo en el mismo día y labor
        grupos[clave]!['total_rendimiento'] = (grupos[clave]!['total_rendimiento'] ?? 0.0) + rendimientoValor;
        grupos[clave]!['total_cantidad_trabajadores'] = (grupos[clave]!['total_cantidad_trabajadores'] ?? 0) + cantidadTrab;
        grupos[clave]!['cantidad_grupos'] = (grupos[clave]!['cantidad_grupos'] ?? 0) + 1;
      } else {
        grupos[clave] = {
          'fecha': fecha,
          'labor': labor,
          'tipo_mo': tipoMo,
          'total_rendimiento': rendimientoValor,
          'total_cantidad_trabajadores': cantidadTrab,
          'cantidad_grupos': 1,
          'unidad': unidad,
        };
      }
    }
    
    return grupos.values.toList();
  }

  Future<void> _cargarRendimientosDetalle(String fechaEspecifica, String tipoMo, String labor, String nombreCeco) async {
    setState(() {
      _isLoadingRendimientosDetalle = true;
    });

    try {
      DateTime fecha = _parseHttpDate(fechaEspecifica) ?? DateTime.now();
      String fechaFormateada = DateFormat('yyyy-MM-dd').format(fecha);

      // Filtrar rendimientos individuales
      List<Map<String, dynamic>> individualesFiltrados = _rendimientosIndividuales.where((rendimiento) {
        bool mismaFecha = false;
        try {
          DateTime rendimientoFecha = _parseHttpDate(rendimiento['fecha']?.toString() ?? '') ?? DateTime.now();
          mismaFecha = rendimientoFecha.day == fecha.day &&
                      rendimientoFecha.month == fecha.month &&
                      rendimientoFecha.year == fecha.year;
        } catch (e) {
          // print('Error parsing fecha in rendimiento individual: ${rendimiento['fecha']}');
        }
        
        final mismoTipoMo = rendimiento['tipo_mo']?.toString() == tipoMo;
        final mismaLabor = rendimiento['labor']?.toString() == labor;
        final mismoCeco = rendimiento['nombre_ceco']?.toString() == nombreCeco;
        
        return mismaFecha && mismoTipoMo && mismaLabor && mismoCeco;
      }).toList();

      // Filtrar rendimientos grupales
      List<Map<String, dynamic>> grupalesFiltrados = _rendimientosGrupales.where((rendimiento) {
        bool mismaFecha = false;
        try {
          DateTime rendimientoFecha = _parseHttpDate(rendimiento['fecha']?.toString() ?? '') ?? DateTime.now();
          mismaFecha = rendimientoFecha.day == fecha.day &&
                      rendimientoFecha.month == fecha.month &&
                      rendimientoFecha.year == fecha.year;
        } catch (e) {
          // print('Error parsing fecha in rendimiento grupal: ${rendimiento['fecha']}');
        }
        
        final mismoTipoMo = rendimiento['tipo_mo']?.toString() == tipoMo;
        final mismaLabor = rendimiento['labor']?.toString() == labor;
        final mismoCeco = rendimiento['nombre_ceco']?.toString() == nombreCeco;
        
        return mismaFecha && mismoTipoMo && mismaLabor && mismoCeco;
      }).toList();
      
      // Combinar resultados
      List<Map<String, dynamic>> rendimientosDetalle = [];
      rendimientosDetalle.addAll(individualesFiltrados);
      rendimientosDetalle.addAll(grupalesFiltrados);

      setState(() {
        _rendimientosDetalle = rendimientosDetalle;
        _isLoadingRendimientosDetalle = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRendimientosDetalle = false;
      });
      // print('Error al cargar detalle de rendimientos: $e');
    }
  }

  // Nuevo método para cargar rendimientos agrupados por CECO
  Future<void> _cargarRendimientosPorCeco(String fechaEspecifica, String tipoMo, String labor) async {
    setState(() {
      _isLoadingRendimientosPorCeco = true;
    });

    try {
      List<Map<String, dynamic>> rendimientosFiltrados = _rendimientosIndividuales.where((rendimiento) {
        DateTime? fecha = _parseHttpDate(rendimiento['fecha']?.toString() ?? '');
        if (fecha == null) return false;
        
        String fechaFormateada = DateFormat('yyyy-MM-dd').format(fecha);
        return fechaFormateada == fechaEspecifica &&
               rendimiento['tipo_mo']?.toString() == tipoMo &&
               rendimiento['labor']?.toString() == labor;
      }).toList();

      // Agrupar por CECO
      Map<String, Map<String, dynamic>> grupos = {};
      for (var rendimientoItem in rendimientosFiltrados) {
        String nombreCeco = rendimientoItem['nombre_ceco']?.toString() ?? 'Sin CECO';
        String detalleCeco = rendimientoItem['detalle_ceco']?.toString() ?? '';
        String grupoMo = rendimientoItem['grupo_mo']?.toString() ?? '';
        String unidad = rendimientoItem['unidad']?.toString() ?? '';
        
        String key = '$nombreCeco|$detalleCeco';
        
        if (!grupos.containsKey(key)) {
          grupos[key] = {
            'nombre_ceco': nombreCeco,
            'detalle_ceco': detalleCeco,
            'grupo_mo': grupoMo,
            'unidad': unidad,
            'total_rendimiento': 0.0,
            'cantidad_trabajadores': 0,
          };
        }
        
        double rendimientoValor = 0.0;
        if (rendimientoItem['rendimiento'] is num) {
          rendimientoValor = (rendimientoItem['rendimiento'] as num).toDouble();
        } else if (rendimientoItem['rendimiento'] is String) {
          rendimientoValor = double.tryParse(rendimientoItem['rendimiento']) ?? 0.0;
        }
        
        grupos[key]!['total_rendimiento'] = (grupos[key]!['total_rendimiento'] as double) + rendimientoValor;
        grupos[key]!['cantidad_trabajadores'] = (grupos[key]!['cantidad_trabajadores'] as int) + 1;
      }

      setState(() {
        _rendimientosPorCeco = grupos.values.toList();
        _isLoadingRendimientosPorCeco = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRendimientosPorCeco = false;
      });
    }
  }

  // Nuevo método para cargar rendimientos por detalle_ceco
  Future<void> _cargarRendimientosPorDetalleCeco(String fechaEspecifica, String tipoMo, String labor, String nombreCeco, String detalleCeco) async {
    setState(() {
      _isLoadingRendimientosPorDetalleCeco = true;
    });

    try {
      List<Map<String, dynamic>> trabajadores = _rendimientosIndividuales.where((rendimiento) {
        DateTime? fecha = _parseHttpDate(rendimiento['fecha']?.toString() ?? '');
        if (fecha == null) return false;
        
        String fechaFormateada = DateFormat('yyyy-MM-dd').format(fecha);
        return fechaFormateada == fechaEspecifica &&
               rendimiento['tipo_mo']?.toString() == tipoMo &&
               rendimiento['labor']?.toString() == labor &&
               rendimiento['nombre_ceco']?.toString() == nombreCeco &&
               rendimiento['detalle_ceco']?.toString() == detalleCeco;
      }).toList();

      setState(() {
        _rendimientosPorDetalleCeco = trabajadores;
        _isLoadingRendimientosPorDetalleCeco = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRendimientosPorDetalleCeco = false;
      });
    }
  }

  // Nuevo método para cargar rendimientos grupales agrupados por CECO
  Future<void> _cargarRendimientosGrupalesPorCeco(String fechaEspecifica, String tipoMo, String labor) async {
    setState(() {
      _isLoadingRendimientosGrupalesPorCeco = true;
    });

    try {
      List<Map<String, dynamic>> rendimientosFiltrados = _rendimientosGrupales.where((rendimiento) {
        DateTime? fecha = _parseHttpDate(rendimiento['fecha']?.toString() ?? '');
        if (fecha == null) return false;
        
        String fechaFormateada = DateFormat('yyyy-MM-dd').format(fecha);
        return fechaFormateada == fechaEspecifica &&
               rendimiento['tipo_mo']?.toString() == tipoMo &&
               rendimiento['labor']?.toString() == labor;
      }).toList();

      // Agrupar por CECO
      Map<String, Map<String, dynamic>> grupos = {};
      for (var rendimientoItem in rendimientosFiltrados) {
        String nombreCeco = rendimientoItem['nombre_ceco']?.toString() ?? 'Sin CECO';
        String detalleCeco = rendimientoItem['detalle_ceco']?.toString() ?? '';
        String grupoMo = rendimientoItem['grupo_mo']?.toString() ?? '';
        String unidad = rendimientoItem['unidad']?.toString() ?? '';
        
        String key = '$nombreCeco|$detalleCeco';
        
        if (!grupos.containsKey(key)) {
          grupos[key] = {
            'nombre_ceco': nombreCeco,
            'detalle_ceco': detalleCeco,
            'grupo_mo': grupoMo,
            'unidad': unidad,
            'total_rendimiento': 0.0,
            'cantidad_grupos': 0,
            'total_cantidad_trabajadores': 0,
          };
        }
        
        double rendimientoValor = 0.0;
        if (rendimientoItem['rendimiento'] is num) {
          rendimientoValor = (rendimientoItem['rendimiento'] as num).toDouble();
        } else if (rendimientoItem['rendimiento'] is String) {
          rendimientoValor = double.tryParse(rendimientoItem['rendimiento']) ?? 0.0;
        }
        
        int cantidadTrab = 0;
        if (rendimientoItem['cantidad_trab'] is num) {
          cantidadTrab = (rendimientoItem['cantidad_trab'] as num).toInt();
        } else if (rendimientoItem['cantidad_trab'] is String) {
          cantidadTrab = int.tryParse(rendimientoItem['cantidad_trab']) ?? 0;
        }
        
        grupos[key]!['total_rendimiento'] = (grupos[key]!['total_rendimiento'] as double) + rendimientoValor;
        grupos[key]!['cantidad_grupos'] = (grupos[key]!['cantidad_grupos'] as int) + 1;
        grupos[key]!['total_cantidad_trabajadores'] = (grupos[key]!['total_cantidad_trabajadores'] as int) + cantidadTrab;
      }

      setState(() {
        _rendimientosGrupalesPorCeco = grupos.values.toList();
        _isLoadingRendimientosGrupalesPorCeco = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRendimientosGrupalesPorCeco = false;
      });
    }
  }

  // Nuevo método para cargar rendimientos grupales por detalle_ceco
  Future<void> _cargarRendimientosGrupalesPorDetalleCeco(String fechaEspecifica, String tipoMo, String labor, String nombreCeco, String detalleCeco) async {
    setState(() {
      _isLoadingRendimientosGrupalesPorDetalleCeco = true;
    });

    try {
      List<Map<String, dynamic>> grupos = _rendimientosGrupales.where((rendimiento) {
        DateTime? fecha = _parseHttpDate(rendimiento['fecha']?.toString() ?? '');
        if (fecha == null) return false;
        
        String fechaFormateada = DateFormat('yyyy-MM-dd').format(fecha);
        return fechaFormateada == fechaEspecifica &&
               rendimiento['tipo_mo']?.toString() == tipoMo &&
               rendimiento['labor']?.toString() == labor &&
               rendimiento['nombre_ceco']?.toString() == nombreCeco &&
               rendimiento['detalle_ceco']?.toString() == detalleCeco;
      }).toList();

      setState(() {
        _rendimientosGrupalesPorDetalleCeco = grupos;
        _isLoadingRendimientosGrupalesPorDetalleCeco = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRendimientosGrupalesPorDetalleCeco = false;
      });
    }
  }

  Future<void> _cargarActividadesColaborador(String idColaborador, String fechaEspecifica) async {
    setState(() {
      _isLoadingActividades = true;
    });
    
    try {
      DateTime? fecha = _parseHttpDate(fechaEspecifica);
      if (fecha == null) {
        setState(() {
          _isLoadingActividades = false;
          _actividadesColaborador = [];
        });
        return;
      }
      
      String fechaFormateada = DateFormat('yyyy-MM-dd').format(fecha);
      
      final actividades = await _apiService.getActividadesColaborador(
        idColaborador: idColaborador,
        fechaInicio: fechaFormateada,
        fechaFin: fechaFormateada,
      );
      
      setState(() {
        _actividadesColaborador = actividades;
        _isLoadingActividades = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingActividades = false;
        _actividadesColaborador = [];
      });
    }
  }

  // Métodos de búsqueda




  // ================= CONTROL RENDIMIENTOS =================
  
  Future<void> _cargarDatosControlRendimientos() async {
    await Future.wait([
      _cargarLabores(),
      _cargarCecos(),
      _cargarUnidades(),
      _cargarGruposMo(),
      _cargarResumenRendimientos(),
      _cargarRendimientosIndividuales(),
      _cargarRendimientosGrupales(),
    ]);
  }

  Future<void> _cargarLabores() async {
    try {
      final labores = await _apiService.getLabores();
      setState(() {
        _labores = labores;
      });
    } catch (e) {
      // print('Error al cargar labores: $e');
    }
  }

  Future<void> _cargarCecos() async {
    try {
      final cecos = await _apiService.getCecosAdministrativos();
      setState(() {
        _cecos = cecos;
      });
    } catch (e) {
      // print('Error al cargar CECOs: $e');
    }
  }

  Future<void> _cargarUnidades() async {
    try {
      final unidades = await _apiService.getUnidades();
      setState(() {
        _unidades = unidades;
      });
    } catch (e) {
      // print('Error al cargar unidades: $e');
    }
  }

  Future<void> _cargarGruposMo() async {
    try {
      // Cargar grupos de mano de obra desde rendimientos grupales
      final rendimientosGrupales = await _apiService.getRendimientosGrupales(
        fechaInicio: null,
        fechaFin: null,
        idTipoRendimiento: null,
        idLabor: null,
        idCeco: null,
        idUnidad: null,
        grupoMo: null,
      );
      final grupos = <Map<String, dynamic>>[];
      final gruposSet = <String>{};
      
      for (var rendimiento in rendimientosGrupales) {
        final grupoMo = rendimiento['grupo_mo']?.toString();
        if (grupoMo != null && grupoMo.isNotEmpty && !gruposSet.contains(grupoMo)) {
          gruposSet.add(grupoMo);
          grupos.add({
            'id': grupoMo,
            'nombre': grupoMo,
          });
        }
      }
      
      setState(() {
        _gruposMo = grupos;
      });
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> _cargarResumenRendimientos() async {
    try {
      final resumen = await _apiService.getResumenRendimientos(
        fechaInicio: null,
        fechaFin: null,
        idTipoRendimiento: null,
        idLabor: _rendLabor,
        idCeco: _rendCeco,
        idUnidad: _rendUnidad,
        tipoMo: _rendTipoMo,
      );
      
      setState(() {
        _resumenRendimientos = resumen;
      });
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> _cargarRendimientosIndividuales() async {
    try {
      final individuales = await _apiService.getRendimientosIndividuales(
        fechaInicio: null,
        fechaFin: null,
        idTipoRendimiento: null,
        idLabor: _rendLabor,
        idCeco: null,
        idTrabajador: null,
        idUnidad: null,
        tipoMo: null,
      );
      
      setState(() {
        _rendimientosIndividuales = individuales;
      });
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> _cargarRendimientosGrupales() async {
    try {
      final grupales = await _apiService.getRendimientosGrupales(
        fechaInicio: null,
        fechaFin: null,
        idTipoRendimiento: null,
        idLabor: _rendLabor,
        idCeco: null,
        idUnidad: null,
        grupoMo: null,
      );
      
      setState(() {
        _rendimientosGrupales = grupales;
      });
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> _actualizarRendimientos() async {
    await Future.wait([
      _cargarResumenRendimientos(),
      _cargarRendimientosIndividuales(),
      _cargarRendimientosGrupales(),
    ]);
  }



  Color _obtenerColorEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'MÁS':
        return Colors.red;
      case 'MENOS':
        return Colors.red;
      case 'EXACTO':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _obtenerIconoEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'MÁS':
        return Icons.trending_up;
      case 'MENOS':
        return Icons.trending_down;
      case 'EXACTO':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  DateTime? _parseHttpDate(String dateString) {
    try {
      // Manejar formato HTTP específico: "Thu, 07 Aug 2025 00:00:00 GMT"
      if (dateString.contains(',') && dateString.contains('GMT')) {
        // Parsear formato HTTP
        final parts = dateString.split(', ');
        if (parts.length >= 2) {
          final datePart = parts[1];
          final timePart = datePart.split(' ');
          if (timePart.length >= 4) {
            final day = int.parse(timePart[0]);
            final monthStr = timePart[1];
            final year = int.parse(timePart[2]);
            final timeStr = timePart[3];
            
            // Mapear nombres de meses a números
            final months = {
              'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
              'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
            };
            
            final month = months[monthStr] ?? 1;
            final timeParts = timeStr.split(':');
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            final second = int.parse(timeParts[2]);
            
            return DateTime(year, month, day, hour, minute, second);
          }
        }
      }
      
      // Intentar parsear como DateTime estándar
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    if (value is int) return value.toString();
    if (value is double) {
      final fixed = value.toStringAsFixed(2);
      // Quitar ceros innecesarios
      return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
    }
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final fixed = parsed.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }

  String _getRendimientoDisplayValue(Map<String, dynamic> rendimiento) {
    // Para rendimientos grupales, mostrar cantidad de trabajadores si no hay total_rendimiento
    if (rendimiento['tipo_rendimiento']?.toString().toLowerCase().contains('grupal') == true) {
      final totalRendimiento = rendimiento['total_rendimiento'];
      final cantidadTrabajadores = rendimiento['cantidad_trabajadores'] ?? rendimiento['total_trabajadores'];
      
      if (totalRendimiento != null && totalRendimiento != 0) {
        return _formatNumber(totalRendimiento);
      } else if (cantidadTrabajadores != null && cantidadTrabajadores > 0) {
        return '${cantidadTrabajadores} personas';
      } else {
        return 'Sin datos';
      }
    }
    
    // Para rendimientos individuales, mostrar el total_rendimiento
    return _formatNumber(rendimiento['total_rendimiento'] ?? 0);
  }

  List<Map<String, dynamic>> _getIndicadoresControlHorasFiltrados() {
    List<Map<String, dynamic>> filtrados = _indicadoresControlHoras;

    // Filtrar por colaborador si está seleccionado
    if (_colaboradorSeleccionado != null) {
      filtrados = filtrados.where((indicador) {
        return indicador['id_colaborador']?.toString() == _colaboradorSeleccionado;
      }).toList();
    }

    // Filtrar por diferencias si el switch está activado
    if (_mostrarSoloDiferencias) {
      filtrados = filtrados.where((indicador) {
        try {
          double horasTrabajadas = 0.0;
          double horasEsperadas = 0.0;

          if (indicador['horas_trabajadas'] is num) {
            horasTrabajadas = (indicador['horas_trabajadas'] as num).toDouble();
          } else if (indicador['horas_trabajadas'] is String) {
            horasTrabajadas = double.tryParse(indicador['horas_trabajadas']) ?? 0.0;
          }

          if (indicador['horas_esperadas'] is num) {
            horasEsperadas = (indicador['horas_esperadas'] as num).toDouble();
          } else if (indicador['horas_esperadas'] is String) {
            horasEsperadas = double.tryParse(indicador['horas_esperadas']) ?? 0.0;
          }

          double diferencia = horasTrabajadas - horasEsperadas;
          return diferencia != 0;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    return filtrados;
  }

  Widget _buildControlHorasTab() {
    return Column(
      children: [
        // Filtros
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dropdown con búsqueda integrada
              DropdownSearch<Map<String, dynamic>>(
                items: [
                  {'id': null, 'nombre': 'Todos los colaboradores', 'apellido_paterno': '', 'apellido_materno': ''},
                  ..._colaboradores,
                ],
                itemAsString: (item) {
                  if (item['id'] == null) return 'Todos los colaboradores';
                  return '${item['nombre'] ?? ''} ${item['apellido_paterno'] ?? ''} ${item['apellido_materno'] ?? ''}'.trim();
                },
                selectedItem: _colaboradorSeleccionado != null
                    ? _colaboradores.where((c) => c['id'] == _colaboradorSeleccionado).isNotEmpty
                        ? _colaboradores.firstWhere((c) => c['id'] == _colaboradorSeleccionado)
                        : null
                    : {'id': null, 'nombre': 'Todos los colaboradores', 'apellido_paterno': '', 'apellido_materno': ''},
                onChanged: (value) {
                  setState(() {
                    _colaboradorSeleccionado = value?['id'];
                  });
                  _cargarIndicadores();
                },
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Colaborador',
                    prefixIcon: Icon(Icons.search, color: Colors.green),
                    border: OutlineInputBorder(),
                  ),
                ),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: "Buscar colaborador...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              // Switch para mostrar solo diferencias
              Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mostrar solo colaboradores con diferencias',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _mostrarSoloDiferencias,
                    onChanged: (value) {
                      setState(() {
                        _mostrarSoloDiferencias = value;
                      });
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _colaboradorSeleccionado = null;
                        });
                        _cargarIndicadores();
                      },
                      icon: Icon(Icons.clear),
                      label: Text('Limpiar'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _cargarIndicadores();
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('Actualizar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Lista de indicadores
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _getIndicadoresControlHorasFiltrados().isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            _mostrarSoloDiferencias 
                                ? 'No hay colaboradores con diferencias' 
                                : 'No hay datos disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _mostrarSoloDiferencias
                                ? 'Todos los colaboradores tienen horas exactas'
                                : 'Ajusta los filtros o selecciona otro rango de fechas',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _getIndicadoresControlHorasFiltrados().length,
                      itemBuilder: (context, index) {
                        final indicador = _getIndicadoresControlHorasFiltrados()[index];
                        final isExpanded = _colaboradorExpandido == indicador['id_colaborador'];
                        
                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _colaboradorExpandido = null;
                                    _actividadesColaborador = [];
                                  } else {
                                    _colaboradorExpandido = indicador['id_colaborador'];
                                    _cargarActividadesColaborador(indicador['id_colaborador'], indicador['fecha']);
                                  }
                                });
                              },
                              child: Card(
                                margin: EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: _obtenerColorEstado(
                                              indicador['estado_trabajo'] ?? '',
                                            ),
                                            child: Icon(
                                              _obtenerIconoEstado(
                                                indicador['estado_trabajo'] ?? '',
                                              ),
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  indicador['colaborador'] ?? 'Sin nombre',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('EEEE, dd/MM/yyyy', 'es_ES').format(
                                                    _parseHttpDate(indicador['fecha']) ?? DateTime.now()
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _obtenerColorEstado(
                                                indicador['estado_trabajo'] ?? '',
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              indicador['estado_trabajo'] ?? 'N/A',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildMetricCard(
                                              'Horas Trabajadas',
                                              '${indicador['horas_trabajadas'] ?? 0}',
                                              Icons.access_time,
                                              Colors.blue,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: _buildMetricCard(
                                              'Horas Esperadas',
                                              '${indicador['horas_esperadas'] ?? 0}',
                                              Icons.schedule,
                                              Colors.orange,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: _buildMetricCard(
                                              'Diferencia',
                                              '${indicador['diferencia_horas'] ?? 0}',
                                              Icons.compare_arrows,
                                              _obtenerColorEstado(
                                                indicador['estado_trabajo'] ?? '',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Sección expandible con actividades
                            if (isExpanded) ...[
                              Container(
                                margin: EdgeInsets.only(top: 8),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.list, color: Colors.green, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Actividades del colaborador',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    if (_isLoadingActividades)
                                      Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else if (_actividadesColaborador.isEmpty)
                                      Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            'No hay actividades registradas',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ..._actividadesColaborador.map((actividad) {
                                        return Container(
                                          margin: EdgeInsets.only(bottom: 12),
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey[200]!),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          actividad['labor'] ?? 'Sin labor',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          'CECO: ${actividad['nombre_ceco'] ?? 'N/A'} - ${actividad['detalle_ceco'] ?? 'N/A'}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                        Text(
                                                          'Tipo: ${actividad['tipoceco'] ?? 'N/A'}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _obtenerColorEstado(
                                                        actividad['estado_trabajo'] ?? '',
                                                      ),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      actividad['estado_trabajo'] ?? 'N/A',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildMetricCard(
                                                      'Horas',
                                                      '${actividad['horas_trabajadas'] ?? 0}',
                                                      Icons.access_time,
                                                      Colors.blue,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: _buildMetricCard(
                                                      'Esperadas',
                                                      '${actividad['horas_esperadas'] ?? 0}',
                                                      Icons.schedule,
                                                      Colors.orange,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: _buildMetricCard(
                                                      'Diferencia',
                                                      '${actividad['diferencia_horas'] ?? 0}',
                                                      Icons.compare_arrows,
                                                      _obtenerColorEstado(
                                                        actividad['estado_trabajo'] ?? '',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Fecha: ${DateFormat('EEEE, dd/MM/yyyy', 'es_ES').format(_parseHttpDate(actividad['fecha']) ?? DateTime.now())}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildOtrosIndicadoresTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 80,
            color: Colors.amber,
          ),
          SizedBox(height: 20),
          Text(
            'Próximamente',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Más indicadores estarán disponibles próximamente',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlRendimientosTab() {
    return Column(
      children: [
        // Filtros
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Filtros en filas
              Row(
                children: [
                  Expanded(
                    child: DropdownSearch<Map<String, dynamic>>(
                      items: [
                        {'id': null, 'nombre': 'Todas'},
                        ..._obtenerLaboresConDatos(),
                      ],
                      itemAsString: (item) => item['nombre'] ?? 'Todas',
                      selectedItem: _rendLabor != null
                          ? _obtenerLaboresConDatos().where((l) => l['id']?.toString() == _rendLabor).isNotEmpty
                              ? _obtenerLaboresConDatos().firstWhere((l) => l['id']?.toString() == _rendLabor)
                              : null
                          : {'id': null, 'nombre': 'Todas'},
                      onChanged: (value) {
                        setState(() {
                          _rendLabor = value?['id']?.toString();
                        });
                        _actualizarRendimientos();
                      },
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Labor',
                          prefixIcon: Icon(Icons.work, color: Colors.orange),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: DropdownSearch<Map<String, dynamic>>(
                      items: [
                        {'id': null, 'nombre': 'Todos'},
                        {'id': 'Individual', 'nombre': 'Individual'},
                        {'id': 'Grupal', 'nombre': 'Grupal'},
                      ],
                      itemAsString: (item) => item['nombre'] ?? 'Todos',
                      selectedItem: _rendTipoRendimiento != null
                          ? {'id': _rendTipoRendimiento, 'nombre': _rendTipoRendimiento}
                          : {'id': null, 'nombre': 'Todos'},
                      onChanged: (value) {
                        setState(() {
                          _rendTipoRendimiento = value?['id']?.toString();
                        });
                        _actualizarRendimientos();
                      },
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Tipo Rendimiento',
                          prefixIcon: Icon(Icons.category, color: Colors.blue),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _rendTrabajador = null;
                          _rendTipoRendimiento = null;
                          _rendLabor = null;
                        });
                        _actualizarRendimientos();
                      },
                      icon: Icon(Icons.clear),
                      label: Text('Limpiar'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _actualizarRendimientos();
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('Actualizar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingRend
              ? Center(child: CircularProgressIndicator())
              : _agruparRendimientosIndividualesPorDiaLaborTipoMo().isEmpty && _agruparRendimientosGrupalesPorDiaLaborTipoMo().isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.insights_outlined, size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text('No hay datos de rendimientos', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.all(16),
                      children: [
                        // Sección de Rendimientos Individuales
                        if (_agruparRendimientosIndividualesPorDiaLaborTipoMo().isNotEmpty && 
                            (_rendTipoRendimiento == null || _rendTipoRendimiento == 'Individual')) ...[
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Rendimientos Individuales',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._agruparRendimientosIndividualesPorDiaLaborTipoMo().map((item) {
                            final fecha = _parseHttpDate(item['fecha']?.toString() ?? DateTime.now().toString());
                            final clave = 'IND-${item['fecha']}-${item['labor']}-${item['tipo_mo']}';
                            final isExpanded = _grupoExpandido == clave;
                            
                            return Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _grupoExpandido = null;
                                        _rendimientosPorCeco = [];
                                        _cecoExpandido = null;
                                        _rendimientosPorDetalleCeco = [];
                                      } else {
                                        _grupoExpandido = clave;
                                        _cargarRendimientosPorCeco(
                                          item['fecha'],
                                          item['tipo_mo'],
                                          item['labor'],
                                        );
                                      }
                                    });
                                  },
                                  child: Card(
                                    margin: EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: (item['tipo_mo']?.toString().toUpperCase() == 'PROPIO') ? Colors.blue : Colors.deepPurple,
                                                child: Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['labor']?.toString() ?? 'Sin labor',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      DateFormat('EEEE, dd/MM/yyyy', 'es_ES').format(fecha!),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: (item['tipo_mo']?.toString().toUpperCase() == 'PROPIO') ? Colors.blue : Colors.deepPurple,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  item['tipo_mo']?.toString() ?? 'N/A',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildMetricCard(
                                                  'Total Rendimiento',
                                                  '${_formatNumber(item['total_rendimiento'])} ${item['unidad'] ?? ''}',
                                                  Icons.speed,
                                                  Colors.green,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: _buildMetricCard(
                                                  'Trabajadores',
                                                  '${item['cantidad_trabajadores'] ?? 0}',
                                                  Icons.person,
                                                  Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Primer nivel expandible: Rendimientos por CECO (Individuales)
                                if (isExpanded) ...[
                                  Container(
                                    margin: EdgeInsets.only(top: 8, left: 16, right: 16),
                                    child: Column(
                                      children: [
                                        if (_isLoadingRendimientosPorCeco)
                                          Center(child: CircularProgressIndicator())
                                        else if (_rendimientosPorCeco.isEmpty)
                                          Center(
                                            child: Text(
                                              'No hay rendimientos por CECO disponibles',
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                          )
                                        else
                                          ..._rendimientosPorCeco.map((cecoItem) {
                                            final claveCeco = 'IND-${cecoItem['nombre_ceco']}-${cecoItem['detalle_ceco']}';
                                            final isCecoExpanded = _cecoExpandido == claveCeco;
                                            
                                            return Column(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      if (isCecoExpanded) {
                                                        _cecoExpandido = null;
                                                        _rendimientosPorDetalleCeco = [];
                                                      } else {
                                                        _cecoExpandido = claveCeco;
                                                        _cargarRendimientosPorDetalleCeco(
                                                          item['fecha'],
                                                          item['tipo_mo'],
                                                          item['labor'],
                                                          cecoItem['nombre_ceco'],
                                                          cecoItem['detalle_ceco'],
                                                        );
                                                      }
                                                    });
                                                  },
                                                  child: Card(
                                                    margin: EdgeInsets.only(bottom: 8),
                                                    elevation: 1,
                                                    child: Padding(
                                                      padding: EdgeInsets.all(12),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(Icons.folder, color: Colors.amber, size: 20),
                                                              SizedBox(width: 8),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      cecoItem['nombre_ceco']?.toString() ?? 'Sin CECO',
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                    if (cecoItem['detalle_ceco']?.toString().isNotEmpty == true)
                                                                      Text(
                                                                        cecoItem['detalle_ceco']?.toString() ?? '',
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          color: Colors.grey[600],
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                              Container(
                                                                padding: EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.green,
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Text(
                                                                  '${_formatNumber(cecoItem['total_rendimiento'])} ${cecoItem['unidad'] ?? ''}',
                                                                  style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          SizedBox(height: 8),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: _buildMetricCard(
                                                                  'Trabajadores',
                                                                  '${cecoItem['cantidad_trabajadores'] ?? 0}',
                                                                  Icons.person,
                                                                  Colors.blue,
                                                                ),
                                                              ),
                                                              SizedBox(width: 8),
                                                              if (cecoItem['grupo_mo']?.toString().isNotEmpty == true)
                                                                Expanded(
                                                                  child: _buildMetricCard(
                                                                    'Grupo MO',
                                                                    cecoItem['grupo_mo']?.toString() ?? '',
                                                                    Icons.group,
                                                                    Colors.purple,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Segundo nivel expandible: Trabajadores por detalle_ceco (Individuales)
                                                if (isCecoExpanded) ...[
                                                  Container(
                                                    margin: EdgeInsets.only(top: 4, left: 16, right: 16),
                                                    child: Column(
                                                      children: [
                                                        if (_isLoadingRendimientosPorDetalleCeco)
                                                          Center(child: CircularProgressIndicator())
                                                        else if (_rendimientosPorDetalleCeco.isEmpty)
                                                          Center(
                                                            child: Text(
                                                              'No hay trabajadores disponibles',
                                                              style: TextStyle(color: Colors.grey[600]),
                                                            ),
                                                          )
                                                        else
                                                          ..._rendimientosPorDetalleCeco.map((trabajadorItem) {
                                                            return Card(
                                                              margin: EdgeInsets.only(bottom: 4),
                                                              elevation: 0.5,
                                                              child: Padding(
                                                                padding: EdgeInsets.all(8),
                                                                child: Row(
                                                                  children: [
                                                                    Icon(Icons.person_outline, color: Colors.indigo, size: 16),
                                                                    SizedBox(width: 8),
                                                                    Expanded(
                                                                      child: Text(
                                                                        trabajadorItem['trabajador']?.toString() ?? 'Sin nombre',
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          fontWeight: FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      padding: EdgeInsets.symmetric(
                                                                        horizontal: 6,
                                                                        vertical: 2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.green.withOpacity(0.2),
                                                                        borderRadius: BorderRadius.circular(8),
                                                                        border: Border.all(color: Colors.green.withOpacity(0.5)),
                                                                      ),
                                                                      child: Text(
                                                                        '${_formatNumber(trabajadorItem['rendimiento'])} ${trabajadorItem['unidad'] ?? ''}',
                                                                        style: TextStyle(
                                                                          color: Colors.green[700],
                                                                          fontSize: 11,
                                                                          fontWeight: FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            );
                                          }).toList(),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          }).toList(),
                        ],
                        
                        // Sección de Rendimientos Grupales
                        if (_agruparRendimientosGrupalesPorDiaLaborTipoMo().isNotEmpty && 
                            (_rendTipoRendimiento == null || _rendTipoRendimiento == 'Grupal')) ...[
                          SizedBox(height: 16),
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.groups, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Rendimientos Grupales',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._agruparRendimientosGrupalesPorDiaLaborTipoMo().map((item) {
                            final fecha = _parseHttpDate(item['fecha']?.toString() ?? DateTime.now().toString());
                            final clave = 'GRUPAL-${item['fecha']}-${item['labor']}-${item['tipo_mo']}';
                            final isExpanded = _grupoGrupalExpandido == clave;
                            
                            return Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _grupoGrupalExpandido = null;
                                        _rendimientosGrupalesPorCeco = [];
                                        _cecoGrupalExpandido = null;
                                        _rendimientosGrupalesPorDetalleCeco = [];
                                      } else {
                                        _grupoGrupalExpandido = clave;
                                        _cargarRendimientosGrupalesPorCeco(
                                          item['fecha'],
                                          item['tipo_mo'],
                                          item['labor'],
                                        );
                                      }
                                    });
                                  },
                                  child: Card(
                                    margin: EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: (item['tipo_mo']?.toString().toUpperCase() == 'PROPIO') ? Colors.blue : Colors.deepPurple,
                                                child: Icon(
                                                  Icons.groups,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['labor']?.toString() ?? 'Sin labor',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      DateFormat('EEEE, dd/MM/yyyy', 'es_ES').format(fecha!),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: (item['tipo_mo']?.toString().toUpperCase() == 'PROPIO') ? Colors.blue : Colors.deepPurple,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  item['tipo_mo']?.toString() ?? 'N/A',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildMetricCard(
                                                  'Total Rendimiento',
                                                  '${_formatNumber(item['total_rendimiento'])} ${item['unidad'] ?? ''}',
                                                  Icons.speed,
                                                  Colors.green,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: _buildMetricCard(
                                                  'Grupos',
                                                  '${item['cantidad_grupos'] ?? 0}',
                                                  Icons.groups,
                                                  Colors.orange,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: _buildMetricCard(
                                                  'Trabajadores',
                                                  '${item['total_cantidad_trabajadores'] ?? 0}',
                                                  Icons.person,
                                                  Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Primer nivel expandible: Rendimientos por CECO (Grupales)
                                if (isExpanded) ...[
                                  Container(
                                    margin: EdgeInsets.only(top: 8, left: 16, right: 16),
                                    child: Column(
                                      children: [
                                        if (_isLoadingRendimientosGrupalesPorCeco)
                                          Center(child: CircularProgressIndicator())
                                        else if (_rendimientosGrupalesPorCeco.isEmpty)
                                          Center(
                                            child: Text(
                                              'No hay rendimientos grupales por CECO disponibles',
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                          )
                                        else
                                          ..._rendimientosGrupalesPorCeco.map((cecoItem) {
                                            final claveCeco = 'GRUPAL-${cecoItem['nombre_ceco']}-${cecoItem['detalle_ceco']}';
                                            final isCecoExpanded = _cecoGrupalExpandido == claveCeco;
                                            
                                            return Column(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      if (isCecoExpanded) {
                                                        _cecoGrupalExpandido = null;
                                                        _rendimientosGrupalesPorDetalleCeco = [];
                                                      } else {
                                                        _cecoGrupalExpandido = claveCeco;
                                                        _cargarRendimientosGrupalesPorDetalleCeco(
                                                          item['fecha'],
                                                          item['tipo_mo'],
                                                          item['labor'],
                                                          cecoItem['nombre_ceco'],
                                                          cecoItem['detalle_ceco'],
                                                        );
                                                      }
                                                    });
                                                  },
                                                  child: Card(
                                                    margin: EdgeInsets.only(bottom: 8),
                                                    elevation: 1,
                                                    child: Padding(
                                                      padding: EdgeInsets.all(12),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(Icons.folder, color: Colors.amber, size: 20),
                                                              SizedBox(width: 8),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      cecoItem['nombre_ceco']?.toString() ?? 'Sin CECO',
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                    if (cecoItem['detalle_ceco']?.toString().isNotEmpty == true)
                                                                      Text(
                                                                        cecoItem['detalle_ceco']?.toString() ?? '',
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          color: Colors.grey[600],
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                              Container(
                                                                padding: EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.green,
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Text(
                                                                  '${_formatNumber(cecoItem['total_rendimiento'])} ${cecoItem['unidad'] ?? ''}',
                                                                  style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          SizedBox(height: 8),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: _buildMetricCard(
                                                                  'Grupos',
                                                                  '${cecoItem['cantidad_grupos'] ?? 0}',
                                                                  Icons.groups,
                                                                  Colors.orange,
                                                                ),
                                                              ),
                                                              SizedBox(width: 8),
                                                              Expanded(
                                                                child: _buildMetricCard(
                                                                  'Trabajadores',
                                                                  '${cecoItem['total_cantidad_trabajadores'] ?? 0}',
                                                                  Icons.person,
                                                                  Colors.blue,
                                                                ),
                                                              ),
                                                              SizedBox(width: 8),
                                                              if (cecoItem['grupo_mo']?.toString().isNotEmpty == true)
                                                                Expanded(
                                                                  child: _buildMetricCard(
                                                                    'Grupo MO',
                                                                    cecoItem['grupo_mo']?.toString() ?? '',
                                                                    Icons.group,
                                                                    Colors.purple,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Segundo nivel expandible: Grupos de trabajadores por detalle_ceco (Grupales)
                                                if (isCecoExpanded) ...[
                                                  Container(
                                                    margin: EdgeInsets.only(top: 4, left: 16, right: 16),
                                                    child: Column(
                                                      children: [
                                                        if (_isLoadingRendimientosGrupalesPorDetalleCeco)
                                                          Center(child: CircularProgressIndicator())
                                                        else if (_rendimientosGrupalesPorDetalleCeco.isEmpty)
                                                          Center(
                                                            child: Text(
                                                              'No hay grupos de trabajadores disponibles',
                                                              style: TextStyle(color: Colors.grey[600]),
                                                            ),
                                                          )
                                                        else
                                                          ..._rendimientosGrupalesPorDetalleCeco.map((grupoItem) {
                                                            return Card(
                                                              margin: EdgeInsets.only(bottom: 4),
                                                              elevation: 0.5,
                                                              child: Padding(
                                                                padding: EdgeInsets.all(8),
                                                                child: Row(
                                                                  children: [
                                                                    Icon(Icons.group_outlined, color: Colors.orange, size: 16),
                                                                    SizedBox(width: 8),
                                                                    Expanded(
                                                                      child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            grupoItem['grupo_mo']?.toString() ?? 'Sin grupo',
                                                                            style: TextStyle(
                                                                              fontSize: 12,
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            '${grupoItem['cantidad_trab'] ?? 0} trabajadores',
                                                                            style: TextStyle(
                                                                              fontSize: 10,
                                                                              color: Colors.grey[600],
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      padding: EdgeInsets.symmetric(
                                                                        horizontal: 6,
                                                                        vertical: 2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.orange.withOpacity(0.2),
                                                                        borderRadius: BorderRadius.circular(8),
                                                                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                                                      ),
                                                                      child: Text(
                                                                        '${_formatNumber(grupoItem['rendimiento'])} ${grupoItem['unidad'] ?? ''}',
                                                                        style: TextStyle(
                                                                          color: Colors.orange[700],
                                                                          fontSize: 11,
                                                                          fontWeight: FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    SizedBox(width: 8),
                                                                    Container(
                                                                      padding: EdgeInsets.symmetric(
                                                                        horizontal: 6,
                                                                        vertical: 2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.purple.withOpacity(0.2),
                                                                        borderRadius: BorderRadius.circular(8),
                                                                        border: Border.all(color: Colors.purple.withOpacity(0.5)),
                                                                      ),
                                                                      child: Text(
                                                                        '${_formatearPorcentaje(grupoItem['porcentaje_contratista'])}',
                                                                        style: TextStyle(
                                                                          color: Colors.purple[700],
                                                                          fontSize: 11,
                                                                          fontWeight: FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            );
                                          }).toList(),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          }).toList(),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.green,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(
                  icon: Icon(Icons.access_time),
                  text: 'Control de Horas',
                ),
                Tab(
                  icon: Icon(Icons.speed),
                  text: 'Control Rendimientos',
                ),
                Tab(
                  icon: Icon(Icons.analytics),
                  text: 'Otros Indicadores',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildControlHorasTab(),
                _buildControlRendimientosTab(),
                _buildOtrosIndicadoresTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método para formatear porcentajes (0.35 -> 35%, 0.5 -> 50%, etc.)
  String _formatearPorcentaje(dynamic valor) {
    if (valor == null) return '';
    
    try {
      double numero = 0.0;
      if (valor is num) {
        numero = valor.toDouble();
      } else if (valor is String) {
        numero = double.tryParse(valor) ?? 0.0;
      } else {
        return valor.toString();
      }
      
      // Si el número es menor a 1, asumimos que es un decimal y lo convertimos a porcentaje
      if (numero < 1 && numero > 0) {
        return '${(numero * 100).toStringAsFixed(0)}%';
      }
      // Si ya es un número mayor a 1, asumimos que ya es un porcentaje
      else if (numero >= 1) {
        return '${numero.toStringAsFixed(0)}%';
      }
      // Si es 0, retornamos 0%
      else {
        return '0%';
      }
    } catch (e) {
      return valor.toString();
    }
  }
}
