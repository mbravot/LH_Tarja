import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:app_lh_tarja/pages/actividades_page.dart';
import 'package:app_lh_tarja/pages/home_page.dart';

class CecoMaquinariaForm extends StatefulWidget {
  final String idActividad;

  const CecoMaquinariaForm({
    Key? key,
    required this.idActividad,
  }) : super(key: key);

  @override
  State<CecoMaquinariaForm> createState() => _CecoMaquinariaFormState();
}

class _CecoMaquinariaFormState extends State<CecoMaquinariaForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Variables para los dropdowns
  String? _selectedTipoMaquinaria;
  String? _selectedMaquinaria;
  String? _selectedCeco;
  
  // Listas de datos
  List<Map<String, dynamic>> tiposMaquinaria = [];
  List<Map<String, dynamic>> maquinarias = [];
  List<Map<String, dynamic>> cecos = [];

  @override
  void initState() {
    super.initState();
    _loadTiposMaquinaria();
  }

  Future<void> _loadTiposMaquinaria() async {
    try {
      setState(() => _isLoading = true);
      final tipos = await ApiService().getTiposMaquinaria(widget.idActividad);
      tipos.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
      setState(() {
        tiposMaquinaria = tipos;
        maquinarias = [];
        cecos = [];
        _selectedTipoMaquinaria = null;
        _selectedMaquinaria = null;
        _selectedCeco = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar tipos de maquinaria: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onTipoMaquinariaChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedTipoMaquinaria = value?['id']?.toString();
      _selectedMaquinaria = null;
      _selectedCeco = null;
      maquinarias = [];
      cecos = [];
    });
    if (value != null) {
      try {
        setState(() => _isLoading = true);
        final maq = await ApiService().getMaquinariasPorTipo(widget.idActividad, value['id']);
        maq.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
        setState(() {
          maquinarias = maq;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar maquinarias: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onMaquinariaChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedMaquinaria = value?['id']?.toString();
      _selectedCeco = null;
      cecos = [];
    });
    if (value != null && _selectedTipoMaquinaria != null) {
      try {
        setState(() => _isLoading = true);
        final cecoList = await ApiService().getCecosMaquinariaPorTipoMaquinariaYActividad(
          widget.idActividad,
          int.parse(_selectedTipoMaquinaria!),
          value['id'],
        );
        cecoList.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
        setState(() {
          cecos = cecoList;
          // Si solo hay un CECO, autocompletar
          if (cecoList.length == 1) {
            _selectedCeco = cecoList[0]['id'].toString();
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
          'id_tipomaquinaria': _selectedTipoMaquinaria,
          'id_maquinaria': _selectedMaquinaria,
          'id_ceco': _selectedCeco,
        };

        final response = await ApiService().crearCecoMaquinaria(cecoData);

        if (response['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CECO Maquinaria creado exitosamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomePage()),
            (Route<dynamic> route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['error'] ?? 'Error al crear el CECO Maquinaria',
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
        title: const Text('CECO Maquinaria'),
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
                    // Dropdown de Tipo de Maquinaria
                    DropdownSearch<Map<String, dynamic>>(
                      items: tiposMaquinaria,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: _onTipoMaquinariaChanged,
                      selectedItem: tiposMaquinaria.firstWhere(
                        (item) => item['id'].toString() == _selectedTipoMaquinaria,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione un tipo de maquinaria';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Tipo de Maquinaria',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropdown de Maquinaria
                    DropdownSearch<Map<String, dynamic>>(
                      items: maquinarias,
                      itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                      onChanged: _onMaquinariaChanged,
                      selectedItem: maquinarias.firstWhere(
                        (item) => item['id'].toString() == _selectedMaquinaria,
                        orElse: () => {},
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione una maquinaria';
                        }
                        return null;
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: 'Maquinaria',
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
                      label: const Text('Guardar CECO Maquinaria', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 