import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'crear_rendimiento_multiple_page.dart';
import 'editar_rendimiento_multiple_page.dart';

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
  List<Map<String, dynamic>> bonos = [];
  bool _seRealizoAccion = false;
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
          if (rendimiento['id_colaborador'] != null && colaboradores.isNotEmpty) {
            final c = colaboradores.firstWhereOrNull((x) => x['id'].toString() == rendimiento['id_colaborador'].toString());
            if (c != null) {
              nombre = ('${c['nombre']} ${c['apellido_paterno'] ?? ''} ${c['apellido_materno'] ?? ''}').trim();
            }
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

      // Cargar colaboradores y bonos para múltiples rendimientos
      final listaColaboradores = await _apiService.getColaboradoresRendimientoMultiple();
      final listaBonos = await _apiService.getBonosRendimientoMultiple();

      setState(() {
        colaboradores = List<Map<String, dynamic>>.from(listaColaboradores);
        bonos = List<Map<String, dynamic>>.from(listaBonos);
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
      
      // print("🔍 Cargando rendimientos múltiples para actividad: $idActividad");
      
      final rendimientos = await _apiService.getRendimientosMultiples(idActividad);
      
      // print("📥 Rendimientos múltiples recibidos: ${rendimientos.length}");
      
      setState(() {
        _rendimientos = rendimientos.map((r) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(r);
          map['tipo'] = 'multiple';
          return map;
        }).toList();
        _rendimientosFiltrados = List.from(_rendimientos);
        _isLoading = false;
      });
      
    } catch (e) {
      // print("❌ Error al cargar rendimientos múltiples: $e");
      setState(() {
        _error = 'Error al cargar los rendimientos múltiples: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _eliminarRendimiento(Map<String, dynamic> rendimiento) async {
    final bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar este rendimiento múltiple? Esta acción no se puede deshacer.'),
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

      try {
        final eliminado = await _apiService.eliminarRendimientoMultiple(rendimiento['id'].toString());

        if (eliminado) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rendimiento múltiple eliminado correctamente', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
            ),
          );
          _cargarRendimientos();
          _seRealizoAccion = true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo eliminar el rendimiento múltiple', style: TextStyle(color: Colors.white)),
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

  void _mostrarOpcionesCrearRendimiento() {
    _crearRendimientoMultiple();
  }

  void _crearRendimientoMultiple() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearRendimientoMultiplePage(
          actividad: widget.actividad,
        ),
      ),
    );
    if (result == true) {
      _cargarRendimientos();
      _seRealizoAccion = true;
    }
  }

  void _editarRendimiento(Map<String, dynamic> rendimiento) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarRendimientoMultiplePage(
          rendimiento: rendimiento,
          actividad: widget.actividad,
        ),
      ),
    );
    if (result == true) {
      _cargarRendimientos();
      _seRealizoAccion = true;
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
          title: Text('Rendimientos Múltiples - ${widget.actividad['nombre_labor']}'),
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
                      // Barra de búsqueda
                      _buildSearchBar(),
                      // Información de la actividad
                      _buildActividadInfo(),
                      // Lista de rendimientos
                      Expanded(
                        child: _rendimientosFiltrados.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay rendimientos múltiples registrados',
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
                                  return _RendimientoMultipleCard(
                                    rendimiento: rendimiento,
                                    colaboradores: colaboradores,
                                    actividad: widget.actividad,
                                    onEditar: () => _editarRendimiento(rendimiento),
                                    onEliminar: () => _eliminarRendimiento(rendimiento),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _mostrarOpcionesCrearRendimiento,
          child: Icon(Icons.add),
          tooltip: 'Agregar Rendimiento Múltiple',
        ),
      ),
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
    );
  }

  Widget _buildActividadInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.work,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Información de la Actividad',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Labor:', widget.actividad['nombre_labor'] ?? 'N/A'),
          _buildInfoRow('Fecha:', widget.actividad['fecha'] ?? 'N/A'),
          _buildInfoRow('Hora Inicio:', widget.actividad['hora_inicio'] ?? 'N/A'),
          _buildInfoRow('Hora Fin:', widget.actividad['hora_fin'] ?? 'N/A'),
          _buildInfoRow('Sucursal:', widget.actividad['nombre_sucursal'] ?? 'N/A'),
          _buildInfoRow('Estado:', widget.actividad['nombre_estado'] ?? 'N/A'),
          _buildInfoRow('Tipo CECO:', widget.actividad['nombre_tipoceco'] ?? 'N/A'),
        ],
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
}

class _RendimientoMultipleCard extends StatelessWidget {
  final Map<String, dynamic> rendimiento;
  final List<Map<String, dynamic>> colaboradores;
  final Map<String, dynamic> actividad;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _RendimientoMultipleCard({
    required this.rendimiento,
    required this.colaboradores,
    required this.actividad,
    required this.onEditar,
    required this.onEliminar,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Obtener nombre del colaborador
    String nombre = '';
    if (rendimiento['id_colaborador'] != null && colaboradores.isNotEmpty) {
      final c = colaboradores.firstWhereOrNull((x) => x['id'].toString() == rendimiento['id_colaborador'].toString());
      if (c != null) {
        nombre = ('${c['nombre']} ${c['apellido_paterno'] ?? ''} ${c['apellido_materno'] ?? ''}').trim();
      }
    }

    // Obtener información de CECOs
    String cecosInfo = '';
    if (rendimiento['cecos'] != null && rendimiento['cecos'] is List) {
      final cecos = rendimiento['cecos'] as List;
      if (cecos.isNotEmpty) {
        cecosInfo = cecos.map((ceco) => ceco['nombre'] ?? 'Sin nombre').join(', ');
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onEditar,
      child: Card(
        color: Colors.white,
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            nombre.isNotEmpty ? nombre : 'Colaborador no encontrado',
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
                      ],
                    ),
                    if (cecosInfo.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.category, color: Colors.purple, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'CECOs: $cecosInfo',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (rendimiento['observaciones'] != null && rendimiento['observaciones'].toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.note, color: Colors.grey, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Obs: ${rendimiento['observaciones']}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
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
