import 'package:myapp/modelo/consumo.dart';
import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/facturacionmodelo/factura.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';

class DetalleFactura {
  int? id_detalle;
  Factura? fk_factura; // Nullable
  Concepto fk_concepto;
  double monto;
  String descripcion;
  int iva_aplicado;
  double subtotal;
  String estado;
  double cantidad;
  Consumo? fk_consumos;
  CuentaCobrar? fk_deudas;
  Ciclo? fk_ciclo; // Solo para consumos

  DetalleFactura({
    this.id_detalle,
    this.fk_factura, // YA NO ES REQUIRED - opcional
    required this.fk_concepto,
    required this.monto,
    required this.descripcion,
    required this.iva_aplicado,
    required this.subtotal,
    required this.estado,
    required this.cantidad,
    this.fk_consumos,
    this.fk_deudas,
    this.fk_ciclo,
  });

  factory DetalleFactura.fromMap(Map<String, dynamic> map) {
    return DetalleFactura(
      id_detalle: map['id_detalle'],
      fk_factura: map['fk_factura'] != null
          ? Factura.fromMap(map['fk_factura'])
          : null,
      fk_concepto: Concepto.fromMap(map['fk_concepto']),
      monto: map['monto'],
      descripcion: map['descripcion'],
      iva_aplicado: map['iva_aplicado'],
      subtotal: map['subtotal'],
      estado: map['estado'],
      cantidad: map['cantidad'],
      fk_consumos: map['fk_consumos'] != null
          ? Consumo.fromMap(map['fk_consumos'])
          : null,
      fk_deudas: map['fk_deudas'] != null
          ? CuentaCobrar.fromMap(map['fk_deudas'])
          : null,
      fk_ciclo: map['fk_ciclo'] != null ? Ciclo.fromMap(map['fk_ciclo']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_detalle': id_detalle,
      'fk_factura': fk_factura?.toMap(),
      'fk_concepto': fk_concepto.toMap(),
      'monto': monto,
      'descripcion': descripcion,
      'iva_aplicado': iva_aplicado,
      'subtotal': subtotal,
      'estado': estado,
      'cantidad': cantidad,
      'fk_consumos': fk_consumos?.toMap(),
      'fk_deudas': fk_deudas?.toMap(),
      'fk_ciclo': fk_ciclo?.toMap(),
    };
  }

  // Método útil para copiar con una factura asignada
  DetalleFactura copyWith({
    int? id_detalle,
    Factura? fk_factura,
    Concepto? fk_concepto,
    double? monto,
    String? descripcion,
    int? iva_aplicado,
    double? subtotal,
    String? estado,
    double? cantidad,
    Consumo? fk_consumos,
    CuentaCobrar? fk_deudas,
    Ciclo? fk_ciclo,
  }) {
    return DetalleFactura(
      id_detalle: id_detalle ?? this.id_detalle,
      fk_factura: fk_factura ?? this.fk_factura,
      fk_concepto: fk_concepto ?? this.fk_concepto,
      monto: monto ?? this.monto,
      descripcion: descripcion ?? this.descripcion,
      iva_aplicado: iva_aplicado ?? this.iva_aplicado,
      subtotal: subtotal ?? this.subtotal,
      estado: estado ?? this.estado,
      cantidad: cantidad ?? this.cantidad,
      fk_consumos: fk_consumos ?? this.fk_consumos,
      fk_deudas: fk_deudas ?? this.fk_deudas,
      fk_ciclo: fk_ciclo ?? this.fk_ciclo,
    );
  }
}
