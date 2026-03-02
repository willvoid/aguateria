import 'package:myapp/modelo/facturacionmodelo/facturacion_payload.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/modelo/facturacionmodelo/detalle_factura.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/facturacionmodelo/apertura_cierre_caja.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';

class FacturaRpcService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Construye el payload desde los objetos del modelo
  FacturaPayload construirPayload({
    required Cliente cliente,
    required Inmuebles inmueble,
    required Establecimiento establecimiento,
    required ModoPago modoPago,
    required Moneda moneda,
    required TipoFactura tipoFactura,
    required AperturaCierreCaja cajaAbierta,
    required int condicionVenta,
    required double totalGravado10,
    required double totalGravado5,
    required double totalExenta,
    required double totalIva,
    required double totalGeneral,
    required String? observacion,
    required int nroSecuencial,
    required double efectivo,
    required double vuelto,
    required double descuentoGlobal,
    required List<DetalleFactura> detalles,
  }) {
    return FacturaPayload(
      // Agregar zona horaria UTC al timestamp
      fechaEmision: DateTime.now().toUtc().toIso8601String(),
      fkCliente: cliente.idCliente!,
      fkInmueble: inmueble.id!,
      condicionVenta: condicionVenta,
      // Redondear a 2 decimales para evitar problemas de precisión
      totalGravado10: double.parse(totalGravado10.toStringAsFixed(2)),
      totalGravado5: double.parse(totalGravado5.toStringAsFixed(2)),
      totalExenta: double.parse(totalExenta.toStringAsFixed(2)),
      totalIva: double.parse(totalIva.toStringAsFixed(2)),
      totalGeneral: double.parse(totalGeneral.toStringAsFixed(2)),
      observacion: observacion?.isEmpty ?? true ? null : observacion,
      fkMonedas: moneda.id_monedas!,
      fkEstablecimientos: establecimiento.id_establecimiento!,
      fkModoPago: modoPago.id_modo_pago!,
      fkTipoFactura: tipoFactura.id_tipo_factura!,
      nroSecuencial: nroSecuencial,
      fkTurno: cajaAbierta.id_turno!,
      tipoEmision: 1,
      efectivo: efectivo,
      vuelto: vuelto,
      descuentoGlobal: descuentoGlobal,
      detalles: detalles.map((detalle) {
        return DetallePayload(
          fkConcepto: detalle.fk_concepto.id!,
          monto: detalle.monto,
          descripcion: detalle.descripcion,
          ivaAplicado: detalle.iva_aplicado,
          subtotal: detalle.subtotal,
          estado: detalle.estado,
          cantidad: detalle.cantidad,
          fkCiclo: detalle.fk_ciclo?.id,
          fkDeudas: null, // Ajusta según tu lógica
          fkConsumos: null, // Ajusta según tu lógica
        );
      }).toList(),
    );
  }

  /// Valida el payload antes de enviarlo
  void validarPayload(FacturaPayload payload) {
    // Validar cabecera
    if (payload.fkCliente <= 0) {
      throw Exception('ID de cliente inválido');
    }
    if (payload.fkInmueble <= 0) {
      throw Exception('ID de inmueble inválido');
    }
    if (payload.totalGeneral <= 0) {
      throw Exception('Total general debe ser mayor a 0');
    }
    /*if (payload.efectivo < payload.totalGeneral) {
      throw Exception('El efectivo debe ser mayor o igual al total');
    }*/
    
    // Validar detalles
    if (payload.detalles.isEmpty) {
      throw Exception('Debe incluir al menos un detalle');
    }
    
    for (var i = 0; i < payload.detalles.length; i++) {
      final detalle = payload.detalles[i];
      if (detalle.fkConcepto <= 0) {
        throw Exception('Detalle ${i + 1}: ID de concepto inválido');
      }
      if (detalle.cantidad <= 0) {
        throw Exception('Detalle ${i + 1}: Cantidad debe ser mayor a 0');
      }
      if (detalle.monto < 0) {
        throw Exception('Detalle ${i + 1}: Monto no puede ser negativo');
      }
    }
  }

  /// Guarda una factura con sus detalles usando RPC
  /// Retorna un Map con la factura completa creada
  Future<Map<String, dynamic>> guardarFacturaRpc(FacturaPayload payload) async {
    try {
      // Validar el payload antes de enviar
      validarPayload(payload);
      
      // Convertir el payload a JSON
      final json = payload.toJson();

      print('📦 Payload a enviar:');
      print(json);

      // Llamar a la función RPC de Supabase
      // IMPORTANTE: El nombre de la función es 'crear_factura_completa'
      final response = await _supabase.rpc(
        'crear_factura_completa',
        params: {'payload': json}, // La función espera un parámetro llamado 'payload'
      );

      print('✅ Respuesta de Supabase:');
      print(response);

      // La función RPC retorna to_jsonb(f) - un objeto completo de la factura
      if (response == null) {
        throw Exception('La respuesta de Supabase es nula');
      }

      // Convertir la respuesta a Map
      Map<String, dynamic> facturaCreada;
      
      if (response is Map<String, dynamic>) {
        facturaCreada = response;
      } else if (response is List && response.isNotEmpty) {
        facturaCreada = response.first as Map<String, dynamic>;
      } else {
        throw Exception('Formato de respuesta inesperado: ${response.runtimeType}');
      }

      // Verificar que tenga el ID
      if (!facturaCreada.containsKey('id_factura')) {
        throw Exception('La respuesta no contiene id_factura');
      }

      print('✅ Factura creada con ID: ${facturaCreada['id_factura']}');
      
      return facturaCreada;
    } on PostgrestException catch (e) {
      print('❌ Error de Supabase: ${e.message}');
      print('   Código: ${e.code}');
      print('   Detalles: ${e.details}');
      print('   Hint: ${e.hint}');
      
      // Proporcionar mensajes más amigables según el error
      String mensajeError = e.message;
      if (e.message.contains('foreign key')) {
        mensajeError = 'Error de referencia: Verifique que cliente, inmueble y establecimiento existan';
      } else if (e.message.contains('not null')) {
        mensajeError = 'Faltan datos obligatorios en la factura';
      } else if (e.message.contains('duplicate')) {
        mensajeError = 'Ya existe una factura con ese número secuencial';
      }
      
      throw Exception(mensajeError);
    } catch (e) {
      print('❌ Error inesperado: $e');
      throw Exception('Error inesperado al guardar factura: $e');
    }
  }

  /// Extrae el ID de la factura de la respuesta
  int? extraerIdFactura(Map<String, dynamic> facturaCreada) {
    try {
      final id = facturaCreada['id_factura'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
      return null;
    } catch (e) {
      print('⚠️ Error al extraer ID: $e');
      return null;
    }
  }

  /// Formatea el número de factura con el formato establecimiento-tipo-secuencial
  String formatearNumeroFactura(Map<String, dynamic> factura) {
    try {
      final establecimiento = factura['fk_establecimientos']?.toString().padLeft(3, '0') ?? '001';
      final tipo = factura['fk_tipo_factura']?.toString().padLeft(3, '0') ?? '001';
      final secuencial = factura['nro_secuencial']?.toString().padLeft(7, '0') ?? '0000001';
      return '$establecimiento-$tipo-$secuencial';
    } catch (e) {
      return 'N/A';
    }
  }
}