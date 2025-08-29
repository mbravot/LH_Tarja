import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:collection/collection.dart';
import 'ceco_productivo_multiple.dart';
import 'ceco_riego_multiple.dart';

// 🔧 Sistema de logging condicional
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

class CreateActividadMultiplePage extends StatefulWidget {
  const CreateActividadMultiplePage({Key? key}) : super(key: key);

  @override
  State<CreateActividadMultiplePage> createState() => _CreateActividadMultiplePageState();
}

class _CreateActividadMultiplePageState extends State<CreateActividadMultiplePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Variables para cada campo
  DateTime selectedDate = DateTime.now();
  TimeOfDay? horaInicio;
  TimeOfDay? horaFin;
  String horasTrabajadas = "00:00"; // Se actualizará dinámicamente
  TextEditingController tarifaController = TextEditingController();

  // 🔹 Inicializados como null
  String? selectedLabor;
  String? selectedUnidad;
  String? selectedTipoCeco;

  // Listas cargadas desde la API
  List<Map<String, dynamic>> labores = [];
  List<Map<String, dynamic>> unidades = [];
  List<Map<String, dynamic>> tipoCecos = [];

  @override
  void initState() {
    super.initState();
    horaInicio = TimeOfDay(hour: 8, minute: 0); // 08:00 por defecto
    horaFin = TimeOfDay(hour: 17, minute: 0); // 17:00 por defecto
    _calcularHorasTrabajadas(); // Inicializar cálculo
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      // Cargar datos de la API usando el mismo método que nueva_actividad_page.dart
      final data = await ApiService().getOpciones();
      
      setState(() {
        labores = List<Map<String, dynamic>>.from(data['labores'] ?? []);
        unidades = List<Map<String, dynamic>>.from(data['unidades'] ?? []);
        
        // Filtrar solo los tipos de CECO permitidos para actividades múltiples
        final todosTipoCecos = List<Map<String, dynamic>>.from(data['tipoCecos'] ?? []);
        tipoCecos = todosTipoCecos.where((ceco) {
          final id = ceco['id'].toString();
          return id == '2' || id == '5'; // Solo Productivo (2) y Riego (5)
        }).toList();
        
        // Seleccionar automáticamente el CECO Productivo (id = 2)
        selectedTipoCeco = '2';
        _isLoading = false;
      });
    } catch (e) {
      logError("❌ Error al cargar datos: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar los datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calcularHorasTrabajadas() {
    if (horaInicio != null && horaFin != null) {
      final inicio = Duration(hours: horaInicio!.hour, minutes: horaInicio!.minute);
      final fin = Duration(hours: horaFin!.hour, minutes: horaFin!.minute);
      
      if (fin > inicio) {
        final diferencia = fin - inicio;
        final horas = diferencia.inHours;
        final minutos = diferencia.inMinutes % 60;
        setState(() {
          horasTrabajadas = "${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}";
        });
      } else {
        setState(() {
          horasTrabajadas = "00:00";
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedLabor == null || selectedUnidad == null || selectedTipoCeco == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa todos los campos requeridos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (horaInicio == null || horaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor selecciona las horas de inicio y fin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final actividad = {
        'fecha': DateFormat('yyyy-MM-dd').format(selectedDate),
        'id_tipotrabajador': 1, // Valor fijo para actividades múltiples (propio)
        'id_contratista': null, // Valor fijo para actividades múltiples (para propios)
        'id_tiporendimiento': 3, // Valor fijo para actividades múltiples (MÚLTIPLE)
        'id_labor': int.parse(selectedLabor!),
        'id_unidad': int.parse(selectedUnidad!),
        'id_tipoceco': int.parse(selectedTipoCeco!), // Convertir a entero como espera el backend
        'tarifa': (selectedUnidad == "35" || selectedUnidad == "36") ? 1 : int.parse(tarifaController.text),
        'hora_inicio': "${horaInicio!.hour.toString().padLeft(2, '0')}:${horaInicio!.minute.toString().padLeft(2, '0')}:00",
        'hora_fin': "${horaFin!.hour.toString().padLeft(2, '0')}:${horaFin!.minute.toString().padLeft(2, '0')}:00",
        'id_estadoactividad': 1, // Estado creada
      };

      // Debug: Imprimir los datos que se están enviando
      logError("🔍 Datos enviados a crearActividadMultiple: $actividad");
      logError("🔍 selectedTipoCeco: $selectedTipoCeco");

      final response = await ApiService().crearActividadMultiple(actividad);

      if (response['success'] == true) {
        if (!mounted) return;
        
        final idActividad = response['id_actividad'];
        
        // Navegar al formulario de CECO correspondiente
        switch (selectedTipoCeco) {
          case '2': // Productivo
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CecoProductivoMultiple(idActividad: idActividad),
              ),
            );
            break;
          case '5': // Riego
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CecoRiegoMultiple(idActividad: idActividad),
              ),
            );
            break;
          default:
            // Para otros tipos de CECO, volver a la página anterior
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Actividad múltiple creada exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
            break;
        }
      } else {
        throw Exception(response['error'] ?? 'Error al crear la actividad múltiple');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.green;
    const secondaryColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("Nueva Actividad Múltiple", style: TextStyle(color: secondaryColor)),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: secondaryColor),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : SingleChildScrollView(
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
                          items: unidades,
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
                          selectedValue: selectedTipoCeco,
                          onChanged: (val) {
                            setState(() => selectedTipoCeco = val);
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
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: secondaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                              ),
                            )
                          : Icon(Icons.save),
                      label: Text(_isLoading ? "Creando..." : "Crear Actividad Múltiple"),
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
