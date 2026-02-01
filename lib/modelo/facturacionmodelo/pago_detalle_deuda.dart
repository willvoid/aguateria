import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/facturacionmodelo/pago.dart';

class PagoDetalleDeuda {
  int? id;
  Pago fk_pago;
  CuentaCobrar fk_deuda;
  double monto_aplicado;

  PagoDetalleDeuda({
    this.id,
    required this.fk_pago,
    required this.fk_deuda,
    required this.monto_aplicado,
  });

  factory PagoDetalleDeuda.fromMap(Map<String, dynamic> map) {
    return PagoDetalleDeuda(
      id: map['id'],
      fk_pago: Pago.fromMap(map['fk_pago']),
      fk_deuda: CuentaCobrar.fromMap(map['fk_deuda']),
      monto_aplicado: map['monto_aplicado'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fk_pago': fk_pago.toMap(),
      'fk_deuda': fk_deuda.toMap(),
      'monto_aplicado': monto_aplicado,
    };
  }

}
