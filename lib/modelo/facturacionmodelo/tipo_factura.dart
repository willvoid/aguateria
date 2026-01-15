class TipoFactura {
  int? id_tipo_factura;
  String descripcion;

  TipoFactura({this.id_tipo_factura, required this.descripcion});

  factory TipoFactura.fromMap(Map<String, dynamic> map) {
    return TipoFactura(
      id_tipo_factura: map['id_tipo_factura'],
      descripcion: map['descripcion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id_tipo_factura': id_tipo_factura, 'descripcion': descripcion};
  }
  
}
