import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../theme/app_theme.dart';
import 'package:collection/collection.dart';

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
  final TextEditingController observacionesController = TextEditingController();

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
    observacionesController.text = widget.rendimiento['observaciones']?.toString() ?? '';
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

    try {
      setState(() => _isLoading = true);

      final datos = {
        'id_actividad': widget.actividad['id'],
        'id_colaborador': selectedColaborador,
        'rendimiento': double.tryParse(rendimientoController.text) ?? 0.0,
        'id_ceco': selectedCeco,
        'observaciones': observacionesController.text.trim(),
      };

      final resultado = await _apiService.editarRendimientoMultiple(
        widget.rendimiento['id'].toString(),
        datos
      );

      if (resultado['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rendimiento múltiple actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(resultado['error'] ?? 'Error desconocido');
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
                        SizedBox(height: 16),
                        
                        // Observaciones
                        _buildObservacionesField(),
                        SizedBox(height: 24),
                        
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
            _buildInfoRow('Unidad', widget.actividad['nombre_unidad'] ?? 'Sin unidad'),
            _buildInfoRow('Tipo CECO', widget.actividad['nombre_tipoceco'] ?? 'Sin tipo CECO'),
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
          selectedItem: colaboradores.firstWhereOrNull((item) => item['id'].toString() == selectedColaborador),
          items: colaboradores,
          itemAsString: (Map<String, dynamic> item) => 
              '${item['nombre']} ${item['apellido_paterno'] ?? ''} ${item['apellido_materno'] ?? ''}'.trim(),
          onChanged: (Map<String, dynamic>? newValue) {
            setState(() {
              selectedColaborador = newValue?['id']?.toString();
            });
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
          selectedItem: cecosDisponibles.firstWhereOrNull((item) => item['id'].toString() == selectedCeco),
          items: cecosDisponibles,
          itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
          onChanged: (Map<String, dynamic>? newValue) {
            setState(() {
              selectedCeco = newValue?['id']?.toString();
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
        TextFormField(
          controller: rendimientoController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
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
      ],
    );
  }

  Widget _buildObservacionesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Observaciones',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: observacionesController,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: 'Ingresa observaciones (opcional)',
          ),
        ),
      ],
    );
  }
}
