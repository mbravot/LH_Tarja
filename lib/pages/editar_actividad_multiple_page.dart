import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

// 🔧 Sistema de logging condicional
void logDebug(String message) {
  if (kDebugMode) {
    print(message);
  }
}

void logError(String message) {
  if (kDebugMode) {
    print("❌ $message");
  }
}

void logInfo(String message) {
  // Comentado para mejorar rendimiento
  // if (kDebugMode) {
  //   print("ℹ️ $message");
  // }
}

class EditarActividadMultiplePage extends StatefulWidget {
  final Map<String, dynamic> actividad;

  EditarActividadMultiplePage({required this.actividad});

  @override
  _EditarActividadMultiplePageState createState() => _EditarActividadMultiplePageState();
}

class _EditarActividadMultiplePageState extends State<EditarActividadMultiplePage> {
  late Future<void> _futureCargarOpciones;
  late TextEditingController tarifaController;
  late DateTime selectedDate;
  TimeOfDay? horaInicio, horaFin;
  String? selectedLabor,
      selectedUnidad,
      selectedContratista;

  // Valores fijos que no se pueden cambiar (ocultos en la UI)
  late String? selectedTipoTrabajador;
  late String? selectedTipoRendimiento;
  late String? selectedTipoCeco;

  List<Map<String, dynamic>> labores = [];
  List<Map<String, dynamic>> unidades = [];
  List<Map<String, dynamic>> contratistas = [];

