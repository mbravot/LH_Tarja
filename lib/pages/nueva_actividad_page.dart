import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
//import 'package:dropdown_search/dropdown_search.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'ceco_administrativo_form.dart';
import 'ceco_productivo_form.dart';
import 'ceco_maquinaria_form.dart';
import 'ceco_inversion_form.dart';
import 'ceco_riego_form.dart';

// 🔧 Sistema de logging condicional - Comentado para mejorar rendimiento
void logDebug(String message) {
  // Comentado para mejorar rendimiento
  // if (kDebugMode) {
  //   print(message);
  // }
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

class NuevaActividadPage extends StatefulWidget {
  const NuevaActividadPage({Key? key}) : super(key: key);

  @override
  State<NuevaActividadPage> createState() => _NuevaActividadPageState();
}

class _NuevaActividadPageState extends State<NuevaActividadPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

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
  List<Map<String, dynamic>> labores = [];
  List<Map<String, dynamic>> unidades = [];
  List<Map<String, dynamic>> tiposTrabajadores = [];
  List<Map<String, dynamic>> contratistas = [];
  List<Map<String, dynamic>> tiposRendimientos = [];
  List<Map<String, dynamic>> sucursales = [];
  List<Map<String, dynamic>> tipoCecos = [];

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
      await _loadData();
    } catch (e) {
      logError("❌ Error al obtener datos iniciales: $e");
    }
  }

  Future<void> _loadData() async {
    try {
      // Cargar datos de la API
      final data = await ApiService().getOpciones();
      // Datos cargados exitosamente
      setState(() {
        tiposTrabajadores = List<Map<String, dynamic>>.from(data['tiposTrabajadores'] ?? []);
        contratistas = List<Map<String, dynamic>>.from(data['contratistas'] ?? []);
        tiposRendimientos = List<Map<String, dynamic>>.from(data['tiposRendimientos'] ?? []);
        labores = List<Map<String, dynamic>>.from(data['labores'] ?? []);
        unidades = List<Map<String, dynamic>>.from(data['unidades'] ?? []);
        tipoCecos = List<Map<String, dynamic>>.from(data['tipoCecos'] ?? []);
        // Seleccionar automáticamente el CECO Productivo (id = 2)
        selectedCeco = '2';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar datos: $e")),
      );
    }
  }

  Future<void> _cargarContratistas() async {
    if (idSucursalUsuario == null || selectedTipoTrabajador == null) {
      logError(
          "⚠ No se puede cargar contratistas sin sucursal o tipo de trabajador.");
      return;
    }

    try {
      // logInfo(
      //     "🔍 Cargando contratistas para id_sucursal: $idSucursalUsuario y id_tipo_trab: $selectedTipoTrabajador");

      final lista = await ApiService().getContratistas(
        idSucursalUsuario!,
      );

      String? contratistaPropioId;

      // 🔹 Si tipo es propio (1), seleccionar automáticamente
      if (selectedTipoTrabajador == "1" && lista.isNotEmpty) {
        contratistaPropioId = lista.first['id'].toString();
        // logInfo(
        //     "✅ Contratista propio seleccionado automáticamente: $contratistaPropioId");
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
      logError("❌ Error al cargar contratistas: $e");
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        final idSucursal = prefs.getString('id_sucursal');

        if (token == null || idSucursal == null) {
          throw Exception('No se encontró el token o la sucursal');
        }

        final actividad = {
          'fecha': DateFormat('yyyy-MM-dd').format(selectedDate),
          'id_tipotrabajador': selectedTipoTrabajador,
          'id_contratista': selectedTipoTrabajador == '2' ? selectedContratista : null,
          'id_tiporendimiento': selectedTipoRendimiento,
          'id_labor': selectedLabor,
          'id_unidad': selectedUnidad,
          'id_tipoceco': selectedCeco,
          'tarifa': (selectedUnidad == "35" || selectedUnidad == "36") ? "1" : tarifaController.text,
          'hora_inicio': horaInicio != null ? "${horaInicio!.hour.toString().padLeft(2, '0')}:${horaInicio!.minute.toString().padLeft(2, '0')}:00" : null,
          'hora_fin': horaFin != null ? "${horaFin!.hour.toString().padLeft(2, '0')}:${horaFin!.minute.toString().padLeft(2, '0')}:00" : null,
          'id_estadoactividad': 1, // Estado creada
        };

        final response = await ApiService().crearActividad(actividad);

        if (response['success'] == true || response['success'] == "true" || response['success'] == 1) {
          final idActividad = response['id_actividad'];
          
          // Navegar al formulario de CECO correspondiente
          if (!mounted) return;
          
          switch (selectedCeco) {
            case '1':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CecoAdministrativoForm(idActividad: idActividad),
                ),
              );
              break;
            case '2':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CecoProductivoForm(idActividad: idActividad),
                ),
              );
              break;
            case '3':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CecoMaquinariaForm(idActividad: idActividad),
                ),
              );
              break;
            case '4':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CecoInversionForm(idActividad: idActividad),
                ),
              );
              break;
            case '5':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CecoRiegoForm(idActividad: idActividad),
                ),
              );
              break;
          }
        } else {
          throw Exception(response['error'] ?? 'Error al crear la actividad');
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
                  if (selectedTipoTrabajador == "2")
                  buildSearchableDropdown(
                    label: "Personal",
                    items: contratistas,
                    selectedValue: selectedContratista,
                    onChanged: (val) => setState(() => selectedContratista = val),
                      isDisabled: false,
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
                    label: "Labor",
                    items: labores,
                    selectedValue: selectedLabor,
                    onChanged: (val) async {
                      setState(() => selectedLabor = val);
                      
                      // Si se seleccionó una labor, cargar la unidad por defecto
                      if (val != null) {
                        try {
                          final unidadDefault = await ApiService().getUnidadDefaultLabor(val);
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
                    selectedValue: selectedUnidad,
                    onChanged: (val) {
                      setState(() {
                        selectedUnidad = val;
                        // Si se selecciona unidad 35 o 36, establecer tarifa en 1
                        if (val == "35" || val == "36") {
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
                  
                  buildSearchableDropdown(
                    label: "Tipo CECO",
                    items: tipoCecos,
                    selectedValue: selectedCeco,
                    onChanged: (val) {
                      setState(() {
                        selectedCeco = val;
                      });
                    },
                    icon: Icons.category,
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
                onPressed: _submitForm,
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
                // Limpiar unidad si estaba seleccionada una que no estaba disponible para contratistas
                if (selectedUnidad == "35" || selectedUnidad == "36") {
                  selectedUnidad = null;
                }
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
                // Limpiar unidad si está seleccionada una que no estará disponible para contratistas
                if (selectedUnidad == "35" || selectedUnidad == "36") {
                  selectedUnidad = null;
                }
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
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
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
      validator: (value) {
        // No validar tarifa si la unidad es 35 o 36
        if (selectedUnidad == "35" || selectedUnidad == "36") {
          return null;
        }
        return value == null || value.isEmpty ? "Ingrese una tarifa" : null;
      },
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
