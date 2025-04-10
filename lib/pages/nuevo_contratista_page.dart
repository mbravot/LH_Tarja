import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NuevoContratistaPage extends StatefulWidget {
  @override
  _NuevoContratistaPageState createState() => _NuevoContratistaPageState();
}

class _NuevoContratistaPageState extends State<NuevoContratistaPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final Color primaryColor = Colors.green;

  bool _guardando = false;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      "rut": _rutController.text.trim(),
      "nombre": _nombreController.text.trim(),
    };

    setState(() {
      _guardando = true;
    });

    final exito = await ApiService().crearContratista(data);

    setState(() {
      _guardando = false;
    });

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contratista creado exitosamente')),
      );
      Navigator.pop(context, true); // ⬅️ Volver indicando que se actualice
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear contratista')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Nuevo Contratista",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
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
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
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
                              SizedBox(width: 10),
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
                          SizedBox(height: 20),
                          TextFormField(
                            controller: _rutController,
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
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Ingrese el RUT' : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _nombreController,
                            decoration: InputDecoration(
                              labelText: 'Nombre',
                              prefixIcon: Icon(Icons.business_center_outlined, color: primaryColor),
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
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
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
                        ? SizedBox(
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
    );
  }
}
