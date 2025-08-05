import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:app_lh_tarja/pages/actividades_page.dart';
import 'package:app_lh_tarja/pages/home_page.dart';
import 'package:flutter/foundation.dart';

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
      _selectedCeco = null;
      equiposRiego = [];
      sectoresRiego = [];
    });
    if (value != null) {
      try {
        setState(() => _isLoading = true);
        final equipos = await ApiService().getEquiposRiegoPorActividadYCaseta(widget.idActividad, value['id'].toString());
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
      _selectedCeco = null;
      sectoresRiego = [];
    });
    if (value != null) {
      try {
        setState(() => _isLoading = true);
            final sectorList = await ApiService().getSectoresRiegoPorActividadYEquipo(widget.idActividad, value['id']);
        sectorList.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
        setState(() {
          sectoresRiego = sectorList;
          // Si solo hay un sector, autocompletar
          if (sectorList.length == 1) {
            _selectedSectorRiego = sectorList[0]['id'].toString();
            // Auto-cargar el CECO si solo hay un sector
            _onSectorRiegoChanged(sectorList[0]);
          }
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

  Future<void> _onSectorRiegoChanged(Map<String, dynamic>? value) async {
    setState(() {
      _selectedSectorRiego = value?['id']?.toString();
      _selectedCeco = null;
      cecos = [];
    });
    if (value != null && _selectedCaseta != null && _selectedEquipoRiego != null) {
      try {
        setState(() => _isLoading = true);
        final ceco = await ApiService().getCecoRiegoPorActividadYCasetaYEquipoYSector(
          widget.idActividad, 
          _selectedCaseta!, 
          _selectedEquipoRiego!, 
          value['id']
        );
        if (ceco != null) {
          setState(() {
            cecos = [ceco];
            _selectedCeco = ceco['id'].toString();
          });
        } else {
          setState(() {
            cecos = [];
            _selectedCeco = null;
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar CECO: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Validación adicional para asegurar que se haya encontrado un CECO
      if (_selectedCeco == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró un CECO asociado a la selección actual'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
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

        if (response['success'] == true || response['success'] == "true" || response['success'] == 1) {
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
    return WillPopScope(
      onWillPop: () async {
        bool? shouldPop = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('¿Está seguro?'),
              content: Text('Si sale ahora, la actividad quedará sin CECO asignado. ¿Desea continuar?'),
              actions: [
                TextButton(
                  child: Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text('Salir'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CECO Riego'),
          backgroundColor: primaryColor,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Información'),
                    content: Text('Debe completar el CECO para finalizar la creación de la actividad. No puede volver atrás.'),
                    actions: [
                      TextButton(
                        child: Text('Entendido'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
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
                      DropdownSearch<Map<String, dynamic>>(
                        items: sectoresRiego,
                        itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
                        onChanged: _onSectorRiegoChanged,
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
      ),
    );
  }
} 