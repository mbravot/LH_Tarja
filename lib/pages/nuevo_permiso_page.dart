import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NuevoPermisoPage extends StatefulWidget {
  @override
  _NuevoPermisoPageState createState() => _NuevoPermisoPageState();
}

class _NuevoPermisoPageState extends State<NuevoPermisoPage> {
  final _formKey = GlobalKey<FormState>();
  final _fechaController = TextEditingController();
  final _fechaVisibleController = TextEditingController();
  final _horasController = TextEditingController();
  String? _tipoPermisoId;
  String? _colaboradorId;
  List<Map<String, dynamic>> tiposPermiso = [];
  List<Map<String, dynamic>> colaboradores = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _fechaController.text = hoy.toIso8601String().substring(0, 10);
    _fechaVisibleController.text = '${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}';
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final tipos = await ApiService().getTiposPermiso();
      final colabs = await ApiService().getColaboradores();
      setState(() {
        tiposPermiso = tipos;
        colaboradores = colabs;
      });
    } catch (e) {
      _mostrarError('Error al cargar datos: ${e.toString()}');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  Future<void> _guardarPermiso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final permiso = {
        'fecha': _fechaController.text,
        'id_tipopermiso': _tipoPermisoId,
        'id_colaborador': _colaboradorId,
        'horas': int.parse(_horasController.text),
        'id_estadopermiso': 1
      };

      await ApiService().crearPermiso(permiso);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Error al guardar el permiso: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: const Text("Nuevo Permiso", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment_turned_in, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          "Datos del Permiso",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event, color: theme.colorScheme.primary),
                      title: TextFormField(
                        controller: _fechaVisibleController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Fecha',
                          border: InputBorder.none,
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            _fechaController.text = picked.toIso8601String().substring(0, 10);
                            _fechaVisibleController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                          }
                        },
                      ),
                      trailing: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tipoPermisoId,
                      items: tiposPermiso.map((tipo) {
                        return DropdownMenuItem<String>(
                          value: tipo['id'].toString(),
                          child: Text(tipo['nombre']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _tipoPermisoId = val),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Permiso',
                        prefixIcon: Icon(Icons.category, color: theme.colorScheme.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.05),
                      ),
                      validator: (val) => val == null ? 'Seleccione un tipo' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _colaboradorId,
                      items: colaboradores.map((colab) {
                        final nombre = (colab['nombre'] ?? '') + ' ' + (colab['apellido_paterno'] ?? '') + ' ' + (colab['apellido_materno'] ?? '');
                        return DropdownMenuItem<String>(
                          value: colab['id'].toString(),
                          child: Text(nombre.trim()),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _colaboradorId = val),
                      decoration: InputDecoration(
                        labelText: 'Colaborador',
                        prefixIcon: Icon(Icons.person, color: theme.colorScheme.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.05),
                      ),
                      validator: (val) => val == null ? 'Seleccione un colaborador' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _horasController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Horas',
                        prefixIcon: Icon(Icons.timer, color: theme.colorScheme.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.05),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Ingrese las horas' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(Icons.save),
                      label: Text(_isLoading ? 'Guardando...' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _guardarPermiso,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
