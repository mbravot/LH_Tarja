import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:collection/collection.dart';

class EditarActividadPage extends StatefulWidget {
  final Map<String, dynamic> actividad;

  EditarActividadPage({required this.actividad});

  @override
  _EditarActividadPageState createState() => _EditarActividadPageState();
}

class _EditarActividadPageState extends State<EditarActividadPage> {
  late Future<void> _futureCargarOpciones;
  late TextEditingController tarifaController;
  late DateTime selectedDate;
  TimeOfDay? horaInicio, horaFin;
  String? selectedEspecie,
      selectedVariedad,
      selectedCeco,
      selectedLabor,
      selectedUnidad,
      selectedTipoTrabajador,
      selectedTipoRendimiento,
      selectedContratista;

  List<Map<String, dynamic>> especies = [];
  List<Map<String, dynamic>> variedades = [];
  List<Map<String, dynamic>> cecos = [];
  List<Map<String, dynamic>> labores = [];
  List<Map<String, dynamic>> unidades = [];
  List<Map<String, dynamic>> tiposTrabajadores = [];
  List<Map<String, dynamic>> tiposRendimientos = [];
  List<Map<String, dynamic>> contratistas = [];

  @override
  void initState() {
    super.initState();

    try {
      selectedDate = DateTime.parse(widget.actividad['fecha']);
    } catch (e) {
      selectedDate = DateTime.now();
    }

    tarifaController = TextEditingController(
        text: widget.actividad['tarifa']?.toString() ?? '');

    selectedEspecie = widget.actividad['id_especie']?.toString();
    selectedVariedad = widget.actividad['id_variedad']?.toString();
    selectedCeco = widget.actividad['id_ceco']?.toString();
    selectedLabor = widget.actividad['id_labor']?.toString();
    selectedUnidad = widget.actividad['id_unidad']?.toString();
    selectedTipoTrabajador = widget.actividad['id_tipo_trab']?.toString();
    selectedTipoRendimiento = widget.actividad['id_tipo_rend']?.toString();
    selectedContratista = widget.actividad['id_contratista']?.toString();

    if (widget.actividad['hora_inicio'] != null) {
      List<String> partes = widget.actividad['hora_inicio'].split(":");
      if (partes.length >= 2) {
        horaInicio = TimeOfDay(
          hour: int.tryParse(partes[0]) ?? 8,
          minute: int.tryParse(partes[1]) ?? 0,
        );
      }
    }

    if (widget.actividad['hora_fin'] != null) {
      List<String> partes = widget.actividad['hora_fin'].split(":");
      if (partes.length >= 2) {
        horaFin = TimeOfDay(
          hour: int.tryParse(partes[0]) ?? 17,
          minute: int.tryParse(partes[1]) ?? 0,
        );
      }
    }

    _futureCargarOpciones = _cargarOpciones();
  }

  Future<void> _cargarOpciones() async {
    try {
      print("🔍 Cargando opciones...");

      especies = await ApiService().getEspecies();
      labores = await ApiService().getLabores();
      unidades = await ApiService().getUnidades();
      tiposTrabajadores = await ApiService().getTipoTrabajadores();
      tiposRendimientos = await ApiService().getTipoRendimientos();

      print("✅ Tipos Trabajadores cargados: $tiposTrabajadores");
      print("✅ Tipos Rendimientos cargados: $tiposRendimientos");

      // ✅ Verificar que id_sucursal no sea nulo ni vacío antes de llamar a la API
      String? idSucursal = widget.actividad['id_sucursal']?.toString();
      if (idSucursal == null || idSucursal.isEmpty) {
        print(
            "⚠️ Error: id_sucursal es nulo o vacío. No se pueden cargar contratistas.");
      } else {
        print("✅ id_sucursal obtenido correctamente: $idSucursal");
        // ✅ Filtrar contratistas según el tipo de trabajador y sucursal
        await _cargarContratistas();
        print("✅ Contratistas cargados: $contratistas");
      }

      // ✅ Cargar variedades si hay un id_especie válido
      if (selectedEspecie != null && selectedEspecie!.isNotEmpty) {
        variedades =
            await ApiService().getVariedades(selectedEspecie!, idSucursal!);
        print("✅ Variedades cargadas: $variedades");
      }

      // ✅ Cargar CECOs si hay un id_especie y id_variedad válidos
      if (selectedEspecie != null && selectedVariedad != null) {
        cecos = await ApiService()
            .getCecos(selectedEspecie!, selectedVariedad!, idSucursal!);
        print("✅ CECOs cargados: $cecos");
      }

      // 🔹 Asegurar que los valores de la actividad existen en las listas
      _asegurarValorEnLista(especies, selectedEspecie);
      _asegurarValorEnLista(variedades, selectedVariedad);
      _asegurarValorEnLista(cecos, selectedCeco);
      _asegurarValorEnLista(labores, selectedLabor);
      _asegurarValorEnLista(unidades, selectedUnidad);
      _asegurarValorEnLista(tiposTrabajadores, selectedTipoTrabajador);
      _asegurarValorEnLista(tiposRendimientos, selectedTipoRendimiento);
      _asegurarValorEnLista(contratistas, selectedContratista);

      setState(() {}); // 🔹 Actualizar UI después de cargar los datos
    } catch (e) {
      print("❌ Error al cargar opciones: $e");
    }
  }

