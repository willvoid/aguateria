import 'package:flutter/foundation.dart';
import 'package:myapp/modelo/consumo.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/inmuebles.dart';

class CuentaCobrar {
  int? id_deuda;
  Concepto fk_concepto;
  String descripcion;
  double monto;
  String estado;
  Ciclo? fk_ciclos;
  Inmuebles fk_inmueble;
  double saldo;
  double pagado;
  Consumo? fk_consumos;

  CuentaCobrar({
    required this.fk_concepto,
    required this.descripcion,
    required this.monto,
    required this.estado,
    required this.fk_ciclos,
    required this.fk_inmueble,
    required this.saldo,
    required this.pagado,
    required this.fk_consumos,
    this.id_deuda,
  });

  factory CuentaCobrar.fromMap(Map<String, dynamic> map) {
    return CuentaCobrar(
      fk_concepto: Concepto.fromMap(map['fk_concepto']),
      descripcion: map['descripcion'],
      monto: map['monto'],
      estado: map['estado'],
      fk_ciclos: Ciclo.fromMap(map['fk_ciclos']),
      fk_inmueble: Inmuebles.fromMap(map['fk_inmueble']),
      saldo: map['saldo'],
      pagado: map['pagado'],
      fk_consumos: Consumo.fromMap(map['fk_consumos']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_deuda': id_deuda,
      'fk_concepto': fk_concepto.toMap(),
      'descripcion': descripcion,
      'monto': monto,
      'estado': estado,
      'fk_ciclos': fk_ciclos?.toMap(),
      'fk_inmueble': fk_inmueble.toMap(),
      'saldo': saldo,
      'pagado': pagado,
      'fk_consumos': fk_consumos?.toMap(),
    };
  }
}
