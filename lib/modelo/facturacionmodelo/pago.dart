import 'package:myapp/modelo/facturacionmodelo/factura.dart';
import 'package:myapp/modelo/usuario/usuario.dart';

class Pago {
  int? idPago; // CamelCase es estándar en Dart
  DateTime? fechaPago; // Debe ser nullable o tener valor por defecto
  Factura? factura; // Renombrado para indicar que es el OBJETO, no el ID
  String? comprobanteUrl;
  double monto;
  String estado;
  Map<String, dynamic>? payloadCreacion;
  Usuario? usuario; // Renombrado para indicar objeto
  String? motivoRechazo; // CRÍTICO: Debe ser nullable

  Pago({
    this.idPago,
    this.fechaPago,
    this.factura,
    this.comprobanteUrl,
    required this.monto,
    this.estado = 'PENDIENTE', // Valor por defecto útil
    this.payloadCreacion,
    this.usuario,
    this.motivoRechazo,
  });

  factory Pago.fromMap(Map<String, dynamic> map) {
    return Pago(
      idPago: map['id_pago'],
      // Supabase devuelve fechas como String ISO8601
      fechaPago: map['fecha_pago'] != null 
          ? DateTime.parse(map['fecha_pago']) 
          : null,
      
      // CRÍTICO: Verificación de nulos antes de convertir a Objeto
      // Asume que haces un select con join: .select('*, facturas(*), usuario(*)')
      // Nota: Supabase suele devolver la relación con el nombre de la tabla, no el fk.
      // Si tu query es normal, esto vendrá como 'facturas': {...}
      factura: map['facturas'] != null 
          ? Factura.fromMap(map['facturas']) 
          : null,
      
      comprobanteUrl: map['comprobante_url'],
      
      // CRÍTICO: Seguridad de tipos (int a double)
      monto: (map['monto'] as num).toDouble(), 
      
      estado: map['estado'] ?? 'PENDIENTE',
      
      // Casting explícito necesario para JSONB
      payloadCreacion: map['payload_creacion'] as Map<String, dynamic>?,
      
      usuario: map['usuario'] != null 
          ? Usuario.fromMap(map['usuario']) 
          : null,
          
      motivoRechazo: map['motivo_rechazo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // 'id_pago': idPago, // Generalmente no se envía al insertar
      if (fechaPago != null) 'fecha_pago': fechaPago!.toIso8601String(),
      // Al enviar a la BD, no envías el objeto Factura entero, envías el ID si lo tienes.
      // Pero como en tu flujo el pago nace sin factura, esto suele ir nulo.
      if (factura?.id_factura != null) 'fk_factura': factura!.id_factura,
      
      'comprobante_url': comprobanteUrl,
      'monto': monto,
      'estado': estado,
      'payload_creacion': payloadCreacion,
      
      if (usuario?.id_usuario != null) 'fk_usuario': usuario!.id_usuario,
      'motivo_rechazo': motivoRechazo,
    };
  }
}