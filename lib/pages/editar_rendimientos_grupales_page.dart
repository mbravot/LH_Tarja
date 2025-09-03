import 'package:flutter/material.dart';
import 'package:app_lh_tarja/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

class EditarRendimientosGrupalesPage extends StatefulWidget {
  final Map<String, dynamic> rendimiento;

  const EditarRendimientosGrupalesPage({Key? key, required this.rendimiento}) : super(key: key);

  @override
  _EditarRendimientosGrupalesPageState createState() => _EditarRendimientosGrupalesPageState();
}

class _EditarRendimientosGrupalesPageState extends State<EditarRendimientosGrupalesPage> {
  final _formKey = GlobalKey<FormState>();
  final _rendimientoController = TextEditingController();
  final _cantidadTrabController = TextEditingController();
  final _rendimientoTotalController = TextEditingController();
  bool _isLoading = false;
  String _error = '';
  List<Map<String, dynamic>> porcentajes = [];
  int? selectedPorcentaje;

  @override
  void initState() {
    super.initState();
    _cargarPorcentajes();
  }

  Future<void> _cargarPorcentajes() async {
    try {
      final listaPorcentajes = await ApiService().getPorcentajesContratista();
      setState(() {
        porcentajes = List<Map<String, dynamic>>.from(listaPorcentajes);
      });
      _inicializarControllers();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar porcentajes: $e';
      });
    }
  }

  void _inicializarControllers() {
    if (widget.rendimiento['id_actividad'] != null) {
      _rendimientoTotalController.text = widget.rendimiento['rendimiento_total']?.toString() ?? '';
      _cantidadTrabController.text = widget.rendimiento['cantidad_trab']?.toString() ?? '';
      final idPorcentaje = widget.rendimiento['id_porcentaje'];
      if (idPorcentaje != null && porcentajes.isNotEmpty) {
        final porcentajeEncontrado = porcentajes.firstWhereOrNull(
          (p) => p['id'].toString() == idPorcentaje.toString()
        );
        if (porcentajeEncontrado != null) {
          selectedPorcentaje = porcentajeEncontrado['id'];
        } else {
          selectedPorcentaje = null;
        }
      }
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Actualizar rendimiento grupal
      final Map<String, dynamic> rendimiento = {
        'id_actividad': widget.rendimiento['id_actividad'],
        'rendimiento_total': double.parse(_rendimientoTotalController.text),
        'cantidad_trab': int.parse(_cantidadTrabController.text),
        'id_porcentaje': selectedPorcentaje,
      };
      
      await ApiService().actualizarRendimientoGrupal(
        widget.rendimiento['id'],
        rendimiento,
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = 'Error al guardar cambios: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Rendimiento Grupal'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _rendimientoTotalController,
                      textInputAction: TextInputAction.done,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        labelText: 'Rendimiento total',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed, color: Colors.green),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese el rendimiento total';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Ingrese un número válido';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _cantidadTrabController,
                      textInputAction: TextInputAction.done,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        labelText: 'Cantidad de trabajadores',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.groups, color: Colors.green),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese la cantidad de trabajadores';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Ingrese un número entero válido';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedPorcentaje,
                      items: porcentajes.map((p) {
                        final valor = (p['porcentaje'] * 100).toStringAsFixed(0);
                        return DropdownMenuItem<int>(
                          value: p['id'],
                          child: Row(
                            children: [
                              Icon(Icons.percent, color: Colors.green, size: 18),
                              SizedBox(width: 6),
                              Text(valor),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedPorcentaje = val),
                      decoration: InputDecoration(
                        labelText: 'Porcentaje de contratista',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.percent, color: Colors.green),
                      ),
                      validator: (value) => value == null ? 'Campo requerido' : null,
                    ),
                    SizedBox(height: 24),
                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_error, style: TextStyle(color: Colors.red)),
                      ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Guardar Cambios'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 