import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
//import 'package:dropdown_search/dropdown_search.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:collection/collection.dart';

class NuevaActividadPage extends StatefulWidget {
  @override
  _NuevaActividadPageState createState() => _NuevaActividadPageState();
}

class _NuevaActividadPageState extends State<NuevaActividadPage> {
  final _formKey = GlobalKey<FormState>();

  // Variables para cada campo
  DateTime selectedDate = DateTime.now();
  TimeOfDay? horaInicio;
  TimeOfDay? horaFin;
  String horasTrabajadas = "00:00"; // Se actualizará dinámicamente
  TextEditingController tarifaController = TextEditingController();

  // 🔹 Inicializados como null
  String? idSucursalUsuario; // 🔹 Nueva variable para almacenar el id_sucursal
  String? selectedEspecie;
  String? selectedVariedad;
  String? selectedCeco;
  String? selectedLabor;
  String? selectedUnidad;
  String? selectedTipoTrabajador;
  String? selectedContratista;
  String? selectedTipoRendimiento;
  String? selectedSucursal;

  // Listas cargadas desde la API
  List<Map<String, dynamic>> especies = [];
  List<Map<String, dynamic>> variedades = [];
  List<Map<String, dynamic>> cecos = [];
  List<Map<String, dynamic>> labores = [];
  List<Map<String, dynamic>> unidades = [];
  List<Map<String, dynamic>> tiposTrabajadores = [];
  List<Map<String, dynamic>> contratistas = [];
  List<Map<String, dynamic>> tiposRendimientos = [];
  List<Map<String, dynamic>> sucursales = [];

  // Valores por defecto
  final String estado = "creada";
  final String oc = "0";

  String? idUsuario;

