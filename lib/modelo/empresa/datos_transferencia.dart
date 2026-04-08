import 'package:myapp/modelo/empresa/establecimiento.dart';

class DatosTransferencia {
  int id;
  String? alias;
  String titular_cuenta;
  String banco;
  String ci;
  String num_cuenta;
  Establecimiento fk_sucursal;
  String? nro_giro;
  String? ci_giro;

  DatosTransferencia({
    required this.id,
    this.alias,
    required this.titular_cuenta,
    required this.banco,
    required this.ci,
    required this.num_cuenta,
    required this.fk_sucursal,
    this.nro_giro,
    this.ci_giro
  });

  factory DatosTransferencia.fromMap(Map<String, dynamic> json) {
    return DatosTransferencia(
      id: json['id'],
      alias: json['alias'],
      titular_cuenta: json['titular_cuenta'],
      banco: json['banco'],
      ci: json['ci'],
      num_cuenta: json['num_cuenta'],
      fk_sucursal: Establecimiento.fromMap(json['fk_sucursal']),
      nro_giro: json['nro_giro'],
      ci_giro: json['ci_giro'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'alias': alias,
      'titular_cuenta': titular_cuenta,
      'banco': banco,
      'ci': ci,
      'num_cuenta': num_cuenta,
      'fk_sucursal': fk_sucursal.toMap(),
      'nro_giro': nro_giro,
      'ci_giro': ci_giro,
    };
  }
}
