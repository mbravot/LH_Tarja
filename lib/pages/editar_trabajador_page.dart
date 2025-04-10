import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
  final TextEditingController apellidoController = TextEditingController();
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
  }

  Future<void> _cargarDatosIniciales() async {
    if (widget.trabajador != null) {
      rutController.text = widget.trabajador['rut'] ?? '';
      nombreController.text = widget.trabajador['nombre'] ?? '';
      apellidoController.text = widget.trabajador['apellido'] ?? '';
      selectedContratista = widget.trabajador['id_contratista']?.toString();
      selectedPorcentaje = widget.trabajador['id_porcentaje']?.toString();
      selectedEstado = widget.trabajador['id_estado']?.toString();
    }

    contratistas = await ApiService().getContratistasPorSucursal();
    porcentajes = await ApiService().getPorcentajes();

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
      final String apellido = apellidoController.text.trim();
      final String nomAp = "$nombre $apellido";

      Map<String, dynamic> data = {
        "rut": rutController.text.trim(),
        "nombre": nombre,
        "apellido": apellido,
        "nom_ap": nomAp,
        "id_contratista": selectedContratista,
        "id_porcentaje": int.parse(selectedPorcentaje!),
        "id_estado": int.parse(selectedEstado!),
      };

      bool success =
          await ApiService().editarTrabajador(widget.trabajador['id'], data);

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

  @override
  Widget build(BuildContext context) {
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      TextFormField(
                        controller: rutController,
                        decoration: InputDecoration(
                          labelText: 'RUT',
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingrese el RUT';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nombreController,
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingrese el nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: apellidoController,
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingrese el apellido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedContratista,
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
                        items: contratistas.map((item) {
                          return DropdownMenuItem<String>(
                            value: item['id'].toString(),
                            child: Text(item['nombre']),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedContratista = val),
                        validator: (value) => value == null ? 'Seleccione un contratista' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedPorcentaje,
                        decoration: InputDecoration(
                          labelText: 'Porcentaje',
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
                        items: porcentajes.map((item) {
                          return DropdownMenuItem<String>(
                            value: item['id'].toString(),
                            child: Text('${item['porcentaje']}%'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedPorcentaje = val),
                        validator: (value) => value == null ? 'Seleccione un porcentaje' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedEstado,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          prefixIcon: Icon(Icons.toggle_on_outlined, color: primaryColor),
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
                        items: estados.map((item) {
                          return DropdownMenuItem<String>(
                            value: item['id'].toString(),
                            child: Text(item['nombre']),
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
                                children: const [
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
