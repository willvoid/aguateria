class Ciclo {
  int? id;
  DateTime inicio;
  DateTime fin;
  DateTime vencimiento;
  int anio;
  String descripcion;
  String ciclo;
  String estado;

  Ciclo({
    this.id,
    required this.inicio,
    required this.fin,
    required this.vencimiento,
    required this.anio,
    required this.descripcion,
    required this.ciclo,
    required this.estado,
  });

  factory Ciclo.fromMap(Map<String, dynamic> map) {
    return Ciclo(
      id: map['id_ciclos'],
      inicio: DateTime.parse(map['inicio']),
      fin: DateTime.parse(map['fin']),
      vencimiento: DateTime.parse(map['vencimiento']),
      anio: map['anio'],
      descripcion: map['descripcion'],
      ciclo: map['ciclo'],
      estado: map['estado'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_ciclos': id,
      'inicio': inicio.toIso8601String(),
      'fin': fin.toIso8601String(),
      'vencimiento': vencimiento.toIso8601String(),
      'anio': anio,
      'descripcion': descripcion,
      'ciclo': ciclo,
      'estado': estado,
    };
  }
}
