import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/facturacionmodelo/apertura_cierre_caja.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:myapp/modelo/facturacionmodelo/motivo_emision.dart';
import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';
import 'package:myapp/modelo/inmuebles.dart';

class Factura {
  int? id_factura;
  DateTime fecha_emision; //En la BD se guarda automaticamente al crearse
  Cliente fk_cliente;
  Inmuebles fk_inmueble;
  int codicion_venta; //Contado, credito
  double total_gravado_10;
  double total_gravado_5; //Estos campos deben ser calculados en el backend
  double total_exenta;
  double total_iva;
  double total_general;
  String observacion; //Mensaje generico de la factura
  Moneda fk_monedas;
  Establecimiento fk_establecimientos;
  ModoPago fk_modo_pago;
  TipoFactura fk_tipo_factura;
  int nro_secuencial; //Numero autoincrementable de la factura
  AperturaCierreCaja
  fk_turno; //Antes de poder ingresar para crear una factura nueva hay que asegurarse que hay una caja activa con ese usuario sino a crear el registro
  int tipo_emision; //Emision normal (1), Emision en contingencia (2)
  MotivoEmision? fk_motivo; //Si el tipo de factura es nota de credito o debito
  Factura?
  fk_factura_asociada; //Si el tipo de factura es nota de credito o debito
  double efectivo;
  double vuelto;
  double descuento_global;

  Factura({
    this.id_factura,
    required this.fk_inmueble,
    required this.fecha_emision,
    required this.fk_cliente,
    required this.codicion_venta,
    required this.total_gravado_10,
    required this.total_gravado_5,
    required this.total_exenta,
    required this.total_iva,
    required this.total_general,
    required this.observacion,
    required this.fk_monedas,
    required this.fk_establecimientos,
    required this.fk_modo_pago,
    required this.fk_tipo_factura,
    required this.nro_secuencial,
    required this.fk_turno,
    required this.tipo_emision,
    this.fk_motivo,
    this.fk_factura_asociada,
    required this.efectivo,
    required this.vuelto,
    required this.descuento_global,
  });

  factory Factura.fromMap(Map<String, dynamic> map) {
    return Factura(
      id_factura: map['id_factura'],
      fecha_emision: DateTime.parse(map['fecha_emision']),
      fk_cliente: Cliente.fromMap(map['fk_cliente']),
      fk_inmueble: Inmuebles.fromMap(map['fk_inmueble']),
      codicion_venta: map['codicion_venta'],
      total_gravado_10: map['total_gravado_10'],
      total_gravado_5: map['total_gravado_5'],
      total_exenta: map['total_exenta'],
      total_iva: map['total_iva'],
      total_general: map['total_general'],
      observacion: map['observacion'],
      fk_monedas: Moneda.fromMap(map['fk_monedas']),
      fk_establecimientos: Establecimiento.fromMap(map['fk_establecimientos']),
      fk_modo_pago: ModoPago.fromMap(map['fk_modo_pago']),
      fk_tipo_factura: TipoFactura.fromMap(map['fk_tipo_factura']),
      nro_secuencial: map['nro_secuencial'],
      fk_turno: AperturaCierreCaja.fromMap(map['fk_turno']),
      tipo_emision: map['tipo_emision'],
      fk_motivo: map['fk_motivo'] != null
          ? MotivoEmision.fromMap(map['fk_motivo'])
          : null,
      fk_factura_asociada: map['fk_factura_asociada'] != null
          ? Factura.fromMap(map['fk_factura_asociada'])
          : null,
      efectivo: map['efectivo'],
      vuelto: map['vuelto'],
      descuento_global: map['descuento_global'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_factura': id_factura,
      'fecha_emision': fecha_emision.toIso8601String(),
      'fk_cliente': fk_cliente.toMap(),
      'fk_inmueble': fk_inmueble.toMap(),
      'codicion_venta': codicion_venta,
      'total_gravado_10': total_gravado_10,
      'total_gravado_5': total_gravado_5,
      'total_exenta': total_exenta,
      'total_iva': total_iva,
      'total_general': total_general,
      'observacion': observacion,
      'fk_monedas': fk_monedas.toMap(),
      'fk_establecimientos': fk_establecimientos.toMap(),
      'fk_modo_pago': fk_modo_pago.toMap(),
      'fk_tipo_factura': fk_tipo_factura.toMap(),
      'nro_secuencial': nro_secuencial,
      'fk_turno': fk_turno.toMap(),
      'tipo_emision': tipo_emision,
      'fk_motivo': fk_motivo?.toMap(),
      'fk_factura_asociada': fk_factura_asociada?.toMap(),
      'efectivo': efectivo,
      'vuelto': vuelto,
      'descuento_global': descuento_global,
    };
  }
}
