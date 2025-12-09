import 'dart:ffi';

class CategoriaServicio {
  int? id;
  String nombre;
  double tarifa_fija;
  double m2_min;
  double m2_max;
  String descripcion;

  CategoriaServicio({
    this.id,
    required this.nombre,
    required this.tarifa_fija,
    required this.m2_min,
    required this.m2_max,
    required this.descripcion,
  });

  factory CategoriaServicio.fromMap(Map<String, dynamic> map) {
    return CategoriaServicio(
      id: map['id'],
      nombre: map['nombre'],
      tarifa_fija: map['tarifa_fija'],
      m2_min: map['m2_min'],
      m2_max: map['m2_max'],
      descripcion: map['descripcion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'tarifa_fija': tarifa_fija,
      'm2_min': m2_min,
      'm2_max': m2_max,
      'descripcion': descripcion,
    };
  }
}
