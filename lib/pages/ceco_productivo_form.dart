import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:app_lh_tarja/pages/actividades_page.dart';
import 'package:app_lh_tarja/pages/home_page.dart';

class CecoProductivoForm extends StatefulWidget {
  final String idActividad;

  const CecoProductivoForm({
    Key? key,
    required this.idActividad,
  }) : super(key: key);

  @override
  State<CecoProductivoForm> createState() => _CecoProductivoFormState();
}

class _CecoProductivoFormState extends State<CecoProductivoForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Variables para los dropdowns
  String? _selectedEspecie;
  String? _selectedVariedad;
  String? _selectedCuartel;
  String? _selectedCeco;
  
  // Listas de datos
  List<Map<String, dynamic>> especies = [];
  List<Map<String, dynamic>> variedades = [];
  List<Map<String, dynamic>> cuarteles = [];
  List<Map<String, dynamic>> cecos = [];

  @override
  void initState() {
    super.initState();
    _loadEspeciesYCecos();
  }

  Future<void> _loadEspeciesYCecos() async {
    try {
      final especiesData = await ApiService().getEspeciesPorActividad(widget.idActividad);
      especiesData.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
      setState(() {
        especies = especiesData;
        variedades = [];
        cuarteles = [];
        cecos = [];
        _selectedEspecie = null;
        _selectedVariedad = null;
        _selectedCuartel = null;
        _selectedCeco = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar especies o cecos: $e')),
      );
    }
  }

  Future<void> _onEspecieChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedEspecie = value?['id']?.toString();
      _selectedVariedad = null;
      _selectedCuartel = null;
      _selectedCeco = null;
      variedades = [];
      cuarteles = [];
      cecos = [];
    });
    if (value != null) {
      try {
        final variedadesData = await ApiService().getVariedadesPorActividadYEspecie(widget.idActividad, value['id'].toString());
        variedadesData.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
        setState(() {
          variedades = variedadesData;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar variedades: $e')),
        );
      }
    }
  }

  Future<void> _onVariedadChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedVariedad = value?['id']?.toString();
      _selectedCuartel = null;
      _selectedCeco = null;
      cuarteles = [];
      cecos = [];
    });
    if (value != null && _selectedEspecie != null) {
      try {
        final cuartelesData = await ApiService().getCuartelesPorActividadYVariedad(widget.idActividad, _selectedEspecie!, value['id'].toString());
        cuartelesData.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
        setState(() {
          cuarteles = cuartelesData;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar cuarteles: $e')),
        );
      }
    }
  }

  Future<void> _onCuartelChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedCuartel = value?['id']?.toString();
      _selectedCeco = null;
      cecos = [];
    });
    if (value != null && _selectedEspecie != null && _selectedVariedad != null) {
      try {
        final cecosData = await ApiService().getCecosProductivosPorActividadEspecieVariedadYCuartel(
          widget.idActividad,
          _selectedEspecie!,
          _selectedVariedad!,
          value['id'].toString(),
        );
        cecosData.sort((a, b) => a['nombre']?.toString().compareTo(b['nombre']?.toString() ?? '') ?? 0);
        setState(() {
          cecos = cecosData;
          // Si solo hay un CECO, autocompletar
          if (cecosData.length == 1) {
            _selectedCeco = cecosData[0]['id'].toString();
          }
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar CECOs: $e')),
        );
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
          'id_especie': _selectedEspecie,
          'id_variedad': _selectedVariedad,
          'id_cuartel': _selectedCuartel,
          'id_ceco': _selectedCeco,
        };

        final response = await ApiService().crearCecoProductivo(cecoData);

        if (response['success'] == true || response['success'] == "true" || response['success'] == 1) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CECO Productivo creado exitosamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomePage()),
            (Route<dynamic> route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['error'] ?? 'Error al crear el CECO Productivo',
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
        title: const Text('CECO Productivo'),
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
                    // Dropdown de Especie
                    DropdownSearch<Map<String, dynamic>>(
                      items: especies,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: _onEspecieChanged,
                      selectedItem: especies.firstWhere(
                        (item) => item['id'].toString() == _selectedEspecie,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione una especie';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Especie',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropdown de Variedad
                    DropdownSearch<Map<String, dynamic>>(
                      items: variedades,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: _onVariedadChanged,
                      selectedItem: variedades.firstWhere(
                        (item) => item['id'].toString() == _selectedVariedad,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione una variedad';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Variedad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropdown de Cuartel
                    DropdownSearch<Map<String, dynamic>>(
                      items: cuarteles,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: _onCuartelChanged,
                      selectedItem: cuarteles.firstWhere(
                        (item) => item['id'].toString() == _selectedCuartel,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione un cuartel';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Cuartel',
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
                      label: const Text('Guardar CECO Productivo', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 