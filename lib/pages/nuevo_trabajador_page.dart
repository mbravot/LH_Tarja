import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class NuevoTrabajadorPage extends StatefulWidget {
  @override
  _NuevoTrabajadorPageState createState() => _NuevoTrabajadorPageState();
}

class _NuevoTrabajadorPageState extends State<NuevoTrabajadorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final Color primaryColor = Colors.green;

  List<dynamic> _tiposTrabajador = [];
  List<dynamic> _contratistas = [];
  List<dynamic> _porcentajes = [];

  String? _tipoSeleccionado;
  String? _contratistaSeleccionado;
  String? _porcentajeSeleccionado;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final tipos = await ApiService().getTipoTrabajadores();
      final porcentajes = await ApiService().getPorcentajes();
      setState(() {
        _tiposTrabajador = tipos;
        _porcentajes = porcentajes;
      });
    } catch (e) {
      print("❌ Error al cargar datos: $e");
    }
  }

  Future<void> _cargarContratistas() async {
    if (_tipoSeleccionado == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final idSucursal = prefs.getString('id_sucursal');
      if (idSucursal == null) return;

      final contratistasFiltrados =
          await ApiService().getContratistas(idSucursal, _tipoSeleccionado!);
      setState(() {
        _contratistas = contratistasFiltrados;
        if (_tipoSeleccionado == "1" && contratistasFiltrados.length == 1) {
          _contratistaSeleccionado = contratistasFiltrados.first['id'];
          _porcentajeSeleccionado = "1"; // propio => 100%
        } else {
          _contratistaSeleccionado = null;
          _porcentajeSeleccionado = null;
        }
      });
    } catch (e) {
      print("❌ Error al cargar contratistas: $e");
    }
  }

  Future<void> _guardarTrabajador() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final idSucursal = prefs.getString('id_sucursal');

    final String nombre = _nombreController.text.trim();
    final String apellido = _apellidoController.text.trim();
    final String nomAp = "$nombre $apellido";

    final data = {
      "rut": _rutController.text.trim(),
      "nombre": nombre,
      "apellido": apellido,
      "nom_ap": nomAp,
      "id_tipo_trab": int.parse(_tipoSeleccionado!),
      "id_contratista": _contratistaSeleccionado,
      "id_sucursal": int.parse(idSucursal!),
      "id_estado": 1,
      "id_porcentaje": int.parse(_porcentajeSeleccionado!),
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
                          TextFormField(
                            controller: _rutController,
                            decoration: InputDecoration(
                              labelText: 'RUT (EJ: 12345678-k)',
                              prefixIcon: Icon(Icons.badge_outlined, color: primaryColor),
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
                                value?.isEmpty ?? true ? 'Ingrese el RUT' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nombreController,
                            decoration: InputDecoration(
                              labelText: 'Nombre',
                              prefixIcon: Icon(Icons.person_outline, color: primaryColor),
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
                            controller: _apellidoController,
                            decoration: InputDecoration(
                              labelText: 'Apellido',
                              prefixIcon: Icon(Icons.person_outline, color: primaryColor),
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
                                value?.isEmpty ?? true ? 'Ingrese el apellido' : null,
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _tipoSeleccionado,
                            items: _tiposTrabajador
                                .map<DropdownMenuItem<String>>((tipo) {
                              return DropdownMenuItem(
                                value: tipo['id'].toString(),
                                child: Text(tipo['desc_tipo']),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Tipo de Trabajador',
                              prefixIcon: Icon(Icons.work_outline, color: primaryColor),
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
                            onChanged: (value) {
                              setState(() {
                                _tipoSeleccionado = value;
                                _cargarContratistas();
                              });
                            },
                            validator: (value) => value == null
                                ? 'Seleccione un tipo de trabajador'
                                : null,
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _contratistaSeleccionado,
                            items: _contratistas
                                .map<DropdownMenuItem<String>>((contratista) {
                              return DropdownMenuItem(
                                value: contratista['id'],
                                child: Text(contratista['nombre']),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Contratista',
                              prefixIcon: Icon(Icons.business_outlined, color: primaryColor),
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
                            onChanged: _tipoSeleccionado == "1"
                            ? null
                            : (value) => setState(
                                () => _contratistaSeleccionado = value),
                        validator: _tipoSeleccionado == "1"
                            ? null
                            : (value) => value == null
                                ? 'Seleccione un contratista'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _porcentajeSeleccionado,
                        items: (_tipoSeleccionado == "1"
                                ? _porcentajes.where((p) => p['porcentaje'] == 1.0)
                                : _porcentajes.where((p) => p['porcentaje'] != 1.0))
                            .map<DropdownMenuItem<String>>((porc) => DropdownMenuItem(
                                  value: porc['id'].toString(),
                                  child: Text('${porc['porcentaje']}%'),
                                ))
                            .toList(),
                        decoration: InputDecoration(
                          labelText: 'Porcentaje asignado',
                          prefixIcon: Icon(Icons.percent_outlined, color: primaryColor),
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
                        onChanged: _tipoSeleccionado == "1"
                            ? null
                            : (value) => setState(() => _porcentajeSeleccionado = value),
                        validator: _tipoSeleccionado == "1"
                            ? null
                            : (value) => value == null ? 'Seleccione un porcentaje' : null,
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
