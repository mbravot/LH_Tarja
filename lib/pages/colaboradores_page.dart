import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'nuevo_colaborador_page.dart';
import 'editar_colaborador_page.dart';

class ColaboradoresPage extends StatefulWidget {
  @override
  _ColaboradoresPageState createState() => _ColaboradoresPageState();
}

class _ColaboradoresPageState extends State<ColaboradoresPage> {
  List<Map<String, dynamic>> colaboradores = [];
  List<Map<String, dynamic>> colaboradoresFiltrados = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarColaboradores();
    searchController.addListener(_filtrarColaboradores);
  }

  Future<void> _cargarColaboradores() async {
    setState(() => isLoading = true);
    try {
      final lista = await ApiService().getColaboradores();
      setState(() {
        colaboradores = lista;
        colaboradoresFiltrados = lista;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _mostrarError('Error al cargar colaboradores: ${e.toString()}');
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

  void _filtrarColaboradores() {
    String query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => colaboradoresFiltrados = List.from(colaboradores));
      return;
    }
    setState(() {
      colaboradoresFiltrados = colaboradores.where((colab) {
        final nombre = (colab['nombre'] ?? '').toString().toLowerCase();
        final ap = (colab['apellido_paterno'] ?? '').toString().toLowerCase();
        final am = (colab['apellido_materno'] ?? '').toString().toLowerCase();
        final rut = (colab['rut'] ?? '').toString().toLowerCase();
        final dv = (colab['codigo_verificador'] ?? '').toString().toLowerCase();
        return nombre.contains(query) ||
               ap.contains(query) ||
               am.contains(query) ||
               ('$rut-$dv').contains(query);
      }).toList();
    });
  }

  String _nombreCompleto(Map<String, dynamic> colab) {
    final nombre = colab['nombre'] ?? '';
    final ap = colab['apellido_paterno'] ?? '';
    final am = colab['apellido_materno'] ?? '';
    return [nombre, ap, am].where((s) => s.isNotEmpty).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: const Text(
          "Colaboradores",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarColaboradores,
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
                : colaboradoresFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No hay colaboradores registrados',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: colaboradoresFiltrados.length,
                        itemBuilder: (context, index) {
                          final colab = colaboradoresFiltrados[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () async {
                              bool? actualizado = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditarColaboradorPage(colaborador: colab),
                                ),
                              );
                              if (actualizado == true) {
                                _cargarColaboradores();
                              }
                            },
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
                                      child: Icon(Icons.person, color: Colors.orange, size: 32),
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
                                                  _nombreCompleto(colab),
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
                                                  color: (colab['id_estado'] == 1)
                                                      ? Colors.green
                                                      : Colors.red,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  (colab['id_estado'] == 1) ? 'Activo' : 'Inactivo',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.badge, color: Colors.blue, size: 18),
                                              const SizedBox(width: 4),
                                              Text(
                                                (colab['rut'] != null && colab['codigo_verificador'] != null)
                                                  ? '${colab['rut']}-${colab['codigo_verificador']}'
                                                  : '--',
                                                style: const TextStyle(
                                                  color: Colors.grey,
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
              builder: (context) => NuevoColaboradorPage(),
            ),
          );
          _cargarColaboradores();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
