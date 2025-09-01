import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

// Sistema de logging condicional
void logInfo(String message) {
  // Comentado para mejorar rendimiento
  // if (const bool.fromEnvironment('dart.vm.product') == false) {
  //   print("ℹ️ $message");
  // }
}

void logError(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("❌ $message");
  }
}

class EditarRendimientosIndividualesPage extends StatefulWidget {
  final dynamic rendimiento;
  EditarRendimientosIndividualesPage({required this.rendimiento});

  @override
  State<EditarRendimientosIndividualesPage> createState() => _EditarRendimientosIndividualesPageState();
}

class _EditarRendimientosIndividualesPageState extends State<EditarRendimientosIndividualesPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? selectedTrabajador;
  String? selectedColaborador;
  String? selectedPorcentaje;
  TextEditingController rendimientoController = TextEditingController();

  List<Map<String, dynamic>> trabajadores = [];
  List<Map<String, dynamic>> colaboradores = [];
  List<Map<String, dynamic>> porcentajes = [];
  int? idTipotrabajador;
  String? idContratista;
  String? idActividad;
  Set<String> idsConRendimiento = {};

  @override
  void initState() {
    super.initState();
    idTipotrabajador = widget.rendimiento['id_tipotrabajador'] is int
        ? widget.rendimiento['id_tipotrabajador']
        : int.tryParse(widget.rendimiento['id_tipotrabajador'].toString() ?? '');
    idContratista = widget.rendimiento['id_contratista']?.toString();
    idActividad = widget.rendimiento['id_actividad']?.toString();
    selectedTrabajador = widget.rendimiento['id_trabajador']?.toString();
    selectedColaborador = widget.rendimiento['id_colaborador']?.toString();
    selectedPorcentaje = widget.rendimiento['id_porcentaje_individual']?.toString();
    rendimientoController.text = widget.rendimiento['rendimiento']?.toString() ?? '';
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final idSucursal = prefs.getString('id_sucursal');
      // logInfo('>>> idTipotrabajador: '
      //     '[32m'
      //     '[1m'
      //     '[4m'
      //     '[7m'
      //     '[0m' + idTipotrabajador.toString());
      // logInfo('>>> idSucursal: $idSucursal');
      // logInfo('>>> idContratista: $idContratista');
      if (idSucursal == null) throw Exception('No se encontró la sucursal activa');
      if (idTipotrabajador == 2) {
        if (idContratista == null || idContratista!.isEmpty) throw Exception('No se encontró el contratista');
        final listaTrabajadores = await ApiService().getTrabajadores(idSucursal, idContratista!);
        final listaPorcentajes = await ApiService().getPorcentajesContratista();
        // logInfo('>>> Trabajadores cargados: [32m${listaTrabajadores.length}[0m');
        // logInfo('>>> Porcentajes cargados: [32m${listaPorcentajes.length}[0m');

        // Cargar rendimientos existentes para filtrar
        // logInfo('>>> Cargando rendimientos existentes para contratistas');
        final rendimientos = await ApiService().getRendimientosIndividualesContratistas(
          idActividad: idActividad!,
          idContratista: idContratista!
        );
        // logInfo('>>> Rendimientos cargados: ${rendimientos.length}');

        // Crear set de IDs que ya tienen rendimiento (excluyendo el actual)
        idsConRendimiento = rendimientos
          .where((r) => r['id_actividad'].toString() == idActividad && 
                       r['id'].toString() != widget.rendimiento['id'].toString())
          .map<String>((r) => r['id_trabajador'].toString())
          .toSet();

        // logInfo('>>> IDs con rendimiento (excluyendo actual): $idsConRendimiento');

        setState(() {
          trabajadores = List<Map<String, dynamic>>.from(listaTrabajadores);
          porcentajes = List<Map<String, dynamic>>.from(listaPorcentajes);
        });
      } else if (idTipotrabajador == 1) {
        final listaColaboradores = await ApiService().getColaboradores();
        // logInfo('>>> Colaboradores cargados: [32m${listaColaboradores.length}[0m');

        // Cargar rendimientos existentes para filtrar
        // logInfo('>>> Cargando rendimientos existentes para propios');
        final rendimientos = await ApiService().getRendimientosIndividualesPropios(
          idActividad: idActividad!
        );
        // logInfo('>>> Rendimientos propios cargados: ${rendimientos.length}');

        // Crear set de IDs que ya tienen rendimiento (excluyendo el actual)
        idsConRendimiento = rendimientos
          .where((r) => r['id'].toString() != widget.rendimiento['id'].toString())
          .map<String>((r) => r['id_colaborador'].toString())
          .toSet();

        // logInfo('>>> IDs con rendimiento (excluyendo actual): $idsConRendimiento');

        setState(() {
          colaboradores = List<Map<String, dynamic>>.from(listaColaboradores);
        });
      }
    } catch (e) {
      logError('>>> Error al cargar datos iniciales: $e');
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
    if (trabajadorId != null && idTipotrabajador == 2) {
      try {
        final trabajador = await ApiService().getTrabajadorById(trabajadorId);
        setState(() {
          if (trabajador != null && trabajador['id_porcentaje'] != null) {
            selectedPorcentaje = trabajador['id_porcentaje'].toString();
          }
        });
      } catch (e) {}
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final Map<String, dynamic> rendimiento = {
          'id_actividad': idActividad,
          'rendimiento': double.tryParse(rendimientoController.text) ?? 0,
          'id_trabajador': null,
          'id_colaborador': null,
          'id_porcentaje_individual': null,
        };
        if (idTipotrabajador == 2) {
          rendimiento['id_trabajador'] = selectedTrabajador?.toString();
          rendimiento['id_porcentaje_individual'] = selectedPorcentaje?.toString();
          await ApiService().actualizarRendimientoIndividualContratista(widget.rendimiento['id'], rendimiento);
        } else if (idTipotrabajador == 1) {
          rendimiento['id_colaborador'] = selectedColaborador?.toString();
          await ApiService().actualizarRendimientoIndividualPropio(widget.rendimiento['id'], rendimiento);
        }
        if (!mounted) return;
        Navigator.pop(context, true);
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
    // logInfo('>>> [build] idTipotrabajador: $idTipotrabajador');
    // logInfo('>>> [build] trabajadores: [32m${trabajadores.length}[0m');
    // logInfo('>>> [build] colaboradores: [32m${colaboradores.length}[0m');
    // logInfo('>>> [build] porcentajes: [32m${porcentajes.length}[0m');
    const primaryColor = Colors.green;
    const secondaryColor = Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Rendimiento Individual', style: TextStyle(color: secondaryColor)),
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
                        if (idTipotrabajador == 2)
                          buildSearchableDropdown(
                            label: 'Trabajador (Contratista)',
                            items: trabajadores,
                            selectedValue: selectedTrabajador,
                            onChanged: _onTrabajadorChanged,
                            icon: Icons.person,
                            iconColor: Colors.green,
                          ),
                        if (idTipotrabajador == 2 && porcentajes.isNotEmpty) ...[
                          SizedBox(height: 16),
                          buildSearchableDropdown(
                            label: 'Porcentaje individual',
                            items: porcentajes,
                            selectedValue: selectedPorcentaje,
                            onChanged: (val) => setState(() => selectedPorcentaje = val),
                            icon: Icons.percent,
                            iconColor: Colors.green,
                          ),
                        ],
                        if (idTipotrabajador == 1)
                          buildSearchableDropdown(
                            label: 'Colaborador (Propio)',
                            items: colaboradores,
                            selectedValue: selectedColaborador,
                            onChanged: (val) => setState(() => selectedColaborador = val),
                            icon: Icons.group,
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
                      child: Text('Guardar Cambios'),
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
