import 'package:app_lh_tarja/pages/nuevo_trabajador_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/api_service.dart';
import 'editar_trabajador_page.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarTrabajadores();
    searchController.addListener(_filtrarTrabajadores);
  }

  Future<void> _cargarTrabajadores() async {
    if (!mounted) return;
    
    if (!isRefreshing) {
      setState(() => isLoading = true);
    }

    try {
      List<dynamic> datos = await ApiService().getTrabajadoresPorSucursal();
      if (!mounted) return;

      Map<String, List<dynamic>> agrupados = {};
      for (var trabajador in datos) {
        String contratista = trabajador['nombre_contratista'] ?? "Sin Contratista";
        if (!agrupados.containsKey(contratista)) {
          agrupados[contratista] = [];
        }
        agrupados[contratista]!.add(trabajador);
      }

      List<String> keysOrdenadas = agrupados.keys.toList()..sort();
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

    Map<String, List<dynamic>> filtrados = {};
    trabajadoresOriginales.forEach((contratista, lista) {
      final coincidencias = lista.where((trabajador) {
        final nombre = (trabajador['nom_ap'] ?? '').toLowerCase();
        final rut = (trabajador['rut'] ?? '').toLowerCase();
        final nombreContratista = contratista.toLowerCase();
        return nombre.contains(query) || 
               rut.contains(query) || 
               nombreContratista.contains(query);
      }).toList();

      if (coincidencias.isNotEmpty) {
        filtrados[contratista] = coincidencias;
      }
    });

    setState(() => trabajadoresAgrupados = filtrados);
  }

  Widget _buildTrabajadorCard(dynamic trabajador) {
    bool isActivo = trabajador['id_estado'] == 1;
    String estado = isActivo ? "Activo" : "Inactivo";
    
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) async {
              bool? actualizado = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditarTrabajadorPage(trabajador: trabajador),
                ),
              );
              if (actualizado == true) {
                _cargarTrabajadores();
              }
            },
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Editar',
          ),
        ],
      ),
      child: Hero(
        tag: 'trabajador-${trabajador['id']}',
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: InkWell(
              onTap: () async {
                bool? actualizado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditarTrabajadorPage(trabajador: trabajador),
                  ),
                );
                if (actualizado == true) {
                  _cargarTrabajadores();
                }
              },
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isActivo ? primaryColor.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        isActivo ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                trabajador['nom_ap'] ?? "Sin nombre",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActivo ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActivo ? Colors.green : Colors.red,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActivo ? Icons.check_circle : Icons.cancel,
                                    size: 16,
                                    color: isActivo ? Colors.green : Colors.red,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    estado,
                                    style: TextStyle(
                                      color: isActivo ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          "RUT: ${trabajador['rut'] ?? 'No especificado'}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.business,
                                size: 20,
                                color: primaryColor,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  trabajador['nombre_contratista'] ?? 'No asignado',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          "Trabajadores",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() => isRefreshing = true);
              _cargarTrabajadores();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarTrabajadores,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, RUT o contratista',
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                ),
              ),
            ),
            Expanded(
              child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : trabajadoresAgrupados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No hay trabajadores disponibles",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: trabajadoresAgrupados.keys.map((contratista) {
                        final cantidadTrabajadores = trabajadoresAgrupados[contratista]!.length;
                        return Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    contratista,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$cantidadTrabajadores trabajadores',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            initiallyExpanded: true,
                            children: trabajadoresAgrupados[contratista]!
                              .map((trabajador) => _buildTrabajadorCard(trabajador))
                              .toList(),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          bool? creado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NuevoTrabajadorPage()),
          );
          if (creado == true) {
            _cargarTrabajadores();
          }
        },
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: primaryColor,
      ),
    );
  }
}
