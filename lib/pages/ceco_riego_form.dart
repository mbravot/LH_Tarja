import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:app_lh_tarja/pages/actividades_page.dart';
import 'package:app_lh_tarja/pages/home_page.dart';

class CecoRiegoForm extends StatefulWidget {
  final String idActividad;

  const CecoRiegoForm({
    Key? key,
    required this.idActividad,
  }) : super(key: key);

  @override
  State<CecoRiegoForm> createState() => _CecoRiegoFormState();
}

class _CecoRiegoFormState extends State<CecoRiegoForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Variables para los dropdowns
  String? _selectedCaseta;
  String? _selectedEquipoRiego;
  String? _selectedSectorRiego;
  String? _selectedCeco;
  
  // Listas de datos
  List<Map<String, dynamic>> casetas = [];
  List<Map<String, dynamic>> equiposRiego = [];
  List<Map<String, dynamic>> sectoresRiego = [];
  List<Map<String, dynamic>> cecos = [];

  @override
  void initState() {
    super.initState();
    _loadCasetasYCecos();
  }

  Future<void> _loadCasetasYCecos() async {
    try {
      setState(() => _isLoading = true);
      final casetasData = await ApiService().getCasetasPorActividad(widget.idActividad);
      casetasData.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
      final cecosData = await ApiService().getCecosRiegoPorActividad(widget.idActividad);
      cecosData.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
      setState(() {
        casetas = casetasData;
        equiposRiego = [];
        sectoresRiego = [];
        cecos = cecosData;
        _selectedCaseta = null;
        _selectedEquipoRiego = null;
        _selectedSectorRiego = null;
        _selectedCeco = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onCasetaChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedCaseta = value?['id']?.toString();
      _selectedEquipoRiego = null;
      _selectedSectorRiego = null;
      equiposRiego = [];
      sectoresRiego = [];
    });
    if (value != null) {
      try {
        setState(() => _isLoading = true);
        final equipos = await ApiService().getEquiposRiegoPorCaseta(value['id'].toString());
        equipos.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
        setState(() {
          equiposRiego = equipos;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar equipos: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onEquipoRiegoChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedEquipoRiego = value?['id']?.toString();
      _selectedSectorRiego = null;
      sectoresRiego = [];
    });
    if (value != null) {
      try {
        setState(() => _isLoading = true);
        print('Llamando a getSectoresRiegoPorEquipo con id_equiporiego: ${value['id']}');
        final sectores = await ApiService().getSectoresRiegoPorEquipo(value['id'].toString());
        print('Sectores recibidos: $sectores');
        sectores.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
        setState(() {
          sectoresRiego = sectores;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar sectores: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        final cecoData = {
          'id_actividad': widget.idActividad,
          'id_caseta': _selectedCaseta,
          'id_equiporiego': _selectedEquipoRiego,
          'id_sectorriego': _selectedSectorRiego,
          'id_ceco': _selectedCeco,
        };

        final response = await ApiService().crearCecoRiego(cecoData);

        if (response['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CECO Riego creado exitosamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomePage()),
            (Route<dynamic> route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['error'] ?? 'Error al crear el CECO Riego',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CECO Riego'),
        backgroundColor: primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dropdown de Caseta
                    DropdownSearch<Map<String, dynamic>>(
                      items: casetas,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: _onCasetaChanged,
                      selectedItem: casetas.firstWhere(
                        (item) => item['id'].toString() == _selectedCaseta,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione una caseta';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Caseta',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropdown de Equipo de Riego
                    DropdownSearch<Map<String, dynamic>>(
                      items: equiposRiego,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: _onEquipoRiegoChanged,
                      selectedItem: equiposRiego.firstWhere(
                        (item) => item['id'].toString() == _selectedEquipoRiego,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione un equipo de riego';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Equipo de Riego',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropdown de Sector de Riego
                    DropdownSearch<Map<String, dynamic>>(
                      items: sectoresRiego,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: (Map<String, dynamic>? value) {
                        setState(() {
                          _selectedSectorRiego = value?['id']?.toString();
                        });
                      },
                      selectedItem: sectoresRiego.firstWhere(
                        (item) => item['id'].toString() == _selectedSectorRiego,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione un sector de riego';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Sector de Riego',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropdown de CECO
                    DropdownSearch<Map<String, dynamic>>(
                      items: cecos,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: (Map<String, dynamic>? value) {
                        setState(() {
                          _selectedCeco = value?['id']?.toString();
                        });
                      },
                      selectedItem: cecos.firstWhere(
                        (item) => item['id'].toString() == _selectedCeco,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione un CECO';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'CECO',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Botón de Submit
                    ElevatedButton.icon(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(color: Colors.white),
                      ),
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text('Guardar CECO Riego', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 