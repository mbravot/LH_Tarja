import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'nuevo_rendimiento_page.dart';
import 'editar_rendimiento_page.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class RendimientosPage extends StatefulWidget {
  final VoidCallback onRefresh;

  const RendimientosPage({
    required this.onRefresh,
    Key? key,
  }) : super(key: key);

  @override
  _RendimientosPageState createState() => _RendimientosPageState();
}

class _RendimientosPageState extends State<RendimientosPage> with SingleTickerProviderStateMixin {
  Future<List<dynamic>>? _futureRendimientos;
  List<dynamic> actividades = [];
  List<dynamic> todosRendimientos = [];
  List<dynamic> rendimientosFiltrados = [];
  Map<String, bool> _expansionState = {};
  TextEditingController searchController = TextEditingController();
  late AnimationController _refreshIconController;
  bool _isLoading = false;

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
      _cargarDatos();
    });
    searchController.addListener(_filtrarRendimientos);
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
      print("❌ Error al formatear fecha: $e");
      return fechaOriginal;
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      actividades = await ApiService().getActividades();
      List<dynamic> rendimientos = await ApiService().getRendimientos(idActividad: null);

      if (!mounted) return;

      // Ordenar rendimientos por fecha (más reciente primero)
      rendimientos.sort((a, b) {
        try {
          DateTime fechaA = DateTime.parse(a['fecha']);
          DateTime fechaB = DateTime.parse(b['fecha']);
          return fechaB.compareTo(fechaA);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        todosRendimientos = rendimientos;
        rendimientosFiltrados = rendimientos;
        _futureRendimientos = Future.value(rendimientos);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      print("❌ Error al cargar datos: $e");
      setState(() {
        _futureRendimientos = Future.error("No se pudieron cargar los datos.");
        _isLoading = false;
      });
      _mostrarError("No se pudieron cargar los datos");
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

  void _filtrarRendimientos() {
    String query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        rendimientosFiltrados = [...todosRendimientos];
      } else {
        rendimientosFiltrados = todosRendimientos.where((rend) {
          final actividad = _obtenerDatosActividad(rend['id_actividad']);
          final labor = actividad['labor']?.toLowerCase() ?? '';
          final contratista = actividad['contratista']?.toLowerCase() ?? '';
          final trabajador = rend['trabajador']?.toString().toLowerCase() ?? '';

          return labor.contains(query) ||
              contratista.contains(query) ||
              trabajador.contains(query);
        }).toList();
      }
    });
  }

  Map<String, dynamic> _obtenerDatosActividad(dynamic idActividad) {
    try {
      final actividad = actividades.firstWhere(
        (act) => act['id'].toString() == idActividad.toString(),
        orElse: () => {
          "id": '',
          "labor": "No asignado",
          "contratista": "No asignado",
          'ceco': '',
          'id_tipo_rend': 1,
        },
      );
      
      return {
        "id": actividad['id'] ?? '',
        "labor": actividad['labor'] ?? "No asignado",
        "contratista": actividad['contratista'] ?? "No asignado",
        'ceco': actividad['ceco'] ?? '',
        'id_tipo_rend': actividad['id_tipo_rend'] ?? 1,
      };
    } catch (e) {
      print('Error al obtener datos de actividad: $e');
      return {
        "id": '',
        "labor": "No asignado",
        "contratista": "No asignado",
        'ceco': '',
        'id_tipo_rend': 1,
      };
    }
  }

  Future<void> _refreshRendimientos() async {
    _refreshIconController.repeat();
    await _cargarDatos();
    _refreshIconController.stop();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshRendimientos,
            color: primaryColor,
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(child: _buildRendimientosList()),
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
                  MaterialPageRoute(builder: (context) => NuevoRendimientoPage()),
                );
                if (resultado == true) {
                  _refreshRendimientos();
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
        color: Colors.white,
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
          hintText: 'Buscar por labor, contratista o trabajador',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: primaryColor),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[50],
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
    );
  }

  Widget _buildRendimientosList() {
    return FutureBuilder<List<dynamic>>(
      future: _futureRendimientos,
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
                  "Error al cargar los rendimientos",
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _refreshRendimientos,
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

        if (rendimientosFiltrados.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  searchController.text.isEmpty
                      ? "No hay rendimientos registrados"
                      : "No se encontraron resultados",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        Map<String, List<dynamic>> rendimientosPorFecha = {};
        for (var rendimiento in rendimientosFiltrados) {
          String fecha = _formatearFecha(rendimiento['fecha']);
          if (!rendimientosPorFecha.containsKey(fecha)) {
            rendimientosPorFecha[fecha] = [];
            _expansionState[fecha] = _expansionState[fecha] ?? true;
          }
          rendimientosPorFecha[fecha]!.add(rendimiento);
        }

        return ListView.builder(
          padding: EdgeInsets.only(bottom: 80),
          itemCount: rendimientosPorFecha.length,
          itemBuilder: (context, index) {
            String fecha = rendimientosPorFecha.keys.elementAt(index);
            List<dynamic> rendimientosDelDia = rendimientosPorFecha[fecha]!;

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
                          '${rendimientosDelDia.length} ${rendimientosDelDia.length == 1 ? 'rendimiento' : 'rendimientos'}',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: rendimientosDelDia.map((rendimiento) {
                    return _buildRendimientoCard(rendimiento);
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRendimientoCard(dynamic rendimiento) {
    final actividad = _obtenerDatosActividad(rendimiento['id_actividad']);
    final tipoRendimiento = actividad['id_tipo_rend'] == 1 ? 'Individual' : 'Grupal';

    return InkWell(
      onTap: () async {
        final resultado = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditarRendimientoPage(
              rendimiento: rendimiento,
            ),
          ),
        );
        if (resultado == true) {
          _refreshRendimientos();
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.work, color: primaryColor, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      actividad['labor'] ?? 'Sin labor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed, color: primaryColor, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Rendimiento: ${rendimiento['rendimiento'] ?? '0'}',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.business, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    actividad['contratista'] ?? 'Sin contratista',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.folder, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'CECO: ${actividad['ceco'] ?? 'No especificado'}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Trabajador: ${rendimiento['trabajador'] ?? 'No especificado'}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.group_work, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Tipo Rendimiento: $tipoRendimiento',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
