// Modelo para rendimientos propios
class RendimientoPropio {
  final String id;
  final String idActividad;
  final String idColaborador;
  final double rendimiento;
  final double horasTrabajadas;
  final double horasExtras;
  final int idBono;

  RendimientoPropio({
    required this.id,
    required this.idActividad,
    required this.idColaborador,
    required this.rendimiento,
    required this.horasTrabajadas,
    required this.horasExtras,
    required this.idBono,
  });

  factory RendimientoPropio.fromJson(Map<String, dynamic> json) {
    return RendimientoPropio(
      id: json['id'],
      idActividad: json['id_actividad'],
      idColaborador: json['id_colaborador'],
      rendimiento: (json['rendimiento'] as num).toDouble(),
      horasTrabajadas: (json['horas_trabajadas'] as num).toDouble(),
      horasExtras: (json['horas_extras'] as num).toDouble(),
      idBono: json['id_bono'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_actividad': idActividad,
      'id_colaborador': idColaborador,
      'rendimiento': rendimiento,
      'horas_trabajadas': horasTrabajadas,
      'horas_extras': horasExtras,
      'id_bono': idBono,
    };
  }
}

// Modelo para rendimientos de contratistas
class RendimientoContratista {
  final String id;
  final String idActividad;
  final String idTrabajador;
  final double rendimiento;
  final int idPorcentajeIndividual;

  RendimientoContratista({
    required this.id,
    required this.idActividad,
    required this.idTrabajador,
    required this.rendimiento,
    required this.idPorcentajeIndividual,
  });

  factory RendimientoContratista.fromJson(Map<String, dynamic> json) {
    return RendimientoContratista(
      id: json['id'],
      idActividad: json['id_actividad'],
      idTrabajador: json['id_trabajador'],
      rendimiento: (json['rendimiento'] as num).toDouble(),
      idPorcentajeIndividual: json['id_porcentaje_individual'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_actividad': idActividad,
      'id_trabajador': idTrabajador,
      'rendimiento': rendimiento,
      'id_porcentaje_individual': idPorcentajeIndividual,
    };
  }
} 