import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../theme/app_theme.dart';
import 'create_actividad_multiple_page.dart';
import 'home_page.dart';
import 'rendimiento_multiple_page.dart';
import 'editar_actividad_multiple_page.dart';

// Sistema de logging condicional
void logInfo(String message) {
  // Comentado para mejorar rendimiento
  // print("ℹ️ $message");
}

void logError(String message) {
  // Solo mostrar errores críticos en producción
  // if (const bool.fromEnvironment('dart.vm.product') == false) {
  //   print("❌ $message");
  // }
}

class ActividadesMultiplesPage extends StatefulWidget {
  const ActividadesMultiplesPage({Key? key}) : super(key: key);

  @override
  State<ActividadesMultiplesPage> createState() => _ActividadesMultiplesPageState();
}

class _ActividadesMultiplesPageState extends State<ActividadesMultiplesPage> 
    with SingleTickerProviderStateMixin {
  
  Future<List<Map<String, dynamic>>>? _futureActividades;
  Map<String, bool> _expansionState = {};
  TextEditingController searchController = TextEditingController();
  late AnimationController _refreshIconController;
  bool _isLoading = false;

  List<Map<String, dynamic>> todasActividades = [];
  List<Map<String, dynamic>> actividadesFiltradas = [];
  Map<String, dynamic>? informacionUsuario;
  final Set<String> _actividadesVerificadas = {};

  final Color secondaryColor = Colors.white;
  final Color backgroundColor = Colors.grey[100]!;

  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    initializeDateFormatting('es_ES', null).then((_) {
      _verificarSesion();
      _cargarDatos();
    });
    searchController.addListener(_filtrarActividades);
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    searchController.dispose();
    super.dispose();
  }

  String _formatearFecha(String fechaOriginal) {
    try {
      final fecha = DateTime.parse(fechaOriginal);
      return DateFormat("EEEE d 'de' MMMM, y", 'es_ES').format(fecha);
    } catch (e) {
      logError("❌ Error al formatear fecha: $e ($fechaOriginal)");
      return fechaOriginal;
    }
  }

  Future<void> _verificarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      await _cargarInformacionUsuario();
      await _cargarActividades();
    } catch (e) {
      logError('❌ Error al cargar datos: $e');
      _mostrarError('No se pudieron cargar los datos');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cargarInformacionUsuario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nombre = prefs.getString('nombre') ?? 'Usuario';
      final sucursal = prefs.getString('sucursal_activa') ?? 'Sin sucursal';
      
      informacionUsuario = {
        'nombre': nombre,
        'sucursal': sucursal,
      };
    } catch (e) {
      logError('❌ Error al cargar información del usuario: $e');
    }
  }

  Future<void> _cargarActividades() async {
    try {
      // Usar el método actualizado que incluye CECOs y rendimientos múltiples
      final actividades = await ApiService().getActividadesMultiplesConCecos();
      if (!mounted) return;

      // Debug: Imprimir información de las actividades cargadas
      print("🔍 Actividades múltiples cargadas: ${actividades.length}");
      for (var actividad in actividades.take(3)) { // Solo las primeras 3 para debug
        print("  - ID: ${actividad['id']} (tipo: ${actividad['id'].runtimeType})");
        print("  - Labor: ${actividad['nombre_labor']}");
        print("  - Fecha: ${actividad['fecha']}");
        print("  - CECOs productivos: ${actividad['cecos_productivos']?.length ?? 0}");
        print("  - CECOs de riego: ${actividad['cecos_riego']?.length ?? 0}");
        print("  - Rendimientos múltiples: ${actividad['rendimientos_multiples']?.length ?? 0}");
        print("  - Tiene rendimientos múltiples: ${actividad['tiene_rendimientos_multiples']}");
        print("  - Nombre CECO calculado: ${obtenerNombreCeco(actividad)}");
      }

      setState(() {
        todasActividades = actividades;
        actividadesFiltradas = actividades;
        _futureActividades = Future.value(actividades);
      });
    } catch (e) {
      logError('❌ Error al cargar actividades múltiples: $e');
      _mostrarError('No se pudieron cargar las actividades múltiples');
    }
  }

  void _filtrarActividades() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        actividadesFiltradas = todasActividades;
      } else {
        actividadesFiltradas = todasActividades.where((actividad) {
          final labor = actividad['nombre_labor']?.toString().toLowerCase() ?? '';
          final unidad = actividad['nombre_unidad']?.toString().toLowerCase() ?? '';
          final tipoCeco = actividad['nombre_tipoceco']?.toString().toLowerCase() ?? '';
          final ceco = obtenerNombreCeco(actividad).toLowerCase();
          return labor.contains(query) || unidad.contains(query) || tipoCeco.contains(query) || ceco.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _refreshActividades() async {
    _refreshIconController.repeat();
    await _cargarDatos();
    _refreshIconController.stop();
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _mostrarExito(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividades Múltiples', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshActividades,
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshActividades,
              color: primaryColor,
              child: Column(
                children: [
                  _buildSearchBar(),
                  Expanded(child: _buildActividadesList()),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final resultado = await _mostrarFormularioNuevaActividad();
          if (resultado == true) {
            _refreshActividades();
          }
        },
        backgroundColor: primaryColor,
        child: Icon(Icons.add, color: Colors.white),
        elevation: 4,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: 'Buscar por labor, unidad, tipo CECO o CECO',
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  onPressed: () {
                    searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildActividadesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureActividades,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  "Error al cargar las actividades múltiples",
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _refreshActividades,
                  icon: RotationTransition(
                    turns: Tween(begin: 0.0, end: 1.0).animate(_refreshIconController),
                    child: Icon(Icons.refresh),
                  ),
                  label: Text("Reintentar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (actividadesFiltradas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  searchController.text.isEmpty
                      ? "No hay actividades múltiples registradas"
                      : "No se encontraron resultados",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        Map<String, List<Map<String, dynamic>>> actividadesPorFecha = {};
        for (var actividad in actividadesFiltradas) {
          String fecha = _formatearFecha(actividad['fecha']);
          if (!actividadesPorFecha.containsKey(fecha)) {
            actividadesPorFecha[fecha] = [];
            _expansionState[fecha] = _expansionState[fecha] ?? true;
          }
          actividadesPorFecha[fecha]!.add(actividad);
        }

        return ListView.builder(
          padding: EdgeInsets.only(bottom: 100),
          itemCount: actividadesPorFecha.length,
          itemBuilder: (context, index) {
            String fecha = actividadesPorFecha.keys.elementAt(index);
            List<Map<String, dynamic>> actividadesDelDia = actividadesPorFecha[fecha]!;

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _expansionState[fecha] ?? false,
                  onExpansionChanged: (expanded) {
                    setState(() => _expansionState[fecha] = expanded);
                  },
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fecha.capitalize(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${actividadesDelDia.length} ${actividadesDelDia.length == 1 ? 'actividad' : 'actividades'}',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: actividadesDelDia.map((actividad) {
                    return _buildActividadCard(actividad);
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActividadCard(Map<String, dynamic> actividad) {
    // Verificación perezosa: si aún no detectamos rendimientos, consultar una sola vez por actividad
    final String actividadId = actividad['id'].toString();
    if (!_tieneRendimientos(actividad) && !_actividadesVerificadas.contains(actividadId)) {
      _actividadesVerificadas.add(actividadId);
      Future.microtask(() async {
        try {
          final datos = await ApiService().getRendimientos(idActividad: actividadId);
          if (mounted && datos is Map && datos['rendimientos'] is List && (datos['rendimientos'] as List).isNotEmpty) {
            setState(() {
              // Marcar tanto en lista total como en filtrada
              actividad['tiene_rendimientos_cache'] = true;
              final i1 = todasActividades.indexWhere((a) => a['id'].toString() == actividadId);
              if (i1 >= 0) todasActividades[i1]['tiene_rendimientos_cache'] = true;
              final i2 = actividadesFiltradas.indexWhere((a) => a['id'].toString() == actividadId);
              if (i2 >= 0) actividadesFiltradas[i2]['tiene_rendimientos_cache'] = true;
            });
          }
        } catch (_) {}
      });
    }

    final estadoData = getEstadoActividad(actividad['id_estadoactividad']);
    final Color estadoColor = estadoData['color'];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.colorScheme.surface;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final textColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: () async {
        final actividadConNombre = Map<String, dynamic>.from(actividad);
        actividadConNombre['nombre'] = actividad['nombre_labor'] ?? 'Sin nombre';
        final resultado = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RendimientoMultiplePage(
              actividad: actividadConNombre,
            ),
          ),
        );
        // Solo actualizar si se realizó alguna acción en rendimientos
        if (resultado == true) {
          // Refrescar lista para recalcular el chip
          await _refreshActividades();
        }
      },
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: borderColor, width: 1),
        ),
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 children: [
                   Icon(Icons.work, color: primaryColor),
                   SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       actividad['nombre_labor'] ?? 'Sin labor',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 16,
                         color: textColor,
                       ),
                     ),
                   ),
                   Container(
                     padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                       color: estadoColor,
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text(
                       actividad['nombre_estado'] ?? 'Sin estado',
                       style: TextStyle(
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                         fontSize: 13,
                       ),
                     ),
                   ),
                 ],
               ),
               SizedBox(height: 8),
               _infoRow(
                 Icons.straighten,
                 Colors.indigo,
                 'Unidad: ${actividad['nombre_unidad'] ?? 'Sin unidad'}',
               ),
               _infoRow(
                 Icons.category,
                 Colors.orange,
                 'Tipo CECO: ${actividad['nombre_tipoceco'] ?? 'Sin tipo CECO'}',
                 trailing: Container(
                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: _tieneRendimientos(actividad) ? Colors.green[300]! : Colors.red[300]!,
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Text(
                     _tieneRendimientos(actividad) ? 'Con rendimientos' : 'Sin rendimientos',
                     style: TextStyle(
                       color: Colors.white,
                       fontWeight: FontWeight.bold,
                       fontSize: 11,
                     ),
                   ),
                 ),
               ),
               // Sección de CECOs asociados
               _buildCecosSection(actividad),
               // Botones de acción
               Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   IconButton(
                     icon: Icon(Icons.edit, color: Colors.green, size: 24),
                     onPressed: () async {
                       final resultado = await Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => EditarActividadMultiplePage(
                             actividad: actividad,
                           ),
                         ),
                       );
                       if (resultado == true) {
                         _refreshActividades();
                       }
                     },
                     tooltip: 'Editar',
                   ),
                   IconButton(
                     icon: Icon(Icons.delete, color: Colors.red, size: 24),
                     onPressed: () => _confirmarEliminarActividad(actividad),
                     tooltip: 'Eliminar',
                   ),
                 ],
               ),
               _infoRow(
                 Icons.attach_money,
                 Colors.green,
                 'Tarifa: \$${actividad['tarifa']?.toString() ?? '0'}',
               ),
               _infoRow(
                 Icons.access_time,
                 Colors.blue,
                 'Horario: ${_formatearHora(actividad['hora_inicio'])} - ${_formatearHora(actividad['hora_fin'])}',
               ),
             ],
           ),
         ),
       ),
     );
   }

  Widget _infoRow(IconData icon, Color color, String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  String _formatearHora(String? hora) {
    if (hora == null) return '--:--';
    try {
      final partes = hora.split(':');
      if (partes.length >= 2) {
        return '${partes[0]}:${partes[1]}';
      }
      return hora;
    } catch (e) {
      return hora;
    }
  }

  Map<String, dynamic> getEstadoActividad(int? id) {
    switch (id) {
      case 1:
        return {"nombre": "CREADA", "color": Colors.orange};
      case 2:
        return {"nombre": "REVISADA", "color": Colors.green};
      case 3:
        return {"nombre": "APROBADA", "color": Colors.green};
      case 4:
        return {"nombre": "FINALIZADA", "color": Colors.blue};
      default:
        return {"nombre": "DESCONOCIDO", "color": Colors.grey};
    }
  }

  bool _tieneRendimientos(Map<String, dynamic> actividad) {
    // 1) cache precomputado
    if (actividad['tiene_rendimientos_cache'] == true) return true;
    // 2) datos grupales embebidos (cuando se cargó desde detalle)
    if (actividad['rendimientos'] is List && (actividad['rendimientos'] as List).isNotEmpty) return true;
    // 3) indicadores de existencia
    if (actividad['tiene_rend_individual'] == true || actividad['tiene_rend_grupal'] == true) return true;
    // 4) rendimientos múltiples específicos
    if (actividad['tiene_rendimientos_multiples'] == true) return true;
    if (actividad['rendimientos_multiples'] is List && (actividad['rendimientos_multiples'] as List).isNotEmpty) return true;
    return false;
  }

  Widget _buildCecosSection(Map<String, dynamic> actividad) {
    List<Map<String, dynamic>> cecos = [];
    String tipoCeco = '';
    IconData iconCeco = Icons.business;
    Color colorCeco = Colors.purple;
    
    // Determinar qué CECOs mostrar según el tipo
    switch ((actividad['nombre_tipoceco'] ?? '').toString().toUpperCase()) {
      case 'PRODUCTIVO':
        if (actividad['cecos_productivos'] != null && actividad['cecos_productivos'].isNotEmpty) {
          cecos = List<Map<String, dynamic>>.from(actividad['cecos_productivos']);
          tipoCeco = 'CECOs Productivos';
          iconCeco = Icons.agriculture;
          colorCeco = Colors.green;
        }
        break;
      case 'RIEGO':
        if (actividad['cecos_riego'] != null && actividad['cecos_riego'].isNotEmpty) {
          cecos = List<Map<String, dynamic>>.from(actividad['cecos_riego']);
          tipoCeco = 'CECOs de Riego';
          iconCeco = Icons.water_drop;
          colorCeco = Colors.blue;
        }
        break;
    }
    
    if (cecos.isEmpty) {
      return _infoRow(
        iconCeco,
        colorCeco,
        'CECOs: Sin CECOs asociados',
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Row(
          children: [
            Icon(iconCeco, size: 16, color: colorCeco),
            SizedBox(width: 8),
            Text(
              tipoCeco,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorCeco.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${cecos.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorCeco,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // Lista de CECOs
        ...cecos.asMap().entries.map((entry) {
          final index = entry.key;
          final ceco = entry.value;
          return Container(
            margin: EdgeInsets.only(left: 24, bottom: 4),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorCeco.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorCeco.withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colorCeco,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ceco['nombre'] ?? 'Sin nombre',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  String obtenerNombreCeco(Map<String, dynamic> actividad) {
    String nombreCeco = 'Sin CECO';
    
    // Para actividades múltiples, solo pueden ser productivas o de riego
    switch ((actividad['nombre_tipoceco'] ?? '').toString().toUpperCase()) {
      case 'PRODUCTIVO':
        if (actividad['cecos_productivos'] != null && actividad['cecos_productivos'].isNotEmpty) {
          // Mostrar todos los CECOs productivos asociados
          final cecos = actividad['cecos_productivos'] as List;
          if (cecos.length == 1) {
            nombreCeco = cecos[0]['nombre'] ?? 'Sin CECO';
          } else {
            // Mostrar todos los CECOs separados por comas
            nombreCeco = cecos.map((ceco) => ceco['nombre'] ?? 'Sin nombre').join(', ');
          }
        }
        break;
      case 'RIEGO':
        if (actividad['cecos_riego'] != null && actividad['cecos_riego'].isNotEmpty) {
          // Mostrar todos los CECOs de riego asociados
          final cecos = actividad['cecos_riego'] as List;
          if (cecos.length == 1) {
            nombreCeco = cecos[0]['nombre'] ?? 'Sin CECO';
          } else {
            // Mostrar todos los CECOs separados por comas
            nombreCeco = cecos.map((ceco) => ceco['nombre'] ?? 'Sin nombre').join(', ');
          }
        }
        break;
    }
    return nombreCeco;
  }

  Future<bool?> _mostrarFormularioNuevaActividad() async {
    return await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateActividadMultiplePage(),
      ),
    );
  }

  Future<void> _confirmarEliminarActividad(Map<String, dynamic> actividad) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar esta actividad múltiple?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmacion == true) {
      try {
        print("🔍 Intentando eliminar actividad múltiple con ID: ${actividad['id']}");
        print("🔍 Tipo de ID: ${actividad['id'].runtimeType}");
        
        final eliminado = await ApiService().eliminarActividadMultiple(actividad['id']);
        if (eliminado) {
          _mostrarExito('Actividad múltiple eliminada exitosamente');
          _refreshActividades();
        } else {
          _mostrarError('No se pudo eliminar la actividad múltiple');
        }
      } catch (e) {
        print("❌ Error al eliminar actividad múltiple: $e");
        _mostrarError('Error al eliminar la actividad múltiple: $e');
      }
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