  @override
  void initState() {
    super.initState();

    try {
      selectedDate = DateTime.parse(widget.actividad['fecha']);
    } catch (e) {
      selectedDate = DateTime.now();
    }

    selectedLabor = widget.actividad['id_labor']?.toString();
    selectedUnidad = widget.actividad['id_unidad']?.toString();
    selectedContratista = widget.actividad['id_contratista']?.toString();
    
    // Valores fijos que no se pueden cambiar
    selectedTipoTrabajador = widget.actividad['id_tipotrabajador']?.toString();
    selectedTipoRendimiento = widget.actividad['id_tiporendimiento']?.toString();
    selectedTipoCeco = widget.actividad['id_tipoceco']?.toString();

    // Establecer tarifa automáticamente si la unidad es 35 o 36
    final unidadId = widget.actividad['id_unidad']?.toString();
    final tarifaInicial = (unidadId == "35" || unidadId == "36") ? "1" : (widget.actividad['tarifa']?.toString() ?? '');
    tarifaController = TextEditingController(text: tarifaInicial);

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
      // Cargando opciones para actividades múltiples
      labores = await ApiService().getLabores();
      unidades = await ApiService().getUnidades();

      // Verificar que id_sucursalactiva no sea nulo ni vacío antes de llamar a la API
      String? idSucursal = widget.actividad['id_sucursalactiva']?.toString();
      if (idSucursal == null || idSucursal.isEmpty) {
        logError("❌ Error: id_sucursalactiva es nulo o vacío. No se pueden cargar contratistas.");
      } else if (selectedTipoTrabajador == "2") {
        // Filtrar contratistas según el tipo de trabajador y sucursal
        await _cargarContratistas();
      }

      // 🔹 Asegurar que los valores de la actividad existen en las listas
      _asegurarValorEnLista(labores, selectedLabor);
      _asegurarValorEnLista(unidades, selectedUnidad);
      _asegurarValorEnLista(contratistas, selectedContratista);

      setState(() {}); // 🔹 Actualizar UI después de cargar los datos
    } catch (e) {
      logError("❌ Error al cargar opciones: $e");
    }
  }

  void _asegurarValorEnLista(List<Map<String, dynamic>> lista, String? valor) {
    if (valor != null &&
        valor.isNotEmpty &&
        !lista.any((item) => item['id'].toString() == valor)) {
      // Agregando valor seleccionado previamente
      lista.insert(0, {'id': valor, 'nombre': 'Seleccionado previamente'});
    }
  }

  void _guardarCambios() async {
    try {
      final datosActualizados = {
        "fecha": DateFormat("yyyy-MM-dd").format(selectedDate),
        "id_labor": selectedLabor,
        "id_unidad": selectedUnidad,
        "id_tipotrabajador": selectedTipoTrabajador, // Valor fijo preservado
        "id_contratista": selectedTipoTrabajador == "2" ? selectedContratista : null,
        "id_tiporendimiento": selectedTipoRendimiento, // Valor fijo preservado
        "hora_inicio": horaInicio != null ? "${horaInicio!.hour.toString().padLeft(2, '0')}:${horaInicio!.minute.toString().padLeft(2, '0')}:00" : null,
        "hora_fin": horaFin != null ? "${horaFin!.hour.toString().padLeft(2, '0')}:${horaFin!.minute.toString().padLeft(2, '0')}:00" : null,
        "id_estadoactividad": widget.actividad['id_estadoactividad'],
        "tarifa": (selectedUnidad == "35" || selectedUnidad == "36") ? "1" : tarifaController.text,
        "id_tipoceco": selectedTipoCeco, // Valor fijo preservado
      };

      final response = await ApiService()
          .editarActividadMultiple(widget.actividad['id'], datosActualizados);

      if (response['error'] == null) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${response['error']}")));
      }
    } catch (e) {
      logError("❌ Error guardando cambios: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error guardando cambios: ${e.toString()}")));
    }
  }

  Future<void> _cargarContratistas() async {
    try {
      String? idSucursal = widget.actividad['id_sucursalactiva']?.toString();
      if (idSucursal == null || idSucursal.isEmpty) {
        logError("❌ Error: id_sucursalactiva es nulo o vacío");
        return;
      }

      if (selectedTipoTrabajador == "2") {
        contratistas = await ApiService().getContratistas(idSucursal);
      } else {
        contratistas = [];
      }
    } catch (e) {
      logError("❌ Error al cargar contratistas: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Actividad Múltiple', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _guardarCambios,
            tooltip: 'Guardar cambios',
          ),
        ],
      ),
      body: FutureBuilder(
        future: _futureCargarOpciones,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    "Error al cargar los datos",
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _futureCargarOpciones = _cargarOpciones();
                      });
                    },
                    child: Text("Reintentar"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

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
                    _buildDatePicker(),
                    SizedBox(height: 16),
                    
                    // Personal (Contratista) - solo si es tipo trabajador 2
                    if (selectedTipoTrabajador == "2") ...[
                      buildSearchableDropdown(
                        label: "Personal",
                        items: contratistas,
                        selectedValue: contratistas.firstWhereOrNull((e) => e['id'].toString() == selectedContratista),
                        onChanged: (val) => setState(() => selectedContratista = val?['id']?.toString()),
                        icon: Icons.person,
                      ),
                      SizedBox(height: 16),
                    ],
                  ],
                ),
                SizedBox(height: 16),

                // Sección de Detalles de Actividad
                _buildSection(
                  "Detalles de Actividad",
                  Icons.work,
                  [
                    buildSearchableDropdown(
                      label: "Labor",
                      items: labores,
                      selectedValue: labores.firstWhereOrNull((e) => e['id'].toString() == selectedLabor),
                      onChanged: (val) async {
                        final laborId = val?['id']?.toString();
                        setState(() => selectedLabor = laborId);
                        
                        // Si se seleccionó una labor, cargar la unidad por defecto
                        if (laborId != null) {
                          try {
                            final unidadDefault = await ApiService().getUnidadDefaultLabor(laborId);
                            if (unidadDefault != null && unidadDefault['unidad_default'] != null) {
                              final unidad = unidadDefault['unidad_default'];
                              setState(() {
                                selectedUnidad = unidad['id'].toString();
                              });
                              
                              // Mostrar mensaje informativo
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Unidad por defecto cargada: ${unidad['nombre']}'),
                                      ],
                                    ),
                                    backgroundColor: Colors.blue,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            logError("❌ Error al cargar unidad por defecto: $e");
                          }
                        }
                      },
                      icon: Icons.engineering,
                    ),
                    SizedBox(height: 16),
                    
                    buildSearchableDropdown(
                      label: "Unidad",
                      items: selectedTipoTrabajador == "2" 
                          ? unidades.where((unidad) => 
                              unidad['id'].toString() != "35" && 
                              unidad['id'].toString() != "36").toList()
                          : unidades,
                      selectedValue: unidades.firstWhereOrNull((e) => e['id'].toString() == selectedUnidad),
                      onChanged: (val) {
                        final newUnidad = val?['id']?.toString();
                        setState(() {
                          selectedUnidad = newUnidad;
                          // Si se selecciona unidad 35 o 36, establecer tarifa en 1
                          if (newUnidad == "35" || newUnidad == "36") {
                            tarifaController.text = "1";
                          } else {
                            // Si se cambia de unidad 35/36 a otra, limpiar tarifa
                            if (selectedUnidad == "35" || selectedUnidad == "36") {
                              tarifaController.clear();
                            }
                          }
                        });
                      },
                      icon: Icons.straighten,
                    ),
                    SizedBox(height: 16),
                    
                    // Solo mostrar campo tarifa si la unidad no es 35 o 36
                    if (selectedUnidad != "35" && selectedUnidad != "36") ...[
                      _buildTarifaField(),
                      SizedBox(height: 16),
                    ],
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
                    foregroundColor: Colors.white,
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
        },
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor, size: 24),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
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

  Widget _buildDatePicker() {
    return ListTile(
      leading: Icon(Icons.calendar_today, color: primaryColor),
      title: Text('Fecha'),
      subtitle: Text(DateFormat('EEEE d \'de\' MMMM, y', 'es_ES').format(selectedDate)),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: Locale('es', 'ES'),
        );
        if (picked != null && picked != selectedDate) {
          setState(() {
            selectedDate = picked;
          });
        }
      },
    );
  }

  Widget buildSearchableDropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? selectedValue,
    required Function(Map<String, dynamic>?) onChanged,
    required IconData icon,
    bool isDisabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: primaryColor),
            SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 8),
        DropdownSearch<Map<String, dynamic>>(
          selectedItem: selectedValue,
          items: items,
          itemAsString: (Map<String, dynamic> item) => item['nombre'] ?? '',
          onChanged: isDisabled ? null : onChanged,
          dropdownButtonProps: DropdownButtonProps(icon: Icon(Icons.arrow_drop_down)),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTarifaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_money, color: primaryColor),
            SizedBox(width: 8),
            Text('Tarifa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 8),
        TextField(
          controller: tarifaController,
          keyboardType: TextInputType.number,
          enabled: selectedUnidad != "35" && selectedUnidad != "36",
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: 'Ingrese la tarifa',
            suffixText: selectedUnidad == "35" || selectedUnidad == "36" ? '(Automática)' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerTile(String label, String time, VoidCallback onTap) {
    return ListTile(
      leading: Icon(Icons.access_time, color: primaryColor),
      title: Text(label),
      subtitle: Text(time),
      onTap: onTap,
    );
  }
}
