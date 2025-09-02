import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'nuevo_permiso_page.dart';
import 'editar_permiso_page.dart';
import 'package:intl/intl.dart';

class PermisosPage extends StatefulWidget {
  @override
  _PermisosPageState createState() => _PermisosPageState();
}

class _PermisosPageState extends State<PermisosPage> {
  List<Map<String, dynamic>> permisos = [];
  List<Map<String, dynamic>> permisosFiltrados = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();
  Map<String, bool> _mesExpandido = {};

  @override
  void initState() {
    super.initState();
    _cargarPermisos();
    searchController.addListener(_filtrarPermisos);
  }

  Future<void> _cargarPermisos() async {
    setState(() => isLoading = true);
    try {
      final lista = await ApiService().getPermisos();
      setState(() {
        permisos = lista;
        permisosFiltrados = lista;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _mostrarError('Error al cargar permisos: ${e.toString()}');
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
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _filtrarPermisos() {
    String query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => permisosFiltrados = List.from(permisos));
      return;
    }
    setState(() {
      permisosFiltrados = permisos.where((perm) {
        final colaborador = (perm['nombre_colaborador'] ?? '').toString().toLowerCase();
        final ap = (perm['apellido_paterno'] ?? '').toString().toLowerCase();
        final am = (perm['apellido_materno'] ?? '').toString().toLowerCase();
        final tipo = (perm['tipo_permiso'] ?? '').toString().toLowerCase();
        final estado = (perm['estado_permiso'] ?? '').toString().toLowerCase();
        final fecha = (perm['fecha'] ?? '').toString().toLowerCase();
        final actividad = (perm['nombre_actividad'] ?? '').toString().toLowerCase();
        return colaborador.contains(query) ||
               ap.contains(query) ||
               am.contains(query) ||
               tipo.contains(query) ||
               estado.contains(query) ||
               fecha.contains(query) ||
               actividad.contains(query);
      }).toList();
    });
  }

  Future<void> _eliminarPermiso(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Permiso'),
        content: Text('¿Estás seguro de que deseas eliminar este permiso?'),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: Text('Eliminar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService().eliminarPermiso(id);
        _cargarPermisos();
      } catch (e) {
        _mostrarError('Error al eliminar permiso: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Agrupar permisos por mes y año
    final Map<String, List<Map<String, dynamic>>> permisosPorMes = {};
    for (var permiso in permisosFiltrados) {
      final fecha = permiso['fecha'];
      String key = '--';
      if (fecha != null && fecha.isNotEmpty) {
        try {
          final dt = DateTime.parse(fecha);
          key = DateFormat('yyyy-MM').format(dt);
        } catch (_) {
          key = '--';
        }
      }
      permisosPorMes.putIfAbsent(key, () => []).add(permiso);
    }
    // Ordenar las claves de los meses del más actual al más antiguo
    final mesesOrdenados = permisosPorMes.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    // Inicializar el estado expandido si es la primera vez
    for (final mes in mesesOrdenados) {
      _mesExpandido.putIfAbsent(mes, () => true);
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: const Text(
          "Permisos",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPermisos,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
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
                controller: searchController,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: 'Buscar por colaborador, tipo, estado o fecha',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                          onPressed: () {
                            searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surface,
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
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : permisosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No hay permisos registrados',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: mesesOrdenados.length,
                        itemBuilder: (context, index) {
                          final mes = mesesOrdenados[index];
                          final dt = mes != '--' ? DateTime.parse(mes + '-01') : null;
                          final nombreMes = dt != null ? '${_nombreMes(dt.month)} ${dt.year}' : '--';
                          final cantidad = permisosPorMes[mes]?.length ?? 0;
                          final expandido = _mesExpandido[mes] ?? true;
                          final permisosDelMes = permisosPorMes[mes]!;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: expandido,
                                onExpansionChanged: (expanded) {
                                  setState(() => _mesExpandido[mes] = expanded);
                                },
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nombreMes,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$cantidad ${cantidad == 1 ? 'permiso' : 'permisos'}',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                children: permisosDelMes.map((permiso) {
                                  return _PermisoCard(
                                    permiso: permiso,
                                    onEditar: () async {
                                      bool? actualizado = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditarPermisoPage(permiso: permiso),
                                        ),
                                      );
                                      if (actualizado == true) {
                                        _cargarPermisos();
                                      }
                                    },
                                    onEliminar: () => _eliminarPermiso(permiso['id'].toString()),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NuevoPermisoPage(),
            ),
          );
          _cargarPermisos();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return '--';
    try {
      DateTime dt = DateTime.tryParse(fecha) ?? DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US').parseLoose(fecha, true);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      try {
        final dt = DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US').parseLoose(fecha, true);
        return DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        return fecha;
      }
    }
  }

  String _nombreMes(int mes) {
    const meses = [
      '',
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[mes];
  }
}

class _PermisoCard extends StatelessWidget {
  final Map<String, dynamic> permiso;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _PermisoCard({
    required this.permiso,
    required this.onEditar,
    required this.onEliminar,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                child: Icon(Icons.assignment_turned_in, color: theme.colorScheme.primary, size: 32),
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
                            (permiso['nombre_colaborador'] ?? '') +
                              ' ' + (permiso['apellido_paterno'] ?? '') +
                              ' ' + (permiso['apellido_materno'] ?? ''),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (permiso['estado_permiso'] == 'APROBADO')
                                ? Colors.green
                                : (permiso['estado_permiso'] == 'RECHAZADO')
                                    ? Colors.red
                                    : Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            permiso['estado_permiso'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Eliminar',
                          onPressed: onEliminar,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event, color: Colors.orange, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _formatearFecha(permiso['fecha']),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.category, color: Colors.blue, size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            permiso['tipo_permiso'] ?? '--',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.purple, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          permiso['horas'] != null ? '${permiso['horas']} horas' : '--',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return '--';
    try {
      DateTime dt = DateTime.tryParse(fecha) ?? DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US').parseLoose(fecha, true);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      try {
        final dt = DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US').parseLoose(fecha, true);
        return DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        return fecha;
      }
    }
  }
}
