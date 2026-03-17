class TipoContribuyente {
  int? id_tipo_contribuyente;
  int codigo_contribuyente;
  String descripcion;

  TipoContribuyente({
    required this.codigo_contribuyente,
    required this.descripcion,
    this.id_tipo_contribuyente,
  });

  factory TipoContribuyente.fromMap(Map<String, dynamic> map) {
    return TipoContribuyente(
      id_tipo_contribuyente: map['id_tipo_contribuyente'],
      codigo_contribuyente: map['codigo_contribuyente'] ?? 0,
      descripcion: map['descripcion'] ?? '',
    );
  }

  factory TipoContribuyente.vacio() {
    return TipoContribuyente(codigo_contribuyente: 0, descripcion: '');
  }

  Map<String, dynamic> toMap() {
    return {
      'id_tipo_contribuyente': id_tipo_contribuyente,
      'codigo_contribuyente': codigo_contribuyente,
      'descripcion': descripcion,
    };
  }
}