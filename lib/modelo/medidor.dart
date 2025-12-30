import 'package:myapp/modelo/inmuebles.dart';

class Medidor {
  int? idMedidor;
  String nro;
  DateTime fechaInstalacion;
  String estado;
  Inmuebles inmueble;

  Medidor({
    this.idMedidor,
    required this.nro,
    required this.fechaInstalacion,
    required this.estado,
    required this.inmueble,
  });

  factory Medidor.fromMap(Map<String, dynamic> map) {
    return Medidor(
      idMedidor: map['id_medidor'],
      nro: map['nro'],
      fechaInstalacion: map['fecha_instalacion'] != null
          ? DateTime.parse(map['fecha_instalacion'])
          : DateTime.now(),
      estado: map['estado'],
      inmueble: Inmuebles.fromMap(map['fk_inmueble']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_medidor': idMedidor,
      'nro': nro,
      'fecha_instalacion': fechaInstalacion.toIso8601String(),
      'estado': estado,
      'fk_inmueble': inmueble.toMap(),
    };
  }
}