  @override
  void initState() {
    super.initState();
    horaInicio = TimeOfDay(hour: 8, minute: 0); // 08:00 por defecto
    horaFin = TimeOfDay(hour: 17, minute: 0); // 17:00 por defecto
    _calcularHorasTrabajadas(); // Inicializar cálculo
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      idSucursalUsuario = await ApiService().getSucursalActiva();
      selectedSucursal = idSucursalUsuario;
      await _cargarOpciones();
    } catch (e) {
      print("❌ Error al obtener datos iniciales: $e");
    }
  }

  Future<void> _cargarOpciones() async {
    try {
      especies = await ApiService().getEspecies();
      labores = await ApiService().getLabores();
      unidades = await ApiService().getUnidades();
      tiposTrabajadores = await ApiService().getTipoTrabajadores();
      tiposRendimientos = await ApiService().getTipoRendimientos();
      sucursales = await ApiService().getSucursales();

      if (especies.isNotEmpty) {
        selectedEspecie = especies.first['id'].toString();
        await _cargarVariedades(selectedEspecie!);
      }

      if (selectedEspecie != null && selectedVariedad != null) {
        await _cargarCecos();
      }

      setState(() {});
    } catch (e) {
      print("❌ Error al cargar opciones: $e");
    }
  }

  Future<void> _cargarVariedades(String? idEspecie) async {
    if (idEspecie == null || idEspecie.isEmpty || idSucursalUsuario == null) {
      print("⚠ No se envió un id_especie o id_sucursal válido");
      print("🔍 idEspecie: $idEspecie, idSucursalUsuario: $idSucursalUsuario");
      return;
    }

    print(
        "🔍 Solicitando variedades para especie: $idEspecie y sucursal: $idSucursalUsuario");

    try {
      List<Map<String, dynamic>> fetchedVariedades =
          await ApiService().getVariedades(idEspecie, idSucursalUsuario!);

      print("✅ Variedades recibidas: $fetchedVariedades");

      setState(() {
        variedades = fetchedVariedades;
        selectedVariedad = null;
      });
    } catch (e) {
      print("❌ Error al cargar variedades: $e");
    }
  }

  Future<void> _cargarCecos() async {
    if (selectedEspecie == null ||
        selectedVariedad == null ||
        idSucursalUsuario == null) {
      print("⚠ No se envió un id_especie, id_variedad o id_sucursal válido");
      print(
          "🔍 idEspecie: $selectedEspecie, idVariedad: $selectedVariedad, idSucursalUsuario: $idSucursalUsuario");
      return;
    }

    print(
        "🔍 Solicitando CECOs para especie: $selectedEspecie, variedad: $selectedVariedad y sucursal: $idSucursalUsuario");

    try {
      cecos = await ApiService()
          .getCecos(selectedEspecie!, selectedVariedad!, idSucursalUsuario!);
      print("✅ CECOs recibidos: $cecos");

      setState(() {});
    } catch (e) {
      print("❌ Error al cargar CECOs: $e");
    }
  }

  Future<void> _cargarContratistas() async {
    if (idSucursalUsuario == null || selectedTipoTrabajador == null) {
      print(
          "⚠ No se puede cargar contratistas sin sucursal o tipo de trabajador.");
      return;
    }

    try {
      print(
          "🔍 Cargando contratistas para id_sucursal: $idSucursalUsuario y id_tipo_trab: $selectedTipoTrabajador");

      final lista = await ApiService().getContratistas(
        idSucursalUsuario!,
        selectedTipoTrabajador!,
      );

      String? contratistaPropioId;

      // 🔹 Si tipo es propio (1), seleccionar automáticamente
      if (selectedTipoTrabajador == "1" && lista.isNotEmpty) {
        contratistaPropioId = lista.first['id'].toString();
        print(
            "✅ Contratista propio seleccionado automáticamente: $contratistaPropioId");
      }

      // 🔹 Limpiar contratista si no está en la nueva lista
      final idsDisponibles = lista.map((e) => e['id'].toString()).toSet();
      if (selectedContratista != null &&
          !idsDisponibles.contains(selectedContratista)) {
        selectedContratista = null; // Limpiar antes del rebuild
      }

      // 🔄 Actualizar estado
      setState(() {
        contratistas = lista;
        if (contratistaPropioId != null) {
          selectedContratista = contratistaPropioId;
        }
      });
    } catch (e) {
      print("❌ Error al cargar contratistas: $e");
    }
  }

  void _calcularHorasTrabajadas() {
    if (horaInicio != null && horaFin != null) {
      final inicio =
          Duration(hours: horaInicio!.hour, minutes: horaInicio!.minute);
      final fin = Duration(hours: horaFin!.hour, minutes: horaFin!.minute);

      if (fin > inicio) {
        final diferencia = fin - inicio;
        setState(() {
          horasTrabajadas = "${diferencia.inHours.toString().padLeft(2, '0')}:"
              "${(diferencia.inMinutes % 60).toString().padLeft(2, '0')}:00";
        });
      } else {
        setState(() {
          horasTrabajadas = "00:00:00";
        });
      }
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final horaInicioStr = horaInicio != null
          ? "${horaInicio!.hour.toString().padLeft(2, '0')}:${horaInicio!.minute.toString().padLeft(2, '0')}:00"
          : "";
      final horaFinStr = horaFin != null
          ? "${horaFin!.hour.toString().padLeft(2, '0')}:${horaFin!.minute.toString().padLeft(2, '0')}:00"
          : "";

      Map<String, dynamic> nuevaActividad = {
        "fecha": selectedDate.toIso8601String().split("T").first,
        "id_usuario": idUsuario,
        "id_especie": selectedEspecie,
        "id_variedad": selectedVariedad,
        "id_ceco": selectedCeco,
        "id_labor": selectedLabor,
        "id_unidad": selectedUnidad,
        "id_tipo_trab": selectedTipoTrabajador,
        "id_contratista": selectedContratista,
        "id_tipo_rend": selectedTipoRendimiento,
        "id_sucursal": selectedSucursal,
        "hora_inicio": horaInicioStr,
        "hora_fin": horaFinStr,
        "horas_trab": horasTrabajadas,
        "estado": estado,
        "tarifa": tarifaController.text,
        "OC": oc,
      };

      try {
        bool success = await ApiService().createActividad(nuevaActividad);
        if (success) Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.green;
    const secondaryColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("Nueva Actividad", style: TextStyle(color: secondaryColor)),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: secondaryColor),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
                        selectedVariedad = null;
                        _cargarVariedades(val!);
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
                        selectedCeco = null;
                        _cargarCecos();
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
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          horaInicio = picked;
                          _calcularHorasTrabajadas();
                        });
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
                          hours: horaInicio?.hour ?? 8,
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
                          setState(() {
                            horaFin = picked;
                            _calcularHorasTrabajadas();
                          });
                        }
                      }
                    },
                  ),
                  _buildHorasTrabajadasTile(),
                ],
              ),
              SizedBox(height: 26),

              // Botón de Submit
              ElevatedButton.icon(
                onPressed: _submit,
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
                  "Crear Actividad",
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

  Widget _buildHorasTrabajadasTile() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Text(
        "Horas trabajadas: $horasTrabajadas",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.green[700],
        ),
      ),
      trailing: Container(
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.all(8),
        child: Icon(Icons.timer, color: Colors.green),
      ),
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
