import 'package:myapp/modelo/empresa/establecimiento.dart';

class Asientos {
  int? id;
  DateTime fecha;
  String descripcion;
  int nroAsiento;
  Establecimiento sucursal;
  String estado;
  String? origenTipo;
  int? fkOrigen;

  Asientos({
    this.id,
    required this.fecha,
    required this.descripcion,
    required this.nroAsiento,
    required this.sucursal,
    required this.estado,
    this.origenTipo,
    this.fkOrigen,
  });

  factory Asientos.fromMap(Map<String, dynamic> map) {
    return Asientos(
      id: map['id'],
      fecha: DateTime.parse(map['fecha']),
      descripcion: map['descripcion'],
      nroAsiento: map['nro_asiento'],
      sucursal: Establecimiento.fromMap(map['fk_sucursal']),
      estado: map['estado'],
      origenTipo: map['origen_tipo'],
      fkOrigen: map['fk_origen'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'descripcion': descripcion,
      'nro_asiento': nroAsiento,
      'fk_sucursal': sucursal.toMap(),
      'estado': estado,
      'origen_tipo': origenTipo,
      'fk_origen': fkOrigen,
    };
  }
}