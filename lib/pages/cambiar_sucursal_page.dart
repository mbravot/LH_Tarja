import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CambiarSucursalPage extends StatefulWidget {
  @override
  _CambiarSucursalPageState createState() => _CambiarSucursalPageState();
}

class _CambiarSucursalPageState extends State<CambiarSucursalPage> {
  List<Map<String, dynamic>> _sucursales = [];
  String? _sucursalSeleccionada;
  bool _cargando = false;
  String? _mensajeError;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    if (_isRefreshing) {
      setState(() => _cargando = true);
    }
    
    try {
      final sucursales = await ApiService().getSucursales();
      final prefs = await SharedPreferences.getInstance();
      final sucursalActual = prefs.getString('id_sucursal');

      if (!mounted) return;

      setState(() {
        _sucursales = sucursales;
        _sucursalSeleccionada = sucursalActual;
        _mensajeError = null;
        _cargando = false;
      });
    } catch (e) {
      print("❌ Error al cargar sucursales: $e");
      if (!mounted) return;
      
      setState(() {
        _mensajeError = "No se pudieron cargar las sucursales.";
        _cargando = false;
      });
    }
  }

  Future<void> _guardarSucursal() async {
    if (_sucursalSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor selecciona una sucursal'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    try {
      final exito = await ApiService().actualizarSucursalActiva(_sucursalSeleccionada!);
      if (exito) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('id_sucursal', _sucursalSeleccionada!);

        final sucursal = _sucursales.firstWhere(
          (s) => s['id'].toString() == _sucursalSeleccionada.toString(),
          orElse: () => {'nombre': 'Sucursal desconocida'},
        );

        await prefs.setString('user_sucursal', sucursal['nombre']);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Sucursal cambiada exitosamente'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception("No se pudo cambiar la sucursal");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajeError = "Error al actualizar sucursal: ${e.toString()}";
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          "Cambiar Sucursal",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargando ? null : () {
              setState(() => _isRefreshing = true);
              _cargarSucursales();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          await _cargarSucursales();
          setState(() => _isRefreshing = false);
        },
        child: _cargando
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'Cargando sucursales...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                              'Selecciona una Sucursal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 16),
                            if (_sucursales.isEmpty && !_cargando)
                              Center(
                                child: Text(
                                  'No hay sucursales disponibles',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                value: _sucursalSeleccionada,
                                onChanged: (nuevoValor) {
                                  setState(() {
                                    _sucursalSeleccionada = nuevoValor;
                                  });
                                },
                                items: _sucursales
                                    .map((s) => DropdownMenuItem<String>(
                                          value: s['id'].toString(),
                                          child: Text(s['nombre']),
                                        ))
                                    .toList(),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                icon: Icon(Icons.business, color: Colors.green),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_mensajeError != null) ...[
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
                                  _mensajeError!,
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
                      onPressed: _cargando ? null : _guardarSucursal,
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
                                  "Guardar Cambios",
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
