import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

class CrearRendimientoIndividualPage extends StatefulWidget {
  final String idActividad;
  final int idTipotrabajador;
  final String? idContratista;
  const CrearRendimientoIndividualPage({Key? key, required this.idActividad, required this.idTipotrabajador, this.idContratista}) : super(key: key);

  @override
  State<CrearRendimientoIndividualPage> createState() => _CrearRendimientoIndividualPageState();
}

class _CrearRendimientoIndividualPageState extends State<CrearRendimientoIndividualPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores y variables de campos
  String? selectedTrabajador;
  String? selectedColaborador;
  int? selectedPorcentaje;
  TextEditingController rendimientoController = TextEditingController();
  TextEditingController horasTrabajadasController = TextEditingController();
  TextEditingController horasExtrasController = TextEditingController();

  // Listas cargadas desde la API
  List<Map<String, dynamic>> trabajadores = [];
  List<Map<String, dynamic>> colaboradores = [];
  List<Map<String, dynamic>> porcentajes = [];

  // IDs de colaboradores/trabajadores con rendimiento ya ingresado
  Set<String> idsConRendimiento = {};

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Forzar recarga de SharedPreferences
      final idSucursal = prefs.getString('id_sucursal');
      print('Sucursal activa usada para cargar colaboradores/trabajadores: $idSucursal');
      if (idSucursal == null) throw Exception('No se encontró la sucursal activa');
      // 1. Obtener IDs con rendimiento ya ingresado
      if (widget.idTipotrabajador == 2) {
        // Contratista: cargar trabajadores y porcentajes
        if (widget.idContratista == null || widget.idContratista!.isEmpty) throw Exception('No se encontró el contratista');
        final listaTrabajadores = await ApiService().getTrabajadores(idSucursal, widget.idContratista!);
        final listaPorcentajes = await ApiService().getPorcentajesContratista();
        final rendimientos = await ApiService().getRendimientosIndividualesContratistas();
        idsConRendimiento = rendimientos
          .where((r) => r['id_actividad'].toString() == widget.idActividad)
          .map<String>((r) => r['id_trabajador'].toString())
          .toSet();
        setState(() {
          trabajadores = List<Map<String, dynamic>>.from(listaTrabajadores);
          porcentajes = List<Map<String, dynamic>>.from(listaPorcentajes);
        });
      } else if (widget.idTipotrabajador == 1) {
        // Propio: cargar colaboradores
        final listaColaboradores = await ApiService().getColaboradores();
        final rendimientos = await ApiService().getRendimientosIndividualesPropios(idActividad: widget.idActividad);
        idsConRendimiento = rendimientos
          .map<String>((r) => r['id_colaborador'].toString())
          .toSet();
        setState(() {
          colaboradores = List<Map<String, dynamic>>.from(listaColaboradores);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  void _onTrabajadorChanged(String? trabajadorId) async {
    setState(() {
      selectedTrabajador = trabajadorId;
      selectedPorcentaje = null;
    });
    if (trabajadorId != null && widget.idTipotrabajador == 2) {
      try {
        final trabajador = await ApiService().getTrabajadorById(trabajadorId);
        setState(() {
          if (trabajador != null && trabajador['id_porcentaje'] != null) {
            selectedPorcentaje = trabajador['id_porcentaje'] is int
                ? trabajador['id_porcentaje']
                : int.tryParse(trabajador['id_porcentaje'].toString());
          }
        });
      } catch (e) {
        // Si falla, deja el porcentaje sin seleccionar
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final Map<String, dynamic> rendimiento = {
          'id_actividad': widget.idActividad.toString(),
          'rendimiento': double.tryParse(rendimientoController.text) ?? 0,
          'horas_trabajadas': null,
          'horas_extras': null,
          'id_trabajador': null,
          'id_colaborador': null,
          'id_porcentaje_individual': null,
        };
        bool response;
        if (widget.idTipotrabajador == 2) {
          rendimiento['id_trabajador'] = selectedTrabajador?.toString();
          rendimiento['id_porcentaje_individual'] = selectedPorcentaje?.toString();
          response = await ApiService().crearRendimientoIndividualContratista(rendimiento);
        } else if (widget.idTipotrabajador == 1) {
          rendimiento['id_colaborador'] = selectedColaborador?.toString();
          response = await ApiService().crearRendimientoIndividualPropio(rendimiento);
        } else {
          throw Exception('Tipo de trabajador no soportado');
        }
        if (response) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          throw Exception('Error al crear rendimiento');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget buildSearchableDropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required String? selectedValue,
    required Function(String?) onChanged,
    IconData? icon,
    Color? iconColor,
  }) {
    return DropdownSearch<String>(
      items: items.map((e) => e['id'].toString()).toList(),
      selectedItem: selectedValue,
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: iconColor) : null,
          border: OutlineInputBorder(),
        ),
      ),
      onChanged: onChanged,
      popupProps: PopupProps.menu(
        showSearchBox: true,
        itemBuilder: (context, item, isSelected) {
          final isDisabled = idsConRendimiento.contains(item);
          if (label.contains('Porcentaje')) {
            final porcentaje = items.firstWhereOrNull((e) => e['id'].toString() == item);
            final valor = porcentaje != null ? ((porcentaje['porcentaje'] * 100).toStringAsFixed(0) + '%') : item;
            return ListTile(title: Text(valor));
          }
          if (label.contains('Colaborador')) {
            final colaborador = items.firstWhereOrNull((e) => e['id'].toString() == item);
            final nombreCompleto = colaborador != null
                ? "${colaborador['nombre']} ${colaborador['apellido_paterno'] ?? ''} ${colaborador['apellido_materno'] ?? ''}".trim()
                : item;
            return ListTile(
              title: Text(nombreCompleto),
              enabled: !isDisabled,
              trailing: isDisabled ? Icon(Icons.check_circle, color: Colors.green) : null,
              subtitle: isDisabled ? Text('Ya ingresado', style: TextStyle(color: Colors.green, fontSize: 12)) : null,
            );
          } else if (label.contains('Trabajador')) {
            final trabajador = items.firstWhereOrNull((e) => e['id'].toString() == item);
            final nombreCompleto = trabajador != null
                ? "${trabajador['nombre']} ${trabajador['apellido_paterno'] ?? ''} ${trabajador['apellido_materno'] ?? ''}".trim()
                : item;
            return ListTile(
              title: Text(nombreCompleto),
              enabled: !isDisabled,
              trailing: isDisabled ? Icon(Icons.check_circle, color: Colors.green) : null,
              subtitle: isDisabled ? Text('Ya ingresado', style: TextStyle(color: Colors.green, fontSize: 12)) : null,
            );
          } else {
            final nombre = items.firstWhereOrNull((e) => e['id'].toString() == item)?['nombre'] ?? item;
            return ListTile(title: Text(nombre));
          }
        },
      ),
      itemAsString: (itemId) {
        if (label.contains('Porcentaje')) {
          final porcentaje = items.firstWhereOrNull((e) => e['id'].toString() == itemId);
          return porcentaje != null ? ((porcentaje['porcentaje'] * 100).toStringAsFixed(0) + '%') : (itemId ?? '');
        }
        if (label.contains('Colaborador')) {
          final colaborador = items.firstWhereOrNull((e) => e['id'].toString() == itemId);
          if (colaborador != null) {
            return "${colaborador['nombre']} ${colaborador['apellido_paterno'] ?? ''} ${colaborador['apellido_materno'] ?? ''}".trim();
          }
          return itemId ?? '';
        } else if (label.contains('Trabajador')) {
          final trabajador = items.firstWhereOrNull((e) => e['id'].toString() == itemId);
          if (trabajador != null) {
            return "${trabajador['nombre']} ${trabajador['apellido_paterno'] ?? ''} ${trabajador['apellido_materno'] ?? ''}".trim();
          }
          return itemId ?? '';
        } else {
          final item = items.firstWhereOrNull((e) => e['id'].toString() == itemId);
          return item != null ? (item['nombre'] ?? itemId ?? '') : (itemId ?? '');
        }
      },
      validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.green;
    const secondaryColor = Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: Text('Nuevo Rendimiento Individual', style: TextStyle(color: secondaryColor)),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: secondaryColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSection(
                      'Datos de Rendimiento',
                      Icons.assignment,
                      [
                        buildSearchableDropdown(
                          label: widget.idTipotrabajador == 1 ? 'Colaborador (Propio)' : 'Trabajador (Contratista)',
                          items: widget.idTipotrabajador == 1 ? colaboradores : trabajadores,
                          selectedValue: widget.idTipotrabajador == 1 ? selectedColaborador : selectedTrabajador,
                          onChanged: (val) => setState(() {
                            if (widget.idTipotrabajador == 1) selectedColaborador = val;
                            else selectedTrabajador = val;
                          }),
                          icon: widget.idTipotrabajador == 1 ? Icons.group : Icons.engineering,
                          iconColor: Colors.green,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: rendimientoController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Rendimiento',
                            prefixIcon: Icon(Icons.speed, color: Colors.green),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
                        ),
                        SizedBox(height: 16),
                        if (widget.idTipotrabajador == 2)
                          DropdownButtonFormField<int>(
                            value: selectedPorcentaje,
                            items: porcentajes.map((p) {
                              final valor = (p['porcentaje'] * 100).toStringAsFixed(0);
                              return DropdownMenuItem<int>(
                                value: p['id'],
                                child: Row(
                                  children: [
                                    Icon(Icons.percent, color: Colors.green, size: 18),
                                    SizedBox(width: 6),
                                    Text(valor),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (int? val) => setState(() => selectedPorcentaje = val),
                            decoration: InputDecoration(
                              labelText: 'Porcentaje',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.percent, color: Colors.green),
                            ),
                            validator: (value) => value == null ? 'Campo requerido' : null,
                          ),
                      ],
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: secondaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                      child: Text('Guardar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green),
                SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
} 