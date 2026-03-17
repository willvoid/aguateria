import 'package:myapp/modelo/contabilidad/cuenta_contable.dart';

class SaldosMensuales {
  int? id;
  CuentasContables cuenta;
  int mes;
  int anio;
  double saldoDebeAcumulado;
  double saldoHaberAcumulado;
  double saldoFinal;

  SaldosMensuales({
    this.id,
    required this.cuenta,
    required this.mes,
    required this.anio,
    required this.saldoDebeAcumulado,
    required this.saldoHaberAcumulado,
    required this.saldoFinal,
  });

  factory SaldosMensuales.fromMap(Map<String, dynamic> map) {
    return SaldosMensuales(
      id: map['id'],
      cuenta: CuentasContables.fromMap(map['fk_cuenta']),
      mes: map['mes'],
      anio: map['anio'],
      saldoDebeAcumulado: (map['saldo_debe_acumulado'] as num).toDouble(),
      saldoHaberAcumulado: (map['saldo_haber_acumulado'] as num).toDouble(),
      saldoFinal: (map['saldo_final'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fk_cuenta': cuenta.toMap(),
      'mes': mes,
      'anio': anio,
      'saldo_debe_acumulado': saldoDebeAcumulado,
      'saldo_haber_acumulado': saldoHaberAcumulado,
      'saldo_final': saldoFinal,
    };
  }
}