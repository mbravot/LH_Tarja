import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:app_lh_tarja/pages/actividades_multiples_page.dart';

class CecoProductivoMultiple extends StatefulWidget {
  final String idActividad;

  const CecoProductivoMultiple({
    Key? key,
    required this.idActividad,
  }) : super(key: key);

  @override
  State<CecoProductivoMultiple> createState() => _CecoProductivoMultipleState();
}

class _CecoProductivoMultipleState extends State<CecoProductivoMultiple> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Variables para los campos
  List<String> _selectedCuarteles = []; // Selección múltiple de cuarteles
  
  // Campos auto-completados basados en cuarteles seleccionados
  String? _autoCompletedCeco;
  String? _autoCompletedVariedad;
  String? _autoCompletedEspecie;
  
  // Listas de datos
  List<Map<String, dynamic>> cuarteles = [];
  List<Map<String, dynamic>> cecosDisponibles = [];
  List<Map<String, dynamic>> variedadesDisponibles = [];
  List<Map<String, dynamic>> especiesDisponibles = [];

  @override
  void initState() {
    super.initState();
    _loadCuarteles();
  }

  Future<void> _loadCuarteles() async {
    try {
  
      setState(() => _isLoading = true);
      
      // Cargar todos los cuarteles productivos disponibles para la actividad múltiple
      final cuartelesData = await ApiService().getCuartelesProductivosPorActividad(widget.idActividad);
      
      
      
      // Normalizar los datos para usar campos estándar 'id' y 'nombre'
      List<Map<String, dynamic>> cuartelesNormalizados = [];
      for (var cuartel in cuartelesData) {
        // Manejar diferentes formatos de datos (nuevo endpoint vs endpoint alternativo)
        final nombre = cuartel['nombre_cuartel'] ?? cuartel['nombre'];
        final id = cuartel['id_cuartel'] ?? cuartel['id'];
        
        // Crear objeto normalizado con campos estándar
        Map<String, dynamic> cuartelNormalizado = {
          'id': id,
          'nombre': nombre,
          // Mantener campos originales para el auto-completado
          'id_ceco': cuartel['id_ceco'],
          'nombre_ceco': cuartel['nombre_ceco'],
          'id_variedad': cuartel['id_variedad'],
          'nombre_variedad': cuartel['nombre_variedad'],
          'id_especie': cuartel['id_especie'],
          'nombre_especie': cuartel['nombre_especie'],
        };
        
        cuartelesNormalizados.add(cuartelNormalizado);
        
      }
      
      // Ordenar por nombre
      cuartelesNormalizados.sort((a, b) {
        final nombreA = a['nombre'] ?? '';
        final nombreB = b['nombre'] ?? '';
        return nombreA.toString().compareTo(nombreB.toString());
      });
      
      setState(() {
        cuarteles = cuartelesNormalizados;
        _isLoading = false;
      });
      
      
    } catch (e) {
      
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar cuarteles: $e')),
      );
    }
  }

  Future<void> _onCuartelesChanged(List<Map<String, dynamic>>? values) async {
    setState(() {
      // Ahora que los datos están normalizados, usar directamente 'id'
      _selectedCuarteles = values?.map((v) => v['id'].toString()).toList() ?? [];
      // Limpiar campos auto-completados
      _autoCompletedCeco = null;
      _autoCompletedVariedad = null;
      _autoCompletedEspecie = null;
      cecosDisponibles = [];
      variedadesDisponibles = [];
      especiesDisponibles = [];
    });
    
    // Si hay cuarteles seleccionados, obtener datos auto-completados
    if (_selectedCuarteles.isNotEmpty) {
      try {
        setState(() => _isLoading = true);
        
        // Obtener los cuarteles seleccionados de la lista completa
        List<Map<String, dynamic>> cuartelesSeleccionados = cuarteles
            .where((cuartel) => _selectedCuarteles.contains(cuartel['id'].toString()))
            .toList();
        
        // Extraer datos únicos de los cuarteles seleccionados
        Set<String> cecosUnicos = {};
        Set<String> variedadesUnicas = {};
        Set<String> especiesUnicas = {};
        
        for (var cuartel in cuartelesSeleccionados) {
          if (cuartel['id_ceco'] != null) { cecosUnicos.add(cuartel['id_ceco'].toString()); }
          if (cuartel['id_variedad'] != null) { variedadesUnicas.add(cuartel['id_variedad'].toString()); }
          if (cuartel['id_especie'] != null) { especiesUnicas.add(cuartel['id_especie'].toString()); }
        }
        
        // Verificar si todos los cuarteles tienen los mismos datos
        bool todosMismoCeco = cecosUnicos.length == 1;
        bool todosMismaVariedad = variedadesUnicas.length == 1;
        bool todosMismaEspecie = especiesUnicas.length == 1;
        
        // Auto-completar si todos los cuarteles tienen los mismos datos
        String? cecoAuto = todosMismoCeco ? cecosUnicos.first : null;
        String? variedadAuto = todosMismaVariedad ? variedadesUnicas.first : null;
        String? especieAuto = todosMismaEspecie ? especiesUnicas.first : null;
        
        // Preparar listas de datos disponibles
        List<Map<String, dynamic>> cecosDisponiblesList = [];
        List<Map<String, dynamic>> variedadesDisponiblesList = [];
        List<Map<String, dynamic>> especiesDisponiblesList = [];
        
        for (var cuartel in cuartelesSeleccionados) {
          if (cuartel['id_ceco'] != null && cuartel['nombre_ceco'] != null) {
            cecosDisponiblesList.add({
              'id': cuartel['id_ceco'],
              'nombre': cuartel['nombre_ceco'],
            });
          }
          if (cuartel['id_variedad'] != null && cuartel['nombre_variedad'] != null) {
            variedadesDisponiblesList.add({
              'id': cuartel['id_variedad'],
              'nombre': cuartel['nombre_variedad'],
            });
          }
          if (cuartel['id_especie'] != null && cuartel['nombre_especie'] != null) {
            especiesDisponiblesList.add({
              'id': cuartel['id_especie'],
              'nombre': cuartel['nombre_especie'],
            });
          }
        }
        
        // Eliminar duplicados
        cecosDisponiblesList = _eliminarDuplicados(cecosDisponiblesList);
        variedadesDisponiblesList = _eliminarDuplicados(variedadesDisponiblesList);
        especiesDisponiblesList = _eliminarDuplicados(especiesDisponiblesList);
        
        setState(() {
          cecosDisponibles = cecosDisponiblesList;
          variedadesDisponibles = variedadesDisponiblesList;
          especiesDisponibles = especiesDisponiblesList;
          _autoCompletedCeco = cecoAuto;
          _autoCompletedVariedad = variedadAuto;
          _autoCompletedEspecie = especieAuto;
          _isLoading = false;
        });
        
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos de cuarteles: $e')),
        );
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Elimina duplicados de una lista de mapas basándose en el campo 'id'
  List<Map<String, dynamic>> _eliminarDuplicados(List<Map<String, dynamic>> lista) {
    Set<String> idsUnicos = {};
    List<Map<String, dynamic>> listaSinDuplicados = [];
    
    for (var item in lista) {
      String id = item['id'].toString();
      if (!idsUnicos.contains(id)) {
        idsUnicos.add(id);
        listaSinDuplicados.add(item);
      }
    }
    
    listaSinDuplicados.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
    return listaSinDuplicados;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCuarteles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor selecciona al menos un cuartel'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Si solo hay un cuartel seleccionado, usar el endpoint individual
      if (_selectedCuarteles.length == 1) {
        final cecoData = {
          'id_actividad': widget.idActividad,
          'id_cuartel': _selectedCuarteles[0],
        };



        final response = await ApiService().crearCecoProductivoMultiple(cecoData);
        
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ CECO productivo creado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navegar de vuelta a la página de actividades múltiples
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => ActividadesMultiplesPage()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al crear CECO productivo: ${response['error'] ?? 'Error desconocido'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Si hay múltiples cuarteles, usar el endpoint bulk
        final cecoData = {
          'id_actividad': widget.idActividad,
          'id_cuarteles': _selectedCuarteles,
        };



        final response = await ApiService().crearCecoProductivoMultipleBulk(cecoData);
        
        if (response['success'] == true) {
          final totalCreados = response['total_creados'] ?? 0;
          final totalExistentes = response['total_existentes'] ?? 0;
          
          String mensaje = '✅ Se crearon $totalCreados CECO(s) productivo(s) exitosamente';
          if (totalExistentes > 0) {
            mensaje += ' ($totalExistentes ya existían)';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navegar de vuelta a la página de actividades múltiples
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => ActividadesMultiplesPage()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al crear CECOs productivos: ${response['error'] ?? 'Error desconocido'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.green;
    const secondaryColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("CECO Productivo Múltiple", style: TextStyle(color: secondaryColor)),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: secondaryColor),
        automaticallyImplyLeading: false, // Eliminar botón de retroceso
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sección de Cuarteles (Selección Múltiple)
                    _buildSection(
                      "Selección de Cuarteles",
                      Icons.map,
                      [
                        buildMultiSelectDropdown(
                          label: "Cuarteles",
                          items: cuarteles,
                          selectedValues: _selectedCuarteles,
                          onChanged: (values) => _onCuartelesChanged(values),
                          keyField: 'id', // Usar 'id' como campo clave estándar
                          labelField: 'nombre', // Usar 'nombre' como campo de etiqueta estándar
                          icon: Icons.map,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Selecciona uno o varios cuarteles. Los campos CECO, Variedad y Especie se auto-completarán basándose en los cuarteles seleccionados.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Sección de Datos Auto-completados
                    if (_selectedCuarteles.isNotEmpty)
                      _buildSection(
                        "Datos Auto-completados",
                        Icons.auto_awesome,
                        [
                          // CECO
                          if (cecosDisponibles.isNotEmpty)
                            _buildAutoCompletedField(
                              "CECO",
                              cecosDisponibles,
                              _autoCompletedCeco,
                              Icons.account_balance,
                            ),
                          if (cecosDisponibles.isNotEmpty) SizedBox(height: 16),
                          
                          // Variedad
                          if (variedadesDisponibles.isNotEmpty)
                            _buildAutoCompletedField(
                              "Variedad",
                              variedadesDisponibles,
                              _autoCompletedVariedad,
                              Icons.category,
                            ),
                          if (variedadesDisponibles.isNotEmpty) SizedBox(height: 16),
                          
                          // Especie
                          if (especiesDisponibles.isNotEmpty)
                            _buildAutoCompletedField(
                              "Especie",
                              especiesDisponibles,
                              _autoCompletedEspecie,
                              Icons.eco,
                            ),
                          
                          SizedBox(height: 16),
                          
                          // Información sobre cuarteles seleccionados
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              border: Border.all(color: Colors.green[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Se crearán CECOs para los siguientes cuarteles:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                SizedBox(height: 8),
                                ..._selectedCuarteles.map((cuartelId) {
                                  var cuartel = cuarteles.firstWhere(
                                    (c) => c['id'].toString() == cuartelId,
                                    orElse: () => {'nombre': 'Cuartel $cuartelId'},
                                  );
                                  return Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${cuartel['nombre']}',
                                            style: TextStyle(color: Colors.green[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    if (_selectedCuarteles.isNotEmpty) SizedBox(height: 26),

                    // Botón de Submit
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: secondaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                              ),
                            )
                          : Icon(Icons.save),
                      label: Text(_isLoading ? "Creando..." : "Crear CECO Productivo"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAutoCompletedField(
    String label,
    List<Map<String, dynamic>> items,
    String? selectedValue,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              if (selectedValue != null)
                Icon(Icons.auto_awesome, color: Colors.orange, size: 16),
            ],
          ),
          SizedBox(height: 8),
          if (selectedValue != null) ...[
            Text(
              items.firstWhere(
                (item) => item['id'].toString() == selectedValue,
                orElse: () => {'nombre': 'No encontrado'},
              )['nombre'] ?? 'No encontrado',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (items.length > 1) ...[
            Text(
              'Múltiples opciones disponibles (${items.length})',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            Text(
              'No hay datos disponibles',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget buildMultiSelectDropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required List<String> selectedValues,
    required Function(List<Map<String, dynamic>>?) onChanged,
    String keyField = 'id',
    String labelField = 'nombre',
    bool isDisabled = false,
    IconData? icon,
  }) {
    return InkWell(
      onTap: isDisabled ? null : () => _showMultiSelectDialog(items, selectedValues, onChanged, keyField, labelField),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: isDisabled ? Colors.grey[200] : Colors.white,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.green),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    selectedValues.isEmpty
                        ? 'Seleccionar $label'
                        : '${selectedValues.length} seleccionado(s)',
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedValues.isEmpty ? Colors.grey[400] : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showMultiSelectDialog(
    List<Map<String, dynamic>> items,
    List<String> selectedValues,
    Function(List<Map<String, dynamic>>?) onChanged,
    String keyField,
    String labelField,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _MultiSelectDialog(
          items: items,
          selectedValues: selectedValues,
          onChanged: onChanged,
          keyField: keyField,
          labelField: labelField,
          title: 'Seleccionar Cuarteles',
        );
      },
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<String> selectedValues;
  final Function(List<Map<String, dynamic>>?) onChanged;
  final String keyField;
  final String labelField;
  final String title;

  const _MultiSelectDialog({
    Key? key,
    required this.items,
    required this.selectedValues,
    required this.onChanged,
    required this.keyField,
    required this.labelField,
    required this.title,
  }) : super(key: key);

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late List<Map<String, dynamic>> filteredItems;
  late TextEditingController searchController;
  late List<String> tempSelectedValues;

  @override
  void initState() {
    super.initState();
    filteredItems = List.from(widget.items);
    searchController = TextEditingController();
    tempSelectedValues = List.from(widget.selectedValues);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void filterItems(String searchTerm) {
    setState(() {
      if (searchTerm.isEmpty) {
        filteredItems = List.from(widget.items);
      } else {
        filteredItems = widget.items.where((item) {
          final nombre = item[widget.labelField]?.toString().toLowerCase() ?? '';
          return nombre.contains(searchTerm.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Campo de búsqueda
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar ${widget.labelField.toLowerCase()}...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    filterItems('');
                  },
                ),
              ),
              onChanged: filterItems,
              autofocus: true,
            ),
            SizedBox(height: 16),
            // Lista filtrada
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron resultados',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: filteredItems.map((item) {
                          String itemId = item[widget.keyField].toString();
                          bool isSelected = tempSelectedValues.contains(itemId);
                          
                          return CheckboxListTile(
                            title: Text(item[widget.labelField] ?? ''),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  tempSelectedValues.add(itemId);
                                } else {
                                  tempSelectedValues.remove(itemId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            List<Map<String, dynamic>> selectedItems = widget.items
                .where((item) => tempSelectedValues.contains(item[widget.keyField].toString()))
                .toList();
            widget.onChanged(selectedItems);
            Navigator.of(context).pop();
          },
          child: Text('Confirmar'),
        ),
      ],
    );
  }
}