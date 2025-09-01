import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'crear_rendimiento_individual_page.dart';
import 'crear_rendimiento_grupal_page.dart';
import 'editar_rendimientos_individuales_page.dart';
import 'editar_rendimientos_grupales_page.dart';

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

class RendimientosPage extends StatefulWidget {
  final Map<String, dynamic> actividad;

  RendimientosPage({required this.actividad});

  @override
  _RendimientosPageState createState() => _RendimientosPageState();
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
  bool _seRealizoAccion = false; // Variable para rastrear si se realizó alguna acción
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarColaboradoresYTrabajadoresYPorcentajesYRendimientos();
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

  Future<void> _cargarColaboradoresYTrabajadoresYPorcentajesYRendimientos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Forzar recarga
      final idSucursal = prefs.getString('id_sucursal');
      // logInfo('Sucursal activa usada para cargar colaboradores/rendimientos: $idSucursal');
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
      
      // logInfo("🔍 ====== CARGANDO RENDIMIENTOS ======");
      // logInfo("🔍 Actividad ID: $idActividad");
      // logInfo("🔍 Tipo rendimiento: $tipo");
      // logInfo("🔍 Tipo trabajador: $idTipotrabajador");
      // logInfo("🔍 Contratista ID: $idContratista");
      // logInfo("🔍 Actividad completa: ${widget.actividad}");
      
      // Limpiar rendimientos anteriores
      setState(() {
        _rendimientos = [];
        _rendimientosFiltrados = [];
      });

