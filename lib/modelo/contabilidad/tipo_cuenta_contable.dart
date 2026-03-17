class TipoCuentaContable {
  int? id;
  String nombre;
  String? descripcion;

  TipoCuentaContable({
    this.id,
    required this.nombre,
    this.descripcion,
  });

  factory TipoCuentaContable.fromMap(Map<String, dynamic> map) {
    return TipoCuentaContable(
      id: map['id'],
      nombre: map['nombre'],
      descripcion: map['descripcion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
    };
  }
}