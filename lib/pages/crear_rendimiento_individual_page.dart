import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../widgets/numeric_text_field.dart';

// Sistema de logging condicional
void logInfo(String message) {
  // Comentado para mejorar rendimiento
  // print("ℹ️ $message");
}

void logError(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("❌ $message");
  }
}

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
  String _error = '';

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
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Forzar recarga de SharedPreferences
      final idSucursal = prefs.getString('id_sucursal');
      // logInfo('🔍 Sucursal activa: $idSucursal');
      // logInfo('🔍 Tipo trabajador: ${widget.idTipotrabajador}');
      // logInfo('🔍 ID Contratista: ${widget.idContratista}');
      // logInfo('🔍 ID Actividad: ${widget.idActividad}');
      
      if (idSucursal == null) throw Exception('No se encontró la sucursal activa');

      if (widget.idTipotrabajador == 2) {
        // Validar contratista
        if (widget.idContratista == null || widget.idContratista!.isEmpty) {
          throw Exception('No se encontró el ID del contratista');
        }

        // Cargar trabajadores y porcentajes
        // logInfo('🔍 Cargando trabajadores para contratista: ${widget.idContratista}');
        final listaTrabajadores = await ApiService().getTrabajadores(idSucursal, widget.idContratista!);
        // logInfo('✅ Trabajadores cargados: ${listaTrabajadores.length}');

        // logInfo('🔍 Cargando porcentajes');
        final listaPorcentajes = await ApiService().getPorcentajesContratista();
        // logInfo('✅ Porcentajes cargados: ${listaPorcentajes.length}');

        // logInfo('🔍 Cargando rendimientos existentes');
        final rendimientos = await ApiService().getRendimientosIndividualesContratistas(
          idActividad: widget.idActividad,
          idContratista: widget.idContratista!
        );
        // logInfo('✅ Rendimientos cargados: ${rendimientos.length}');

        idsConRendimiento = rendimientos
          .where((r) => r['id_actividad'].toString() == widget.idActividad)
          .map<String>((r) => r['id_trabajador'].toString())
          .toSet();

        // logInfo('✅ IDs con rendimiento: $idsConRendimiento');

        setState(() {
          trabajadores = List<Map<String, dynamic>>.from(listaTrabajadores);
          porcentajes = List<Map<String, dynamic>>.from(listaPorcentajes);
          _error = '';
        });
      } else if (widget.idTipotrabajador == 1) {
        // logInfo('🔍 Cargando colaboradores');
        final listaColaboradores = await ApiService().getColaboradores();
        // logInfo('✅ Colaboradores cargados: ${listaColaboradores.length}');

        final rendimientos = await ApiService().getRendimientosIndividualesPropios(
          idActividad: widget.idActividad
        );
        // logInfo('✅ Rendimientos propios cargados: ${rendimientos.length}');

        idsConRendimiento = rendimientos
          .map<String>((r) => r['id_colaborador'].toString())
          .toSet();

        // logInfo('✅ IDs con rendimiento: $idsConRendimiento');

        setState(() {
          colaboradores = List<Map<String, dynamic>>.from(listaColaboradores);
          _error = '';
        });
      }
    } catch (e) {
      logError('❌ Error al cargar datos iniciales: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
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
            selectedPorcentaje = trabajador['id_porcentaje'];
          }
        });
      } catch (e) {
        logError('❌ Error al cargar porcentaje del trabajador: $e');
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
                              final double rendimientoValor = double.tryParse(rendimientoController.text) ?? 0;
                      
                      final Map<String, dynamic> rendimiento = {
                        'id_actividad': widget.idActividad,
                        'rendimiento': rendimientoValor,
                        'id_trabajador': null,
                        'id_colaborador': null,
                        'id_porcentaje_individual': null,
                      };

        bool response;
        if (widget.idTipotrabajador == 2) {
          if (selectedTrabajador == null) {
            throw Exception('Debe seleccionar un trabajador');
          }
          if (selectedPorcentaje == null) {
            throw Exception('Debe seleccionar un porcentaje');
          }

          rendimiento['id_trabajador'] = selectedTrabajador;
          rendimiento['id_porcentaje_individual'] = selectedPorcentaje;
          // logInfo('📤 Enviando rendimiento contratista: $rendimiento');
          response = await ApiService().crearRendimientoIndividualContratista(rendimiento);
        } else {
          if (selectedColaborador == null) {
            throw Exception('Debe seleccionar un colaborador');
          }

          rendimiento['id_colaborador'] = selectedColaborador;
          // logInfo('📤 Enviando rendimiento propio: $rendimiento');
          response = await ApiService().crearRendimientoIndividualPropio(rendimiento);
        }

        if (response) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          throw Exception('Error al crear el rendimiento');
        }
      } catch (e) {
        logError('❌ Error al crear rendimiento: $e');
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
    required IconData icon,
    required Color iconColor,
  }) {
    return DropdownSearch<String>(
      popupProps: PopupProps.menu(
        showSelectedItems: true,
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
      items: items.map((e) => e['id'].toString()).toList(),
      selectedItem: selectedValue,
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: iconColor),
          border: OutlineInputBorder(),
        ),
      ),
      onChanged: onChanged,
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
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _error,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarDatosIniciales,
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
                        _buildSection(
                          'Datos de Rendimiento',
                          Icons.assignment,
                          [
                            buildSearchableDropdown(
                              label: widget.idTipotrabajador == 1 ? 'Colaborador (Propio)' : 'Trabajador (Contratista)',
                              items: widget.idTipotrabajador == 1 ? colaboradores : trabajadores,
                              selectedValue: widget.idTipotrabajador == 1 ? selectedColaborador : selectedTrabajador,
                              onChanged: widget.idTipotrabajador == 1 
                                ? (val) => setState(() => selectedColaborador = val)
                                : _onTrabajadorChanged,
                              icon: widget.idTipotrabajador == 1 ? Icons.group : Icons.engineering,
                              iconColor: Colors.green,
                            ),
                            SizedBox(height: 16),
                            if (widget.idTipotrabajador == 2 && porcentajes.isNotEmpty) ...[
                              buildSearchableDropdown(
                                label: 'Porcentaje individual',
                                items: porcentajes,
                                selectedValue: selectedPorcentaje?.toString(),
                                onChanged: (val) => setState(() => selectedPorcentaje = int.tryParse(val ?? '')),
                                icon: Icons.percent,
                                iconColor: Colors.green,
                              ),
                              SizedBox(height: 16),
                            ],
                                                         NumericTextField(
                               controller: rendimientoController,
                               labelText: 'Rendimiento',
                               hintText: 'Ingresa el rendimiento',
                               prefixIcon: Icons.speed,
                               prefixIconColor: Colors.green,
                               allowDecimal: true,
                               forceNumericKeyboard: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'El rendimiento es requerido';
                                }
                                final numero = double.tryParse(value);
                                if (numero == null) {
                                  return 'Ingrese un número válido';
                                }
                                if (numero <= 0) {
                                  return 'El rendimiento debe ser mayor a 0';
                                }
                                return null;
                              },
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
                          child: _isLoading
                              ? CircularProgressIndicator(color: secondaryColor)
                              : Text('Guardar'),
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