      if (tipo == 1) { // Individual
        if (idTipotrabajador == 1) { // Propio
          // logInfo("🔍 Cargando rendimientos individuales PROPIOS");
          final rendimientosPropios = await _apiService.getRendimientosIndividualesPropios(
            idActividad: idActividad
          );
          // logInfo("📥 Rendimientos propios recibidos: ${rendimientosPropios.length}");
          
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
            // logInfo("❌ Error: Actividad de contratista sin ID de contratista");
            setState(() {
              _error = 'Error: Actividad de contratista sin ID de contratista';
              _isLoading = false;
            });
            return;
          }
          
          // logInfo("🔍 Cargando rendimientos individuales de CONTRATISTA");
          // logInfo("🔍 ID Actividad: $idActividad");
          // logInfo("🔍 ID Contratista: $idContratista");
          
          final rendimientosContratistas = await _apiService.getRendimientosIndividualesContratistas(
            idActividad: idActividad,
            idContratista: idContratista
          );
          
          // logInfo("📥 Rendimientos contratistas recibidos: ${rendimientosContratistas.length}");
          // rendimientosContratistas.forEach((r) {
          //   logInfo("📥 Rendimiento: ID Actividad=${r['id_actividad']}, ID Contratista=${r['id_contratista']}");
          // });
          
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
        // logInfo("🔍 Cargando rendimientos GRUPALES");
        final data = await _apiService.getRendimientos(idActividad: idActividad);
        if (data['rendimientos'] != null && data['rendimientos'] is List) {
          final List<dynamic> rawRendimientos = data['rendimientos'];
          // logInfo("📥 Rendimientos grupales recibidos: ${rawRendimientos.length}");
          
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
      
      // logInfo("✅ Carga de rendimientos completada");
      // logInfo("✅ Total rendimientos: ${_rendimientos.length}");
      // logInfo("✅ ====== FIN CARGA RENDIMIENTOS ======");
      
    } catch (e) {
      logError("❌ Error al cargar rendimientos: $e");
      setState(() {
        _error = 'Error al cargar los rendimientos: $e';
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
                            onChanged: _filtrarRendimientos,
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
                            : Column(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
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
                                          actividad: widget.actividad,
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
                                                _seRealizoAccion = true; // Marcar que se realizó una acción
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
                                                _seRealizoAccion = true; // Marcar que se realizó una acción
                                              }
                                            }
                                          },
                                          onEliminar: () => _confirmarEliminarRendimiento(rendimiento),
                                        );
                                      },
                                    ),
                                  ),
                                                                                                        // Widget de resumen total (abajo de la lista, arriba del botón flotante)
                                   if (_rendimientosFiltrados.isNotEmpty)
                                     Column(
                                       children: [
                                         Container(
                                           margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                           padding: const EdgeInsets.all(16),
                                           decoration: BoxDecoration(
                                             color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                             borderRadius: BorderRadius.circular(12),
                                             border: Border.all(
                                               color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                               width: 1,
                                             ),
                                           ),
                                           child: Row(
                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                             children: [
                                               Row(
                                                 children: [
                                                   Icon(
                                                     Icons.calculate,
                                                     color: Theme.of(context).colorScheme.primary,
                                                     size: 24,
                                                   ),
                                                   const SizedBox(width: 8),
                                                   Text(
                                                     'Rendimiento Total Actividad:',
                                                     style: TextStyle(
                                                       fontSize: 16,
                                                       fontWeight: FontWeight.bold,
                                                       color: Theme.of(context).colorScheme.primary,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                               Row(
                                                 children: [
                                                   Text(
                                                     _calcularRendimientoTotal().toStringAsFixed(1),
                                                     style: TextStyle(
                                                       fontSize: 18,
                                                       fontWeight: FontWeight.bold,
                                                       color: Theme.of(context).colorScheme.primary,
                                                     ),
                                                   ),
                                                   const SizedBox(width: 8),
                                                   Icon(
                                                     Icons.category,
                                                     color: Theme.of(context).colorScheme.primary,
                                                     size: 16,
                                                   ),
                                                   const SizedBox(width: 2),
                                                   Text(
                                                     widget.actividad['nombre_unidad'] ?? 'unidad',
                                                     style: TextStyle(
                                                       fontSize: 14,
                                                       fontWeight: FontWeight.w500,
                                                       color: Theme.of(context).colorScheme.primary,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             ],
                                           ),
                                         ),
                                         // Widget de pago total actividad
                                         Container(
                                           margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                                           padding: const EdgeInsets.all(16),
                                           decoration: BoxDecoration(
                                             color: Colors.green.withOpacity(0.1),
                                             borderRadius: BorderRadius.circular(12),
                                             border: Border.all(
                                               color: Colors.green.withOpacity(0.3),
                                               width: 1,
                                             ),
                                           ),
                                           child: Row(
                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                             children: [
                                               Row(
                                                 children: [
                                                   Icon(
                                                     Icons.attach_money,
                                                     color: Colors.green,
                                                     size: 24,
                                                   ),
                                                   const SizedBox(width: 8),
                                                   Text(
                                                     'Pago Total Actividad:',
                                                     style: TextStyle(
                                                       fontSize: 16,
                                                       fontWeight: FontWeight.bold,
                                                       color: Colors.green,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                               Row(
                                                 children: [
                                                   Text(
                                                     _formatearPesoChileno(_calcularPagoTotal()),
                                                     style: TextStyle(
                                                       fontSize: 18,
                                                       fontWeight: FontWeight.bold,
                                                       color: Colors.green,
                                                     ),
                                                   ),
                                                   const SizedBox(width: 8),
                                                   Icon(
                                                     Icons.monetization_on,
                                                     color: Colors.green,
                                                     size: 16,
                                                   ),
                                                   const SizedBox(width: 2),
                                                   Text(
                                                     'CLP',
                                                     style: TextStyle(
                                                       fontSize: 14,
                                                       fontWeight: FontWeight.w500,
                                                       color: Colors.green,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             ],
                                           ),
                                         ),
                                       ],
                                     ),
                                ],
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
                _seRealizoAccion = true; // Marcar que se realizó una acción
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
                _seRealizoAccion = true; // Marcar que se realizó una acción
              }
            }
          },
          child: Icon(Icons.add),
          tooltip: 'Agregar Rendimiento',
        ),
      ),
    );
  }

  // Método para calcular el rendimiento total de la actividad
  double _calcularRendimientoTotal() {
    double total = 0.0;
    
    for (var rendimiento in _rendimientosFiltrados) {
      if (rendimiento['tipo'] == 'grupal') {
        // Para rendimientos grupales, usar rendimiento_total
        double valor = double.tryParse(rendimiento['rendimiento_total']?.toString() ?? '0') ?? 0.0;
        total += valor;
      } else {
        // Para rendimientos individuales (propios y de contratista)
        double valor = double.tryParse(rendimiento['rendimiento']?.toString() ?? '0') ?? 0.0;
        total += valor;
      }
    }
    
    return total;
  }

    // Método para calcular el pago total de la actividad
  double _calcularPagoTotal() {
    double pagoTotal = 0.0;
    double tarifa = double.tryParse(widget.actividad['tarifa']?.toString() ?? '0') ?? 0.0;
    
    for (var rendimiento in _rendimientosFiltrados) {
      if (rendimiento['tipo'] == 'grupal') {
        // Para rendimientos grupales: rendimiento_total * tarifa * (1 + porcentaje)
        double rendimientoTotal = double.tryParse(rendimiento['rendimiento_total']?.toString() ?? '0') ?? 0.0;
        
        // Obtener el porcentaje del rendimiento grupal
        double porcentaje = 0.0;
        var porcentajeValor = rendimiento['porcentaje'] ?? rendimiento['porcentaje_trabajador'];
        if (porcentajeValor == null && rendimiento['id_porcentaje'] != null) {
          final p = porcentajesContratista.firstWhereOrNull((porc) => porc['id'].toString() == rendimiento['id_porcentaje'].toString());
          if (p != null && p['porcentaje'] != null) porcentajeValor = p['porcentaje'];
        }
        if (porcentajeValor != null) {
          porcentaje = porcentajeValor is num ? (porcentajeValor as num).toDouble() : double.tryParse(porcentajeValor.toString()) ?? 0.0;
        }
        
        // Calcular: rendimiento_total * tarifa * (1 + porcentaje)
        double pagoGrupal = rendimientoTotal * tarifa * (1 + porcentaje);
        pagoTotal += pagoGrupal;
      } else {
        // Para rendimientos individuales
        double rendimientoValor = double.tryParse(rendimiento['rendimiento']?.toString() ?? '0') ?? 0.0;
        
        // Verificar si es rendimiento de contratista (tiene id_trabajador)
        if (rendimiento['id_trabajador'] != null) {
          // Para rendimientos individuales de contratista: rendimiento * tarifa * (1 + porcentaje)
          double porcentaje = 0.0;
          var porcentajeValor = rendimiento['porcentaje'] ?? rendimiento['porcentaje_trabajador'] ?? rendimiento['porcentaje_individual'];
          if (porcentajeValor == null && rendimiento['id_porcentaje_individual'] != null) {
            final p = porcentajesContratista.firstWhereOrNull((porc) => porc['id'].toString() == rendimiento['id_porcentaje_individual'].toString());
            if (p != null && p['porcentaje'] != null) porcentajeValor = p['porcentaje'];
          }
          if (porcentajeValor != null) {
            porcentaje = porcentajeValor is num ? (porcentajeValor as num).toDouble() : double.tryParse(porcentajeValor.toString()) ?? 0.0;
          }
          
          // Calcular: rendimiento * tarifa * (1 + porcentaje)
          double pagoIndividualContratista = rendimientoValor * tarifa * (1 + porcentaje);
          pagoTotal += pagoIndividualContratista;
        } else {
          // Para rendimientos individuales propios: rendimiento * tarifa
          double pagoIndividualPropio = rendimientoValor * tarifa;
          pagoTotal += pagoIndividualPropio;
        }
      }
    }
    
    return pagoTotal;
  }

  // Método para formatear peso chileno con separación de miles y 2 decimales
  String _formatearPesoChileno(double valor) {
    return valor.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]}.'
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
          _seRealizoAccion = true; // Marcar que se realizó una acción
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
  final Map<String, dynamic> actividad;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _RendimientoCard({
    required this.rendimiento,
    required this.esIndividual,
    required this.trabajadores,
    required this.colaboradores,
    required this.porcentajesContratista,
    required this.actividad,
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
    
    // Método para calcular el pago por persona (individual)
    double _calcularPagoPorPersona(Map<String, dynamic> rendimiento) {
      double rendimientoValor = double.tryParse(rendimiento['rendimiento']?.toString() ?? '0') ?? 0.0;
      double tarifa = double.tryParse(actividad['tarifa']?.toString() ?? '0') ?? 0.0;
      return rendimientoValor * tarifa;
    }
    
    // Método para calcular el pago estimado por persona (grupal)
    double _calcularPagoEstimadoPorPersona(Map<String, dynamic> rendimiento) {
      double rendimientoTotal = double.tryParse(rendimiento['rendimiento_total']?.toString() ?? '0') ?? 0.0;
      double cantidadTrabajadores = double.tryParse(rendimiento['cantidad_trab']?.toString() ?? '1') ?? 1.0;
      double tarifa = double.tryParse(actividad['tarifa']?.toString() ?? '0') ?? 0.0;
      
      // (Rendimiento total ÷ Cantidad trabajadores) × Tarifa
      double rendimientoPorPersona = rendimientoTotal / cantidadTrabajadores;
      return rendimientoPorPersona * tarifa;
    }
    
    // Método para formatear peso chileno
    String _formatearPesoChileno(double valor) {
      return valor.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match match) => '${match[1]}.'
      );
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
                child: Icon(Icons.person, color: theme.colorScheme.primary, size: 32),
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
                           Icon(Icons.speed, color: Colors.orange, size: 18),
                           const SizedBox(width: 4),
                           Text(
                             'Rendimiento: ',
                             style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                           ),
                           Text(
                             rendimiento['rendimiento']?.toString() ?? '-',
                             style: const TextStyle(fontWeight: FontWeight.w500),
                           ),
                           const SizedBox(width: 8),
                           Icon(
                             Icons.straighten,
                             color: Colors.blue,
                             size: 14,
                           ),
                           const SizedBox(width: 2),
                           Text(
                             actividad['nombre_unidad'] ?? 'unidad',
                             style: TextStyle(
                               color: Colors.grey[600],
                               fontWeight: FontWeight.w500,
                               fontSize: 12,
                             ),
                           ),
                           if (porcentaje.isNotEmpty) ...[
                             const SizedBox(width: 12),
                             Icon(Icons.percent, color: Colors.purple, size: 18),
                             const SizedBox(width: 2),
                             Text(
                               porcentaje,
                               style: const TextStyle(fontWeight: FontWeight.w500),
                             ),
                           ],
                         ],
                       ),
                       const SizedBox(height: 2),
                       Row(
                         children: [
                           Icon(Icons.attach_money, color: Colors.green, size: 18),
                           const SizedBox(width: 4),
                           Text(
                             'Líquido por persona: ',
                             style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                           ),
                           Text(
                             _formatearPesoChileno(_calcularPagoPorPersona(rendimiento)),
                             style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green),
                           ),
                           const SizedBox(width: 8),
                           Icon(
                             Icons.monetization_on,
                             color: Colors.green,
                             size: 14,
                           ),
                           const SizedBox(width: 2),
                           Text(
                             'CLP',
                             style: TextStyle(
                               color: Colors.green,
                               fontWeight: FontWeight.w500,
                               fontSize: 12,
                             ),
                           ),
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
                           const SizedBox(width: 8),
                           Icon(
                             Icons.straighten,
                             color: Colors.blue,
                             size: 14,
                           ),
                           const SizedBox(width: 2),
                           Text(
                             actividad['nombre_unidad'] ?? 'unidad',
                             style: TextStyle(
                               color: Colors.grey[600],
                               fontWeight: FontWeight.w500,
                               fontSize: 12,
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 2),
                       Row(
                         children: [
                           Icon(Icons.groups, color: Colors.orange, size: 18),
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
                           Icon(Icons.percent, color: Colors.purple, size: 18),
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
                       const SizedBox(height: 2),
                       Row(
                         children: [
                           Icon(Icons.attach_money, color: Colors.green, size: 18),
                           const SizedBox(width: 4),
                           Text(
                             'Líquido promedio por persona: ',
                             style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                           ),
                           Text(
                             _formatearPesoChileno(_calcularPagoEstimadoPorPersona(rendimiento)),
                             style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green),
                           ),
                           const SizedBox(width: 8),
                           Icon(
                             Icons.monetization_on,
                             color: Colors.green,
                             size: 14,
                           ),
                           const SizedBox(width: 2),
                           Text(
                             'CLP',
                             style: TextStyle(
                               color: Colors.green,
                               fontWeight: FontWeight.w500,
                               fontSize: 12,
                             ),
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