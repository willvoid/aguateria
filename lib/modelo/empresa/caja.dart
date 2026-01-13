import 'package:myapp/modelo/empresa/establecimiento.dart';

class Caja {
  int? id_caja;
  int nro_caja;
  String descripcion_caja;
  Establecimiento fk_establecimiento;

  Caja({
    this.id_caja,
    required this.nro_caja,
    required this.descripcion_caja,
    required this.fk_establecimiento,
  });

  factory Caja.fromMap(Map<String, dynamic> map) {
    return Caja(
      id_caja: map['id_caja'],
      nro_caja: map['nro_caja'],
      descripcion_caja: map['descripcion_caja'],
      fk_establecimiento: Establecimiento.fromMap(map['fk_establecimientos']),
      );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_caja': id_caja,
      'nro_caja': nro_caja,
      'descripcion_caja': descripcion_caja,
      'fk_establecimientos': fk_establecimiento.toMap(),
    };
  }
}
