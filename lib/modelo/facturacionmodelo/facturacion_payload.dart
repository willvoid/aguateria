// Modelo para el payload de la factura RPC
class FacturaPayload {
  // Campos de cabecera
  final String fechaEmision;
  final int fkCliente;
  final int fkInmueble;
  final int condicionVenta;
  final double totalGravado10;
  final double totalGravado5;
  final double totalExenta;
  final double totalIva;
  final double totalGeneral;
  final String? observacion;
  final int fkMonedas;
  final int fkEstablecimientos;
  final int fkModoPago;
  final int fkTipoFactura;
  final int nroSecuencial;
  final int fkTurno;
  final int tipoEmision;
  final int? fkMotivo;
  final int? fkFacturaAsociada;
  final double efectivo;
  final double vuelto;
  final double descuentoGlobal;
  
  // Lista de detalles
  final List<DetallePayload> detalles;

  FacturaPayload({
    required this.fechaEmision,
    required this.fkCliente,
    required this.fkInmueble,
    required this.condicionVenta,
    required this.totalGravado10,
    required this.totalGravado5,
    required this.totalExenta,
    required this.totalIva,
    required this.totalGeneral,
    this.observacion,
    required this.fkMonedas,
    required this.fkEstablecimientos,
    required this.fkModoPago,
    required this.fkTipoFactura,
    required this.nroSecuencial,
    required this.fkTurno,
    required this.tipoEmision,
    this.fkMotivo,
    this.fkFacturaAsociada,
    required this.efectivo,
    required this.vuelto,
    required this.descuentoGlobal,
    required this.detalles,
  });

  Map<String, dynamic> toJson() {
    return {
      'fecha_emision': fechaEmision, // Ya debe venir en formato ISO8601 con zona horaria
      'fk_cliente': fkCliente,
      'fk_inmueble': fkInmueble,
      'condicion_venta': condicionVenta,
      'total_gravado_10': totalGravado10,
      'total_gravado_5': totalGravado5,
      'total_exenta': totalExenta,
      'total_iva': totalIva,
      'total_general': totalGeneral,
      'observacion': observacion,
      'fk_monedas': fkMonedas,
      'fk_establecimientos': fkEstablecimientos,
      'fk_modo_pago': fkModoPago,
      'fk_tipo_factura': fkTipoFactura,
      'nro_secuencial': nroSecuencial,
      'fk_turno': fkTurno,
      'tipo_emision': tipoEmision,
      'fk_motivo': fkMotivo,
      'fk_factura_asociada': fkFacturaAsociada,
      'efectivo': efectivo,
      'vuelto': vuelto,
      'descuento_global': descuentoGlobal,
      'detalles': detalles.map((d) => d.toJson()).toList(),
    };
  }
}

class DetallePayload {
  final int fkConcepto;
  final double monto;
  final String descripcion;
  final int ivaAplicado;
  final double subtotal;
  final String estado;
  final double cantidad;
  final int? fkCiclo;
  final int? fkDeudas;
  final int? fkConsumos;

  DetallePayload({
    required this.fkConcepto,
    required this.monto,
    required this.descripcion,
    required this.ivaAplicado,
    required this.subtotal,
    required this.estado,
    required this.cantidad,
    this.fkCiclo,
    this.fkDeudas,
    this.fkConsumos,
  });

  Map<String, dynamic> toJson() {
    return {
      'fk_concepto': fkConcepto,
      'monto': monto,
      'descripcion': descripcion,
      'iva_aplicado': ivaAplicado,
      'subtotal': subtotal,
      'estado': estado,
      'cantidad': cantidad,
      'fk_ciclo': fkCiclo,
      'fk_deudas': fkDeudas,
      'fk_consumos': fkConsumos,
    };
  }
}