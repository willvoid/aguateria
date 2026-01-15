class ModoPago {
  int? id_modo_pago;
  String descripcion;

  ModoPago({this.id_modo_pago, required this.descripcion});

  factory ModoPago.fromMap(Map<String, dynamic> map) {
    return ModoPago(
      id_modo_pago: map['id_modo_pago'],
      descripcion: map['descripcion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id_modo_pago': id_modo_pago, 'descripcion': descripcion};
  }
}
