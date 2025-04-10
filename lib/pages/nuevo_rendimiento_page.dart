import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:collection/collection.dart';

class NuevoRendimientoPage extends StatefulWidget {
  @override
  _NuevoRendimientoPageState createState() => _NuevoRendimientoPageState();
}

class _NuevoRendimientoPageState extends State<NuevoRendimientoPage> {
  String? selectedActividad;
  String? idSucursal;
  int? tipoRendimientoActividad;
  DateTime selectedDate = DateTime.now();

  List<dynamic> actividades = [];
  List<dynamic> actividadesFiltradas = [];
  List<dynamic> trabajadores = [];
  List<dynamic> selectedTrabajadores = [];

  Map<String, TextEditingController> rendimientoControllers = {};
  TextEditingController rendimientoGrupalController = TextEditingController();
  TextEditingController cantConPapelController = TextEditingController();
  TextEditingController cantSinPapelController = TextEditingController();

  final String cantTrab = "1"; // Siempre 1
  final String horasExtra = "0"; // Siempre 0
  String horasTrab = "0"; // Se actualizará según la actividad seleccionada

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      idSucursal = await ApiService().getSucursalActiva();

      if (idSucursal != null) {
        await prefs.setString('idSucursal', idSucursal!);
      } else {
        print("❌ ERROR: No se pudo obtener la sucursal del usuario");
        return;
      }

      print("📌 ID Sucursal obtenida: $idSucursal");

      List<dynamic> actividadesData = await ApiService().getActividades();
      setState(() {
        actividades = actividadesData;
        _filtrarActividades();
      });

