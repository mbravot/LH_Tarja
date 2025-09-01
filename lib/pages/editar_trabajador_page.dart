import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:app_lh_tarja/utils/colors.dart';
import 'package:app_lh_tarja/pages/trabajadores_page.dart';

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

class EditarTrabajadorPage extends StatefulWidget {
  final dynamic trabajador;

  EditarTrabajadorPage({this.trabajador});

  @override
  _EditarTrabajadorPageState createState() => _EditarTrabajadorPageState();
}

class _EditarTrabajadorPageState extends State<EditarTrabajadorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController rutController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController apellidoPController = TextEditingController();
  final TextEditingController apellidoMController = TextEditingController();
  final TextEditingController dvController = TextEditingController();
  final Color primaryColor = Colors.green;

  bool _guardando = false;
  List<Map<String, dynamic>> contratistas = [];
  List<Map<String, dynamic>> porcentajes = [];
  List<Map<String, dynamic>> estados = [
    {"id": 1, "nombre": "Activo"},
    {"id": 2, "nombre": "Inactivo"}
  ];

  String? selectedContratista;
  String? selectedPorcentaje;
  String? selectedEstado;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    if (widget.trabajador != null) {
      rutController.text = widget.trabajador['rut']?.toString() ?? '';
      nombreController.text = widget.trabajador['nombre']?.toString() ?? '';
      apellidoPController.text = widget.trabajador['apellido_paterno']?.toString() ?? '';
      apellidoMController.text = widget.trabajador['apellido_materno']?.toString() ?? '';
      dvController.text = widget.trabajador['codigo_verificador']?.toString() ?? '';
      selectedContratista = widget.trabajador['id_contratista']?.toString();
      selectedPorcentaje = widget.trabajador['id_porcentaje']?.toString();
      selectedEstado = widget.trabajador['id_estado']?.toString();
    }
    rutController.addListener(_calcularDV);
  }

  Future<void> _cargarDatosIniciales() async {
    contratistas = await ApiService().getContratistasPorSucursal();
    porcentajes = await ApiService().getPorcentajesContratista();

    setState(() {});
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    }
  }

  void _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final String nombre = nombreController.text.trim();
      final String apellidoPaterno = apellidoPController.text.trim();
      final String apellidoMaterno = apellidoMController.text.trim();
      final String nomAp = "$nombre $apellidoPaterno $apellidoMaterno";

      Map<String, dynamic> data = {
        "nombre": nombreController.text.trim(),
        "apellido_paterno": apellidoPController.text.trim(),
        "apellido_materno": apellidoMController.text.trim(),
        "nom_ap": "${nombreController.text.trim()} ${apellidoPController.text.trim()} ${apellidoMController.text.trim()}",
        "id_contratista": selectedContratista,
        "id_porcentaje": int.parse(selectedPorcentaje!),
        "id_estado": int.parse(selectedEstado!),
      };

      // Solo agregamos RUT y DV si no están vacíos
      if (rutController.text.trim().isNotEmpty) {
        data["rut"] = int.parse(rutController.text.trim());
        data["codigo_verificador"] = dvController.text.trim();
      }

              // logInfo("📤 Datos a enviar: $data"); // Para debugging

      bool success = await ApiService().editarTrabajador(widget.trabajador['id'].toString(), data);

      if (success) {
        Navigator.pop(context, true);
      } else {
        _mostrarError("Error al guardar los cambios");
      }
    } catch (e) {
      _mostrarError("Error al actualizar el trabajador: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _calcularDV() {
    String rut = rutController.text.replaceAll('.', '').replaceAll('-', '');
    if (rut.isEmpty || int.tryParse(rut) == null) {
      dvController.text = '';
      return;
    }
    int suma = 0;
    int multiplicador = 2;
    for (int i = rut.length - 1; i >= 0; i--) {
      suma += int.parse(rut[i]) * multiplicador;
      multiplicador++;
      if (multiplicador > 7) multiplicador = 2;
    }
    int resto = suma % 11;
    int dvNum = 11 - resto;
    String dv;
    if (dvNum == 11) {
      dv = '0';
    } else if (dvNum == 10) {
      dv = 'K';
    } else {
      dv = dvNum.toString();
    }
    dvController.text = dv;
  }

  bool _validarFormulario() {
    if (nombreController.text.trim().isEmpty) {
      _mostrarError("El nombre es obligatorio");
      return false;
    }
    if (apellidoPController.text.trim().isEmpty) {
      _mostrarError("El apellido paterno es obligatorio");
      return false;
    }
    if (selectedContratista == null) {
      _mostrarError("Debe seleccionar un contratista");
      return false;
    }
    if (selectedPorcentaje == null) {
      _mostrarError("Debe seleccionar un porcentaje");
      return false;
    }
    if (selectedEstado == null) {
      _mostrarError("Debe seleccionar un estado");
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Editar Trabajador",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.green.withOpacity(0.1),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: primaryColor),
                          const SizedBox(width: 10),
                          Text(
                            "Datos del Trabajador",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: rutController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                              decoration: InputDecoration(
                                labelText: 'RUT (opcional)',
                                hintText: 'RUT (opcional)',
                                prefixIcon: const Icon(Icons.badge_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                errorStyle: const TextStyle(height: 0),
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (int.tryParse(value) == null) {
                                    return 'El RUT debe ser un número';
                                  }
                                  if (value.length > 8) {
                                    return 'El RUT debe tener máximo 8 dígitos';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: dvController,
                              decoration: InputDecoration(
                                labelText: 'DV (opcional)',
                                hintText: 'DV (opcional)',
                                prefixIcon: const Icon(Icons.verified_user_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                errorStyle: const TextStyle(height: 0),
                              ),
                              validator: (value) {
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nombreController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.person_outline_outlined, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.05),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Ingrese el nombre' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: apellidoPController,
                        decoration: InputDecoration(
                          labelText: 'Apellido Paterno',
                          prefixIcon: Icon(Icons.person_outline_outlined, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.05),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Ingrese el apellido paterno' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: apellidoMController,
                        decoration: InputDecoration(
                          labelText: 'Apellido Materno (opcional)',
                          prefixIcon: Icon(Icons.person_outline_outlined, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (contratistas.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No hay contratistas disponibles para la sucursal.',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ] else ...[
                        DropdownSearch<Map<String, dynamic>>(
                          items: List<Map<String, dynamic>>.from(contratistas),
                          itemAsString: (item) => item['nombre'],
                          selectedItem: (contratistas.isEmpty || selectedContratista == null)
                            ? null
                            : contratistas.firstWhere(
                                (e) => e['id'].toString() == selectedContratista,
                                orElse: () => <String, dynamic>{},
                              ),
                          onChanged: (val) {
                            setState(() {
                              selectedContratista = val?['id'].toString();
                            });
                          },
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: 'Contratista',
                              prefixIcon: Icon(Icons.apartment, color: theme.colorScheme.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                          ),
                          validator: (val) => val == null ? 'Seleccione un contratista' : null,
                          clearButtonProps: const ClearButtonProps(isVisible: true, icon: Icon(Icons.clear, size: 20)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (porcentajes.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No hay porcentajes disponibles.',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ] else ...[
                        DropdownSearch<Map<String, dynamic>>(
                          items: List<Map<String, dynamic>>.from(porcentajes),
                          itemAsString: (item) => '${(item['porcentaje'] * 100).toStringAsFixed(0)}%',
                          selectedItem: (porcentajes.isEmpty || selectedPorcentaje == null)
                            ? null
                            : porcentajes.firstWhere(
                                (e) => e['id'].toString() == selectedPorcentaje,
                                orElse: () => <String, dynamic>{},
                              ),
                          onChanged: (val) {
                            setState(() {
                              selectedPorcentaje = val?['id'].toString();
                            });
                          },
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: 'Porcentaje asignado',
                              prefixIcon: Icon(Icons.percent, color: theme.colorScheme.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                          ),
                          validator: (val) => val == null ? 'Seleccione un porcentaje' : null,
                          clearButtonProps: const ClearButtonProps(isVisible: true, icon: Icon(Icons.clear, size: 20)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedEstado,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          prefixIcon: Icon(Icons.toggle_on_outlined, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.05),
                        ),
                        items: estados.map((estado) {
                          return DropdownMenuItem<String>(
                            value: estado['id'].toString(),
                            child: Text(estado['nombre']),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedEstado = val),
                        validator: (value) => value == null ? 'Seleccione un estado' : null,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _guardando ? null : _guardarCambios,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _guardando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_outlined),
                                  SizedBox(width: 8),
                                  Text('Guardar Cambios'),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
