import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../theme/app_theme.dart';
import 'package:collection/collection.dart';
import '../widgets/numeric_text_field.dart';

class EditarRendimientoMultiplePage extends StatefulWidget {
  final Map<String, dynamic> rendimiento;
  final Map<String, dynamic> actividad;

  EditarRendimientoMultiplePage({
    required this.rendimiento,
    required this.actividad,
  });

  @override
  _EditarRendimientoMultiplePageState createState() => _EditarRendimientoMultiplePageState();
}

class _EditarRendimientoMultiplePageState extends State<EditarRendimientoMultiplePage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  String _error = '';
  
  List<Map<String, dynamic>> colaboradores = [];
  List<Map<String, dynamic>> cecosDisponibles = [];
  
  String? selectedColaborador;
  String? selectedCeco;
  final TextEditingController rendimientoController = TextEditingController();
  
  // IDs de colaboradores con rendimiento ya ingresado para esta actividad (excluyendo el actual)
  Set<String> idsConRendimiento = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarDatosRendimiento();
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

  void _cargarDatosRendimiento() {
    // Cargar datos del rendimiento existente
    selectedColaborador = widget.rendimiento['id_colaborador']?.toString();
    selectedCeco = widget.rendimiento['id_ceco']?.toString();
    rendimientoController.text = widget.rendimiento['rendimiento']?.toString() ?? 
                                 widget.rendimiento['cantidad']?.toString() ?? '';
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
      
      // Extraer IDs de colaboradores que ya tienen rendimiento (excluyendo el actual)
      idsConRendimiento = rendimientos
        .where((r) => r['id'].toString() != widget.rendimiento['id'].toString())
        .map<String>((r) => r['id_colaborador'].toString())
        .toSet();
        
    } catch (e) {
      // print("❌ Error al cargar rendimientos existentes: $e");
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedColaborador == null || selectedCeco == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, selecciona un colaborador y un CECO'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar que el colaborador seleccionado no tenga otro rendimiento para esta actividad
    // PERO permitir editar el rendimiento actual
    if (idsConRendimiento.contains(selectedColaborador) && 
        selectedColaborador != widget.rendimiento['id_colaborador']?.toString()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Este colaborador ya tiene un rendimiento registrado para esta actividad'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final datos = {
        'id_actividad': widget.actividad['id'],
        'id_colaborador': selectedColaborador,
        'rendimiento': double.tryParse(rendimientoController.text) ?? 0.0,
        'horas_trabajadas': double.tryParse(rendimientoController.text) ?? 0.0, // Mismo valor que rendimiento
        'id_ceco': selectedCeco,
      };

      final resultado = await _apiService.editarRendimientoMultiple(
        widget.rendimiento['id'].toString(),
        datos
      );

      // Debug: Imprimir la respuesta del API para entender la estructura
      print('🔍 Respuesta del API editarRendimientoMultiple: $resultado');
      print('🔍 Tipo de resultado: ${resultado.runtimeType}');

      // El API puede devolver diferentes estructuras de respuesta
      // Verificamos si la operación fue exitosa de varias maneras
      bool isSuccess = false;
      String? errorMessage;
      
      if (resultado is Map<String, dynamic>) {
        // Si devuelve un Map, verificamos diferentes campos posibles
        if (resultado['success'] == true) {
          isSuccess = true;
        } else if (resultado['message'] != null && (
          resultado['message'].toString().toLowerCase().contains('exito') ||
          resultado['message'].toString().toLowerCase().contains('correctamente') ||
          resultado['message'].toString().toLowerCase().contains('actualizado')
        )) {
          isSuccess = true;
        } else if (resultado['status'] == 'success' || resultado['status'] == 200) {
          isSuccess = true;
        } else if (resultado['error'] != null) {
          errorMessage = resultado['error'].toString();
        } else if (resultado['message'] != null) {
          errorMessage = resultado['message'].toString();
        }
      } else if (resultado != null) {
        // Si devuelve algo que no es null, consideramos que fue exitoso
        isSuccess = true;
      }

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rendimiento múltiple actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(errorMessage ?? 'Error al actualizar rendimiento múltiple');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar rendimiento múltiple: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Rendimiento Múltiple'),
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
                        
                        // CECO
                        _buildCecoDropdown(),
                        SizedBox(height: 16),
                        
                                                 // Rendimiento
                         _buildRendimientoField(),
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
                          onPressed: _guardarCambios,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Actualizar Rendimiento Múltiple',
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
            _buildInfoRow('Tarifa', '\$${widget.actividad['tarifa']?.toString() ?? '0'}'),
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
              final itemId = item['id'].toString();
              final isCurrentRendimiento = itemId == widget.rendimiento['id_colaborador']?.toString();
              final isDisabled = idsConRendimiento.contains(itemId) && !isCurrentRendimiento;
              final nombreCompleto = "${item['nombre']} ${item['apellido_paterno'] ?? ''} ${item['apellido_materno'] ?? ''}".trim();
              
              return ListTile(
                title: Text(nombreCompleto),
                enabled: !isDisabled,
                trailing: isDisabled ? Icon(Icons.check_circle, color: Colors.green) : 
                         isCurrentRendimiento ? Icon(Icons.edit, color: Colors.blue) : null,
                subtitle: isDisabled ? Text('Ya ingresado', style: TextStyle(color: Colors.green, fontSize: 12)) :
                         isCurrentRendimiento ? Text('Rendimiento actual', style: TextStyle(color: Colors.blue, fontSize: 12)) : null,
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
            if (newValue != null) {
              final itemId = newValue['id'].toString();
              final isCurrentRendimiento = itemId == widget.rendimiento['id_colaborador']?.toString();
              
              // Permitir seleccionar si no tiene rendimiento O si es el rendimiento actual
              if (!idsConRendimiento.contains(itemId) || isCurrentRendimiento) {
                setState(() {
                  selectedColaborador = itemId;
                });
              }
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

  Widget _buildCecoDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CECO *',
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
          ),
          selectedItem: cecosDisponibles.firstWhereOrNull((item) => item['id_ceco'].toString() == selectedCeco),
          items: cecosDisponibles,
          compareFn: (Map<String, dynamic> item1, Map<String, dynamic> item2) {
            return item1['id_ceco'].toString() == item2['id_ceco'].toString();
          },
          itemAsString: (Map<String, dynamic> item) => '${item['nombre_ceco'] ?? ''} (${item['tipo_ceco'] ?? 'Sin tipo'})',
          onChanged: (Map<String, dynamic>? newValue) {
            setState(() {
              selectedCeco = newValue?['id_ceco'].toString();
            });
          },
          validator: (value) {
            if (value == null) return 'Por favor selecciona un CECO';
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
      ],
    );
  }

  Widget _buildRendimientoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rendimiento *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        NumericTextField(
          controller: rendimientoController,
          labelText: 'Rendimiento',
          hintText: 'Ingresa el rendimiento',
          allowDecimal: true,
          forceNumericKeyboard: true,
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
      ],
    );
  }


}
