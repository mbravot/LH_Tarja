import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'nueva_actividad_page.dart';
import 'login_page.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'editar_actividad_page.dart';

class ActividadesPage extends StatefulWidget {
  final VoidCallback onRefresh;

  const ActividadesPage({
    required this.onRefresh,
    Key? key,
  }) : super(key: key);

  @override
  _ActividadesPageState createState() => _ActividadesPageState();
}

class _ActividadesPageState extends State<ActividadesPage> with SingleTickerProviderStateMixin {
  Future<List<dynamic>>? _futureActividades;
  Map<String, bool> _expansionState = {};
  TextEditingController searchController = TextEditingController();
  late AnimationController _refreshIconController;
  bool _isLoading = false;

  List<dynamic> todasActividades = [];
  List<dynamic> actividadesFiltradas = [];

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
    final token = prefs.getString('token');
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
      final actividades = await ApiService().getActividades();
      if (!mounted) return;

      List<dynamic> actividadesProcesadas = actividades.map((actividad) {
        try {
          DateTime fechaOriginal = DateTime.parse(actividad['fecha']);
          actividad['fecha_mostrada'] = DateFormat("dd/MM/yyyy").format(fechaOriginal);
          actividad['fecha_datetime'] = fechaOriginal;
        } catch (e) {
          actividad['fecha_mostrada'] = "Fecha inválida";
          actividad['fecha_datetime'] = DateTime(1970, 1, 1);
        }
        return actividad;
      }).toList();

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

  void _filtrarActividades() {
    String query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        actividadesFiltradas = [...todasActividades];
      } else {
        actividadesFiltradas = todasActividades.where((actividad) {
          return actividad['labor'].toString().toLowerCase().contains(query) ||
              actividad['contratista'].toString().toLowerCase().contains(query) ||
              actividad['ceco'].toString().toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _refreshActividades() async {
    _refreshIconController.repeat();
    await _cargarActividades();
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
          hintText: 'Buscar por labor, contratista o CECO',
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

  Widget _buildActividadCard(dynamic actividad) {
    final estado = actividad['estado'] ?? 'pendiente';
    final Color estadoColor = estado.toLowerCase() == 'creada' 
        ? Colors.orange 
        : estado.toLowerCase() == 'finalizada'
            ? Colors.green
            : Colors.grey;

    return InkWell(
      onTap: () async {
        final resultado = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditarActividadPage(
              actividad: actividad,
            ),
          ),
        );
        if (resultado == true) {
          _refreshActividades();
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
                      color: estadoColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
                  Icon(Icons.assessment, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Rendimiento: ${actividad['tipo_rend'] ?? 'No especificado'}',
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
