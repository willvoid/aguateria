class UnidadMedida {
  int? id;
  int cod_unidades_medida;
  String representacion;
  String descripcion;

  UnidadMedida({
    this.id,
    required this.cod_unidades_medida,
    required this.representacion,
    required this.descripcion,
  });

  factory UnidadMedida.fromMap(Map<String, dynamic> map) {
    return UnidadMedida(
      id: map['id_unidades'],
      cod_unidades_medida: map['cod_unidades_medida'],
      representacion: map['representacion'],
      descripcion: map['descripcion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_unidades': id,
      'cod_unidades_medida': cod_unidades_medida,
      'representacion': representacion,
      'descripcion': descripcion,
    };
  }
}
