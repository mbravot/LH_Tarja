import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EditarContratistaPage extends StatefulWidget {
  final dynamic contratista;

  EditarContratistaPage({required this.contratista});

  @override
  _EditarContratistaPageState createState() => _EditarContratistaPageState();
}

class _EditarContratistaPageState extends State<EditarContratistaPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController rutController = TextEditingController();
  final Color primaryColor = Colors.green;
  
  bool _guardando = false;
  int estadoSeleccionado = 1;

  final List<Map<String, dynamic>> _estados = [
    {"id": 1, "nombre": "Activo"},
    {"id": 2, "nombre": "Inactivo"},
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.contratista;
    if (c != null) {
      nombreController.text = c['nombre'] ?? '';
      rutController.text = c['rut'] ?? '';
      estadoSeleccionado = c['id_estado'] ?? 1;
    }
  }

  void _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final data = {
        "nombre": nombreController.text.trim(),
        "rut": rutController.text.trim(),
        "id_estado": estadoSeleccionado
      };

      final success =
          await ApiService().editarContratista(widget.contratista['id'], data);

      if (success) {
        Navigator.pop(context, true);
      } else {
        _mostrarError("Error al guardar los datos.");
      }
    } catch (e) {
      _mostrarError("Error al actualizar el contratista: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Editar Contratista",
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
                          Icon(Icons.business, color: primaryColor),
                          const SizedBox(width: 10),
                          Text(
                            "Datos del Contratista",
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
                        controller: nombreController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingrese el nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
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
                      DropdownButtonFormField<int>(
                        value: estadoSeleccionado,
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
                        items: _estados.map((estado) {
                          return DropdownMenuItem<int>(
                            value: estado['id'] as int,
                            child: Text(estado['nombre'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              estadoSeleccionado = value;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Seleccione un estado';
                          }
                          return null;
                        },
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
