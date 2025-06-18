class RendimientoGrupal {
  final String id;
  final String idActividad;
  final double? rendimientoTotal;
  final int cantidadTrab;
  final int idPorcentaje;

  RendimientoGrupal({
    required this.id,
    required this.idActividad,
    this.rendimientoTotal,
    required this.cantidadTrab,
    required this.idPorcentaje,
  });

  factory RendimientoGrupal.fromJson(Map<String, dynamic> json) {
    return RendimientoGrupal(
      id: json['id'] as String,
      idActividad: json['id_actividad'] as String,
      rendimientoTotal: json['rendimiento_total'] != null
          ? (json['rendimiento_total'] as num).toDouble()
          : null,
      cantidadTrab: json['cantidad_trab'] is int
          ? json['cantidad_trab']
          : int.parse(json['cantidad_trab'].toString()),
      idPorcentaje: json['id_porcentaje'] is int
          ? json['id_porcentaje']
          : int.parse(json['id_porcentaje'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_actividad': idActividad,
      'rendimiento_total': rendimientoTotal,
      'cantidad_trab': cantidadTrab,
      'id_porcentaje': idPorcentaje,
    };
  }
} 