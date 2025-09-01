import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:app_lh_tarja/utils/colors.dart';
import 'package:app_lh_tarja/pages/trabajadores_page.dart';

// Sistema de logging condicional
void logInfo(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("ℹ️ $message");
  }
}

void logError(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("❌ $message");
  }
}

class NuevoTrabajadorPage extends StatefulWidget {
  @override
  _NuevoTrabajadorPageState createState() => _NuevoTrabajadorPageState();
}

class _NuevoTrabajadorPageState extends State<NuevoTrabajadorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _dvController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoPController = TextEditingController();
  final TextEditingController _apellidoMController = TextEditingController();
  final Color primaryColor = Colors.green;

  List<dynamic> _tiposTrabajador = [];
  List<dynamic> _contratistas = [];
  List<dynamic> _porcentajes = [];

  String? _tipoSeleccionado;
  String? _contratistaSeleccionado;
  String? _porcentajeSeleccionado;
  int _estadoSeleccionado = 1;

  bool _guardando = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _rutController.addListener(_calcularDV);
  }

  void _calcularDV() {
    String rut = _rutController.text.replaceAll('.', '').replaceAll('-', '');
    if (rut.isEmpty || int.tryParse(rut) == null) {
      _dvController.text = '';
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
    _dvController.text = dv;
  }

  Future<void> _cargarDatos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idSucursal = prefs.getString('id_sucursal');
      if (idSucursal == null) throw Exception('No se encontró la sucursal activa');
      final contratistas = await ApiService().getContratistas(idSucursal);
      final porcentajes = await ApiService().getPorcentajesContratista();
      setState(() {
        _contratistas = contratistas;
        _porcentajes = porcentajes;
        _cargando = false;
      });
    } catch (e) {
      logError("❌ Error al cargar datos: $e");
      setState(() { _cargando = false; });
    }
  }

  Future<void> _guardarTrabajador() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final idSucursal = prefs.getString('id_sucursal');

    final String nombre = _nombreController.text.trim();
    final String apellidoPaterno = _apellidoPController.text.trim();
    final String apellidoMaterno = _apellidoMController.text.trim();
    final String nomAp = "$nombre $apellidoPaterno $apellidoMaterno";

    final data = {
      "rut": _rutController.text.trim().isEmpty ? null : int.parse(_rutController.text.trim()),
      "codigo_verificador": _dvController.text.trim().isEmpty ? null : _dvController.text.trim(),
      "nombre": nombre,
      "apellido_paterno": apellidoPaterno,
      "apellido_materno": apellidoMaterno,
      "nom_ap": nomAp,
      "id_contratista": _contratistaSeleccionado ?? '',
      "id_sucursal": int.parse(idSucursal!),
      "id_estado": _estadoSeleccionado,
      "id_porcentaje": int.tryParse(_porcentajeSeleccionado ?? '') ?? 0,
    };

    setState(() => _guardando = true);

    final exito = await ApiService().crearTrabajador(data);

    setState(() => _guardando = false);

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Trabajador creado exitosamente'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al crear trabajador'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Nuevo Trabajador",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // --- Asignación segura de valores seleccionados ---
    if (_contratistas.isNotEmpty && (_contratistaSeleccionado == null || !_contratistas.any((c) => c['id'].toString() == _contratistaSeleccionado))) {
      _contratistaSeleccionado = _contratistas.first['id'].toString();
    }
    if (_porcentajes.isNotEmpty && (_porcentajeSeleccionado == null || !_porcentajes.any((p) => p['id'].toString() == _porcentajeSeleccionado))) {
      _porcentajeSeleccionado = _porcentajes.first['id'].toString();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Nuevo Trabajador",
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
                              Icon(Icons.person_add_alt_1_outlined, color: primaryColor),
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
                                  controller: _rutController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(8),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'RUT',
                                    prefixIcon: Icon(Icons.badge_outlined, color: primaryColor),
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
                                  controller: _dvController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'DV',
                                    prefixIcon: Icon(Icons.verified_user_outlined, color: primaryColor),
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
                                  maxLength: 1,
                                  validator: (value) {
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nombreController,
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
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Ingrese el nombre' : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _apellidoPController,
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
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Ingrese el apellido paterno' : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _apellidoMController,
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
                          SizedBox(height: 16),
                          if (_contratistas.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'No hay contratistas disponibles para la sucursal y tipo seleccionados.',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ] else ...[
                            DropdownSearch<Map<String, dynamic>>(
                              items: List<Map<String, dynamic>>.from(_contratistas),
                              itemAsString: (item) => item['nombre'],
                              selectedItem: (_contratistas.isEmpty || _contratistaSeleccionado == null)
                                ? null
                                : _contratistas.firstWhere(
                                    (e) => e['id'].toString() == _contratistaSeleccionado,
                                    orElse: () => <String, dynamic>{},
                                  ),
                              onChanged: (val) {
                                setState(() {
                                  _contratistaSeleccionado = val?['id'].toString();
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
                          if (_porcentajes.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'No hay porcentajes disponibles.',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ] else ...[
                            DropdownSearch<Map<String, dynamic>>(
                              items: List<Map<String, dynamic>>.from(_porcentajes),
                              itemAsString: (item) => '${(item['porcentaje'] * 100).toStringAsFixed(0)}%',
                              selectedItem: (_porcentajes.isEmpty || _porcentajeSeleccionado == null)
                                ? null
                                : _porcentajes.firstWhere(
                                    (e) => e['id'].toString() == _porcentajeSeleccionado,
                                    orElse: () => <String, dynamic>{},
                                  ),
                              onChanged: (val) {
                                setState(() {
                                  _porcentajeSeleccionado = val?['id'].toString();
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
                      DropdownButtonFormField<int>(
                        value: _estadoSeleccionado,
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
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Activo')),
                          DropdownMenuItem(value: 2, child: Text('Inactivo')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _estadoSeleccionado = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _guardando ? null : _guardarTrabajador,
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
                                  Text('Guardar'),
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
