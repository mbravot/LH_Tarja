import 'package:app_lh_tarja/pages/nuevo_trabajador_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/api_service.dart';
import 'editar_trabajador_page.dart';
import 'package:app_lh_tarja/utils/colors.dart';
import 'package:app_lh_tarja/pages/home_page.dart';

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

class TrabajadoresPage extends StatefulWidget {
  @override
  _TrabajadoresPageState createState() => _TrabajadoresPageState();
}

class _TrabajadoresPageState extends State<TrabajadoresPage> {
  final Color primaryColor = Colors.green;
  Map<String, List<dynamic>> trabajadoresAgrupados = {};
  Map<String, List<dynamic>> trabajadoresOriginales = {};
  bool isLoading = true;
  bool isRefreshing = false;
  final TextEditingController searchController = TextEditingController();

  // NUEVO: Listas auxiliares para lookup
  List<Map<String, dynamic>> contratistas = [];
  List<Map<String, dynamic>> porcentajes = [];

  // NUEVO: Estado de expansión por grupo de contratista
  Map<String, bool> _expansionStateTrabajadores = {};

  @override
  void initState() {
    super.initState();
    _cargarListasAuxiliares();
    _cargarTrabajadores();
    searchController.addListener(_filtrarTrabajadores);
  }

  Future<void> _cargarListasAuxiliares() async {
    try {
      final idSucursal = await ApiService().getSucursalActiva();
      final listaContratistas = await ApiService().getContratistas(idSucursal!);
      final listaPorcentajes = await ApiService().getPorcentajesContratista();
      setState(() {
        contratistas = listaContratistas;
        porcentajes = listaPorcentajes;
      });
      // DEPURACIÓN MEJORADA
      // logInfo('================ CONTRATISTAS CARGADOS ================');
      // if (contratistas.isEmpty) {
      //   logInfo('¡La lista de contratistas está VACÍA!');
      // } else {
      //   for (var c in contratistas) {
      //     logInfo('Contratista: ${c.toString()}');
      //   }
      // }
      // logInfo('================ PORCENTAJES CARGADOS ================');
      // if (porcentajes.isEmpty) {
      //   logInfo('¡La lista de porcentajes está VACÍA!');
      // } else {
      //   for (var p in porcentajes) {
      //     logInfo('Porcentaje: ${p.toString()}');
      //   }
      // }
      // logInfo('=======================================================');
    } catch (e) {
      // Si falla, deja las listas vacías
      setState(() {
        contratistas = [];
        porcentajes = [];
      });
    }
  }

