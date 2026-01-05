class Iva {
  int? id;
  String descripcion;
  int valor;

  Iva({this.id, required this.descripcion, required this.valor});

  factory Iva.fromMap(Map<String, dynamic> map) {
    return Iva(
      id: map['id_iva'],
      descripcion: map['descripcion'],
      valor: map['valor'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_iva': id,
      'descripcion': descripcion,
      'valor': valor,
    };
  }
}
