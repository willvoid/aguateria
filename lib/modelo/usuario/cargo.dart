
class Cargo {
  int? id_cargo;
  String nombre;
  String descripcion_cargo;

  Cargo({
    this.id_cargo,
    required this.nombre,
    required this.descripcion_cargo,
  });

  factory Cargo.fromMap(Map<String, dynamic> map) {
    return Cargo(
      id_cargo: map['id_cargo'],
      nombre: map['cargo'],
      descripcion_cargo: map['descripcion_cargo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cargo': id_cargo,
      'cargo': nombre,
      'descripcion_cargo': descripcion_cargo,
    };
  }

}
