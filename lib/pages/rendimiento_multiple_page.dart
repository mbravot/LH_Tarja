import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'crear_rendimiento_multiple_page.dart';
import 'editar_rendimiento_multiple_page.dart';

import '../theme/app_theme.dart';

// Sistema de logging condicional
void logInfo(String message) {
  // Comentado para mejorar rendimiento
  // if (const bool.fromEnvironment('dart.vm.product') == false) {
  //   print("ℹ️ $message");
  // }
}

void logError(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("❌ $message");
  }
}

class RendimientoMultiplePage extends StatefulWidget {
  final Map<String, dynamic> actividad;

  RendimientoMultiplePage({required this.actividad});

  @override
  _RendimientoMultiplePageState createState() => _RendimientoMultiplePageState();
}

class _RendimientoMultiplePageState extends State<RendimientoMultiplePage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _rendimientos = [];
  List<Map<String, dynamic>> _rendimientosFiltrados = [];
  String _error = '';
  List<Map<String, dynamic>> colaboradores = [];
  List<Map<String, dynamic>> porcentajesContratista = [];
  List<Map<String, dynamic>> trabajadores = [];
  bool _seRealizoAccion = false; // Variable para rastrear si se realizó alguna acción
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarRendimientos(String query) {
    setState(() {
      if (query.isEmpty) {
        _rendimientosFiltrados = List.from(_rendimientos);
      } else {
        _rendimientosFiltrados = _rendimientos.where((rendimiento) {
          String nombre = '';
          if (rendimiento['trabajador'] != null && rendimiento['trabajador'].toString().trim().isNotEmpty) {
            nombre = rendimiento['trabajador'];
          } else if (rendimiento['id_trabajador'] != null && trabajadores.isNotEmpty) {
            final t = trabajadores.firstWhereOrNull((x) => x['id'].toString() == rendimiento['id_trabajador'].toString());
            if (t != null) {
              nombre = ('${t['nombre']} ${t['apellido_paterno'] ?? ''} ${t['apellido_materno'] ?? ''}').trim();
            }
          } else if (rendimiento['id_colaborador'] != null && colaboradores.isNotEmpty) {
            final c = colaboradores.firstWhereOrNull((x) => x['id'].toString() == rendimiento['id_colaborador'].toString());
            if (c != null) {
              nombre = ('${c['nombre']} ${c['apellido_paterno'] ?? ''} ${c['apellido_materno'] ?? ''}').trim();
            }
          } else if (rendimiento['nombre'] != null) {
            nombre = ('${rendimiento['nombre']} ${rendimiento['apellido_paterno'] ?? ''} ${rendimiento['apellido_materno'] ?? ''}').trim();
          }
          return nombre.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      
      // Usar endpoints específicos para rendimientos múltiples
      final listaColaboradores = await ApiService().getColaboradoresRendimientoMultiple();
      final listaBonos = await ApiService().getBonosRendimientoMultiple();
      
      setState(() {
        colaboradores = List<Map<String, dynamic>>.from(listaColaboradores);
        porcentajesContratista = List<Map<String, dynamic>>.from(listaBonos);
      });
      
      await _cargarRendimientos();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarRendimientos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final idActividad = widget.actividad['id'].toString();
      
      print("🔍 ====== CARGANDO RENDIMIENTOS MÚLTIPLES ======");
      print("🔍 Actividad ID: $idActividad");
      print("🔍 Actividad completa: ${widget.actividad}");
      
      setState(() {
        _rendimientos = [];
        _rendimientosFiltrados = [];
      });

      // Usar el endpoint específico para rendimientos múltiples
      final rendimientosMultiples = await _apiService.getRendimientosMultiples(idActividad);
      
      print("📥 Rendimientos múltiples recibidos: ${rendimientosMultiples.length}");
      
      setState(() {
        _rendimientos = rendimientosMultiples.map((r) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(r);
          map['tipo'] = 'multiple';
          return map;
        }).toList();
        _rendimientosFiltrados = List.from(_rendimientos);
        _isLoading = false;
      });
      
      print("✅ Carga de rendimientos múltiples completada");
      print("✅ Total rendimientos: ${_rendimientos.length}");
      print("✅ ====== FIN CARGA RENDIMIENTOS MÚLTIPLES ======");
      
    } catch (e) {
      print("❌ Error al cargar rendimientos múltiples: $e");
      setState(() {
        _error = 'Error al cargar los rendimientos múltiples: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _seRealizoAccion);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Rendimientos Múltiples - ${widget.actividad['nombre_labor'] ?? 'Sin nombre'}'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)))
            : _error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(_error, textAlign: TextAlign.center),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargarRendimientos,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                                 : Column(
                     children: [
                       _buildActividadInfo(),
                       Expanded(
                         child: _rendimientosFiltrados.isEmpty
                             ? Center(
                                 child: Column(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                     Icon(Icons.assessment_outlined, size: 48, color: Colors.grey),
                                     SizedBox(height: 16),
                                     Text(
                                       'No hay rendimientos registrados',
                                       style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                     ),
                                   ],
                                 ),
                               )
                             : Column(
                                 children: [
                                   _buildSearchBar(),
                                   Expanded(
                                     child: ListView.builder(
                                       padding: EdgeInsets.only(bottom: 100),
                                       itemCount: _rendimientosFiltrados.length,
                                       itemBuilder: (context, index) {
                                         return _buildRendimientoCard(_rendimientosFiltrados[index]);
                                       },
                                     ),
                                   ),
                                 ],
                               ),
                       ),
                     ],
                   ),
         floatingActionButton: FloatingActionButton(
           onPressed: () => _mostrarOpcionesCrearRendimiento(),
           backgroundColor: primaryColor,
           child: Icon(Icons.add, color: Colors.white),
           tooltip: 'Crear Rendimiento',
         ),
      ),
    );
  }

  Widget _buildActividadInfo() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work, color: primaryColor, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.actividad['nombre_labor'] ?? 'Sin labor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MÚLTIPLE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow('Fecha', widget.actividad['fecha'] ?? 'Sin fecha'),
            _buildInfoRow('Unidad', widget.actividad['nombre_unidad'] ?? 'Sin unidad'),
            _buildInfoRow('Tipo CECO', widget.actividad['nombre_tipoceco'] ?? 'Sin tipo CECO'),
            _buildInfoRow('Tarifa', '\$${widget.actividad['tarifa']?.toString() ?? '0'}'),
            _buildInfoRow('Horario', '${_formatearHora(widget.actividad['hora_inicio'])} - ${_formatearHora(widget.actividad['hora_fin'])}'),
            SizedBox(height: 12),
            _buildCecosSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCecosSection() {
    List<Map<String, dynamic>> cecos = [];
    String tipoCeco = '';
    IconData iconCeco = Icons.business;
    Color colorCeco = Colors.purple;
    
    switch ((widget.actividad['nombre_tipoceco'] ?? '').toString().toUpperCase()) {
      case 'PRODUCTIVO':
        if (widget.actividad['cecos_productivos'] != null && widget.actividad['cecos_productivos'].isNotEmpty) {
          cecos = List<Map<String, dynamic>>.from(widget.actividad['cecos_productivos']);
          tipoCeco = 'CECOs Productivos';
          iconCeco = Icons.agriculture;
          colorCeco = Colors.green;
        }
        break;
      case 'RIEGO':
        if (widget.actividad['cecos_riego'] != null && widget.actividad['cecos_riego'].isNotEmpty) {
          cecos = List<Map<String, dynamic>>.from(widget.actividad['cecos_riego']);
          tipoCeco = 'CECOs de Riego';
          iconCeco = Icons.water_drop;
          colorCeco = Colors.blue;
        }
        break;
    }
    
    if (cecos.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(),
        Row(
          children: [
            Icon(iconCeco, size: 16, color: colorCeco),
            SizedBox(width: 8),
            Text(
              tipoCeco,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorCeco,
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
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: cecos.map((ceco) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorCeco.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colorCeco.withOpacity(0.3), width: 1),
              ),
              child: Text(
                ceco['nombre'] ?? 'Sin nombre',
                style: TextStyle(
                  fontSize: 12,
                  color: colorCeco,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          borderRadius: BorderRadius.circular(15),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _filtrarRendimientos,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o apellido',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            prefixIcon: Icon(Icons.search, color: primaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    onPressed: () {
                      _searchController.clear();
                      _filtrarRendimientos('');
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
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRendimientoCard(Map<String, dynamic> rendimiento) {
    String nombre = '';
    if (rendimiento['trabajador'] != null && rendimiento['trabajador'].toString().trim().isNotEmpty) {
      nombre = rendimiento['trabajador'];
    } else if (rendimiento['id_trabajador'] != null && trabajadores.isNotEmpty) {
      final t = trabajadores.firstWhereOrNull((x) => x['id'].toString() == rendimiento['id_trabajador'].toString());
      if (t != null) {
        nombre = ('${t['nombre']} ${t['apellido_paterno'] ?? ''} ${t['apellido_materno'] ?? ''}').trim();
      }
    } else if (rendimiento['id_colaborador'] != null && colaboradores.isNotEmpty) {
      final c = colaboradores.firstWhereOrNull((x) => x['id'].toString() == rendimiento['id_colaborador'].toString());
      if (c != null) {
        nombre = ('${c['nombre']} ${c['apellido_paterno'] ?? ''} ${c['apellido_materno'] ?? ''}').trim();
      }
    } else if (rendimiento['nombre'] != null) {
      nombre = ('${rendimiento['nombre']} ${rendimiento['apellido_paterno'] ?? ''} ${rendimiento['apellido_materno'] ?? ''}').trim();
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: primaryColor),
        ),
        title: Text(
          nombre.isNotEmpty ? nombre : 'Sin nombre',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rendimiento['cantidad'] != null)
              Text('Cantidad: ${rendimiento['cantidad']}'),
            if (rendimiento['observaciones'] != null && rendimiento['observaciones'].toString().isNotEmpty)
              Text('Observaciones: ${rendimiento['observaciones']}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editarRendimiento(rendimiento),
              tooltip: 'Editar',
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmarEliminarRendimiento(rendimiento),
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesCrearRendimiento() {
    // Para rendimientos múltiples, ir directamente a crear rendimiento múltiple
    _crearRendimientoMultiple();
  }

  void _crearRendimientoMultiple() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearRendimientoMultiplePage(
          actividad: widget.actividad,
        ),
      ),
    );
    if (resultado == true) {
      setState(() {
        _seRealizoAccion = true;
      });
      await _cargarRendimientos();
    }
  }

  void _editarRendimiento(Map<String, dynamic> rendimiento) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarRendimientoMultiplePage(
          rendimiento: rendimiento,
          actividad: widget.actividad,
        ),
      ),
    );
    
    if (resultado == true) {
      setState(() {
        _seRealizoAccion = true;
      });
      await _cargarRendimientos();
    }
  }

  void _confirmarEliminarRendimiento(Map<String, dynamic> rendimiento) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar este rendimiento?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _eliminarRendimiento(rendimiento);
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _eliminarRendimiento(Map<String, dynamic> rendimiento) async {
    try {
      final idRendimiento = rendimiento['id'].toString();
      final eliminado = await _apiService.eliminarRendimientoMultiple(idRendimiento);
      
      if (eliminado) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rendimiento múltiple eliminado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _seRealizoAccion = true;
        });
        await _cargarRendimientos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar el rendimiento múltiple'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar el rendimiento múltiple: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
}
