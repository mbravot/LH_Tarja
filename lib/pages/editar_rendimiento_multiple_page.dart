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
  List<Map<String, dynamic>> bonos = [];
  List<Map<String, dynamic>> cecosDisponibles = [];
  
  String? selectedColaborador;
  String? selectedBono;
  String? selectedCeco;
  final TextEditingController cantidadController = TextEditingController();
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

      // Cargar colaboradores y bonos específicos para rendimientos múltiples
      final listaColaboradores = await _apiService.getColaboradoresRendimientoMultiple();
      final listaBonos = await _apiService.getBonosRendimientoMultiple();
      
      // Cargar CECOs disponibles según el tipo de actividad
      await _cargarCecosDisponibles();

      setState(() {
        colaboradores = List<Map<String, dynamic>>.from(listaColaboradores);
        bonos = List<Map<String, dynamic>>.from(listaBonos);
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
    selectedBono = widget.rendimiento['id_bono']?.toString();
    selectedCeco = widget.rendimiento['id_ceco']?.toString();
    cantidadController.text = widget.rendimiento['cantidad']?.toString() ?? '';
    observacionesController.text = widget.rendimiento['observaciones']?.toString() ?? '';
  }

  Future<void> _cargarCecosDisponibles() async {
    try {
      final idActividad = widget.actividad['id'].toString();
      
      // Obtener CECOs según el tipo de actividad
      switch ((widget.actividad['nombre_tipoceco'] ?? '').toString().toUpperCase()) {
        case 'PRODUCTIVO':
          final cecosProductivos = await _apiService.getCecosProductivosMultiple(idActividad);
          cecosDisponibles = cecosProductivos;
          break;
        case 'RIEGO':
          final cecosRiego = await _apiService.getCecosRiegoMultiple(idActividad);
          cecosDisponibles = cecosRiego;
          break;
      }
    } catch (e) {
      print("❌ Error al cargar CECOs disponibles: $e");
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
        'id_ceco': selectedCeco,
        'cantidad': double.tryParse(cantidadController.text) ?? 0.0,
        'observaciones': observacionesController.text.trim(),
      };

      if (selectedBono != null) {
        datos['id_bono'] = selectedBono;
      }

      final resultado = await _apiService.editarRendimientoMultiple(
        widget.rendimiento['id'].toString(),
        datos,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['message'] ?? 'Error al actualizar el rendimiento múltiple'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar el rendimiento múltiple: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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
      body: FutureBuilder(
        future: Future.delayed(Duration(milliseconds: 100)),
        builder: (context, snapshot) {
          if (_isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (_error.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error al cargar datos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(_error),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarDatos,
                    child: Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // Cantidad
                  _buildCantidadField(),
                  SizedBox(height: 16),

                  // Bono (opcional)
                  _buildBonoDropdown(),
                  SizedBox(height: 16),

                  // Observaciones (opcional)
                  _buildObservacionesField(),
                  SizedBox(height: 24),

                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Guardar Cambios',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActividadInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información de la Actividad',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            SizedBox(height: 12),
            _buildInfoRow('Labor', widget.actividad['nombre_labor'] ?? 'Sin nombre'),
            _buildInfoRow('Sucursal', widget.actividad['nombre_sucursal'] ?? 'Sin sucursal'),
            _buildInfoRow('Fecha', widget.actividad['fecha'] ?? 'Sin fecha'),
            _buildInfoRow('Tipo CECO', widget.actividad['nombre_tipoceco'] ?? 'Sin tipo'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w400,
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
          selectedItem: colaboradores.firstWhereOrNull(
            (c) => c['id'].toString() == selectedColaborador,
          ),
          items: colaboradores,
          itemAsString: (item) => item['nombre'] ?? 'Sin nombre',
          onChanged: (value) {
            setState(() {
              selectedColaborador = value?['id'].toString();
            });
          },
          validator: (value) {
            if (selectedColaborador == null) {
              return 'Por favor selecciona un colaborador';
            }
            return null;
          },
          dropdownButtonProps: DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          selectedItem: cecosDisponibles.firstWhereOrNull(
            (c) => c['id'].toString() == selectedCeco,
          ),
          items: cecosDisponibles,
          itemAsString: (item) => item['nombre'] ?? 'Sin nombre',
          onChanged: (value) {
            setState(() {
              selectedCeco = value?['id'].toString();
            });
          },
          validator: (value) {
            if (selectedCeco == null) {
              return 'Por favor selecciona un CECO';
            }
            return null;
          },
          dropdownButtonProps: DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCantidadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cantidad *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: cantidadController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            hintText: 'Ingresa la cantidad',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor ingresa una cantidad';
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

  Widget _buildBonoDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bono (Opcional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        DropdownSearch<Map<String, dynamic>>(
          selectedItem: bonos.firstWhereOrNull(
            (b) => b['id'].toString() == selectedBono,
          ),
          items: bonos,
          itemAsString: (item) => item['nombre'] ?? 'Sin nombre',
          onChanged: (value) {
            setState(() {
              selectedBono = value?['id'].toString();
            });
          },
          dropdownButtonProps: DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: 'Selecciona un bono (opcional)',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildObservacionesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Observaciones (Opcional)',
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
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            hintText: 'Ingresa observaciones adicionales',
          ),
        ),
      ],
    );
  }
}