  void _asegurarValorEnLista(List<Map<String, dynamic>> lista, String? valor) {
    if (valor != null &&
        valor.isNotEmpty &&
        !lista.any((item) => item['id'].toString() == valor)) {
      print("⚠️ Agregando valor seleccionado previamente: $valor");
      lista.insert(0, {'id': valor, 'nombre': 'Seleccionado previamente'});
    }
  }

  void _guardarCambios() async {
    try {
      final datosActualizados = {
        "fecha": DateFormat("yyyy-MM-dd").format(selectedDate), // ✅ Corregido
        "id_especie": selectedEspecie,
        "id_variedad": selectedVariedad,
        "id_ceco": selectedCeco,
        "id_labor": selectedLabor,
        "id_unidad": selectedUnidad,
        "id_tipo_trab": selectedTipoTrabajador,
        "id_contratista": selectedContratista,
        "id_tipo_rend": selectedTipoRendimiento,
        "hora_inicio": horaInicio != null
            ? "${horaInicio!.hour}:${horaInicio!.minute}:00"
            : null,
        "hora_fin":
            horaFin != null ? "${horaFin!.hour}:${horaFin!.minute}:00" : null,
        "tarifa": tarifaController.text
      };

      final response = await ApiService()
          .editarActividad(widget.actividad['id'], datosActualizados);

      if (response['error'] == null) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${response['error']}")));
      }
    } catch (e) {
      print("❌ Error guardando cambios: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error guardando cambios: ${e.toString()}")));
    }
  }

  Future<void> _cargarContratistas() async {
    try {
      String? idSucursal = widget.actividad['id_sucursal']?.toString();
      if (idSucursal == null ||
          idSucursal.isEmpty ||
          selectedTipoTrabajador == null) {
        print(
            "⚠ No se puede cargar contratistas sin id_sucursal o id_tipo_trab.");
        return;
      }

      print(
          "🔍 Cargando contratistas para id_sucursal: $idSucursal y id_tipo_trab: $selectedTipoTrabajador");

      contratistas = await ApiService()
          .getContratistas(idSucursal, selectedTipoTrabajador!);
      print("✅ Contratistas filtrados cargados: $contratistas");

      setState(() {});
    } catch (e) {
      print("❌ Error al cargar contratistas: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.green;
    const secondaryColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title:
            Text("Editar Actividad", style: TextStyle(color: secondaryColor)),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: secondaryColor),
      ),
      body: FutureBuilder<void>(
        future: _futureCargarOpciones,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else {
            return SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sección de Datos Generales
                  _buildSection(
                    "Datos Generales",
                    Icons.description,
                    [
                      // Fecha
                      _buildDatePicker(context),
                      SizedBox(height: 16),
                      
                      // Tipo Personal
                      _buildLabelText("Tipo Personal"),
                      SizedBox(height: 8),
                      _buildTipoPersonalButtons(),
                      SizedBox(height: 16),
                      
                      // Personal (Contratista)
                      buildSearchableDropdown(
                        label: "Personal",
                        items: contratistas,
                        selectedValue: selectedContratista,
                        onChanged: (val) => setState(() => selectedContratista = val),
                        isDisabled: selectedTipoTrabajador == "1",
                        icon: Icons.person,
                      ),
                      SizedBox(height: 16),

                      // Tipo Rendimiento
                      _buildLabelText("Tipo Rendimiento"),
                      SizedBox(height: 8),
                      _buildTipoRendimientoButtons(),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Sección de Detalles de Actividad
                  _buildSection(
                    "Detalles de Actividad",
                    Icons.work,
                    [
                      buildSearchableDropdown(
                        label: "Especie",
                        items: especies,
                        selectedValue: selectedEspecie,
                        onChanged: (val) {
                          setState(() {
                            selectedEspecie = val;
                            _cargarOpciones();
                          });
                        },
                        icon: Icons.eco,
                      ),
                      SizedBox(height: 16),
                      
                      buildSearchableDropdown(
                        label: "Variedad",
                        items: variedades,
                        selectedValue: selectedVariedad,
                        onChanged: (val) {
                          setState(() {
                            selectedVariedad = val;
                            _cargarOpciones();
                          });
                        },
                        icon: Icons.category,
                      ),
                      SizedBox(height: 16),
                      
                      buildSearchableDropdown(
                        label: "CECO",
                        items: cecos,
                        selectedValue: selectedCeco,
                        onChanged: (val) => setState(() => selectedCeco = val),
                        icon: Icons.business,
                      ),
                      SizedBox(height: 16),
                      
                      buildSearchableDropdown(
                        label: "Labor",
                        items: labores,
                        selectedValue: selectedLabor,
                        onChanged: (val) => setState(() => selectedLabor = val),
                        icon: Icons.engineering,
                      ),
                      SizedBox(height: 16),
                      
                      buildSearchableDropdown(
                        label: "Unidad",
                        items: unidades.where((u) {
                          final idUnidad = u['id'].toString();
                          if (selectedTipoTrabajador == "2") {
                            return idUnidad != "35" && idUnidad != "36";
                          } else if (selectedTipoTrabajador == "1") {
                            return idUnidad != "4" && idUnidad != "5";
                          }
                          return true;
                        }).toList(),
                        selectedValue: selectedUnidad,
                        onChanged: (val) => setState(() => selectedUnidad = val),
                        icon: Icons.straighten,
                      ),
                      SizedBox(height: 16),
                      
                      _buildTarifaField(),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Sección de Horario
                  _buildSection(
                    "Horario",
                    Icons.access_time,
                    [
                      _buildTimePickerTile(
                        "Hora de inicio",
                        horaInicio?.format(context) ?? '--:--',
                        () async {
                          TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: horaInicio ?? TimeOfDay(hour: 8, minute: 0),
                          );
                          if (picked != null) {
                            setState(() => horaInicio = picked);
                          }
                        },
                      ),
                      _buildTimePickerTile(
                        "Hora de fin",
                        horaFin?.format(context) ?? '--:--',
                        () async {
                          TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: horaFin ?? TimeOfDay(hour: 17, minute: 0),
                          );
                          if (picked != null) {
                            final inicio = Duration(
                              hours: horaInicio?.hour ?? 0,
                              minutes: horaInicio?.minute ?? 0,
                            );
                            final fin = Duration(
                              hours: picked.hour,
                              minutes: picked.minute,
                            );

                            if (fin <= inicio) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "La hora de fin no puede ser menor o igual a la de inicio",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else {
                              setState(() => horaFin = picked);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 26),

                  // Botón de Guardar
                  ElevatedButton.icon(
                    onPressed: _guardarCambios,
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
                      "Guardar Cambios",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }
        },
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
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() {
            selectedDate = picked;
          });
        }
      },
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
              "Fecha: ${DateFormat("dd/MM/yyyy").format(selectedDate)}",
              style: TextStyle(fontSize: 16),
            ),
            Icon(Icons.calendar_today, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelText(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
    );
  }

  Widget _buildTipoPersonalButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSelectionButton(
            text: "Propio",
            isSelected: selectedTipoTrabajador == "1",
            onPressed: () {
              setState(() {
                selectedTipoTrabajador = "1";
                selectedContratista = null;
                selectedTipoRendimiento = "1";
              });
              _cargarContratistas();
            },
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildSelectionButton(
            text: "Contratista",
            isSelected: selectedTipoTrabajador == "2",
            onPressed: () {
              setState(() {
                selectedTipoTrabajador = "2";
                selectedContratista = null;
                selectedTipoRendimiento = null;
              });
              _cargarContratistas();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTipoRendimientoButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSelectionButton(
            text: "Individual",
            isSelected: selectedTipoRendimiento == "1",
            onPressed: () {
              setState(() {
                selectedTipoRendimiento = "1";
              });
            },
          ),
        ),
        if (selectedTipoTrabajador == "2") ...[
          SizedBox(width: 8),
          Expanded(
            child: _buildSelectionButton(
              text: "Grupal",
              isSelected: selectedTipoRendimiento == "2",
              onPressed: () {
                setState(() {
                  selectedTipoRendimiento = "2";
                });
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectionButton({
    required String text,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.green : Colors.grey.shade400,
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(text),
    );
  }

  Widget _buildTarifaField() {
    return TextFormField(
      controller: tarifaController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: "Tarifa",
        prefixIcon: Icon(Icons.attach_money, color: Colors.green),
        prefixText: "\$ ",
        prefixStyle: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
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
      validator: (value) =>
          value == null || value.isEmpty ? "Ingrese una tarifa" : null,
    );
  }

  Widget _buildTimePickerTile(
    String title,
    String time,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Text(
        "$title: $time",
        style: TextStyle(fontSize: 16),
      ),
      trailing: Container(
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.all(8),
        child: Icon(Icons.access_time, color: Colors.green),
      ),
      onTap: onTap,
    );
  }

  Widget buildSearchableDropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required String? selectedValue,
    required Function(String?) onChanged,
    String keyField = 'id',
    String labelField = 'nombre',
    bool isDisabled = false,
    IconData? icon,
  }) {
    final TextEditingController searchController = TextEditingController();

    return DropdownSearch<Map<String, dynamic>>(
      enabled: !isDisabled,
      items: items,
      itemAsString: (item) => item[labelField],
      selectedItem: selectedValue == null
          ? null
          : items.firstWhereOrNull((e) => e[keyField].toString() == selectedValue),
      onChanged: (val) => onChanged(val?[keyField].toString()),
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
          fillColor: isDisabled ? Colors.grey[200] : Colors.grey[50],
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          controller: searchController,
          decoration: InputDecoration(
            hintText: "Buscar $label...",
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                searchController.clear();
              },
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
      clearButtonProps: const ClearButtonProps(
        isVisible: true,
        icon: Icon(Icons.clear, size: 20),
      ),
    );
  }
}
