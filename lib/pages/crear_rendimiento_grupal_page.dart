import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:collection/collection.dart';

class CrearRendimientoGrupalPage extends StatefulWidget {
  final Map<String, dynamic> actividad;

  const CrearRendimientoGrupalPage({Key? key, required this.actividad}) : super(key: key);

  @override
  _CrearRendimientoGrupalPageState createState() => _CrearRendimientoGrupalPageState();
}

class _CrearRendimientoGrupalPageState extends State<CrearRendimientoGrupalPage> {
  final _formKey = GlobalKey<FormState>();
  final _rendimientoTotalController = TextEditingController();
  final _cantidadTrabController = TextEditingController();
  int? selectedPorcentaje;
  List<Map<String, dynamic>> porcentajes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarPorcentajes();
  }

  Future<void> _cargarPorcentajes() async {
    setState(() => _isLoading = true);
    try {
      final listaPorcentajes = await ApiService().getPorcentajesContratista();
      setState(() {
        porcentajes = List<Map<String, dynamic>>.from(listaPorcentajes);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar porcentajes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarRendimiento() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final rendimiento = {
        'id_actividad': widget.actividad['id'].toString(),
        'rendimiento_total': double.parse(_rendimientoTotalController.text),
        'cantidad_trab': int.parse(_cantidadTrabController.text),
        'id_porcentaje': selectedPorcentaje,
      };
      await ApiService().crearRendimientoGrupal(rendimiento);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _rendimientoTotalController.dispose();
    _cantidadTrabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crear Rendimiento Grupal'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
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
                    ElevatedButton(
                      onPressed: _isLoading ? null : _guardarRendimiento,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