  Future<void> _cargarTrabajadores() async {
    if (!mounted) return;
    
    if (!isRefreshing) {
      setState(() => isLoading = true);
    }

    try {
      List<dynamic> datos = await ApiService().getTrabajadoresPorSucursal();
      if (!mounted) return;

      // Agrupar por id_contratista
      Map<String, List<dynamic>> agrupados = {};
      for (var trabajador in datos) {
        String idContratista = trabajador['id_contratista']?.toString() ?? 'sin';
        if (!agrupados.containsKey(idContratista)) {
          agrupados[idContratista] = [];
        }
        agrupados[idContratista]!.add(trabajador);
      }

      // Ordenar por nombre de contratista usando el lookup
      List<String> keysOrdenadas = agrupados.keys.toList()
        ..sort((a, b) => _getNombreContratista(a).compareTo(_getNombreContratista(b)));
      Map<String, List<dynamic>> trabajadoresOrdenados = {
        for (var key in keysOrdenadas) key: agrupados[key]!
      };

      setState(() {
        trabajadoresAgrupados = trabajadoresOrdenados;
        trabajadoresOriginales = trabajadoresOrdenados;
        isLoading = false;
        isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
      
      _mostrarError('Error al cargar trabajadores: ${e.toString()}');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    
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

  void _filtrarTrabajadores() {
    String query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => trabajadoresAgrupados = Map.from(trabajadoresOriginales));
      return;
    }

    // Unir todos los trabajadores en una lista plana
    List<dynamic> todos = trabajadoresOriginales.values.expand((x) => x).toList();
    // Filtrar por nombre, apellidos, rut o nombre de contratista
    List<dynamic> filtrados = todos.where((trabajador) {
      final nombre = (trabajador['nombre'] ?? '').toString().toLowerCase();
      final ap = (trabajador['apellido_paterno'] ?? '').toString().toLowerCase();
      final am = (trabajador['apellido_materno'] ?? '').toString().toLowerCase();
      final rut = (trabajador['rut'] ?? '').toString().toLowerCase();
      final dv = (trabajador['codigo_verificador'] ?? '').toString().toLowerCase();
      final nombreContratista = _getNombreContratista(trabajador['id_contratista']).toLowerCase();
        return nombre.contains(query) || 
             ap.contains(query) ||
             am.contains(query) ||
             ('$rut-$dv').contains(query) ||
               nombreContratista.contains(query);
      }).toList();

    // Reagrupar los filtrados por contratista
    Map<String, List<dynamic>> agrupados = {};
    for (var trabajador in filtrados) {
      String idContratista = trabajador['id_contratista']?.toString() ?? 'sin';
      if (!agrupados.containsKey(idContratista)) {
        agrupados[idContratista] = [];
      }
      agrupados[idContratista]!.add(trabajador);
                }
    // Ordenar por nombre de contratista
    List<String> keysOrdenadas = agrupados.keys.toList()
      ..sort((a, b) => _getNombreContratista(a).compareTo(_getNombreContratista(b)));
    Map<String, List<dynamic>> trabajadoresOrdenados = {
      for (var key in keysOrdenadas) key: agrupados[key]!
    };

    setState(() => trabajadoresAgrupados = trabajadoresOrdenados);
  }

  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  return Scaffold(
    appBar: AppBar(
      backgroundColor: theme.colorScheme.primary,
      title: const Text(
        "Trabajadores",
        style: TextStyle(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _cargarTrabajadores,
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
                hintText: 'Buscar por nombre, apellido o RUT',
                hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search,
                    color: theme.colorScheme.primary),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.6)),
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
                  borderSide: BorderSide(
                      color: theme.colorScheme.primary, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              ),
            ),
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : trabajadoresAgrupados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No hay trabajadores registrados',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 80),
                      children: [
                        for (final entry in trabajadoresAgrupados.entries)
                          Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                key: PageStorageKey(entry.key),
                                initiallyExpanded:
                                    _expansionStateTrabajadores[entry.key] ??
                                        true,
                                onExpansionChanged: (expanded) {
                                  setState(() => _expansionStateTrabajadores[
                                      entry.key] = expanded);
                                },
                                tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                title: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.13),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(Icons.groups,
                                          color: Colors.orange,
                                          size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _getNombreContratista(entry.key),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${entry.value.length} trabajador${entry.value.length == 1 ? '' : 'es'}',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  for (final trabajador in entry.value)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(15),
                                      onTap: () async {
                                        bool? actualizado =
                                            await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditarTrabajadorPage(
                                                    trabajador: trabajador),
                                          ),
                                        );
                                        if (actualizado == true) {
                                          _cargarTrabajadores();
                                        }
                                      },
                                      child: Card(
                                        color: Colors.white,
                                        elevation: 3,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          side: BorderSide(
                                              color: Colors.grey[200]!),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 16),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme
                                                      .primary
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Icon(Icons.person,
                                                    color: theme
                                                        .colorScheme.primary,
                                                    size: 32),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            _nombreCompleto(
                                                                trabajador),
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16,
                                                                color: Colors
                                                                    .black87),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                      .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: (trabajador[
                                                                        'id_estado'] ==
                                                                    1)
                                                                ? Colors.green
                                                                : Colors.red,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: Text(
                                                            (trabajador[
                                                                        'id_estado'] ==
                                                                    1)
                                                                ? 'Activo'
                                                                : 'Inactivo',
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 13),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.badge,
                                                            color: Colors.blue,
                                                            size: 18),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          (trabajador['rut'] == null || trabajador['rut'].toString().isEmpty) && (trabajador['codigo_verificador'] == null || trabajador['codigo_verificador'].toString().isEmpty)
                                                              ? 'SIN RUT'
                                                              : '${trabajador['rut'] ?? ''}-${trabajador['codigo_verificador'] ?? ''}',
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.groups,
                                                            color: Colors.orange,
                                                            size: 18),
                                                        const SizedBox(
                                                            width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            _getNombreContratista(
                                                                trabajador[
                                                                    'id_contratista']),
                                                            style:
                                                                const TextStyle(
                                                              color: Colors
                                                                  .black54,
                                                              fontSize: 14,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.percent,
                                                            color: Colors.purple,
                                                            size: 18),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          _getValorPorcentaje(
                                                              trabajador[
                                                                  'id_porcentaje']),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors
                                                                .black54,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
            builder: (context) => NuevoTrabajadorPage(),
          ),
        );
        _cargarTrabajadores();
      },
      child: const Icon(Icons.add, color: Colors.white),
    ),
  );
}


  String _nombreCompleto(dynamic trabajador) {
    final nombre = trabajador['nombre'] ?? '';
    final ap = trabajador['apellido_paterno'] ?? '';
    final am = trabajador['apellido_materno'] ?? '';
    return [nombre, ap, am].where((s) => s.isNotEmpty).join(' ');
  }

  // NUEVO: Métodos auxiliares para lookup
  String _getNombreContratista(dynamic idContratista) {
    if (idContratista == null) return 'Sin Contratista';
    final c = contratistas.firstWhere(
      (x) => x['id'].toString() == idContratista.toString(),
      orElse: () => {},
    );
    // DEPURACIÓN
            // logInfo('Buscando contratista para id: $idContratista, encontrado: ${c['nombre']}');
    return c.isNotEmpty ? (c['nombre'] ?? 'Sin Contratista') : 'Sin Contratista';
  }

  String _getValorPorcentaje(dynamic idPorcentaje) {
    if (idPorcentaje == null) return '--';
    final p = porcentajes.firstWhere(
      (x) => x['id'].toString() == idPorcentaje.toString(),
      orElse: () => {},
    );
    // DEPURACIÓN
            // logInfo('Buscando porcentaje para id: $idPorcentaje, encontrado: ${p['porcentaje']}');
    if (p.isNotEmpty && p['porcentaje'] != null) {
      final valor = p['porcentaje'];
      if (valor is num) {
        return '${(valor * 100).round()}%';
      }
      return '$valor%';
    }
    return '--';
  }
}
