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

  Future<void> _guardarRendimiento() async {
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
        if (selectedBono != null) 'id_bono': selectedBono,
      };

      final resultado = await _apiService.crearRendimientoMultiple(datos);

      if (resultado['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rendimiento múltiple creado exitosamente'),
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
          content: Text('Error al crear rendimiento múltiple: $e'),
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
                        
                        // CECO
                        _buildCecoDropdown(),
                        SizedBox(height: 16),
                        
                        // Cantidad
                        _buildCantidadField(),
                        SizedBox(height: 16),
                        
                        // Bono (opcional)
                        if (bonos.isNotEmpty) ...[
                          _buildBonoDropdown(),
                          SizedBox(height: 16),
                        ],
                        
                        // Observaciones
                        _buildObservacionesField(),
                        SizedBox(height: 24),
                        
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
                            'Crear Rendimiento Múltiple',
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          'Bono (opcional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        DropdownSearch<Map<String, dynamic>>(
          selectedItem: bonos.firstWhereOrNull((item) => item['id'].toString() == selectedBono),
          items: bonos,
          itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
          onChanged: (Map<String, dynamic>? newValue) {
            setState(() {
              selectedBono = newValue?['id']?.toString();
            });
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
