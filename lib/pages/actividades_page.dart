import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'nueva_actividad_page.dart';
import 'login_page.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'editar_actividad_page.dart';
import 'rendimientos_page.dart';



class ActividadesPage extends StatefulWidget {
  const ActividadesPage({
    Key? key,
  }) : super(key: key);

  @override
  State<ActividadesPage> createState() => _ActividadesPageState();
}

// GlobalKey para acceder al estado de la página de actividades
final GlobalKey<_ActividadesPageState> actividadesPageKey = GlobalKey<_ActividadesPageState>();

class _ActividadesPageState extends State<ActividadesPage> with SingleTickerProviderStateMixin {
  Future<List<dynamic>>? _futureActividades;
  Map<String, bool> _expansionState = {};
  TextEditingController searchController = TextEditingController();
  late AnimationController _refreshIconController;
  bool _isLoading = false;

  List<dynamic> todasActividades = [];
  List<dynamic> actividadesFiltradas = [];
  final Set<String> _actividadesVerificadas = {};

  final Color primaryColor = Colors.green;
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
      _cargarActividades();
    });
    searchController.addListener(_filtrarActividades);
  }


  // Método para actualizar la lista cuando regresamos de otras páginas
  void actualizarLista() {
    _cargarActividades();
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

  Future<void> _cargarActividades() async {
    setState(() => _isLoading = true);
    try {
      // Limpiar cache de verificación para forzar nueva verificación de rendimientos
      _actividadesVerificadas.clear();
      
      // Usar el método optimizado: solo 2 llamadas (actividades + rendimientos/todos)
      final actividadesProcesadas = await ApiService().getActividadesConRendimientosOptimizado();
      if (!mounted) return;

      // Procesar fechas
      for (var actividad in actividadesProcesadas) {
        try {
          DateTime? fechaOriginal = _parseHttpDate(actividad['fecha']);
          if (fechaOriginal != null) {
            actividad['fecha_mostrada'] = DateFormat("dd/MM/yyyy").format(fechaOriginal);
            actividad['fecha_datetime'] = fechaOriginal;
          } else {
            actividad['fecha_mostrada'] = "Fecha inválida";
            actividad['fecha_datetime'] = DateTime(1970, 1, 1);
          }
        } catch (e) {
          actividad['fecha_mostrada'] = "Fecha inválida";
          actividad['fecha_datetime'] = DateTime(1970, 1, 1);
        }
      }

      // Ordenar por fecha
      actividadesProcesadas.sort((a, b) => b['fecha_datetime'].compareTo(a['fecha_datetime']));

      setState(() {
        todasActividades = actividadesProcesadas;
        actividadesFiltradas = actividadesProcesadas;
        _futureActividades = Future.value(actividadesProcesadas);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _futureActividades = Future.error("No se pudieron cargar las actividades.");
        _isLoading = false;
      });
      _mostrarError("No se pudieron cargar las actividades");
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatearHora(dynamic valor) {
    if (valor == null) return '--:--';
    final String s = valor.toString();
    if (!s.contains(':')) return s;
    final parts = s.split(':');
    if (parts.length >= 2) {
      final hh = parts[0].padLeft(2, '0');
      final mm = parts[1].padLeft(2, '0');
      return '$hh:$mm';
    }
    return s;
  }

  Widget _infoRow(IconData icon, Color iconColor, String text, {Widget? trailing}) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  void _filtrarActividades() {
    String query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        actividadesFiltradas = [...todasActividades];
      } else {
        actividadesFiltradas = todasActividades.where((actividad) {
          final labor = (actividad['nombre_labor'] ?? '').toString().toLowerCase();
          final contratista = (actividad['nombre_contratista'] ?? '').toString().toLowerCase();
          final ceco = (obtenerNombreCeco(actividad) ?? '').toString().toLowerCase();
          final tipoRendimiento = (actividad['nombre_tiporendimiento'] ?? '').toString().toLowerCase();
          return labor.contains(query) ||
                 contratista.contains(query) ||
                 ceco.contains(query) ||
                 tipoRendimiento.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _refreshActividades() async {
    _refreshIconController.repeat();
    await _cargarActividades();
    
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () async {
                final resultado = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (context) => NuevaActividadPage()),
                );
                if (resultado == true) {
                  _refreshActividades();
                }
              },
              backgroundColor: primaryColor,
              child: Icon(Icons.add, color: Colors.white),
              elevation: 4,
            ),
          ),
        ],
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
          hintText: 'Buscar por labor, contratista o CECO',
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
    return FutureBuilder<List<dynamic>>(
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
                  "Error al cargar las actividades",
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
                      ? "No hay actividades registradas"
                      : "No se encontraron resultados",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        Map<String, List<dynamic>> actividadesPorFecha = {};
        for (var actividad in actividadesFiltradas) {
          String fecha = _formatearFecha(actividad['fecha']);
          if (!actividadesPorFecha.containsKey(fecha)) {
            actividadesPorFecha[fecha] = [];
            _expansionState[fecha] = _expansionState[fecha] ?? true;
          }
          actividadesPorFecha[fecha]!.add(actividad);
        }

        return ListView.builder(
          padding: EdgeInsets.only(bottom: 80),
          itemCount: actividadesPorFecha.length,
          itemBuilder: (context, index) {
            String fecha = actividadesPorFecha.keys.elementAt(index);
            List<dynamic> actividadesDelDia = actividadesPorFecha[fecha]!;

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

  Widget _buildActividadCard(dynamic actividad) {
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
    final String estadoNombre = estadoData['nombre'];
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
            builder: (context) => RendimientosPage(
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
                'Tipo CECO: ${actividad['nombre_tipoceco'] ?? 'Sin tipo de CECO'}',
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
              _infoRow(
                Icons.folder,
                Colors.amber,
                'CECO: ${obtenerNombreCeco(actividad)}',
                trailing: IconButton(
                  icon: Icon(Icons.edit, color: Colors.green, size: 24),
                  onPressed: () async {
                    final resultado = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditarActividadPage(
                          actividad: actividad,
                        ),
                      ),
                    );
                    if (resultado == true) _refreshActividades();
                  },
                  tooltip: 'Editar',
                ),
              ),
              _infoRow(
                Icons.business,
                Colors.blue,
                actividad['nombre_contratista'] ?? 'PERSONAL PROPIO',
              ),
              _infoRow(
                Icons.assessment,
                Colors.purple,
                'Rendimiento: ${actividad['nombre_tiporendimiento'] ?? 'Sin tipo de rendimiento'}',
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: 24),
                  onPressed: () async {
                    final confirmacion = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('¿Eliminar actividad?'),
                        content: Text('¿Está seguro que desea eliminar esta actividad?'),
                        actions: [
                          TextButton(
                            child: Text('Cancelar'),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Eliminar'),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    );
                    if (confirmacion == true) {
                      try {
                        final exito = await ApiService().eliminarActividad(actividad['id'].toString());
                        if (exito) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Actividad eliminada correctamente'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _refreshActividades();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('No se pudo eliminar la actividad'),
                                ],
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Error al eliminar la actividad: ' + e.toString()),
                              ],
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              _infoRow(
                Icons.attach_money,
                Colors.green,
                'Tarifa: \$${actividad['tarifa']?.toString() ?? '0'}',
              ),
              _infoRow(
                Icons.access_time,
                Colors.teal,
                'Horario: ${_formatearHora(actividad['hora_inicio'])} - ${_formatearHora(actividad['hora_fin'])}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _tieneRendimientos(Map<String, dynamic> actividad) {
    // 1) cache precomputado
    if (actividad['tiene_rendimientos_cache'] == true) return true;
    // 2) datos grupales embebidos (cuando se cargó desde detalle)
    if (actividad['rendimientos'] is List && (actividad['rendimientos'] as List).isNotEmpty) return true;
    // 3) indicadores de existencia
    if (actividad['tiene_rend_individual'] == true || actividad['tiene_rend_grupal'] == true) return true;
    return false;
  }

  String obtenerNombreCeco(Map<String, dynamic> actividad) {
    String nombreCeco = 'Sin CECO';
    switch ((actividad['nombre_tipoceco'] ?? '').toString().toUpperCase()) {
      case 'PRODUCTIVO':
        if (actividad['cecos_productivos'] != null && actividad['cecos_productivos'].isNotEmpty) {
          nombreCeco = actividad['cecos_productivos'][0]['nombre'] ?? 'Sin CECO';
        }
        break;
      case 'RIEGO':
        if (actividad['cecos_riego'] != null && actividad['cecos_riego'].isNotEmpty) {
          nombreCeco = actividad['cecos_riego'][0]['nombre'] ?? 'Sin CECO';
        }
        break;
      case 'MAQUINARIA':
        if (actividad['cecos_maquinaria'] != null && actividad['cecos_maquinaria'].isNotEmpty) {
          nombreCeco = actividad['cecos_maquinaria'][0]['nombre'] ?? 'Sin CECO';
        }
        break;
      case 'INVERSION':
        if (actividad['cecos_inversion'] != null && actividad['cecos_inversion'].isNotEmpty) {
          nombreCeco = actividad['cecos_inversion'][0]['nombre'] ?? 'Sin CECO';
        }
        break;
      case 'ADMINISTRATIVO':
        if (actividad['cecos_administrativos'] != null && actividad['cecos_administrativos'].isNotEmpty) {
          nombreCeco = actividad['cecos_administrativos'][0]['nombre'] ?? 'Sin CECO';
        }
        break;
      // Puedes agregar más casos si tienes otros tipos
    }
    return nombreCeco;
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
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
