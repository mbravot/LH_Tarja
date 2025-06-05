import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'editar_contratista_page.dart';
import 'nuevo_contratista_page.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ContratistasPage extends StatefulWidget {
  @override
  _ContratistasPageState createState() => _ContratistasPageState();
}

class _ContratistasPageState extends State<ContratistasPage> with SingleTickerProviderStateMixin {
  List<dynamic> contratistas = [];
  List<dynamic> contratistasFiltrados = [];
  bool isLoading = true;
  bool isRefreshing = false;
  TextEditingController searchController = TextEditingController();
  late AnimationController _animationController;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  // Colores consistentes
  final Color primaryColor = Colors.green;
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = Colors.grey[100]!;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _cargarContratistas();
    searchController.addListener(_filtrarContratistas);
  }

  Future<void> _cargarContratistas() async {
    if (!mounted) return;
    
    if (!isRefreshing) {
      setState(() => isLoading = true);
    }

    try {
      List<dynamic> datos = await ApiService().getContratistasPorSucursal();
      if (!mounted) return;
      
      setState(() {
        contratistas = datos;
        contratistasFiltrados = datos;
        isLoading = false;
        isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
      
      _mostrarError('Error al cargar contratistas: ${e.toString()}');
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

  Future<void> _onRefresh() async {
    setState(() => isRefreshing = true);
    await _cargarContratistas();
  }

  void _filtrarContratistas() {
    String query = searchController.text.toLowerCase();
    setState(() {
      contratistasFiltrados = contratistas.where((contratista) {
        final nombre = contratista['nombre']?.toLowerCase() ?? '';
        final rut = contratista['rut']?.toLowerCase() ?? '';
        final sucursal = contratista['nombre_sucursal']?.toLowerCase() ?? '';
        return nombre.contains(query) || rut.contains(query) || sucursal.contains(query);
      }).toList();
    });
  }

  Future<void> _confirmarEdicion(dynamic contratista, BuildContext context) async {
    if (contratista['id_estado'] != 1) {
      bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Contratista Inactivo'),
            content: Text('Este contratista está inactivo. ¿Desea editarlo de todas formas?'),
            actions: [
              TextButton(
                child: Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: Text('Editar'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );
      
      if (confirmar != true) return;
    }

    bool? actualizado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarContratistaPage(contratista: contratista),
      ),
    );

    if (actualizado == true) {
      _cargarContratistas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contratista actualizado exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildContratistaCard(dynamic contratista) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String estado = contratista['id_estado'] == 1 ? "Activo" : "Inactivo";
    Color estadoColor = contratista['id_estado'] == 1 ? theme.colorScheme.primary : Colors.red;
    final cardColor = theme.colorScheme.surface;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final textColor = theme.colorScheme.onSurface;

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _confirmarEdicion(contratista, context),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Editar',
          ),
        ],
      ),
      child: Hero(
        tag: 'contratista-${contratista['id']}',
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contratista['nombre'] ?? "Sin nombre",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "RUT: ${contratista['rut']}",
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: estadoColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: estadoColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              contratista['id_estado'] == 1
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 16,
                              color: estadoColor,
                            ),
                            SizedBox(width: 4),
                            Text(
                              estado,
                              style: TextStyle(
                                color: estadoColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: primaryColor,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            contratista['nombre_sucursal'] ?? "Sin sucursal",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          "Contratistas",
          style: TextStyle(color: secondaryColor),
        ),
        iconTheme: IconThemeData(color: secondaryColor),
      ),
      body: Stack(
        children: [
          isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                      SizedBox(height: 16),
                      Text('Cargando contratistas...'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  key: _refreshIndicatorKey,
                  onRefresh: _onRefresh,
                  color: primaryColor,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: TextField(
                          controller: searchController,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, RUT o sucursal',
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: contratistasFiltrados.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_off, 
                                         size: 64, 
                                         color: primaryColor.withOpacity(0.5)),
                                    SizedBox(height: 16),
                                    Text(
                                      "No hay contratistas disponibles",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (searchController.text.isNotEmpty) ...[
                                      SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          searchController.clear();
                                          _filtrarContratistas();
                                        },
                                        icon: Icon(Icons.clear),
                                        label: Text('Limpiar búsqueda'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: secondaryColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : ListView.builder(
                                physics: AlwaysScrollableScrollPhysics(),
                                itemCount: contratistasFiltrados.length,
                                itemBuilder: (context, index) {
                                  return _buildContratistaCard(contratistasFiltrados[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
          if (isRefreshing)
            Container(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          bool? creado = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NuevoContratistaPage(),
            ),
          );
          if (creado == true) {
            _cargarContratistas();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Contratista creado exitosamente'),
                  backgroundColor: primaryColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          }
        },
        child: Icon(Icons.add, color: secondaryColor),
        backgroundColor: primaryColor,
      ),
    );
  }
}
