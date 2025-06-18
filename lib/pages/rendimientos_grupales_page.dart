import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'crear_rendimiento_grupal_page.dart';

class RendimientosGrupalesPage extends StatefulWidget {
  final Map<String, dynamic> actividad;

  const RendimientosGrupalesPage({Key? key, required this.actividad}) : super(key: key);

  @override
  _RendimientosGrupalesPageState createState() => _RendimientosGrupalesPageState();
}

class _RendimientosGrupalesPageState extends State<RendimientosGrupalesPage> {
  late List<Map<String, dynamic>> _rendimientos;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarRendimientos();
  }

  void _cargarRendimientos() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final rendimientos = await ApiService().getRendimientosGrupales(widget.actividad['id']);
      setState(() {
        _rendimientos = rendimientos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar rendimientos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rendimientos Grupales'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _rendimientos.isEmpty
              ? Center(child: Text('No hay rendimientos grupales'))
              : ListView.builder(
                  itemCount: _rendimientos.length,
                  itemBuilder: (context, index) {
                    final rendimiento = _rendimientos[index];
                    return ListTile(
                      title: Text('Fecha: ${rendimiento['fecha']}'),
                      subtitle: Text('Cantidad: ${rendimiento['cantidad']}'),
                      trailing: IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditarRendimientoGrupalPage(rendimiento: rendimiento),
                            ),
                          );
                          if (result == true) {
                            _cargarRendimientos();
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CrearRendimientoGrupalPage(actividad: widget.actividad),
            ),
          );
          if (result == true) {
            _cargarRendimientos();
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
} 