import 'package:myapp/modelo/contabilidad/asiento.dart';
import 'package:myapp/modelo/contabilidad/cuenta_contable.dart';

class DetalleAsientos {
  int? id;
  CuentasContables cuentaContable;
  Asientos asiento;
  double debe;
  double haber;

  DetalleAsientos({
    this.id,
    required this.cuentaContable,
    required this.asiento,
    required this.debe,
    required this.haber,
  });

  factory DetalleAsientos.fromMap(Map<String, dynamic> map) {
    return DetalleAsientos(
      id: map['id'],
      cuentaContable: CuentasContables.fromMap(map['fk_cuenta_contables']),
      asiento: Asientos.fromMap(map['fk_asientos']),
      debe: (map['debe'] as num).toDouble(),
      haber: (map['haber'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fk_cuenta_contables': cuentaContable.toMap(),
      'fk_asientos': asiento.toMap(),
      'debe': debe,
      'haber': haber,
    };
  }
}