import 'package:myapp/modelo/empresa/caja.dart';
import 'package:myapp/modelo/usuario/usuario.dart';

class AperturaCierreCaja {
  int? id_turno;
  DateTime apertura;
  DateTime? cierre;
  double monto_inicial;
  double monto_final;
  Usuario fk_usuario;
  Caja fk_caja;

  AperturaCierreCaja({
    this.id_turno,
    required this.apertura,
    this.cierre,
    required this.monto_inicial,
    required this.monto_final,
    required this.fk_usuario,
    required this.fk_caja,
  });

  factory AperturaCierreCaja.fromMap(Map<String, dynamic> map) {
    return AperturaCierreCaja(
      id_turno: map['id_turno'],
      apertura: DateTime.parse(map['apertura']),
      cierre: map['cierre'] != null ? DateTime.parse(map['cierre']) : null,
      monto_inicial: map['monto_inicial'],
      monto_final: map['monto_final'],
      fk_usuario: Usuario.fromMap(map['fk_usuario']),
      fk_caja: Caja.fromMap(map['fk_caja']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_turno': id_turno,
      'apertura': apertura.toIso8601String(),
      'cierre': cierre?.toIso8601String(),
      'monto_inicial': monto_inicial,
      'monto_final': monto_final,
      'fk_usuario': fk_usuario.toMap(),
      'fk_caja': fk_caja.toMap(),
    };
  }
}
