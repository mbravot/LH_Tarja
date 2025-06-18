import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'nuevo_contratista_page.dart';
import 'editar_contratista_page.dart';
import '../theme/app_theme.dart';

class ContratistasPage extends StatefulWidget {
  const ContratistasPage({super.key});

  @override
  State<ContratistasPage> createState() => _ContratistasPageState();
}

class _ContratistasPageState extends State<ContratistasPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _contratistas = [];
  List<Map<String, dynamic>> _contratistasFiltrados = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarContratistas();
    _searchController.addListener(_filtrarContratistas);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarContratistas() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final contratistas = await _apiService.getContratistasPorSucursal();
      setState(() {
        _contratistas = contratistas;
        _contratistasFiltrados = contratistas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar los contratistas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filtrarContratistas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _contratistasFiltrados = _contratistas.where((contratista) {
        final nombre = (contratista['nombre'] ?? '').toString().toLowerCase();
        final rut = (contratista['rut'] ?? '').toString().toLowerCase();
        final dv = (contratista['codigo_verificador'] ?? '').toString().toLowerCase();
        return nombre.contains(query) || ('$rut-$dv').contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contratistas', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarContratistas,
        ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
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
                  hintText: 'Buscar por nombre o RUT',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: errorColor, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Error: $_error',
                              style: const TextStyle(color: errorColor, fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _cargarContratistas,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                          ],
                        ),
                      )
                    : _contratistasFiltrados.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                    Text(
                                  'No hay contratistas registrados',
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _contratistasFiltrados.length,
                            itemBuilder: (context, index) {
                              final contratista = _contratistasFiltrados[index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditarContratistaPage(
                                        contratista: contratista,
                                      ),
                                    ),
                                  );
                                  _cargarContratistas();
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
                                            color: primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(Icons.apartment, color: primaryColor, size: 32),
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
                                                      contratista['nombre'] ?? 'Sin nombre',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: textPrimaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: (contratista['id_estado'] == 1)
                                                          ? Colors.green
                                                          : Colors.red,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      (contratista['id_estado'] == 1) ? 'Activo' : 'Inactivo',
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
                                                  Icon(Icons.badge, color: accentColor, size: 18),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${contratista['rut']}-${contratista['codigo_verificador']}',
                                                    style: const TextStyle(
                                                      color: textSecondaryColor,
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
        backgroundColor: primaryColor,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NuevoContratistaPage(),
            ),
          );
            _cargarContratistas();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
