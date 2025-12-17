import 'package:myapp/modelo/categoria_servicio.dart';

class Tarifa {
  int? id_tarifa;
  double rango_min;
  double rango_max;
  double costo_m3;
  CategoriaServicio categoriaServicio;

  Tarifa({
    this.id_tarifa,
    required this.rango_min,
    required this.rango_max,
    required this.costo_m3,
    required this.categoriaServicio,
  });

  factory Tarifa.fromMap(Map<String, dynamic> map) {
    return Tarifa(
      id_tarifa: map['id_tarifas'],
      rango_min: map['rango_min'],
      rango_max: map['rango_max'],
      costo_m3: map['costo_m3'],
      categoriaServicio: CategoriaServicio.fromMap(map['fk_categoria_servicio']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_tarifas': id_tarifa,
      'rango_min': rango_min,
      'rango_max': rango_max,
      'costo_m3': costo_m3,
      'categoria_servicio': categoriaServicio.toMap(),
    };
  }

}
