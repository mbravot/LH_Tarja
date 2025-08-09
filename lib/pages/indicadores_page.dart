import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class IndicadoresPage extends StatefulWidget {
  const IndicadoresPage({Key? key}) : super(key: key);

  @override
  _IndicadoresPageState createState() => _IndicadoresPageState();
}

class _IndicadoresPageState extends State<IndicadoresPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  // Variables para filtros
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _colaboradorSeleccionado;
  List<Map<String, dynamic>> _colaboradores = [];
  
  // Variables para datos
  bool _isLoading = false;
  List<Map<String, dynamic>> _indicadoresControlHoras = [];
  List<Map<String, dynamic>> _indicadoresRendimientos = [];
  bool _isLoadingRend = false;

  // Filtros Control Rendimientos
  DateTime? _rendFechaInicio;
  DateTime? _rendFechaFin;
  String? _rendTipoRendimiento; // id_tiporendimiento
  String? _rendLabor; // id_labor
  String? _rendCeco; // id_ceco
  String? _rendTrabajador; // id_trabajador
  List<Map<String, dynamic>> _tiposRend = [];
  List<Map<String, dynamic>> _labores = [];
  List<Map<String, dynamic>> _cecos = [];
  List<Map<String, dynamic>> _trabajadores = [];
  
  // Variables para actividades expandibles
  String? _colaboradorExpandido;
  List<Map<String, dynamic>> _actividadesColaborador = [];
  bool _isLoadingActividades = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarColaboradores();
    _cargarIndicadoresControlHoras();
    _cargarOpcionesRendimientos();
    _cargarIndicadoresRendimientos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarColaboradores() async {
    try {
      final colaboradores = await _apiService.getColaboradores();
      setState(() {
        _colaboradores = colaboradores;
      });
    } catch (e) {
      print('Error al cargar colaboradores: $e');
    }
  }

  Future<void> _cargarIndicadoresControlHoras() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? fechaInicio;
      String? fechaFin;
      String? idColaborador;

      if (_fechaInicio != null) {
        fechaInicio = DateFormat('yyyy-MM-dd').format(_fechaInicio!);
      }
      if (_fechaFin != null) {
        fechaFin = DateFormat('yyyy-MM-dd').format(_fechaFin!);
      }
      if (_colaboradorSeleccionado != null) {
        idColaborador = _colaboradorSeleccionado;
      }

      final indicadores = await _apiService.getIndicadoresControlHoras(
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        idColaborador: idColaborador,
      );

      setState(() {
        _indicadoresControlHoras = indicadores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error al cargar indicadores: $e');
    }
  }

  Future<void> _cargarActividadesColaborador(String idColaborador, String fechaEspecifica) async {
    setState(() {
      _isLoadingActividades = true;
    });

    try {
      // Parse the HTTP date format to get the specific date
      DateTime fecha = _parseHttpDate(fechaEspecifica);
      String fechaFormateada = DateFormat('yyyy-MM-dd').format(fecha);

      final actividades = await _apiService.getActividadesColaborador(
        idColaborador: idColaborador,
        fechaInicio: fechaFormateada,
        fechaFin: fechaFormateada,
      );

      setState(() {
        _actividadesColaborador = actividades;
        _isLoadingActividades = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingActividades = false;
      });
      print('Error al cargar actividades del colaborador: $e');
    }
  }

  // -------- Control Rendimientos --------
  Future<void> _cargarOpcionesRendimientos() async {
    try {
      final tipos = await _apiService.getTipoRendimientos();
      final labores = await _apiService.getLabores();
      final trabajadores = await _apiService.getColaboradores();
      // Para CECOs podemos no cargar todos por ahora; backend filtra por sucursal
      setState(() {
        _tiposRend = tipos;
        _labores = labores;
        _trabajadores = trabajadores;
      });
    } catch (e) {
      print('Error al cargar opciones de rendimientos: $e');
    }
  }

  Future<void> _cargarIndicadoresRendimientos() async {
    setState(() => _isLoadingRend = true);
    try {
      String? fi = _rendFechaInicio != null ? DateFormat('yyyy-MM-dd').format(_rendFechaInicio!) : null;
      String? ff = _rendFechaFin != null ? DateFormat('yyyy-MM-dd').format(_rendFechaFin!) : null;
      final data = await _apiService.getIndicadoresControlRendimientos(
        fechaInicio: fi,
        fechaFin: ff,
        idTipoRendimiento: _rendTipoRendimiento,
        idLabor: _rendLabor,
        idCeco: _rendCeco,
        idTrabajador: _rendTrabajador,
      );
      setState(() {
        _indicadoresRendimientos = data;
        _isLoadingRend = false;
      });
    } catch (e) {
      setState(() => _isLoadingRend = false);
      print('Error al cargar indicador de rendimientos: $e');
    }
  }

  Future<void> _seleccionarFechaInicio() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (fecha != null) {
      setState(() {
        _fechaInicio = fecha;
      });
      _cargarIndicadoresControlHoras();
    }
  }

  Future<void> _seleccionarFechaFin() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (fecha != null) {
      setState(() {
        _fechaFin = fecha;
      });
      _cargarIndicadoresControlHoras();
    }
  }

  Color _obtenerColorEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'MÁS':
        return Colors.red;
      case 'MENOS':
        return Colors.red;
      case 'EXACTO':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _obtenerIconoEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'MÁS':
        return Icons.trending_up;
      case 'MENOS':
        return Icons.trending_down;
      case 'EXACTO':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  DateTime _parseHttpDate(String dateString) {
    try {
      // Handle HTTP date format: "Thu, 07 Aug 2025 00:00:00 GMT"
      if (dateString.contains('GMT')) {
        // Parse the specific format: "Thu, 07 Aug 2025 00:00:00 GMT"
        // Extract day, month, year from the string
        List<String> parts = dateString.split(' ');
        if (parts.length >= 4) {
          String day = parts[1];
          String month = parts[2];
          String year = parts[3];
          
          // Convert month name to number
          Map<String, String> months = {
            'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
            'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
            'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
          };
          
          String monthNumber = months[month] ?? '01';
          
          // Create ISO format string
          String isoDate = '$year-$monthNumber-${day.padLeft(2, '0')}T00:00:00Z';
          return DateTime.parse(isoDate);
        }
      }
      // Try standard parsing for other formats
      return DateTime.parse(dateString);
    } catch (e) {
      print('Error parsing date: $dateString - $e');
      // If parsing fails, return current date
      return DateTime.now();
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    if (value is int) return value.toString();
    if (value is double) {
      final fixed = value.toStringAsFixed(2);
      // Quitar ceros innecesarios
      return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
    }
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final fixed = parsed.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }

  Widget _buildControlHorasTab() {
    return Column(
      children: [
        // Filtros
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _seleccionarFechaInicio,
                      icon: Icon(Icons.calendar_today),
                      label: Text(
                        _fechaInicio != null
                            ? DateFormat('dd/MM/yyyy').format(_fechaInicio!)
                            : 'Fecha Inicio',
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _seleccionarFechaFin,
                      icon: Icon(Icons.calendar_today),
                      label: Text(
                        _fechaFin != null
                            ? DateFormat('dd/MM/yyyy').format(_fechaFin!)
                            : 'Fecha Fin',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _colaboradorSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Colaborador',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('Todos los colaboradores'),
                  ),
                  ..._colaboradores.map((colaborador) {
                    final nombreCompleto = '${colaborador['nombre'] ?? ''} ${colaborador['apellido_paterno'] ?? ''} ${colaborador['apellido_materno'] ?? ''}'.trim();
                    return DropdownMenuItem<String>(
                      value: colaborador['id'],
                      child: Text(
                        nombreCompleto.isNotEmpty ? nombreCompleto : 'Sin nombre',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _colaboradorSeleccionado = value;
                  });
                  _cargarIndicadoresControlHoras();
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cargarIndicadoresControlHoras,
                      icon: Icon(Icons.refresh),
                      label: Text('Actualizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _fechaInicio = null;
                          _fechaFin = null;
                          _colaboradorSeleccionado = null;
                        });
                        _cargarIndicadoresControlHoras();
                      },
                      icon: Icon(Icons.clear),
                      label: Text('Limpiar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Lista de indicadores
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _indicadoresControlHoras.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No hay datos disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ajusta los filtros o selecciona otro rango de fechas',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _indicadoresControlHoras.length,
                      itemBuilder: (context, index) {
                        final indicador = _indicadoresControlHoras[index];
                        final isExpanded = _colaboradorExpandido == indicador['id_colaborador'];
                        
                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _colaboradorExpandido = null;
                                    _actividadesColaborador = [];
                                  } else {
                                    _colaboradorExpandido = indicador['id_colaborador'];
                                    _cargarActividadesColaborador(indicador['id_colaborador'], indicador['fecha']);
                                  }
                                });
                              },
                              child: Card(
                                margin: EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: _obtenerColorEstado(
                                              indicador['estado_trabajo'] ?? '',
                                            ),
                                            child: Icon(
                                              _obtenerIconoEstado(
                                                indicador['estado_trabajo'] ?? '',
                                              ),
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  indicador['colaborador'] ?? 'Sin nombre',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('EEEE, dd/MM/yyyy', 'es_ES')
                                                      .format(_parseHttpDate(indicador['fecha'])),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _obtenerColorEstado(
                                                indicador['estado_trabajo'] ?? '',
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              indicador['estado_trabajo'] ?? 'N/A',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildMetricCard(
                                              'Horas Trabajadas',
                                              '${indicador['horas_trabajadas'] ?? 0}',
                                              Icons.access_time,
                                              Colors.blue,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: _buildMetricCard(
                                              'Horas Esperadas',
                                              '${indicador['horas_esperadas'] ?? 0}',
                                              Icons.schedule,
                                              Colors.orange,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: _buildMetricCard(
                                              'Diferencia',
                                              '${indicador['diferencia_horas'] ?? 0}',
                                              Icons.compare_arrows,
                                              _obtenerColorEstado(
                                                indicador['estado_trabajo'] ?? '',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Sección expandible con actividades
                            if (isExpanded) ...[
                              Container(
                                margin: EdgeInsets.only(top: 8),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.list, color: Colors.green, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Actividades del colaborador',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    if (_isLoadingActividades)
                                      Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else if (_actividadesColaborador.isEmpty)
                                      Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            'No hay actividades registradas',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ..._actividadesColaborador.map((actividad) {
                                        return Container(
                                          margin: EdgeInsets.only(bottom: 12),
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey[200]!),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          actividad['labor'] ?? 'Sin labor',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          'CECO: ${actividad['nombre_ceco'] ?? 'N/A'} - ${actividad['detalle_ceco'] ?? 'N/A'}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                        Text(
                                                          'Tipo: ${actividad['tipoceco'] ?? 'N/A'}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _obtenerColorEstado(
                                                        actividad['estado_trabajo'] ?? '',
                                                      ),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      actividad['estado_trabajo'] ?? 'N/A',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildMetricCard(
                                                      'Horas',
                                                      '${actividad['horas_trabajadas'] ?? 0}',
                                                      Icons.access_time,
                                                      Colors.blue,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: _buildMetricCard(
                                                      'Esperadas',
                                                      '${actividad['horas_esperadas'] ?? 0}',
                                                      Icons.schedule,
                                                      Colors.orange,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: _buildMetricCard(
                                                      'Diferencia',
                                                      '${actividad['diferencia_horas'] ?? 0}',
                                                      Icons.compare_arrows,
                                                      _obtenerColorEstado(
                                                        actividad['estado_trabajo'] ?? '',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Fecha: ${DateFormat('EEEE, dd/MM/yyyy', 'es_ES').format(DateTime.parse(actividad['fecha']))}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildOtrosIndicadoresTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 80,
            color: Colors.amber,
          ),
          SizedBox(height: 20),
          Text(
            'Próximamente',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Más indicadores estarán disponibles próximamente',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlRendimientosTab() {
    return Column(
      children: [
        // Filtros
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final f = await showDatePicker(
                          context: context,
                          initialDate: _rendFechaInicio ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (f != null) {
                          setState(() => _rendFechaInicio = f);
                          _cargarIndicadoresRendimientos();
                        }
                      },
                      icon: Icon(Icons.calendar_today),
                      label: Text(_rendFechaInicio != null
                          ? DateFormat('dd/MM/yyyy').format(_rendFechaInicio!)
                          : 'Fecha Inicio'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final f = await showDatePicker(
                          context: context,
                          initialDate: _rendFechaFin ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (f != null) {
                          setState(() => _rendFechaFin = f);
                          _cargarIndicadoresRendimientos();
                        }
                      },
                      icon: Icon(Icons.calendar_today),
                      label: Text(_rendFechaFin != null
                          ? DateFormat('dd/MM/yyyy').format(_rendFechaFin!)
                          : 'Fecha Fin'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _rendTipoRendimiento,
                      decoration: InputDecoration(labelText: 'Tipo de rendimiento', border: OutlineInputBorder()),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String>(value: null, child: Text('Todos')),
                        ..._tiposRend.map((t) => DropdownMenuItem<String>(
                              value: t['id']?.toString(),
                              child: Text(
                                t['tipo']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _rendTipoRendimiento = v);
                        _cargarIndicadoresRendimientos();
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _rendLabor,
                      decoration: InputDecoration(labelText: 'Labor', border: OutlineInputBorder()),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String>(value: null, child: Text('Todas')),
                        ..._labores.map((l) => DropdownMenuItem<String>(
                              value: l['id']?.toString(),
                              child: Text(
                                l['nombre']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _rendLabor = v);
                        _cargarIndicadoresRendimientos();
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _rendTrabajador,
                decoration: InputDecoration(labelText: 'Trabajador', border: OutlineInputBorder()),
                isExpanded: true,
                items: [
                  DropdownMenuItem<String>(value: null, child: Text('Todos')),
                  ..._trabajadores.map((t) {
                    final nombre = '${t['nombre'] ?? ''} ${t['apellido_paterno'] ?? ''} ${t['apellido_materno'] ?? ''}'.trim();
                    return DropdownMenuItem<String>(
                      value: t['id']?.toString(),
                      child: Text(nombre.isNotEmpty ? nombre : 'Sin nombre', overflow: TextOverflow.ellipsis, maxLines: 1),
                    );
                  }),
                ],
                onChanged: (v) {
                  setState(() => _rendTrabajador = v);
                  _cargarIndicadoresRendimientos();
                },
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _rendFechaInicio = null;
                          _rendFechaFin = null;
                          _rendTipoRendimiento = null;
                          _rendLabor = null;
                          _rendCeco = null;
                          _rendTrabajador = null;
                        });
                        _cargarIndicadoresRendimientos();
                      },
                      icon: Icon(Icons.clear),
                      label: Text('Limpiar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingRend
              ? Center(child: CircularProgressIndicator())
              : _indicadoresRendimientos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.insights_outlined, size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text('No hay datos de rendimientos', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _indicadoresRendimientos.length,
                      itemBuilder: (context, index) {
                        final item = _indicadoresRendimientos[index];
                        final fecha = _parseHttpDate(item['fecha']?.toString() ?? DateTime.now().toString());
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, color: Colors.green),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat('EEEE, dd/MM/yyyy', 'es_ES').format(fecha),
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (item['tipo_mo']?.toString().toUpperCase() == 'PROPIO') ? Colors.blue : Colors.deepPurple,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        item['tipo_mo']?.toString() ?? 'N/A',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricCard('Total Rendimiento', _formatNumber(item['total_rendimiento']), Icons.speed, Colors.green)),
                                    SizedBox(width: 12),
                                    Expanded(child: _buildMetricCard('Trabajadores', '${item['total_trabajadores'] ?? 0}', Icons.groups, Colors.orange)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.label_important_outline, color: Colors.purple),
                                    SizedBox(width: 8),
                                    Text(item['tipo_rendimiento']?.toString() ?? 'Tipo rendimiento'),
                                  ],
                                ),
                                SizedBox(height: 8),
                                if (item.containsKey('trabajador'))
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline, color: Colors.green),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Trabajador: ' + (item['trabajador']?.toString() ?? 'N/A'),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                SizedBox(height: 8),
                                if (item.containsKey('labor'))
                                  Row(
                                    children: [
                                      Icon(Icons.work_outline, color: Colors.indigo),
                                      SizedBox(width: 8),
                                      Expanded(child: Text('Labor: ' + (item['labor']?.toString() ?? 'N/A'))),
                                    ],
                                  ),
                                if (item.containsKey('unidad'))
                                  SizedBox(height: 6),
                                if (item.containsKey('unidad'))
                                  Row(
                                    children: [
                                      Icon(Icons.straighten, color: Colors.blueGrey),
                                      SizedBox(width: 8),
                                      Expanded(child: Text('Unidad: ' + (item['unidad']?.toString() ?? 'N/A'))),
                                    ],
                                  ),
                                if (item.containsKey('nombre_ceco') || item.containsKey('detalle_ceco'))
                                  SizedBox(height: 6),
                                if (item.containsKey('nombre_ceco') || item.containsKey('detalle_ceco'))
                                  Row(
                                    children: [
                                      Icon(Icons.folder_open, color: Colors.amber),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'CECO: ' +
                                              ((item['nombre_ceco']?.toString() ?? 'N/A') +
                                                  (item['detalle_ceco'] != null ? ' - ${item['detalle_ceco']}' : '')),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.green,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(
                  icon: Icon(Icons.access_time),
                  text: 'Control de Horas',
                ),
                Tab(
                  icon: Icon(Icons.speed),
                  text: 'Control Rendimientos',
                ),
                Tab(
                  icon: Icon(Icons.analytics),
                  text: 'Otros Indicadores',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildControlHorasTab(),
                _buildControlRendimientosTab(),
                _buildOtrosIndicadoresTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
