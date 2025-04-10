import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CambiarClavePage extends StatefulWidget {
  @override
  _CambiarClavePageState createState() => _CambiarClavePageState();
}

class _CambiarClavePageState extends State<CambiarClavePage> {
  final TextEditingController _claveActualController = TextEditingController();
  final TextEditingController _nuevaClaveController = TextEditingController();
  final TextEditingController _confirmarClaveController = TextEditingController();
  bool _cargando = false;
  String? _errorMensaje;
  bool _mostrarClaveActual = false;
  bool _mostrarNuevaClave = false;
  bool _mostrarConfirmarClave = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _claveActualController.dispose();
    _nuevaClaveController.dispose();
    _confirmarClaveController.dispose();
    super.dispose();
  }

  String? _validarClave(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es requerido';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  void _cambiarClave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMensaje = null;
      _cargando = true;
    });

    try {
      String claveActual = _claveActualController.text;
      String nuevaClave = _nuevaClaveController.text;
      String confirmarClave = _confirmarClaveController.text;

      if (nuevaClave != confirmarClave) {
        setState(() {
          _errorMensaje = "Las nuevas contraseñas no coinciden";
          _cargando = false;
        });
        return;
      }

      var respuesta = await ApiService().cambiarClave(claveActual, nuevaClave);

      if (respuesta["error"] != null) {
        setState(() {
          _errorMensaje = respuesta["error"];
          _cargando = false;
        });
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text("Contraseña cambiada con éxito"),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMensaje = "Error al cambiar la contraseña: ${e.toString()}";
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          "Cambiar Contraseña",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ingresa tus Contraseñas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _claveActualController,
                          obscureText: !_mostrarClaveActual,
                          validator: _validarClave,
                          decoration: InputDecoration(
                            labelText: "Contraseña actual",
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.green),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _mostrarClaveActual ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _mostrarClaveActual = !_mostrarClaveActual;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _nuevaClaveController,
                          obscureText: !_mostrarNuevaClave,
                          validator: _validarClave,
                          decoration: InputDecoration(
                            labelText: "Nueva contraseña",
                            prefixIcon: Icon(Icons.lock, color: Colors.green),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _mostrarNuevaClave ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _mostrarNuevaClave = !_mostrarNuevaClave;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmarClaveController,
                          obscureText: !_mostrarConfirmarClave,
                          validator: _validarClave,
                          decoration: InputDecoration(
                            labelText: "Confirmar nueva contraseña",
                            prefixIcon: Icon(Icons.lock_clock, color: Colors.green),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _mostrarConfirmarClave ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _mostrarConfirmarClave = !_mostrarConfirmarClave;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMensaje != null) ...[
                  SizedBox(height: 16),
                  Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMensaje!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _cargando ? null : _cambiarClave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _cargando
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Cambiar Contraseña",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
