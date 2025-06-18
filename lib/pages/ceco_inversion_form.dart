import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:app_lh_tarja/pages/actividades_page.dart';
import 'package:app_lh_tarja/pages/home_page.dart';

class CecoInversionForm extends StatefulWidget {
  final String idActividad;

  const CecoInversionForm({
    Key? key,
    required this.idActividad,
  }) : super(key: key);

  @override
  State<CecoInversionForm> createState() => _CecoInversionFormState();
}

class _CecoInversionFormState extends State<CecoInversionForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Variables para los dropdowns
  String? _selectedTipoInversion;
  String? _selectedInversion;
  String? _selectedCeco;
  
  // Listas de datos
  List<Map<String, dynamic>> tiposInversion = [];
  List<Map<String, dynamic>> inversiones = [];
  List<Map<String, dynamic>> cecos = [];

  @override
  void initState() {
    super.initState();
    _loadTiposInversion();
  }

  Future<void> _loadTiposInversion() async {
    try {
      setState(() => _isLoading = true);
      final tipos = await ApiService().getTiposInversionPorActividad(widget.idActividad);
      tipos.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
      setState(() {
        tiposInversion = tipos;
        inversiones = [];
        cecos = [];
        _selectedTipoInversion = null;
        _selectedInversion = null;
        _selectedCeco = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar tipos de inversión: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onTipoInversionChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedTipoInversion = value?['id']?.toString();
      _selectedInversion = null;
      _selectedCeco = null;
      inversiones = [];
      cecos = [];
    });
    if (value != null) {
      try {
        setState(() => _isLoading = true);
        final inv = await ApiService().getInversionesPorActividadYTipo(widget.idActividad, value['id'].toString());
        inv.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
        setState(() {
          inversiones = inv;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar inversiones: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onInversionChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedInversion = value?['id']?.toString();
      _selectedCeco = null;
      cecos = [];
    });
    if (value != null && _selectedTipoInversion != null) {
      try {
        setState(() => _isLoading = true);
        final cecoList = await ApiService().getCecosPorActividadTipoInversion(
          widget.idActividad,
          _selectedTipoInversion!,
          value['id'].toString(),
        );
        cecoList.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
        setState(() {
          cecos = cecoList;
          if (cecos.length == 1) {
            _selectedCeco = cecos.first['id'].toString();
          }
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar CECOs: $e')),
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
          'id_tipoinversion': _selectedTipoInversion,
          'id_inversion': _selectedInversion,
          'id_ceco': _selectedCeco,
        };

        final response = await ApiService().crearCecoInversion(cecoData);

        if (response['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CECO Inversión creado exitosamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomePage()),
            (Route<dynamic> route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['error'] ?? 'Error al crear el CECO Inversión',
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
        title: const Text('CECO Inversión'),
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
                    // Dropdown de Tipo de Inversión
                    DropdownSearch<Map<String, dynamic>>(
                      items: tiposInversion,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: _onTipoInversionChanged,
                      selectedItem: tiposInversion.firstWhere(
                        (item) => item['id'].toString() == _selectedTipoInversion,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione un tipo de inversión';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Tipo de Inversión',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropdown de Inversión
                    DropdownSearch<Map<String, dynamic>>(
                      items: inversiones,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: _onInversionChanged,
                      selectedItem: inversiones.firstWhere(
                        (item) => item['id'].toString() == _selectedInversion,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione una inversión';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Inversión',
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
                      label: const Text('Guardar CECO Inversión', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 