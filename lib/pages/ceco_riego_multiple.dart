import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/api_service.dart';
import 'package:app_lh_tarja/pages/actividades_multiples_page.dart';

// Sistema de logging condicional
void logInfo(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("ℹ️ $message");
  }
}

void logError(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("❌ $message");
  }
}

class CecoRiegoMultiple extends StatefulWidget {
  final String idActividad;

  const CecoRiegoMultiple({
    Key? key,
    required this.idActividad,
  }) : super(key: key);

  @override
  State<CecoRiegoMultiple> createState() => _CecoRiegoMultipleState();
}

class _CecoRiegoMultipleState extends State<CecoRiegoMultiple> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Variables para los campos
  List<String> _selectedSectoresRiego = []; // Selección múltiple de sectores de riego
  
  // Campos auto-completados basados en sectores seleccionados
  String? _autoCompletedCeco;
  String? _autoCompletedCaseta;
  String? _autoCompletedEquipoRiego;
  
  // Listas de datos
  List<Map<String, dynamic>> sectoresRiego = [];
  List<Map<String, dynamic>> cecosDisponibles = [];
  List<Map<String, dynamic>> casetasDisponibles = [];
  List<Map<String, dynamic>> equiposRiegoDisponibles = [];

  @override
  void initState() {
    super.initState();
    _loadSectoresRiego();
  }

  Future<void> _loadSectoresRiego() async {
    try {
      print("🔍 Iniciando carga de sectores de riego para actividad: ${widget.idActividad}");
      setState(() => _isLoading = true);
      
      // Cargar todos los sectores de riego disponibles para la actividad
      final sectoresData = await ApiService().getSectoresRiegoPorActividad(widget.idActividad);
      
      print("✅ Datos recibidos del API: ${sectoresData.length} sectores");
      for (var sector in sectoresData) {
        // Manejar diferentes formatos de datos (nuevo endpoint vs endpoint alternativo)
        final nombre = sector['nombre_sector'] ?? sector['nombre'];
        final id = sector['id_sectorriego'] ?? sector['id'];
        print("  - Sector: $nombre (ID: $id)");
      }
      
      // Ordenar por nombre, manejando diferentes formatos
      sectoresData.sort((a, b) {
        final nombreA = a['nombre_sector'] ?? a['nombre'] ?? '';
        final nombreB = b['nombre_sector'] ?? b['nombre'] ?? '';
        return nombreA.toString().compareTo(nombreB.toString());
      });
      
      setState(() {
        sectoresRiego = sectoresData;
        _isLoading = false;
      });
      
      print("✅ Estado actualizado con ${sectoresRiego.length} sectores");
    } catch (e) {
      print("❌ Error al cargar sectores de riego: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar sectores de riego: $e')),
      );
    }
  }

  Future<void> _onSectoresRiegoChanged(List<Map<String, dynamic>>? values) async {
    setState(() {
      // Manejar diferentes formatos de datos (nuevo endpoint vs endpoint alternativo)
      _selectedSectoresRiego = values?.map((v) => (v['id_sectorriego'] ?? v['id']).toString()).toList() ?? [];
      // Limpiar campos auto-completados
      _autoCompletedCeco = null;
      _autoCompletedCaseta = null;
      _autoCompletedEquipoRiego = null;
      cecosDisponibles = [];
      casetasDisponibles = [];
      equiposRiegoDisponibles = [];
    });
    
    // Si hay sectores seleccionados, obtener datos auto-completados
    if (_selectedSectoresRiego.isNotEmpty) {
      try {
        setState(() => _isLoading = true);
        
        // Obtener los datos de los sectores seleccionados desde la lista ya cargada
        List<Map<String, dynamic>> sectoresSeleccionados = sectoresRiego
            .where((sector) => _selectedSectoresRiego.contains((sector['id_sectorriego'] ?? sector['id']).toString()))
            .toList();
        
        // Extraer datos únicos de CECOs, casetas y equipos
        Set<String> cecosUnicos = {};
        Set<String> casetasUnicas = {};
        Set<String> equiposUnicos = {};
        
        for (var sector in sectoresSeleccionados) {
          if (sector['id_ceco'] != null) {
            cecosUnicos.add(sector['id_ceco'].toString());
          }
          if (sector['id_caseta'] != null) {
            casetasUnicas.add(sector['id_caseta'].toString());
          }
          if (sector['id_equiporiego'] != null) {
            equiposUnicos.add(sector['id_equiporiego'].toString());
          }
        }
        
        // Verificar si todos los sectores tienen los mismos datos
        bool todosMismoCeco = cecosUnicos.length == 1;
        bool todosMismaCaseta = casetasUnicas.length == 1;
        bool todosMismoEquipo = equiposUnicos.length == 1;
        
        // Auto-completar si todos los sectores tienen los mismos datos
        String? cecoAuto = todosMismoCeco ? cecosUnicos.first : null;
        String? casetaAuto = todosMismaCaseta ? casetasUnicas.first : null;
        String? equipoAuto = todosMismoEquipo ? equiposUnicos.first : null;
        
        // Crear listas de datos disponibles para mostrar
        List<Map<String, dynamic>> cecosDisponiblesList = [];
        List<Map<String, dynamic>> casetasDisponiblesList = [];
        List<Map<String, dynamic>> equiposDisponiblesList = [];
        
        for (var sector in sectoresSeleccionados) {
          if (sector['id_ceco'] != null && sector['nombre_ceco'] != null) {
            cecosDisponiblesList.add({
              'id': sector['id_ceco'],
              'nombre': sector['nombre_ceco'],
            });
          }
          if (sector['id_caseta'] != null && sector['nombre_caseta'] != null) {
            casetasDisponiblesList.add({
              'id': sector['id_caseta'],
              'nombre': sector['nombre_caseta'],
            });
          }
          if (sector['id_equiporiego'] != null && sector['nombre_equipo'] != null) {
            equiposDisponiblesList.add({
              'id': sector['id_equiporiego'],
              'nombre': sector['nombre_equipo'],
            });
          }
        }
        
        // Eliminar duplicados
        cecosDisponiblesList = _eliminarDuplicados(cecosDisponiblesList);
        casetasDisponiblesList = _eliminarDuplicados(casetasDisponiblesList);
        equiposDisponiblesList = _eliminarDuplicados(equiposDisponiblesList);
        
        setState(() {
          cecosDisponibles = cecosDisponiblesList;
          casetasDisponibles = casetasDisponiblesList;
          equiposRiegoDisponibles = equiposDisponiblesList;
          _autoCompletedCeco = cecoAuto;
          _autoCompletedCaseta = casetaAuto;
          _autoCompletedEquipoRiego = equipoAuto;
          _isLoading = false;
        });
        
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos de sectores: $e')),
        );
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  bool _verificarDatosUnicos(Map<String, List<Map<String, dynamic>>> datosPorSector) {
    if (datosPorSector.isEmpty) return false;
    
    List<String> primerSectorIds = datosPorSector.values.first.map((d) => d['id'].toString()).toList();
    primerSectorIds.sort();
    
    for (var sectorDatos in datosPorSector.values) {
      List<String> sectorIds = sectorDatos.map((d) => d['id'].toString()).toList();
      sectorIds.sort();
      
      if (sectorIds.length != primerSectorIds.length) return false;
      
      for (int i = 0; i < sectorIds.length; i++) {
        if (sectorIds[i] != primerSectorIds[i]) return false;
      }
    }
    
    return true;
  }

  List<Map<String, dynamic>> _obtenerDatosUnicos(Map<String, List<Map<String, dynamic>>> datosPorSector) {
    Set<String> idsUnicos = {};
    List<Map<String, dynamic>> datosUnicos = [];
    
    for (var sectorDatos in datosPorSector.values) {
      for (var dato in sectorDatos) {
        String id = dato['id'].toString();
        if (!idsUnicos.contains(id)) {
          idsUnicos.add(id);
          datosUnicos.add(dato);
        }
      }
    }
    
    datosUnicos.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
    return datosUnicos;
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

    if (_selectedSectoresRiego.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor selecciona al menos un sector de riego'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Si solo hay un sector seleccionado, usar el endpoint individual
      if (_selectedSectoresRiego.length == 1) {
        final cecoData = {
          'id_actividad': widget.idActividad,
          'id_sectorriego': _selectedSectoresRiego[0],
        };

        print("🔍 Enviando datos para crear CECO de riego individual:");
        print("  - id_actividad: ${cecoData['id_actividad']}");
        print("  - id_sectorriego: ${cecoData['id_sectorriego']}");

        final response = await ApiService().crearCecoRiegoMultiple(cecoData);
        
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ CECO de riego creado exitosamente'),
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
              content: Text('❌ Error al crear CECO de riego: ${response['error'] ?? 'Error desconocido'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Si hay múltiples sectores, usar el endpoint bulk
        final cecoData = {
          'id_actividad': widget.idActividad,
          'id_sectoresriego': _selectedSectoresRiego,
        };

        print("🔍 Enviando datos para crear CECOs de riego múltiples:");
        print("  - id_actividad: ${cecoData['id_actividad']}");
        print("  - id_sectoresriego: ${cecoData['id_sectoresriego']}");

        final response = await ApiService().crearCecoRiegoMultipleBulk(cecoData);
        
        if (response['success'] == true) {
          final totalCreados = response['total_creados'] ?? 0;
          final totalExistentes = response['total_existentes'] ?? 0;
          
          String mensaje = '✅ Se crearon $totalCreados CECO(s) de riego exitosamente';
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
              content: Text('❌ Error al crear CECOs de riego: ${response['error'] ?? 'Error desconocido'}'),
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
        title: Text("CECO Riego Múltiple", style: TextStyle(color: secondaryColor)),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: secondaryColor),
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
                    // Sección de Sectores de Riego (Selección Múltiple)
                    _buildSection(
                      "Selección de Sectores de Riego",
                      Icons.water_drop,
                      [
                        buildMultiSelectDropdown(
                          label: "Sectores de Riego",
                          items: sectoresRiego,
                          selectedValues: _selectedSectoresRiego,
                          onChanged: (values) => _onSectoresRiegoChanged(values),
                          keyField: 'id_sectorriego',
                          labelField: 'nombre_sector',
                          icon: Icons.water_drop,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Selecciona uno o varios sectores de riego. Los campos CECO, Caseta y Equipo de Riego se auto-completarán basándose en los sectores seleccionados.",
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
                    if (_selectedSectoresRiego.isNotEmpty)
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
                          
                          // Caseta
                          if (casetasDisponibles.isNotEmpty)
                            _buildAutoCompletedField(
                              "Caseta",
                              casetasDisponibles,
                              _autoCompletedCaseta,
                              Icons.home,
                            ),
                          if (casetasDisponibles.isNotEmpty) SizedBox(height: 16),
                          
                          // Equipo de Riego
                          if (equiposRiegoDisponibles.isNotEmpty)
                            _buildAutoCompletedField(
                              "Equipo de Riego",
                              equiposRiegoDisponibles,
                              _autoCompletedEquipoRiego,
                              Icons.settings,
                            ),
                          
                          SizedBox(height: 16),
                          
                          // Información sobre sectores seleccionados
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
                                  'Se crearán CECOs para los siguientes sectores:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                SizedBox(height: 8),
                                ..._selectedSectoresRiego.map((sectorId) {
                                  var sector = sectoresRiego.firstWhere(
                                    (s) => (s['id_sectorriego'] ?? s['id']).toString() == sectorId,
                                    orElse: () => {'nombre_sector': 'Sector $sectorId', 'nombre': 'Sector $sectorId'},
                                  );
                                  return Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${sector['nombre_sector'] ?? sector['nombre']}',
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
                    if (_selectedSectoresRiego.isNotEmpty) SizedBox(height: 26),

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
                      label: Text(_isLoading ? "Creando..." : "Crear CECO Riego"),
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
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Seleccionar Sectores de Riego'),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((item) {
                    String itemId = item[keyField].toString();
                    bool isSelected = selectedValues.contains(itemId);
                    
                    return CheckboxListTile(
                      title: Text(item[labelField] ?? ''),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedValues.add(itemId);
                          } else {
                            selectedValues.remove(itemId);
                          }
                        });
                      },
                    );
                  }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    List<Map<String, dynamic>> selectedItems = items
                        .where((item) => selectedValues.contains(item[keyField].toString()))
                        .toList();
                    onChanged(selectedItems);
                    Navigator.of(context).pop();
                  },
                  child: Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
