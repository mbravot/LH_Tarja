import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';

class NuevoUsuarioPage extends StatefulWidget {
  @override
  _NuevoUsuarioPageState createState() => _NuevoUsuarioPageState();
}

class _NuevoUsuarioPageState extends State<NuevoUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final claveController = TextEditingController();
  final Color primaryColor = Colors.green;

  List<Map<String, dynamic>> sucursales = [];
  List<Map<String, dynamic>> roles = [
    {'id': 1, 'nombre': 'Administrador'},
    {'id': 2, 'nombre': 'Usuario'}
  ];

  String? selectedSucursal;
  String? selectedRol;
  bool _guardando = false;
  bool _ocultarClave = true;

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    try {
      final lista = await ApiService().getSucursales();
      setState(() => sucursales = List<Map<String, dynamic>>.from(lista));
    } catch (e) {
      _mostrarError('Error al cargar sucursales: ${e.toString()}');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _guardarUsuario() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _guardando = true);

    try {
      final exito = await ApiService().crearUsuario(
        nombre: nombreController.text.trim(),
        correo: correoController.text.trim(),
        clave: claveController.text,
        idSucursal: int.parse(selectedSucursal!),
        idRol: int.parse(selectedRol!),
      );

      if (exito) {
        Navigator.pop(context, true);
      } else {
        _mostrarError('Error al crear el usuario');
      }
    } catch (e) {
      _mostrarError('Error al crear el usuario: ${e.toString()}');
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
        title: Text(
          "Nuevo Usuario",
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
                              Icon(Icons.person_add, color: primaryColor),
                              SizedBox(width: 10),
                              Text(
                                "Datos del Usuario",
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
                          SizedBox(height: 16),
                          TextFormField(
                            controller: correoController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
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
                              if (value?.trim().isEmpty ?? true) {
                                return 'Ingrese el correo';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                                return 'Ingrese un correo válido';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: claveController,
                            obscureText: _ocultarClave,
                            decoration: InputDecoration(
                              labelText: 'Clave',
                              prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultarClave ? Icons.visibility : Icons.visibility_off,
                                  color: primaryColor,
                                ),
                                onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                              ),
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
                              if (value?.isEmpty ?? true) {
                                return 'Ingrese la clave';
                              }
                              if (value!.length < 6) {
                                return 'La clave debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          DropdownSearch<String>(
                            popupProps: PopupProps.menu(
                              fit: FlexFit.loose,
                              menuProps: MenuProps(
                                backgroundColor: Colors.white,
                                elevation: 2,
                              ),
                              showSelectedItems: true,
                            ),
                            items: sucursales.map((s) => s['nombre'] as String).toList(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: "Sucursal",
                                prefixIcon: Icon(Icons.business, color: primaryColor),
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
                            ),
                            onChanged: (String? value) {
                              if (value != null) {
                                final sucursal = sucursales.firstWhere(
                                  (s) => s['nombre'] == value,
                                  orElse: () => {'id': null},
                                );
                                setState(() => selectedSucursal = sucursal['id']?.toString());
                              }
                            },
                            selectedItem: selectedSucursal != null
                                ? sucursales
                                    .firstWhere(
                                      (s) => s['id'].toString() == selectedSucursal,
                                      orElse: () => {'nombre': ''},
                                    )['nombre']
                                : null,
                            validator: (value) =>
                                value == null ? 'Seleccione una sucursal' : null,
                          ),
                          SizedBox(height: 20),
                          DropdownSearch<String>(
                            popupProps: PopupProps.menu(
                              fit: FlexFit.loose,
                              menuProps: MenuProps(
                                backgroundColor: Colors.white,
                                elevation: 2,
                              ),
                              showSelectedItems: true,
                            ),
                            items: roles.map((r) => r['nombre'] as String).toList(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: "Rol",
                                prefixIcon: Icon(Icons.admin_panel_settings, color: primaryColor),
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
                            ),
                            onChanged: (String? value) {
                              if (value != null) {
                                final rol = roles.firstWhere(
                                  (r) => r['nombre'] == value,
                                  orElse: () => {'id': null},
                                );
                                setState(() => selectedRol = rol['id']?.toString());
                              }
                            },
                            selectedItem: selectedRol != null
                                ? roles
                                    .firstWhere(
                                      (r) => r['id'].toString() == selectedRol,
                                      orElse: () => {'nombre': ''},
                                    )['nombre']
                                : null,
                            validator: (value) =>
                                value == null ? 'Seleccione un rol' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 26),
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          primaryColor.withGreen(150),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardarUsuario,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _guardando
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save),
                                SizedBox(width: 8),
                                Text(
                                  'Crear Usuario',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
