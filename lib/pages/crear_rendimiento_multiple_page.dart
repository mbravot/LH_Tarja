import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../theme/app_theme.dart';
import 'package:collection/collection.dart';

class CrearRendimientoMultiplePage extends StatefulWidget {
  final Map<String, dynamic> actividad;

  CrearRendimientoMultiplePage({required this.actividad});

  @override
  _CrearRendimientoMultiplePageState createState() => _CrearRendimientoMultiplePageState();
}

class _CrearRendimientoMultiplePageState extends State<CrearRendimientoMultiplePage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  String _error = '';
  
  List<Map<String, dynamic>> colaboradores = [];
  List<Map<String, dynamic>> cecosDisponibles = [];
  
  String? selectedColaborador;
  List<String> selectedCecos = [];
  Map<String, TextEditingController> rendimientoControllers = {};

  // IDs de colaboradores con rendimiento ya ingresado para esta actividad
  Set<String> idsConRendimiento = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Cargar colaboradores específicos para rendimientos múltiples
      final listaColaboradores = await _apiService.getColaboradoresRendimientoMultiple();
      
      // Cargar CECOs disponibles usando el nuevo endpoint
      await _cargarCecosDisponibles();

      // Cargar rendimientos existentes para esta actividad
      await _cargarRendimientosExistentes();

      setState(() {
        colaboradores = List<Map<String, dynamic>>.from(listaColaboradores);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarCecosDisponibles() async {
    try {
      final idActividad = widget.actividad['id'].toString();
      
      // Usar el nuevo endpoint para obtener CECOs de la actividad
      final cecos = await _apiService.getCecosActividadMultiple(idActividad);
      setState(() {
        cecosDisponibles = List<Map<String, dynamic>>.from(cecos);
      });
    } catch (e) {
      // print("❌ Error al cargar CECOs disponibles: $e");
    }
  }

  Future<void> _cargarRendimientosExistentes() async {
    try {
      final idActividad = widget.actividad['id'].toString();
      
      // Obtener rendimientos existentes para esta actividad
      final rendimientos = await _apiService.getRendimientosMultiples(idActividad);
      
      // Extraer IDs de colaboradores que ya tienen rendimiento
      idsConRendimiento = rendimientos
        .map<String>((r) => r['id_colaborador'].toString())
        .toSet();
        
    } catch (e) {
      // print("❌ Error al cargar rendimientos existentes: $e");
    }
  }

  Future<void> _guardarRendimiento() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedColaborador == null || selectedCecos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, selecciona un colaborador y al menos un CECO'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar que todos los CECOs seleccionados tengan rendimiento
    for (String cecoId in selectedCecos) {
      final controller = rendimientoControllers[cecoId];
      if (controller == null || controller.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor, ingresa el rendimiento para todos los CECOs seleccionados'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (double.tryParse(controller.text) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor, ingresa un número válido para todos los rendimientos'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      setState(() => _isLoading = true);

      // Crear un rendimiento por cada CECO seleccionado
      List<Map<String, dynamic>> rendimientos = [];
      
      for (String cecoId in selectedCecos) {
        final controller = rendimientoControllers[cecoId];
        if (controller != null) {
          rendimientos.add({
            'id_actividad': widget.actividad['id'],
            'id_colaborador': selectedColaborador,
            'id_ceco': cecoId, // Campo individual en la BD
            'rendimiento': double.tryParse(controller.text) ?? 0.0,
            'hora_inicio': widget.actividad['hora_inicio'],
            'hora_fin': widget.actividad['hora_fin'],
          });
        }
      }

      // Crear cada rendimiento individualmente
      bool todosExitosos = true;
      String errorMessage = '';

      for (Map<String, dynamic> rendimiento in rendimientos) {
        try {
          final resultado = await _apiService.crearRendimientoMultiple(rendimiento);
          if (resultado['success'] != true) {
            todosExitosos = false;
            errorMessage = resultado['error'] ?? 'Error desconocido';
            break;
          }
        } catch (e) {
          todosExitosos = false;
          errorMessage = e.toString();
          break;
        }
      }

      if (todosExitosos) {
        // Actualizar la lista de rendimientos existentes
        await _cargarRendimientosExistentes();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rendimientos.length} rendimientos creados exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear rendimientos múltiples: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crear Rendimiento Múltiple'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)))
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(_error, textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarDatos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Información de la actividad
                        _buildActividadInfo(),
                        SizedBox(height: 24),
                        
                        // Colaborador
                        _buildColaboradorDropdown(),
                        SizedBox(height: 16),
                        
                        // CECOs (selección múltiple)
                        _buildCecosMultiSelect(),
                        SizedBox(height: 24),
                        
                        // Botón refrescar rendimientos existentes
                        if (idsConRendimiento.isNotEmpty) ...[
                          OutlinedButton.icon(
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              await _cargarRendimientosExistentes();
                              setState(() => _isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Información de rendimientos actualizada'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                            icon: Icon(Icons.refresh, color: Colors.blue),
                            label: Text(
                              'Refrescar rendimientos existentes',
                              style: TextStyle(color: Colors.blue),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.blue),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                        
                        // Botón guardar
                        ElevatedButton(
                          onPressed: _guardarRendimiento,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Crear Rendimientos Múltiples',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildActividadInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work, color: primaryColor, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.actividad['nombre_labor'] ?? 'Sin labor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MÚLTIPLE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow('Fecha', widget.actividad['fecha'] ?? 'Sin fecha'),
            _buildInfoRow('Unidad', widget.actividad['nombre_unidad'] ?? 'Sin unidad'),
            _buildInfoRow('Tipo CECO', widget.actividad['nombre_tipoceco'] ?? 'Sin tipo CECO'),
            if (idsConRendimiento.isNotEmpty) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '${idsConRendimiento.length} colaborador(es) ya tienen rendimiento registrado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColaboradorDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Colaborador *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        DropdownSearch<Map<String, dynamic>>(
          popupProps: PopupProps.menu(
            showSelectedItems: true,
            showSearchBox: true,
            itemBuilder: (context, item, isSelected) {
              final isDisabled = idsConRendimiento.contains(item['id'].toString());
              final nombreCompleto = "${item['nombre']} ${item['apellido_paterno'] ?? ''} ${item['apellido_materno'] ?? ''}".trim();
              
              return ListTile(
                title: Text(nombreCompleto),
                enabled: !isDisabled,
                trailing: isDisabled ? Icon(Icons.check_circle, color: Colors.green) : null,
                subtitle: isDisabled ? Text('Ya ingresado', style: TextStyle(color: Colors.green, fontSize: 12)) : null,
              );
            },
          ),
          selectedItem: colaboradores.firstWhereOrNull((item) => item['id'].toString() == selectedColaborador),
          items: colaboradores,
          compareFn: (Map<String, dynamic> item1, Map<String, dynamic> item2) {
            return item1['id'].toString() == item2['id'].toString();
          },
          itemAsString: (Map<String, dynamic> item) => 
              '${item['nombre']} ${item['apellido_paterno'] ?? ''} ${item['apellido_materno'] ?? ''}'.trim(),
          onChanged: (Map<String, dynamic>? newValue) {
            // Solo permitir seleccionar colaboradores que no tengan rendimiento
            if (newValue != null && !idsConRendimiento.contains(newValue['id'].toString())) {
              setState(() {
                selectedColaborador = newValue['id'].toString();
              });
            }
          },
          validator: (value) {
            if (value == null) return 'Por favor selecciona un colaborador';
            return null;
          },
          dropdownButtonProps: DropdownButtonProps(icon: Icon(Icons.arrow_drop_down)),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        if (idsConRendimiento.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            'Colaboradores con rendimiento ya registrado: ${idsConRendimiento.length}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCecosMultiSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CECOs y Rendimientos *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (cecosDisponibles.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay CECOs disponibles para esta actividad',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                ...cecosDisponibles.map((ceco) {
                  final cecoId = ceco['id_ceco'].toString();
                  final isSelected = selectedCecos.contains(cecoId);
                  
                  return Column(
                    children: [
                      CheckboxListTile(
                        title: Text(ceco['nombre_ceco'] ?? 'Sin nombre'),
                        subtitle: Text('Tipo: ${ceco['tipo_ceco'] ?? 'Sin tipo'}'),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedCecos.add(cecoId);
                              // Crear controller para este CECO si no existe
                              if (!rendimientoControllers.containsKey(cecoId)) {
                                rendimientoControllers[cecoId] = TextEditingController();
                              }
                            } else {
                              selectedCecos.remove(cecoId);
                              // Limpiar controller cuando se deselecciona
                              rendimientoControllers.remove(cecoId);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                      // Campo de rendimiento para este CECO
                      if (isSelected)
                        Padding(
                          padding: EdgeInsets.only(left: 48, right: 16, bottom: 8),
                          child: TextFormField(
                            controller: rendimientoControllers[cecoId],
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Rendimiento para ${ceco['nombre_ceco']}',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              hintText: 'Ingresa el rendimiento',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor ingresa un rendimiento';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Por favor ingresa un número válido';
                              }
                              return null;
                            },
                          ),
                        ),
                    ],
                  );
                }).toList(),
            ],
          ),
        ),
        if (selectedCecos.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            'CECOs seleccionados: ${selectedCecos.length}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }


}
