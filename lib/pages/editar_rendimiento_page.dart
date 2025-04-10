import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../services/api_service.dart';
//import 'package:dropdown_search/dropdown_search.dart';
//import 'package:collection/collection.dart';

class EditarRendimientoPage extends StatefulWidget {
  final dynamic rendimiento; // Recibe el rendimiento a editar

  EditarRendimientoPage({required this.rendimiento});

  @override
  _EditarRendimientoPageState createState() => _EditarRendimientoPageState();
}

class _EditarRendimientoPageState extends State<EditarRendimientoPage> {
  // Controladores de texto
  TextEditingController fechaController = TextEditingController();
  TextEditingController rendimientoController = TextEditingController();
  TextEditingController rendimientoGrupalController = TextEditingController();
  TextEditingController cantConPapelController = TextEditingController();
  TextEditingController cantSinPapelController = TextEditingController();

  String? selectedActividad;
  String? selectedTrabajador;
  String? selectedSucursal;
  String? selectedContratista;
  int? tipoRendimientoActividad;
  List<dynamic> trabajadores = [];
  List<dynamic> selectedTrabajadores = [];

  @override
  void initState() {
    super.initState();

    // 📌 Convertir la fecha de string a DateTime
    try {
      DateTime fecha = DateTime.parse(widget.rendimiento['fecha']);
      fechaController.text = DateFormat('dd/MM/yyyy')
          .format(fecha); // ✅ Mostrar en formato correcto
    } catch (e) {
      print("❌ Error al parsear la fecha: $e. Se usará la fecha actual.");
      fechaController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    // Asegurar valores en controladores
    rendimientoController.text =
        widget.rendimiento['rendimiento']?.toString() ?? '0';
    cantConPapelController.text =
        widget.rendimiento['cant_con_papel']?.toString() ?? '0';
    cantSinPapelController.text =
        widget.rendimiento['cant_sin_papel']?.toString() ?? '0';

    // Convertir IDs a String
    selectedActividad = widget.rendimiento['id_actividad']?.toString();
    selectedTrabajador = widget.rendimiento['id_trabajador']?.toString();
    selectedSucursal = widget.rendimiento['id_sucursal']?.toString();

    // Cargar datos iniciales
    _cargarDatosIniciales();
  }

  /// 🔹 Cargar datos del rendimiento seleccionado
  void _cargarDatosIniciales() async {
    try {
      selectedActividad = widget.rendimiento['id_actividad']?.toString();
      tipoRendimientoActividad =
          await _obtenerTipoRendimiento(selectedActividad!);

      // Obtener `id_contratista` de la actividad seleccionada
      selectedContratista = await _obtenerContratista(selectedActividad!);

      print(
          "📌 Actividad: $selectedActividad, Tipo Rendimiento: $tipoRendimientoActividad");
      print(
          "📌 Sucursal: $selectedSucursal, Contratista: $selectedContratista");

      if (tipoRendimientoActividad == 1) {
        if (selectedSucursal == null || selectedContratista == null) {
          print(
              "❌ No se puede buscar trabajadores sin sucursal o contratista.");
        } else {
          print("🔍 Buscando trabajadores...");
          trabajadores = await ApiService().getTrabajadores(
            selectedSucursal!,
            selectedContratista!,
          );
          print("✅ Trabajadores obtenidos: $trabajadores");

          selectedTrabajadores = [widget.rendimiento['id_trabajador']];
          rendimientoController.text =
              widget.rendimiento['rendimiento'].toString();
        }
      } else if (tipoRendimientoActividad == 2) {
        rendimientoGrupalController.text =
            widget.rendimiento['rendimiento'].toString();
      }

      setState(() {});
    } catch (e) {
      print("❌ Error cargando datos iniciales: $e");
    }
  }

  /// 🔹 Obtener el tipo de rendimiento de la actividad
  Future<int?> _obtenerTipoRendimiento(String idActividad) async {
    List<dynamic> actividades = await ApiService().getActividades();
    try {
      var actividad = actividades.firstWhere(
        (a) => a['id'].toString() == idActividad,
      );
      return actividad['id_tipo_rend'];
    } catch (e) {
      return null;
    }
  }

  /// 🔹 Obtener `id_contratista` de la actividad seleccionada
  Future<String?> _obtenerContratista(String idActividad) async {
    List<dynamic> actividades = await ApiService().getActividades();
    try {
      var actividad = actividades.firstWhere(
        (a) => a['id'].toString() == idActividad,
      );
      return actividad['id_contratista'].toString();
    } catch (e) {
      return null;
    }
  }

  /// 🔹 Guardar cambios sin sobrescribir valores predeterminados
  void _guardarCambios() async {
    if (tipoRendimientoActividad == 1 && selectedTrabajadores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Debe seleccionar al menos un trabajador.")),
      );
      return;
    }

    // 📌 Convertir la fecha al formato adecuado para la API
    DateTime fecha = DateFormat('dd/MM/yyyy').parse(fechaController.text);
    String fechaFormateada = DateFormat('yyyy-MM-dd').format(fecha);

    Map<String, dynamic> datosActualizados = {
      "fecha": fechaFormateada, // ✅ Guardar la fecha en formato correcto
      "id_trabajador": selectedTrabajadores.isNotEmpty
          ? selectedTrabajadores.first
          : widget.rendimiento['id_trabajador'],

      "rendimiento": tipoRendimientoActividad == 1
          ? double.tryParse(rendimientoController.text) ??
              widget.rendimiento['rendimiento']
          : double.tryParse(rendimientoGrupalController.text) ??
              widget.rendimiento['rendimiento'],
      "cant_trab": widget.rendimiento['cant_trab'] ?? 1,
      "cant_con_papel": tipoRendimientoActividad == 2
          ? int.tryParse(cantConPapelController.text) ??
              widget.rendimiento['cant_con_papel']
          : widget.rendimiento['cant_con_papel'],
      "cant_sin_papel": tipoRendimientoActividad == 2
          ? int.tryParse(cantSinPapelController.text) ??
              widget.rendimiento['cant_sin_papel']
          : widget.rendimiento['cant_sin_papel'],
      "horas_trab": widget.rendimiento['horas_trab'] ?? "00:00:00",
      "horas_extra": widget.rendimiento['horas_extra'] ?? "00:00:00",
      "hr_trabajada": widget.rendimiento['hr_trabajada'] ?? "00:00:00",
    };

    print("📤 Enviando datos actualizados: $datosActualizados");

    bool success = await ApiService().editarRendimiento(
      widget.rendimiento['id'],
      datosActualizados,
    );

    if (success) {
      widget.rendimiento.remove('trabajador'); // <--- fuerza recarga real
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al actualizar rendimiento.")),
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
            Text("Editar Rendimiento", style: TextStyle(color: secondaryColor)),
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
                  Text(
                    "Actividad:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.work, color: Colors.green),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.rendimiento['actividad'] ?? "Sin actividad",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
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
                          });
                        },
                        initialValue: selectedTrabajadores
                            .map((e) => e.toString())
                            .toList(),
                        chipDisplay: MultiSelectChipDisplay(
                          onTap: (value) {
                            setState(() {
                              selectedTrabajadores.remove(value);
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: rendimientoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Rendimiento",
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
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateFormat('dd/MM/yyyy').parse(fechaController.text),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );

        if (pickedDate != null) {
          setState(() {
            fechaController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
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
              "Fecha: ${fechaController.text}",
              style: TextStyle(fontSize: 16),
            ),
            Icon(Icons.calendar_today, color: Colors.green),
          ],
        ),
      ),
    );
  }
}
