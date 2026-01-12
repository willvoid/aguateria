import 'package:myapp/modelo/empresa/establecimiento.dart';

class Timbrado {
  int? id_timbrado;
  String timbrado;
  DateTime inicio;
  DateTime vencimiento;
  String estado;
  Establecimiento fk_establecimiento;

  Timbrado({
    this.id_timbrado,
    required this.timbrado,
    required this.inicio,
    required this.vencimiento,
    required this.estado,
    required this.fk_establecimiento,
  });

  factory Timbrado.fromMap(Map<String, dynamic> map) {
        return Timbrado(
          id_timbrado: map['id_timbrado'],
          timbrado: map['timbrado'],
          inicio: DateTime.parse(map['inicio']),
          vencimiento: DateTime.parse(map['vencimiento']),
          estado: map['estado'],
          fk_establecimiento: Establecimiento.fromMap(map['fk_establecimiento']),
        );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_timbrado': id_timbrado,
      'timbrado': timbrado,
      'inicio': inicio.toIso8601String(),
      'vencimiento': vencimiento.toIso8601String(),
      'estado': estado,
      'fk_establecimiento': fk_establecimiento.toMap(),
    };
  }
  
}
