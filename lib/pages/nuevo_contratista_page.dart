import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class NuevoContratistaPage extends StatefulWidget {
  const NuevoContratistaPage({super.key});

  @override
  State<NuevoContratistaPage> createState() => _NuevoContratistaPageState();
}

class _NuevoContratistaPageState extends State<NuevoContratistaPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  bool _isLoading = false;

  final _nombreController = TextEditingController();
  final _rutController = TextEditingController();
  final _codigoVerificadorController = TextEditingController();
  int _estadoSeleccionado = 1;

  final List<Map<String, dynamic>> _estados = [
    {"id": 1, "nombre": "Activo"},
    {"id": 2, "nombre": "Inactivo"},
  ];

  void _calcularDV() {
    String rut = _rutController.text.replaceAll('.', '').replaceAll('-', '');
    if (rut.isEmpty || int.tryParse(rut) == null) {
      _codigoVerificadorController.text = '';
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
    _codigoVerificadorController.text = dv;
  }

  @override
  void initState() {
    super.initState();
    _rutController.addListener(_calcularDV);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _codigoVerificadorController.dispose();
    super.dispose();
  }

  Future<void> _guardarContratista() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final contratistaData = {
        'nombre': _nombreController.text,
        'rut': int.parse(_rutController.text),
        'codigo_verificador': _codigoVerificadorController.text,
        'id_estado': _estadoSeleccionado,
      };

      await _apiService.createContratista(contratistaData);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contratista creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear el contratista: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Contratista', style: TextStyle(color: Colors.white)),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSection(
                      'Datos del Contratista',
                      Icons.business,
                      [
                        TextFormField(
                          controller: _nombreController,
                          decoration: InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: Icon(Icons.person, color: theme.colorScheme.primary),
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese el nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _rutController,
                                decoration: InputDecoration(
                                  labelText: 'RUT',
                                  prefixIcon: Icon(Icons.badge, color: theme.colorScheme.primary),
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
                                keyboardType: TextInputType.number,
                                maxLength: 8,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor ingrese el RUT';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'El RUT debe ser un número';
                                  }
                                  if (value.length > 8) {
                                    return 'El RUT debe tener máximo 8 dígitos';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: _codigoVerificadorController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'DV',
                                  prefixIcon: Icon(Icons.verified_user, color: theme.colorScheme.primary),
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
                                maxLength: 1,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingrese un RUT válido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _estadoSeleccionado,
                          decoration: InputDecoration(
                            labelText: 'Estado',
                            prefixIcon: Icon(Icons.toggle_on, color: theme.colorScheme.primary),
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
                          items: _estados.map((estado) {
                            return DropdownMenuItem<int>(
                              value: estado['id'] as int,
                              child: Text(estado['nombre'] as String),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _estadoSeleccionado = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _guardarContratista,
                            icon: const Icon(Icons.save),
                            label: const Text('Guardar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
