class TipoOperacion {
  int id_tipo_operacion;
  String codigo_tipo_operacion;

  TipoOperacion({
    required this.id_tipo_operacion,
    required this.codigo_tipo_operacion,
  });

  factory TipoOperacion.fromMap(Map<String, dynamic> map) {
    return TipoOperacion(
      id_tipo_operacion: map['id_tipo_operacion'],
      codigo_tipo_operacion: map['codigo_tipo_op'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_tipo_operacion': id_tipo_operacion,
      'codigo_tipo_op': codigo_tipo_operacion,
    };
  }
}