      if (selectedActividad != null) {
        await _cargarTrabajadores();
      }
    } catch (e) {
      print("❌ Error cargando datos: $e");
    }
  }

  Future<void> _cargarTrabajadores() async {
    if (selectedActividad == null || selectedActividad!.isEmpty) {
      print(
          "⚠ No se puede cargar trabajadores sin una actividad seleccionada.");
      setState(() {
        trabajadores = [];
      });
      return;
    }

    try {
      var actividadSeleccionada = actividades.firstWhere(
          (actividad) => actividad['id'].toString() == selectedActividad,
          orElse: () => null);

      if (actividadSeleccionada == null) {
        print("❌ No se encontró la actividad seleccionada.");
        return;
      }

      // 🔹 Obtener el id_tipo_rend de la actividad seleccionada
      int? tipoRendimiento = actividadSeleccionada['id_tipo_rend'];

      // ✅ Si la actividad es de tipo rendimiento grupal (id_tipo_rend == 2), no se cargan trabajadores
      if (tipoRendimiento == 2) {
        print(
            "✅ Actividad de rendimiento grupal (id_tipo_rend = 2), no se cargan trabajadores.");
        setState(() {
          trabajadores = []; // Asegurar que no haya trabajadores
        });
        return; // 🔹 Salir de la función sin hacer la carga de trabajadores
      }

      // 🔹 Si la actividad es de tipo individual (id_tipo_rend == 1), se cargan los trabajadores
      String? idContratistaActividad = actividadSeleccionada['id_contratista'];
      if (idContratistaActividad == null || idContratistaActividad.isEmpty) {
        print("⚠ No se encontró un contratista en la actividad seleccionada.");
        setState(() {
          trabajadores = [];
        });
        return;
      }

      print(
          "🔍 Cargando trabajadores para id_sucursal: $idSucursal y id_contratista: $idContratistaActividad");

      List<dynamic> trabajadoresData = await ApiService()
          .getTrabajadores(idSucursal!, idContratistaActividad);

      setState(() {
        trabajadores = trabajadoresData;
        selectedTrabajadores.clear();
        rendimientoControllers.clear();
      });

      print(
          "✅ Trabajadores cargados: ${trabajadores.map((t) => t['nom_ap']).toList()}");
    } catch (e) {
      print("❌ Error al cargar trabajadores: $e");
    }
  }

  void _filtrarActividades() {
    String fechaSeleccionada = DateFormat('yyyy-MM-dd').format(selectedDate);
    setState(() {
      actividadesFiltradas = actividades
          .where((actividad) {
            try {
              String fechaActividad = actividad['fecha'];
              return fechaActividad == fechaSeleccionada &&
                  actividad['id_sucursal'].toString() == idSucursal;
            } catch (e) {
              print("❌ Error al filtrar actividad: $e");
              return false;
            }
          })
          .map((actividad) => Map<String, dynamic>.from(actividad))
          .toList();
    });

    if (!actividadesFiltradas
        .any((actividad) => actividad['id'].toString() == selectedActividad)) {
      selectedActividad = null;
    }

    _cargarTrabajadores();
  }

  void _inicializarControladores() {
    for (var trabajador in selectedTrabajadores) {
      if (!rendimientoControllers.containsKey(trabajador)) {
        rendimientoControllers[trabajador] = TextEditingController();
      }
    }
  }

  void _seleccionarFecha() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
        _filtrarActividades();
      });
    }
  }

  void _guardarRendimientos() async {
    if (selectedActividad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Seleccione una actividad antes de continuar."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    var actividadSeleccionada = actividades.firstWhere(
      (actividad) => actividad['id'].toString() == selectedActividad,
      orElse: () => null,
    );

    if (actividadSeleccionada == null) {
      print("❌ Error: No se encontró la actividad seleccionada.");
      return;
    }

    int idTipoRend = actividadSeleccionada['id_tipo_rend'];

    // ✅ Validar si el tipo de rendimiento es individual (id_tipo_rend == 1)
    if (idTipoRend == 1 && selectedTrabajadores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Seleccione al menos un trabajador.")),
      );
      return;
    }

    // ✅ Validar si el tipo de rendimiento es grupal (id_tipo_rend == 2)
    if (idTipoRend == 2 && selectedTrabajadores.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "No debe seleccionar trabajadores en rendimiento grupal.")),
      );
      return;
    }

    List<Map<String, dynamic>> rendimientosAEnviar = [];

    if (idTipoRend == 1) {
      for (var trabajador in selectedTrabajadores) {
        if (rendimientoControllers[trabajador]?.text.isEmpty ?? true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Ingrese rendimiento para cada trabajador seleccionado.")),
          );
          return;
        }

        rendimientosAEnviar.add({
          "fecha": DateFormat('yyyy-MM-dd').format(selectedDate),
          "id_actividad": selectedActividad,
          "id_trabajador": trabajador,
          "id_sucursal": idSucursal,
          "rendimiento":
              double.tryParse(rendimientoControllers[trabajador]!.text) ?? 0,
          "cant_trab": 1,
          "cant_con_papel": 0,
          "cant_sin_papel": 0,
          "horas_trab": actividadSeleccionada['horas_trab'],
          "horas_extra": 0,
        });
      }
    } else if (idTipoRend == 2) {
      if (rendimientoGrupalController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ingrese el rendimiento grupal.")),
        );
        return;
      }

      if (cantConPapelController.text.isEmpty ||
          cantSinPapelController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Ingrese la cantidad de trabajadores con/sin papel.")),
        );
        return;
      }

      rendimientosAEnviar.add({
        "fecha": DateFormat('yyyy-MM-dd').format(selectedDate),
        "id_actividad": selectedActividad,
        "id_trabajador": null,
        "id_sucursal": idSucursal,
        "rendimiento": double.tryParse(rendimientoGrupalController.text) ?? 0,
        "cant_trab": (int.tryParse(cantConPapelController.text) ?? 0) +
            (int.tryParse(cantSinPapelController.text) ?? 0),
        "cant_con_papel": int.tryParse(cantConPapelController.text) ?? 0,
        "cant_sin_papel": int.tryParse(cantSinPapelController.text) ?? 0,
        "horas_trab": actividadSeleccionada['horas_trab'],
        "horas_extra": 0,
      });
    }

    print("📤 Enviando rendimientos: ${rendimientosAEnviar}");

    bool success = await ApiService().createRendimientos(rendimientosAEnviar);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar rendimientos")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.green;
    const secondaryColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title:
            Text("Nuevo Rendimiento", style: TextStyle(color: secondaryColor)),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: secondaryColor),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sección de Datos Generales
              _buildSection(
                "Datos Generales",
                Icons.description,
                [
                  _buildDatePicker(context),
                  SizedBox(height: 20),
                  buildSearchableDropdown(
                    label: "Actividad",
                    items: actividadesFiltradas.cast<Map<String, dynamic>>(),
                    selectedValue: selectedActividad,
                    onChanged: (value) {
                      setState(() {
                        selectedActividad = value;
                        var actividadSeleccionada = actividades.firstWhere(
                          (actividad) =>
                              actividad['id'].toString() == selectedActividad,
                          orElse: () => null,
                        );
                        if (actividadSeleccionada != null) {
                          tipoRendimientoActividad =
                              actividadSeleccionada['id_tipo_rend'];
                          horasTrab =
                              actividadSeleccionada['horas_trab'].toString();
                          if (tipoRendimientoActividad == 1) {
                            _cargarTrabajadores();
                          } else {
                            trabajadores = [];
                            selectedTrabajadores.clear();
                            rendimientoControllers.clear();
                          }
                        }
                      });
                    },
                    itemAsString: (actividad) {
                      final contratista =
                          actividad['contratista'] ?? "Sin contratista";
                      final labor = actividad['labor'] ?? "Sin labor";
                      final tipoRend = actividad['id_tipo_rend'] == 1
                          ? "Individual"
                          : "Grupal";
                      final ceco = actividad['ceco'] ?? "Sin CECO";
                      return "$contratista - $labor - $tipoRend - $ceco";
                    },
                    icon: Icons.work,
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Sección de Rendimiento Individual
              if (tipoRendimientoActividad == 1)
                _buildSection(
                  "Rendimiento Individual",
                  Icons.person,
                  [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: MultiSelectDialogField(
                        buttonText: Text("Seleccionar Trabajadores"),
                        title: Text("Trabajadores"),
                        searchable: true,
                        buttonIcon: Icon(Icons.arrow_drop_down),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        items: trabajadores
                            .map((trabajador) => MultiSelectItem(
                                trabajador['id'].toString(),
                                trabajador['nom_ap']))
                            .toList(),
                        listType: MultiSelectListType.CHIP,
                        onConfirm: (values) {
                          setState(() {
                            selectedTrabajadores = values.cast<String>();
                            _inicializarControladores();
                          });
                        },
                        chipDisplay: MultiSelectChipDisplay(
                          onTap: (value) {
                            setState(() {
                              selectedTrabajadores.remove(value);
                              rendimientoControllers.remove(value);
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    ...selectedTrabajadores.map((trabajadorId) {
                      var trabajador = trabajadores.firstWhere(
                        (t) => t['id'].toString() == trabajadorId,
                        orElse: () => {'nom_ap': 'Desconocido'},
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TextFormField(
                          controller: rendimientoControllers[trabajadorId],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Rendimiento - ${trabajador['nom_ap']}",
                            prefixIcon:
                                Icon(Icons.trending_up, color: Colors.green),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.green, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),

              // Sección de Rendimiento Grupal
              if (tipoRendimientoActividad == 2)
                _buildSection(
                  "Rendimiento Grupal",
                  Icons.groups,
                  [
                    TextFormField(
                      controller: rendimientoGrupalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Rendimiento Grupal",
                        prefixIcon:
                            Icon(Icons.trending_up, color: Colors.green),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cantConPapelController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "50%",
                              prefixIcon:
                                  Icon(Icons.person, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.green, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: cantSinPapelController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "35%",
                              prefixIcon: Icon(Icons.person_outline,
                                  color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.green, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              SizedBox(height: 26),
              ElevatedButton.icon(
                onPressed: _guardarRendimientos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: secondaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(Icons.save),
                label: Text(
                  "Guardar Rendimientos",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: _seleccionarFecha,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Fecha: ${DateFormat('dd/MM/yyyy').format(selectedDate)}",
              style: TextStyle(fontSize: 16),
            ),
            Icon(Icons.calendar_today, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget buildSearchableDropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required String? selectedValue,
    required Function(String?) onChanged,
    required String Function(Map<String, dynamic>) itemAsString,
    IconData? icon,
  }) {
    return DropdownSearch<Map<String, dynamic>>(
      items: items,
      selectedItem: selectedValue == null
          ? null
          : items.firstWhereOrNull((e) => e['id'].toString() == selectedValue),
      itemAsString: itemAsString,
      onChanged: (val) => onChanged(val?['id'].toString()),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.green) : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: "Buscar $label...",
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        containerBuilder: (context, popupWidget) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: popupWidget,
          );
        },
      ),
    );
  }
}
