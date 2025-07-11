import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'crear_rendimiento_individual_page.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'editar_rendimientos_individuales_page.dart';
import 'editar_rendimientos_grupales_page.dart';
import 'crear_rendimiento_grupal_page.dart';

// Sistema de logging condicional
void logInfo(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("ℹ️ $message");
  }
}

void logError(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("❌ $message");
  }
}

class RendimientosPage extends StatefulWidget {
  final Map<String, dynamic> actividad;

  const RendimientosPage({
    Key? key,
    required this.actividad,
  }) : super(key: key);

  @override
  State<RendimientosPage> createState() => _RendimientosPageState();
}

class _RendimientosPageState extends State<RendimientosPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _rendimientos = [];
  List<Map<String, dynamic>> _rendimientosFiltrados = [];
  String _error = '';
  List<Map<String, dynamic>> colaboradores = [];
  List<Map<String, dynamic>> porcentajesContratista = [];
  List<Map<String, dynamic>> trabajadores = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarRendimientos);
    _cargarColaboradoresYTrabajadoresYPorcentajesYRendimientos();
  }

  void _filtrarRendimientos() {
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _rendimientosFiltrados = List.from(_rendimientos));
      return;
    }
    setState(() {
      _rendimientosFiltrados = _rendimientos.where((rend) {
        String nombre = '';
        if (rend['trabajador'] != null) {
          nombre = rend['trabajador'].toString().toLowerCase();
        } else if (rend['id_trabajador'] != null && trabajadores.isNotEmpty) {
          final t = trabajadores.firstWhereOrNull((x) => x['id'].toString() == rend['id_trabajador'].toString());
          if (t != null) {
            nombre = ('${t['nombre']} ${t['apellido_paterno'] ?? ''} ${t['apellido_materno'] ?? ''}').toLowerCase();
          }
        } else if (rend['id_colaborador'] != null && colaboradores.isNotEmpty) {
          final c = colaboradores.firstWhereOrNull((x) => x['id'].toString() == rend['id_colaborador'].toString());
          if (c != null) {
            nombre = ('${c['nombre']} ${c['apellido_paterno'] ?? ''} ${c['apellido_materno'] ?? ''}').toLowerCase();
          }
        }
        return nombre.contains(query);
      }).toList();
    });
  }

  Future<void> _cargarColaboradoresYTrabajadoresYPorcentajesYRendimientos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Forzar recarga
      final idSucursal = prefs.getString('id_sucursal');
      logInfo('Sucursal activa usada para cargar colaboradores/rendimientos: $idSucursal');
      if (idSucursal == null) throw Exception('No se encontró la sucursal activa');
      final listaColaboradores = await ApiService().getColaboradores();
      final listaPorcentajes = await ApiService().getPorcentajesContratista();
      setState(() {
        colaboradores = List<Map<String, dynamic>>.from(listaColaboradores);
        porcentajesContratista = List<Map<String, dynamic>>.from(listaPorcentajes);
      });
      // Cargar trabajadores solo si es contratista
      if (widget.actividad['id_tipotrabajador'] == 2 && widget.actividad['id_contratista'] != null) {
        final listaTrabajadores = await ApiService().getTrabajadores(idSucursal, widget.actividad['id_contratista'].toString());
        setState(() {
          trabajadores = List<Map<String, dynamic>>.from(listaTrabajadores);
        });
      }
      await _cargarRendimientos();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar colaboradores, trabajadores o porcentajes: $e';
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

      final tipo = widget.actividad['id_tiporendimiento'];
      final idTipotrabajador = widget.actividad['id_tipotrabajador'];
      final idActividad = widget.actividad['id'].toString();
      final idContratista = widget.actividad['id_contratista']?.toString();
      
      logInfo("🔍 ====== CARGANDO RENDIMIENTOS ======");
      logInfo("🔍 Actividad ID: $idActividad");
      logInfo("🔍 Tipo rendimiento: $tipo");
      logInfo("🔍 Tipo trabajador: $idTipotrabajador");
      logInfo("🔍 Contratista ID: $idContratista");
      logInfo("🔍 Actividad completa: ${widget.actividad}");
      
      // Limpiar rendimientos anteriores
      setState(() {
        _rendimientos = [];
        _rendimientosFiltrados = [];
      });

      if (tipo == 1) { // Individual
        if (idTipotrabajador == 1) { // Propio
          logInfo("🔍 Cargando rendimientos individuales PROPIOS");
          final rendimientosPropios = await _apiService.getRendimientosIndividualesPropios(
            idActividad: idActividad
          );
          logInfo("📥 Rendimientos propios recibidos: ${rendimientosPropios.length}");
          
          setState(() {
            _rendimientos = rendimientosPropios.map((r) {
              final Map<String, dynamic> map = Map<String, dynamic>.from(r);
              map['tipo'] = 'individual';
              map['es_propio'] = true;
              return map;
            }).toList();
            _rendimientosFiltrados = List.from(_rendimientos);
            _isLoading = false;
          });
        } else if (idTipotrabajador == 2) { // Contratista
          if (idContratista == null || idContratista.isEmpty) {
            logInfo("❌ Error: Actividad de contratista sin ID de contratista");
            setState(() {
              _error = 'Error: Actividad de contratista sin ID de contratista';
              _isLoading = false;
            });
            return;
          }
          
          logInfo("🔍 Cargando rendimientos individuales de CONTRATISTA");
          logInfo("🔍 ID Actividad: $idActividad");
          logInfo("🔍 ID Contratista: $idContratista");
          
          final rendimientosContratistas = await _apiService.getRendimientosIndividualesContratistas(
            idActividad: idActividad,
            idContratista: idContratista
          );
          
          logInfo("📥 Rendimientos contratistas recibidos: ${rendimientosContratistas.length}");
          rendimientosContratistas.forEach((r) {
            logInfo("📥 Rendimiento: ID Actividad=${r['id_actividad']}, ID Contratista=${r['id_contratista']}");
          });
          
          setState(() {
            _rendimientos = rendimientosContratistas.map((r) {
              final Map<String, dynamic> map = Map<String, dynamic>.from(r);
              map['tipo'] = 'individual';
              map['es_propio'] = false;
              return map;
            }).toList();
            _rendimientosFiltrados = List.from(_rendimientos);
            _isLoading = false;
          });
        }
      } else if (tipo == 2) { // Grupal
        logInfo("🔍 Cargando rendimientos GRUPALES");
        final data = await _apiService.getRendimientos(idActividad: idActividad);
        if (data['rendimientos'] != null && data['rendimientos'] is List) {
          final List<dynamic> rawRendimientos = data['rendimientos'];
          logInfo("📥 Rendimientos grupales recibidos: ${rawRendimientos.length}");
          
          setState(() {
            _rendimientos = rawRendimientos.map((rendimiento) {
              final Map<String, dynamic> map = Map<String, dynamic>.from(rendimiento);
              map['tipo'] = 'grupal';
              return map;
            }).toList();
            _rendimientosFiltrados = List.from(_rendimientos);
            _isLoading = false;
          });
        }
      }
      
      logInfo("✅ Carga de rendimientos completada");
      logInfo("✅ Total rendimientos: ${_rendimientos.length}");
      logInfo("✅ ====== FIN CARGA RENDIMIENTOS ======");
      
    } catch (e) {
      logError("❌ Error al cargar rendimientos: $e");
      setState(() {
        _error = 'Error al cargar los rendimientos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _editarRendimiento(Map<String, dynamic> rendimiento) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarRendimientosGrupalesPage(
          rendimiento: rendimiento,
        ),
      ),
    );
    if (result == true) {
      await _cargarRendimientos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rendimientos - ${widget.actividad['nombre']}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
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
                        child: Text('Reintentar'),
                ),
              ],
            ),
                )
              : Column(
                  children: [
                    Padding(
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
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre o apellido',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                            prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                    onPressed: () {
                                      _searchController.clear();
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _rendimientosFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay rendimientos registrados',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _rendimientosFiltrados.length,
                              itemBuilder: (context, index) {
                                final rendimiento = _rendimientosFiltrados[index];
                                final bool esIndividual = rendimiento['tipo'] == 'individual';
                                return _RendimientoCard(
                                  rendimiento: rendimiento,
                                  esIndividual: esIndividual,
                                  trabajadores: trabajadores,
                                  colaboradores: colaboradores,
                                  porcentajesContratista: porcentajesContratista,
                                  onEditar: () async {
                                    final rendimientoConTipo = Map<String, dynamic>.from(rendimiento);
                                    rendimientoConTipo['id_tipotrabajador'] ??= widget.actividad['id_tipotrabajador'];
                                    rendimientoConTipo['id_contratista'] ??= widget.actividad['id_contratista'];
                                    rendimientoConTipo['id_actividad'] ??= widget.actividad['id'];
                                    if (rendimiento['tipo'] == 'grupal') {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditarRendimientosGrupalesPage(rendimiento: rendimientoConTipo),
                                        ),
                                      );
                                      if (result == true) {
                                        _cargarRendimientos();
                                      }
                                    } else {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditarRendimientosIndividualesPage(rendimiento: rendimientoConTipo),
                                        ),
                                      );
                                      if (result == true) {
                                        _cargarRendimientos();
                                      }
                                    }
                                  },
                                  onEliminar: () => _confirmarEliminarRendimiento(rendimiento),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final tipo = widget.actividad['id_tiporendimiento'];
          final idTipotrabajador = widget.actividad['id_tipotrabajador'];
          final idContratista = widget.actividad['id_contratista']?.toString();
          if (tipo == 1) {
            // Individual
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CrearRendimientoIndividualPage(
                  idActividad: widget.actividad['id'].toString(),
                  idTipotrabajador: idTipotrabajador,
                  idContratista: idContratista,
                ),
              ),
            );
            if (result == true) {
              _cargarRendimientos();
            }
          } else {
            // Grupal
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CrearRendimientoGrupalPage(
                  actividad: widget.actividad,
                ),
              ),
            );
            if (result == true) {
              _cargarRendimientos();
            }
          }
        },
        child: Icon(Icons.add),
        tooltip: 'Agregar Rendimiento',
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
                  Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
                  ),
                ],
              ),
    );
  }

  Future<void> _confirmarEliminarRendimiento(Map<String, dynamic> rendimiento) async {
    final bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar este rendimiento? Esta acción no se puede deshacer.'),
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
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      bool eliminado = false;

      try {
        if (rendimiento['tipo'] == 'grupal') {
          eliminado = await ApiService().eliminarRendimientoGrupal(rendimiento['id'].toString());
        } else {
          // Determinar si es rendimiento propio o de contratista
          if (rendimiento['id_trabajador'] != null) {
            eliminado = await ApiService().eliminarRendimientoIndividualContratista(rendimiento['id'].toString());
          } else {
            eliminado = await ApiService().eliminarRendimientoIndividualPropio(rendimiento['id'].toString());
          }
        }

        if (eliminado) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rendimiento eliminado correctamente', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
            ),
          );
          _cargarRendimientos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo eliminar el rendimiento', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _RendimientoCard extends StatelessWidget {
  final Map<String, dynamic> rendimiento;
  final bool esIndividual;
  final List<Map<String, dynamic>> trabajadores;
  final List<Map<String, dynamic>> colaboradores;
  final List<Map<String, dynamic>> porcentajesContratista;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _RendimientoCard({
    required this.rendimiento,
    required this.esIndividual,
    required this.trabajadores,
    required this.colaboradores,
    required this.porcentajesContratista,
    required this.onEditar,
    required this.onEliminar,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    String porcentaje = '';
    if ((rendimiento['porcentaje_trabajador'] != null && rendimiento['id_trabajador'] != null) || (rendimiento['porcentaje'] != null && rendimiento['id_trabajador'] != null)) {
      if (rendimiento['porcentaje_trabajador'] != null) {
        final valor = (rendimiento['porcentaje_trabajador'] is num ? rendimiento['porcentaje_trabajador'] : double.tryParse(rendimiento['porcentaje_trabajador'].toString()) ?? 0) * 100;
        porcentaje = valor.toStringAsFixed(0) + '%';
      } else {
        var porc = rendimiento['porcentaje'] ?? rendimiento['porcentaje_individual'];
        if (porc == null && rendimiento['id_porcentaje_individual'] != null && rendimiento['porcentajes'] is List) {
          final p = (rendimiento['porcentajes'] as List).firstWhereOrNull((porc) => porc['id'].toString() == rendimiento['id_porcentaje_individual'].toString());
          if (p != null && p['porcentaje'] != null) porc = p['porcentaje'];
        }
        if (porc != null) {
          final valor = (porc is num ? porc : double.tryParse(porc.toString()) ?? 0) * 100;
          porcentaje = valor.toStringAsFixed(0) + '%';
        }
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onEditar,
      child: Card(
        color: Colors.white,
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.speed, color: theme.colorScheme.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                          onPressed: onEditar,
                          tooltip: 'Editar',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: onEliminar,
                          tooltip: 'Eliminar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (esIndividual) ...[
                      Row(
                        children: [
                          Icon(Icons.speed, color: Colors.green, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Rendimiento: ',
                            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          Text(
                            rendimiento['rendimiento']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (porcentaje.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.percent, color: Colors.green, size: 18),
                            const SizedBox(width: 2),
                            Text(
                              porcentaje,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(Icons.speed, color: Colors.green, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Rendimiento total: ',
                            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          Text(
                            rendimiento['rendimiento_total']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.groups, color: Colors.green, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Cantidad trabajadores: ',
                            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          Text(
                            rendimiento['cantidad_trab']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.percent, color: Colors.green, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Porcentaje: ',
                            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          Text(
                            (() {
                              var porcentaje = rendimiento['porcentaje'] ?? rendimiento['porcentaje_trabajador'];
                              if (porcentaje == null && rendimiento['id_porcentaje'] != null) {
                                final p = porcentajesContratista.firstWhereOrNull((porc) => porc['id'].toString() == rendimiento['id_porcentaje'].toString());
                                if (p != null && p['porcentaje'] != null) porcentaje = p['porcentaje'];
                              }
                              if (porcentaje != null) {
                                final valor = (porcentaje is num ? porcentaje : double.tryParse(porcentaje.toString()) ?? 0) * 100;
                                return valor.toStringAsFixed(0) + '%';
                              }
                              return '-';
                            })(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
