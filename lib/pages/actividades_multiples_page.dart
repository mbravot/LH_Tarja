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
      print("❌ Error al formatear fecha: $e ($fechaOriginal)");
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
      print('❌ Error al cargar datos: $e');
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
      print('❌ Error al cargar información del usuario: $e');
    }
  }

  Future<void> _cargarActividades() async {
    try {
      // Limpiar cache de verificación para forzar nueva verificación de rendimientos
      _actividadesVerificadas.clear();
      
      // Usar el método actualizado que incluye CECOs y rendimientos múltiples
      final actividades = await ApiService().getActividadesMultiplesConCecos();
      if (!mounted) return;



      setState(() {
        todasActividades = actividades;
        actividadesFiltradas = actividades;
        _futureActividades = Future.value(actividades);
      });
    } catch (e) {
      print('❌ Error al cargar actividades múltiples: $e');
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
          
          // Buscar en todos los tipos de CECOs
          bool tieneCecoEnQuery = false;
          if (actividad['cecos_productivos'] != null && actividad['cecos_productivos'].isNotEmpty) {
            tieneCecoEnQuery = (actividad['cecos_productivos'] as List).any((ceco) => 
              (ceco['nombre']?.toString().toLowerCase() ?? '').contains(query));
          }
          if (!tieneCecoEnQuery && actividad['cecos_riego'] != null && actividad['cecos_riego'].isNotEmpty) {
            tieneCecoEnQuery = (actividad['cecos_riego'] as List).any((ceco) => 
              (ceco['nombre']?.toString().toLowerCase() ?? '').contains(query));
          }
          if (!tieneCecoEnQuery && actividad['cecos_maquinaria'] != null && actividad['cecos_maquinaria'].isNotEmpty) {
            tieneCecoEnQuery = (actividad['cecos_maquinaria'] as List).any((ceco) => 
              (ceco['nombre']?.toString().toLowerCase() ?? '').contains(query));
          }
          if (!tieneCecoEnQuery && actividad['cecos_inversion'] != null && actividad['cecos_inversion'].isNotEmpty) {
            tieneCecoEnQuery = (actividad['cecos_inversion'] as List).any((ceco) => 
              (ceco['nombre']?.toString().toLowerCase() ?? '').contains(query));
          }
          if (!tieneCecoEnQuery && actividad['cecos_administrativos'] != null && actividad['cecos_administrativos'].isNotEmpty) {
            tieneCecoEnQuery = (actividad['cecos_administrativos'] as List).any((ceco) => 
              (ceco['nombre']?.toString().toLowerCase() ?? '').contains(query));
          }
          
          return labor.contains(query) || unidad.contains(query) || tipoCeco.contains(query) || tieneCecoEnQuery;
        }).toList();
      }
    });
  }

  Future<void> _refreshActividades() async {
    _refreshIconController.repeat();
    await _cargarDatos();
    
    // Forzar verificación de rendimientos para todas las actividades después de actualizar
    await _verificarRendimientosTodasActividades();
    
    _refreshIconController.stop();
  }

  Future<void> _verificarRendimientosTodasActividades() async {
    for (var actividad in todasActividades) {
      final actividadId = actividad['id'].toString();
      if (!_tieneRendimientos(actividad)) {
        try {
          final datos = await ApiService().getRendimientos(idActividad: actividadId);
          if (mounted && datos is Map && datos['rendimientos'] is List && (datos['rendimientos'] as List).isNotEmpty) {
            setState(() {
              actividad['tiene_rendimientos_cache'] = true;
            });
          }
        } catch (e) {
          // Error silencioso
        }
      }
    }
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

        // Ordenar las fechas de más reciente a más antigua
        List<String> fechasOrdenadas = actividadesPorFecha.keys.toList();
        fechasOrdenadas.sort((a, b) {
          // Extraer la fecha original para comparar correctamente
          String fechaA = actividadesFiltradas.firstWhere((act) => _formatearFecha(act['fecha']) == a)['fecha'];
          String fechaB = actividadesFiltradas.firstWhere((act) => _formatearFecha(act['fecha']) == b)['fecha'];
          return DateTime.parse(fechaB).compareTo(DateTime.parse(fechaA));
        });

        return ListView.builder(
          padding: EdgeInsets.only(bottom: 100),
          itemCount: fechasOrdenadas.length,
          itemBuilder: (context, index) {
            String fecha = fechasOrdenadas[index];
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
                 Colors.purple,
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
               // Sección de CECOs organizada
               _buildCecosSection(actividad),
               // Tipo de rendimiento
               _infoRow(
                 Icons.category,
                 Colors.orange,
                 'Rendimiento: ${_obtenerTipoRendimiento(actividad)}',
               ),
               // Tarifa
               _infoRow(
                 Icons.attach_money,
                 Colors.green,
                 'Tarifa: \$${actividad['tarifa']?.toString() ?? '0'}',
                 trailing: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     IconButton(
                       icon: Icon(Icons.edit, color: Colors.green, size: 20),
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
                       icon: Icon(Icons.delete, color: Colors.red, size: 20),
                       onPressed: () => _confirmarEliminarActividad(actividad),
                       tooltip: 'Eliminar',
                     ),
                   ],
                 ),
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

  String _obtenerTipoRendimiento(Map<String, dynamic> actividad) {
    // Para actividades múltiples, el tipo de rendimiento es siempre "Múltiple"
    // independientemente de si ya tiene rendimientos registrados o no
    return 'MÚLTIPLE';
  }





  Widget _buildCecosSection(Map<String, dynamic> actividad) {
    final List<Map<String, dynamic>> cecos = [];
    
    // Agregar solo los tipos de CECO que tienen datos
    if (actividad['cecos_productivos'] != null && actividad['cecos_productivos'].isNotEmpty) {
      cecos.add({
        'nombre': 'Productivos',
        'icon': Icons.agriculture,
        'color': Colors.green,
        'cecos': actividad['cecos_productivos'] as List,
      });
    }
    if (actividad['cecos_riego'] != null && actividad['cecos_riego'].isNotEmpty) {
      cecos.add({
        'nombre': 'De Riego',
        'icon': Icons.water_drop,
        'color': Colors.blue,
        'cecos': actividad['cecos_riego'] as List,
      });
    }
    if (actividad['cecos_maquinaria'] != null && actividad['cecos_maquinaria'].isNotEmpty) {
      cecos.add({
        'nombre': 'Maquinaria',
        'icon': Icons.build,
        'color': Colors.orange,
        'cecos': actividad['cecos_maquinaria'] as List,
      });
    }
    if (actividad['cecos_inversion'] != null && actividad['cecos_inversion'].isNotEmpty) {
      cecos.add({
        'nombre': 'Inversión',
        'icon': Icons.trending_up,
        'color': Colors.purple,
        'cecos': actividad['cecos_inversion'] as List,
      });
    }
    if (actividad['cecos_administrativos'] != null && actividad['cecos_administrativos'].isNotEmpty) {
      cecos.add({
        'nombre': 'Administrativos',
        'icon': Icons.admin_panel_settings,
        'color': Colors.indigo,
        'cecos': actividad['cecos_administrativos'] as List,
      });
    }

    if (cecos.isEmpty) {
      return Container(
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_open, color: Colors.grey[600], size: 20),
            SizedBox(width: 8),
            Text(
              'No hay CECOs asociados',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'CECOs Asociados',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...cecos.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item['icon'], color: item['color'], size: 16),
                      SizedBox(width: 6),
                      Text(
                        item['nombre'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: item['color'],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                                     ...(item['cecos'] as List).map((ceco) {
                     // Debug temporal para ver qué campos tiene el CECO
             
                     
                     // Intentar diferentes campos posibles para el nombre
                     String nombreCeco = ceco['nombre'] ?? 
                                       ceco['nombre_ceco'] ?? 
                                       ceco['descripcion'] ?? 
                                       ceco['detalle_ceco'] ?? 
                                       'Sin nombre';
                     
                     return Padding(
                       padding: EdgeInsets.only(left: 22, top: 2),
                       child: Row(
                         children: [
                           Icon(Icons.circle, size: 6, color: item['color']),
                           SizedBox(width: 8),
                           Expanded(
                             child: Text(
                               nombreCeco,
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
              ),
            );
          }).toList(),
        ],
      ),
    );
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

        
        final eliminado = await ApiService().eliminarActividadMultiple(actividad['id']);
        if (eliminado) {
          _mostrarExito('Actividad múltiple eliminada exitosamente');
          _refreshActividades();
        } else {
          _mostrarError('No se pudo eliminar la actividad múltiple');
        }
      } catch (e) {

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
