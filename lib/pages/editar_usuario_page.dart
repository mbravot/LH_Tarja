import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../theme/app_theme.dart' show primaryColor;

class EditarUsuarioPage extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const EditarUsuarioPage({Key? key, required this.usuario}) : super(key: key);

  @override
  State<EditarUsuarioPage> createState() => _EditarUsuarioPageState();
}

class _EditarUsuarioPageState extends State<EditarUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _correoController = TextEditingController();
  final _claveController = TextEditingController();

  List<Map<String, dynamic>> sucursales = [];
  List<Map<String, dynamic>> colaboradores = [];
  
  String? selectedSucursal;
  String? selectedColaborador;
  String? selectedEstado;
  List<int> sucursalesPermitidasSeleccionadas = [];
  List<Map<String, dynamic>> aplicaciones = [];
  List<int> aplicacionesPermitidasSeleccionadas = [];
  
  bool _guardando = false;
  bool _ocultarClave = true;
  bool _mostrarSelectorColaborador = false;

  @override
  void initState() {
    super.initState();
    _usuarioController.text = widget.usuario['usuario'] ?? '';
    _correoController.text = widget.usuario['correo'] ?? '';
    selectedSucursal = widget.usuario['id_sucursalactiva']?.toString();
    selectedColaborador = widget.usuario['id_colaborador']?.toString();
    selectedEstado = widget.usuario['id_estado']?.toString() ?? '1';
    _mostrarSelectorColaborador = selectedColaborador != null;
    _cargarSucursales();
    _cargarColaboradores();
    _cargarSucursalesPermitidas();
    _cargarAplicaciones();
    _cargarAplicacionesPermitidas();
  }

  Future<void> _cargarSucursales() async {
    try {
      final lista = await ApiService().getSucursalesUsuarios();
      if (mounted) {
        setState(() => sucursales = lista);
      }
    } catch (e) {
      _mostrarError('Error al cargar sucursales: ${e.toString()}');
    }
  }

  Future<void> _cargarColaboradores() async {
    try {
      final lista = await ApiService().getColaboradores();
      if (mounted) {
        setState(() => colaboradores = List<Map<String, dynamic>>.from(lista));
      }
    } catch (e) {
      _mostrarError('Error al cargar colaboradores: ${e.toString()}');
    }
  }

  Future<void> _cargarSucursalesPermitidas() async {
    try {
      final lista = await ApiService().getSucursalesPermitidasUsuario(widget.usuario['id'].toString());
      if (mounted) {
        setState(() {
          sucursalesPermitidasSeleccionadas = lista.map((s) => s['id'] as int).toList();
        });
      }
    } catch (e) {
      // Si hay error, simplemente no cargar las sucursales permitidas
      print('Error al cargar sucursales permitidas: ${e.toString()}');
    }
  }

  Future<void> _cargarAplicaciones() async {
    try {
      final lista = await ApiService().getAplicaciones();
      if (mounted) {
        setState(() => aplicaciones = lista);
      }
    } catch (e) {
      _mostrarError('Error al cargar aplicaciones: ${e.toString()}');
    }
  }

  Future<void> _cargarAplicacionesPermitidas() async {
    try {
      final lista = await ApiService().getAplicacionesPermitidasUsuario(widget.usuario['id'].toString());
      if (mounted) {
        setState(() {
          aplicacionesPermitidasSeleccionadas = lista.map((a) => a['id'] as int).toList();
        });
      }
    } catch (e) {
      // Si hay error, simplemente no cargar las aplicaciones permitidas
      print('Error al cargar aplicaciones permitidas: ${e.toString()}');
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
        "usuario": _usuarioController.text.trim(),
        "correo": _correoController.text.trim(),
        "id_sucursalactiva": selectedSucursal,
        "id_colaborador": _mostrarSelectorColaborador ? selectedColaborador : null,
        "id_estado": int.parse(selectedEstado ?? "1"),
      };

      // Solo incluir la clave si se ha modificado
      if (_claveController.text.isNotEmpty) {
        usuarioActualizado["clave"] = _claveController.text;
      }

      final exito = await ApiService().editarUsuario(
        widget.usuario['id'].toString(), 
        usuarioActualizado
      );

      if (exito) {
        // Actualizar sucursales permitidas
        try {
          if (sucursalesPermitidasSeleccionadas.isNotEmpty) {
            await ApiService().asignarSucursalesPermitidas(
              widget.usuario['id'].toString(),
              sucursalesPermitidasSeleccionadas,
            );
          } else {
            // Si no hay sucursales seleccionadas, eliminar todas las asignaciones
            await ApiService().eliminarSucursalesPermitidas(
              widget.usuario['id'].toString(),
            );
          }
        } catch (e) {
          print('Error al actualizar sucursales permitidas: $e');
          // No mostrar error al usuario, ya que el usuario se guardó correctamente
        }

        // Actualizar aplicaciones permitidas
        try {
          if (aplicacionesPermitidasSeleccionadas.isNotEmpty) {
            await ApiService().asignarAplicacionesPermitidas(
              widget.usuario['id'].toString(),
              aplicacionesPermitidasSeleccionadas,
            );
          } else {
            // Si no hay aplicaciones seleccionadas, eliminar todas las asignaciones
            await ApiService().eliminarAplicacionesPermitidas(
              widget.usuario['id'].toString(),
            );
          }
        } catch (e) {
          print('Error al actualizar aplicaciones permitidas: $e');
          // No mostrar error al usuario, ya que el usuario se guardó correctamente
        }

        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError(e.toString());
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
      body: Container(
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
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Información del Usuario",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: 20),
                        // Campo de usuario
                        TextFormField(
                          controller: _usuarioController,
                          decoration: InputDecoration(
                            labelText: "Nombre de Usuario",
                            prefixIcon: Icon(Icons.person, color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese un nombre de usuario';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        // Campo de correo
                        TextFormField(
                          controller: _correoController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Correo Electrónico",
                            prefixIcon: Icon(Icons.email, color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese un correo electrónico';
                            }
                            if (!value.contains('@')) {
                              return 'Por favor ingrese un correo electrónico válido';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        // Campo de contraseña (opcional)
                        TextFormField(
                          controller: _claveController,
                          obscureText: _ocultarClave,
                          decoration: InputDecoration(
                            labelText: "Nueva Contraseña (opcional)",
                            prefixIcon: Icon(Icons.lock, color: primaryColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _ocultarClave ? Icons.visibility : Icons.visibility_off,
                                color: primaryColor,
                              ),
                              onPressed: () {
                                setState(() => _ocultarClave = !_ocultarClave);
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        // Selector de sucursal
                        DropdownSearch<String>(
                          popupProps: PopupProps.menu(
                            fit: FlexFit.loose,
                            menuProps: MenuProps(
                              backgroundColor: Colors.white,
                              elevation: 2,
                            ),
                            showSelectedItems: true,
                          ),
                          items: sucursales.map((s) => s['nombre'].toString()).toList(),
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: "Sucursal",
                              prefixIcon: Icon(Icons.business, color: primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                              value == null ? 'Por favor seleccione una sucursal' : null,
                        ),
                        SizedBox(height: 16),
                        // Estado del usuario
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: "Estado",
                            prefixIcon: Icon(Icons.toggle_on, color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          value: selectedEstado,
                          items: [
                            DropdownMenuItem(value: "1", child: Text("Activo")),
                            DropdownMenuItem(value: "2", child: Text("Inactivo")),
                          ],
                          onChanged: (value) {
                            setState(() => selectedEstado = value);
                          },
                        ),
                        SizedBox(height: 16),
                        // Switch para mostrar/ocultar selector de colaborador
                        SwitchListTile(
                          title: Text("¿Asignar a un colaborador?"),
                          value: _mostrarSelectorColaborador,
                          onChanged: (bool value) {
                            setState(() {
                              _mostrarSelectorColaborador = value;
                              if (!value) {
                                selectedColaborador = null;
                              }
                            });
                          },
                          activeColor: primaryColor,
                        ),
                        if (_mostrarSelectorColaborador) ...[
                          SizedBox(height: 16),
                          // Selector de colaborador
                          DropdownSearch<String>(
                            popupProps: PopupProps.menu(
                              fit: FlexFit.loose,
                              menuProps: MenuProps(
                                backgroundColor: Colors.white,
                                elevation: 2,
                              ),
                              showSelectedItems: true,
                            ),
                            items: colaboradores.map((c) => c['nombre'].toString()).toList(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: "Colaborador",
                                prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            onChanged: (String? value) {
                              if (value != null) {
                                final colaborador = colaboradores.firstWhere(
                                  (c) => c['nombre'] == value,
                                  orElse: () => {'id': null},
                                );
                                setState(() => selectedColaborador = colaborador['id']?.toString());
                              }
                            },
                            selectedItem: selectedColaborador != null
                                ? colaboradores
                                    .firstWhere(
                                      (c) => c['id'].toString() == selectedColaborador,
                                      orElse: () => {'nombre': ''},
                                    )['nombre']
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                
                // Sección de Sucursales Permitidas
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: primaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Sucursales Permitidas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Selecciona las sucursales a las que este usuario tendrá acceso:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        // Lista de sucursales con checkboxes
                        Container(
                          constraints: BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: sucursales.length,
                            itemBuilder: (context, index) {
                              final sucursal = sucursales[index];
                              final sucursalId = sucursal['id'] as int;
                              final isSelected = sucursalesPermitidasSeleccionadas.contains(sucursalId);
                              
                              return CheckboxListTile(
                                title: Text(
                                  sucursal['nombre'],
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  sucursal['ubicacion'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      sucursalesPermitidasSeleccionadas.add(sucursalId);
                                    } else {
                                      sucursalesPermitidasSeleccionadas.remove(sucursalId);
                                    }
                                  });
                                },
                                activeColor: primaryColor,
                                checkColor: Colors.white,
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            },
                          ),
                        ),
                        
                        // Botones de acción para sucursales permitidas
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    sucursalesPermitidasSeleccionadas.clear();
                                  });
                                },
                                icon: Icon(Icons.clear, color: primaryColor),
                                label: Text(
                                  'Limpiar',
                                  style: TextStyle(color: primaryColor),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: primaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    sucursalesPermitidasSeleccionadas = sucursales
                                        .map((s) => s['id'] as int)
                                        .toList();
                                  });
                                },
                                icon: Icon(Icons.select_all, color: primaryColor),
                                label: Text(
                                  'Seleccionar Todas',
                                  style: TextStyle(color: primaryColor),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: primaryColor),
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
                
                SizedBox(height: 20),
                
                // Sección de Aplicaciones Permitidas
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.apps, color: primaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Aplicaciones Permitidas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Selecciona las aplicaciones a las que este usuario tendrá acceso:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        // Lista de aplicaciones con checkboxes
                        Container(
                          constraints: BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: aplicaciones.length,
                            itemBuilder: (context, index) {
                              final aplicacion = aplicaciones[index];
                              final aplicacionId = aplicacion['id'] as int;
                              final isSelected = aplicacionesPermitidasSeleccionadas.contains(aplicacionId);
                              
                              return CheckboxListTile(
                                title: Text(
                                  aplicacion['nombre'],
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      aplicacionesPermitidasSeleccionadas.add(aplicacionId);
                                    } else {
                                      aplicacionesPermitidasSeleccionadas.remove(aplicacionId);
                                    }
                                  });
                                },
                                activeColor: primaryColor,
                                checkColor: Colors.white,
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            },
                          ),
                        ),
                        
                        // Botones de acción para aplicaciones permitidas
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    aplicacionesPermitidasSeleccionadas.clear();
                                  });
                                },
                                icon: Icon(Icons.clear, color: primaryColor),
                                label: Text(
                                  'Limpiar',
                                  style: TextStyle(color: primaryColor),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: primaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    aplicacionesPermitidasSeleccionadas = aplicaciones
                                        .map((a) => a['id'] as int)
                                        .toList();
                                  });
                                },
                                icon: Icon(Icons.select_all, color: primaryColor),
                                label: Text(
                                  'Seleccionar Todas',
                                  style: TextStyle(color: primaryColor),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: primaryColor),
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
                
                SizedBox(height: 20),
                // Botón de guardar
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.8),
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
                              Icon(Icons.save, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Guardar Cambios',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
    );
  }
}
