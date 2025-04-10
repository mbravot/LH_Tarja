import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';

class EditarUsuarioPage extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const EditarUsuarioPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<EditarUsuarioPage> createState() => _EditarUsuarioPageState();
}

class _EditarUsuarioPageState extends State<EditarUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _claveController = TextEditingController();
  final Color primaryColor = Colors.green;

  String? selectedSucursal;
  String? selectedSucursalActiva;
  String? selectedRol;
  String? selectedEstado;

  bool _guardando = false;
  bool _ocultarClave = true;
  List<Map<String, dynamic>> _sucursales = [];
  List<Map<String, dynamic>> _roles = [
    {"id": 1, "nombre": "Administrador"},
    {"id": 2, "nombre": "Usuario"},
  ];
  List<Map<String, dynamic>> _estados = [
    {"id": 1, "nombre": "Activo"},
    {"id": 2, "nombre": "Inactivo"},
  ];

  @override
  void initState() {
    super.initState();
    _nombreController.text = widget.usuario['nombre'] ?? '';
    _correoController.text = widget.usuario['correo'] ?? '';
    selectedSucursal = widget.usuario['id_sucursal']?.toString();
    selectedSucursalActiva = widget.usuario['sucursal_activa']?.toString();
    selectedRol = widget.usuario['id_rol']?.toString();
    selectedEstado = widget.usuario['id_estado']?.toString();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    try {
      final data = await ApiService().getSucursales();
      if (mounted) {
        setState(() {
          _sucursales = List<Map<String, dynamic>>.from(data);
        });
      }
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

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final usuarioActualizado = {
        "nombre": _nombreController.text.trim(),
        "correo": _correoController.text.trim(),
        "clave": _claveController.text.isEmpty ? null : _claveController.text.trim(),
        "id_sucursal": selectedSucursal,
        "sucursal_activa": selectedSucursalActiva,
        "id_rol": int.tryParse(selectedRol ?? "2"),
        "id_estado": int.tryParse(selectedEstado ?? "1"),
      };

      final exito = await ApiService().editarUsuario(widget.usuario['id'], usuarioActualizado);

      if (exito) {
        if (mounted) Navigator.pop(context, true);
      } else {
        _mostrarError('Error al actualizar el usuario');
      }
    } catch (e) {
      _mostrarError('Error al actualizar el usuario: ${e.toString()}');
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
          "Editar Usuario",
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
                              Icon(Icons.edit_note, color: primaryColor),
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
                            controller: _nombreController,
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
                            controller: _correoController,
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
                            controller: _claveController,
                            obscureText: _ocultarClave,
                            decoration: InputDecoration(
                              labelText: 'Nueva Clave (opcional)',
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
                              if (value != null && value.isNotEmpty && value.length < 6) {
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
                            items: _sucursales.map((s) => s['nombre'] as String).toList(),
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
                                final sucursal = _sucursales.firstWhere(
                                  (s) => s['nombre'] == value,
                                  orElse: () => {'id': null},
                                );
                                setState(() => selectedSucursal = sucursal['id']?.toString());
                              }
                            },
                            selectedItem: selectedSucursal != null
                                ? _sucursales
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
                            items: _sucursales.map((s) => s['nombre'] as String).toList(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: "Sucursal Activa",
                                prefixIcon: Icon(Icons.location_on, color: primaryColor),
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
                                final sucursal = _sucursales.firstWhere(
                                  (s) => s['nombre'] == value,
                                  orElse: () => {'id': null},
                                );
                                setState(() => selectedSucursalActiva = sucursal['id']?.toString());
                              }
                            },
                            selectedItem: selectedSucursalActiva != null
                                ? _sucursales
                                    .firstWhere(
                                      (s) => s['id'].toString() == selectedSucursalActiva,
                                      orElse: () => {'nombre': ''},
                                    )['nombre']
                                : null,
                            validator: (value) =>
                                value == null ? 'Seleccione una sucursal activa' : null,
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
                            items: _roles.map((r) => r['nombre'] as String).toList(),
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
                                final rol = _roles.firstWhere(
                                  (r) => r['nombre'] == value,
                                  orElse: () => {'id': null},
                                );
                                setState(() => selectedRol = rol['id']?.toString());
                              }
                            },
                            selectedItem: selectedRol != null
                                ? _roles
                                    .firstWhere(
                                      (r) => r['id'].toString() == selectedRol,
                                      orElse: () => {'nombre': ''},
                                    )['nombre']
                                : null,
                            validator: (value) =>
                                value == null ? 'Seleccione un rol' : null,
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
                            items: _estados.map((e) => e['nombre'] as String).toList(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: "Estado",
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
                            ),
                            onChanged: (String? value) {
                              if (value != null) {
                                final estado = _estados.firstWhere(
                                  (e) => e['nombre'] == value,
                                  orElse: () => {'id': null},
                                );
                                setState(() => selectedEstado = estado['id']?.toString());
                              }
                            },
                            selectedItem: selectedEstado != null
                                ? _estados
                                    .firstWhere(
                                      (e) => e['id'].toString() == selectedEstado,
                                      orElse: () => {'nombre': ''},
                                    )['nombre']
                                : null,
                            validator: (value) =>
                                value == null ? 'Seleccione un estado' : null,
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
                      onPressed: _guardando ? null : _guardarCambios,
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
                                  'Guardar Cambios',
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
