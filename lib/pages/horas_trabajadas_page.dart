import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';

DateTime? parsearFechaFlexible(String fecha) {
  try {
    return DateTime.parse(fecha);
  } catch (_) {
    try {
      return DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US').parseUtc(fecha);
    } catch (_) {
      return null;
    }
  }
}

class HorasTrabajadasPage extends StatefulWidget {
  const HorasTrabajadasPage({Key? key}) : super(key: key);

  @override
  _HorasTrabajadasPageState createState() => _HorasTrabajadasPageState();
}

class _HorasTrabajadasPageState extends State<HorasTrabajadasPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rendimientos = [];
  Map<String, dynamic>? _actividadInfo;
  final _horasController = TextEditingController();
  List<Map<String, dynamic>> _actividades = [];
  Map<String, dynamic>? _actividadSeleccionada;
  Map<String, bool> _mesExpandido = {};
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _actividadesFiltradas = [];

  @override
  void initState() {
    super.initState();
    _cargarActividades();
    _searchController.addListener(_filtrarActividades);
  }

  @override
  void dispose() {
    _horasController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarActividades() {
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _actividadesFiltradas = List.from(_actividades));
      return;
    }
    setState(() {
      _actividadesFiltradas = _actividades.where((actividad) {
        final labor = (actividad['labor'] ?? '').toString().toLowerCase();
        final ceco = (actividad['ceco'] ?? '').toString().toLowerCase();
        final colaborador = ((actividad['nombre_colaborador'] ?? '') + ' ' + (actividad['apellido_paterno'] ?? '') + ' ' + (actividad['apellido_materno'] ?? '')).toLowerCase();
        return labor.contains(query) || ceco.contains(query) || colaborador.contains(query);
      }).toList();
    });
  }

  Future<void> _cargarActividades() async {
    setState(() => _isLoading = true);
    try {
      final actividades = await ApiService().getActividadesConRendimientos();
      final propias = actividades.where((a) => a['id_tipotrabajador'] == 1).toList();
      setState(() {
        _actividades = propias;
        _actividadesFiltradas = List.from(propias);
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las actividades: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarActividad() async {
    final seleccion = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Selecciona una Actividad'),
          content: Container(
            width: double.maxFinite,
            child: _actividades.isEmpty
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _actividades.length,
                    itemBuilder: (context, index) {
                      final actividad = _actividades[index];
                      final fecha = parsearFechaFlexible(actividad['fecha']);
                      final fechaMostrada = fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : 'Fecha inválida';
                      return ListTile(
                        leading: Icon(Icons.assignment, color: Colors.green),
                        title: Text(
                          actividad['labor'] ?? 'Sin labor',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CECO: ${actividad['ceco'] ?? 'Sin CECO'}'),
                            Text(
                              'Fecha: $fechaMostrada',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.pop(context, actividad),
                      );
                    },
                  ),
          ),
        );
      },
    );

    if (seleccion != null) {
      setState(() {
        _actividadSeleccionada = seleccion;
      });
      _cargarRendimientos();
    }
  }

  Future<void> _cargarRendimientos() async {
    if (_actividadSeleccionada == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService().getRendimientosPropios(_actividadSeleccionada!['id'].toString());
      setState(() {
        _rendimientos = List<Map<String, dynamic>>.from(response['rendimientos']);
        _actividadInfo = response['actividad'];
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar los rendimientos: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editarHoras(Map<String, dynamic> rendimiento) async {
    _horasController.text = rendimiento['horas_trabajadas'].toString();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Horas Trabajadas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${rendimiento['nombre_colaborador']} ${rendimiento['apellido_paterno']} ${rendimiento['apellido_materno']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _horasController,
              decoration: InputDecoration(
                labelText: 'Horas Trabajadas',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService().editarRendimientoPropio(
                  rendimiento['id'].toString(),
                  {
                    'horas_trabajadas': double.parse(_horasController.text),
                  },
                );
                Navigator.pop(context);
                _cargarRendimientos();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Horas actualizadas correctamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al actualizar las horas: $e', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                );
              }
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }

  String _nombreMes(int mes) {
    const meses = [
      '',
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[mes];
  }

  String _formatearFechaDia(DateTime fecha) {
    return DateFormat("EEEE d 'de' MMMM, y", 'es_ES').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_actividadSeleccionada == null) {
      // Agrupar actividades por día
      Map<String, List<Map<String, dynamic>>> actividadesPorDia = {};
      for (var actividad in _actividadesFiltradas) {
        final fecha = parsearFechaFlexible(actividad['fecha']);
        String key = '--';
        if (fecha != null) {
          key = DateFormat('yyyy-MM-dd').format(fecha);
        }
        actividadesPorDia.putIfAbsent(key, () => []).add(actividad);
      }
      // Ordenar los días del más reciente al más antiguo
      final diasOrdenados = actividadesPorDia.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      // Inicializar el estado expandido si es la primera vez
      for (final dia in diasOrdenados) {
        _mesExpandido.putIfAbsent(dia, () => true);
      }

      return Scaffold(
        appBar: AppBar(
          title: Text('Horas Trabajadas'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: 'Buscar por labor, CECO o colaborador',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                            onPressed: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _actividadesFiltradas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No hay actividades disponibles',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: diasOrdenados.length,
                      itemBuilder: (context, index) {
                        final dia = diasOrdenados[index];
                        final actividadesDelDia = actividadesPorDia[dia]!;
                        final dt = dia != '--' ? DateTime.parse(dia) : null;
                        final nombreDia = dt != null ? _formatearFechaDia(dt) : '--';
                        final cantidad = actividadesDelDia.length;
                        final expandido = _mesExpandido[dia] ?? true;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: expandido,
                              onExpansionChanged: (expanded) {
                                setState(() => _mesExpandido[dia] = expanded);
                              },
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      nombreDia,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green[800]!.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$cantidad ${cantidad == 1 ? 'actividad' : 'actividades'}',
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              children: actividadesDelDia.map((actividad) {
                                final nombreColaborador = ((actividad['nombre_colaborador'] ?? '') + ' ' + (actividad['apellido_paterno'] ?? '') + ' ' + (actividad['apellido_materno'] ?? '')).trim();
                                final horasTrabajadas = actividad['horas_trabajadas']?.toString() ?? '--';
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetalleHorasTrabajadasPage(actividad: actividad),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(15),
                                  child: Card(
                                    color: Colors.white,
                                    elevation: 3,
                                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(Icons.assignment, color: Colors.green, size: 32),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        actividad['labor'] ?? 'Sin labor',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'CECO: ${actividad['ceco'] ?? 'Sin CECO'}',
                                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    }

    final fechaActividad = _actividadInfo != null ? parsearFechaFlexible(_actividadInfo!['fecha']) : null;
    final fechaMostradaActividad = fechaActividad != null ? DateFormat('dd/MM/yyyy').format(fechaActividad) : 'Fecha inválida';

    return Scaffold(
      appBar: AppBar(
        title: Text('Horas Trabajadas'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarRendimientos,
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              setState(() {
                _actividadSeleccionada = null;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_actividadInfo != null)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[200],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Labor: ${_actividadInfo!['labor']}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'CECO: ${_actividadInfo!['ceco']}',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Fecha: $fechaMostradaActividad',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _rendimientos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No hay colaboradores registrados',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _rendimientos.length,
                    itemBuilder: (context, index) {
                      final rendimiento = _rendimientos[index];
                      final nombreCompleto = '${rendimiento['nombre_colaborador']} ${rendimiento['apellido_paterno']} ${rendimiento['apellido_materno']}';
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _editarHoras(rendimiento),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombreCompleto,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Horas Trabajadas: ${rendimiento['horas_trabajadas']}',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.edit, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class DetalleHorasTrabajadasPage extends StatefulWidget {
  final Map<String, dynamic> actividad;
  const DetalleHorasTrabajadasPage({Key? key, required this.actividad}) : super(key: key);

  @override
  State<DetalleHorasTrabajadasPage> createState() => _DetalleHorasTrabajadasPageState();
}

class _DetalleHorasTrabajadasPageState extends State<DetalleHorasTrabajadasPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rendimientos = [];
  Map<String, dynamic>? _actividadInfo;

  @override
  void initState() {
    super.initState();
    _cargarRendimientos();
  }

  Future<void> _cargarRendimientos() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService().getRendimientosPropios(widget.actividad['id'].toString());
      setState(() {
        _rendimientos = List<Map<String, dynamic>>.from(response['rendimientos']);
        _actividadInfo = response['actividad'];
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar los rendimientos: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle Horas Trabajadas'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_actividadInfo != null)
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.grey[200],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Labor: ${_actividadInfo!['labor']}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'CECO: ${_actividadInfo!['ceco']}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _rendimientos.isEmpty
                      ? Center(
                          child: Text('No hay colaboradores registrados en esta actividad'),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _rendimientos.length,
                          itemBuilder: (context, index) {
                            final r = _rendimientos[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Icon(Icons.person, color: Colors.green),
                                title: Text(r['nombre_colaborador'] ?? '--', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Horas trabajadas: ${r['horas_trabajadas'] ?? '--'}'),
                                trailing: Icon(Icons.edit, color: Colors.grey),
                                onTap: () => _mostrarEditarHorasDialog(r),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _mostrarEditarHorasDialog(Map<String, dynamic> rendimiento) {
    final _formKey = GlobalKey<FormState>();
    final _horasController = TextEditingController(text: rendimiento['horas_trabajadas']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.timer, color: Colors.green),
              SizedBox(width: 10),
              Text("Editar Horas Trabajadas"),
            ],
          ),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rendimiento['nombre_colaborador'] ?? '--',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _horasController,
                  decoration: InputDecoration(
                    labelText: 'Horas trabajadas',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese las horas trabajadas';
                    }
                    final n = num.tryParse(value);
                    if (n == null || n < 0) {
                      return 'Ingrese un valor válido';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Guardar"),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  if (rendimiento['id'] == null) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: El rendimiento no tiene un ID válido.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  try {
                    await ApiService().editarRendimientoPropio(
                      rendimiento['id'].toString(),
                      {'horas_trabajadas': double.parse(_horasController.text)},
                    );
                    Navigator.of(context).pop();
                    _cargarRendimientos();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Horas actualizadas correctamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al actualizar las horas: $e', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
