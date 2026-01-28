/// Helper para construir el payload_creacion correcto para pagos pendientes
/// Este payload debe contener TODA la información necesaria para generar la factura
/// cuando el administrador apruebe el pago

import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/inmuebles.dart';

class PayloadBuilder {
  /// Construye el payload completo para crear un pago de transferencia/giro
  /// 
  /// Este payload se guardará en el campo `payload_creacion` del pago
  /// y será usado por la función RPC cuando el admin apruebe el pago
  static Map<String, dynamic> construirPayloadPagoDeuda({
    required CuentaCobrar deuda,
    required Cliente cliente,
    required Inmuebles inmueble,
    required List<Ciclo> ciclosSeleccionados,
    required double totalAPagar,
    required double totalGravado,
    required double totalIva,
    required int idUsuario,
    required int idTurnoActual, // IMPORTANTE: Pasar el turno activo del usuario
    int idEstablecimiento = 1, // Por defecto 1, ajustar según tu app
    int idMoneda = 1, // Por defecto 1 (Guaraníes)
    int idTipoFactura = 1, // Por defecto 1, ajustar según tu app
    int idModoPago = 5, // 5 = Transferencia, ajustar según corresponda
  }) {
    // Calcular totales según IVA
    final ivaValor = deuda.fk_concepto.fk_iva.valor;
    double totalGravado10 = 0;
    double totalGravado5 = 0;
    double totalExenta = 0;
    
    if (ivaValor == 10) {
      // Si es IVA 10%, separar la base gravada
      totalGravado10 = totalGravado;
    } else if (ivaValor == 5) {
      // Si es IVA 5%, separar la base gravada
      totalGravado5 = totalGravado;
    } else {
      // Si no tiene IVA, es exenta
      totalExenta = totalAPagar;
    }
    
    // Construir detalles de la factura
    final detalles = _construirDetalles(
      deuda: deuda,
      ciclosSeleccionados: ciclosSeleccionados,
      totalAPagar: totalAPagar,
      totalGravado: totalGravado,
      ivaValor: ivaValor,
    );
    
    // ESTRUCTURA COMPLETA DEL PAYLOAD
    return {
      // ========== CAMPOS REQUERIDOS DE LA FACTURA ==========
      'fk_cliente': cliente.idCliente,
      'fk_inmueble': inmueble.id,
      'condicion_venta': 1, // 1 = Contado (siempre para pagos de deudas)
      
      // ========== TOTALES ==========
      'total_gravado_10': totalGravado10,
      'total_gravado_5': totalGravado5,
      'total_exenta': totalExenta,
      'total_iva': totalIva,
      'total_general': totalAPagar,
      
      // ========== INFORMACIÓN DEL PAGO ==========
      'observacion': _construirObservacion(deuda, ciclosSeleccionados),
      'fk_monedas': idMoneda,
      'fk_establecimientos': idEstablecimiento,
      'fk_modo_pago': idModoPago,
      'fk_tipo_factura': idTipoFactura,
      'nro_secuencial': 0, // Se asignará automáticamente
      'fk_turno': idTurnoActual, // CRÍTICO: El turno debe estar activo
      'tipo_emision': 1, // 1 = Normal
      'fk_motivo': null,
      'fk_factura_asociada': null,
      
      // ========== MONTOS DE PAGO ==========
      'efectivo': 0, // Para transferencias siempre 0
      'vuelto': 0, // Para transferencias siempre 0
      'descuento_global': 0,
      
      // ========== DETALLES DE LA FACTURA ==========
      'detalles': detalles,
      
      // ========== INFORMACIÓN ADICIONAL (ÚTIL PARA AUDITORÍA) ==========
      'metadata': {
        'deuda_id': deuda.id_deuda,
        'concepto_id': deuda.fk_concepto.id,
        'concepto_nombre': deuda.fk_concepto.nombre,
        'cliente_nombre': cliente.razonSocial,
        'inmueble_codigo': inmueble.cod_inmueble,
        'usuario_creador_id': idUsuario,
        'fecha_creacion_pago': DateTime.now().toIso8601String(),
        'ciclos_seleccionados': ciclosSeleccionados.map((c) => {
          'id': c.id,
          'descripcion': c.descripcion,
          'anio': c.anio,
          'ciclo': c.ciclo,
        }).toList(),
      },
    };
  }
  
  /// Construye los detalles de la factura
  static List<Map<String, dynamic>> _construirDetalles({
    required CuentaCobrar deuda,
    required List<Ciclo> ciclosSeleccionados,
    required double totalAPagar,
    required double totalGravado,
    required int ivaValor,
  }) {
    final esConsumo = deuda.fk_concepto.id == 1;
    
    if (esConsumo && ciclosSeleccionados.isNotEmpty) {
      // Para consumo: un detalle por cada ciclo
      return ciclosSeleccionados.map((ciclo) {
        final montoPorCiclo = deuda.fk_concepto.arancel;
        final subtotal = montoPorCiclo;
        
        return {
          'fk_concepto': deuda.fk_concepto.id,
          'monto': montoPorCiclo,
          'descripcion': '${deuda.fk_concepto.nombre} - ${ciclo.descripcion}',
          'iva_aplicado': ivaValor,
          'subtotal': subtotal,
          'estado': 'PENDIENTE',
          'cantidad': 1.0,
          'fk_consumos': null, // Se puede vincular si existe
          'fk_deudas': deuda.id_deuda,
          'fk_ciclo': ciclo.id,
        };
      }).toList();
    } else {
      // Para otros conceptos: un solo detalle
      return [
        {
          'fk_concepto': deuda.fk_concepto.id,
          'monto': totalAPagar,
          'descripcion': deuda.descripcion ?? deuda.fk_concepto.nombre,
          'iva_aplicado': ivaValor,
          'subtotal': totalAPagar,
          'estado': 'PENDIENTE',
          'cantidad': 1.0,
          'fk_consumos': null,
          'fk_deudas': deuda.id_deuda,
          'fk_ciclo': null,
        }
      ];
    }
  }
  
  /// Construye una observación descriptiva
  static String _construirObservacion(
    CuentaCobrar deuda,
    List<Ciclo> ciclosSeleccionados,
  ) {
    final esConsumo = deuda.fk_concepto.id == 1;
    
    if (esConsumo && ciclosSeleccionados.isNotEmpty) {
      final ciclosTexto = ciclosSeleccionados
          .map((c) => 'Ciclo ${c.ciclo}/${c.anio}')
          .join(', ');
      return 'Pago de ${deuda.fk_concepto.nombre} - $ciclosTexto - Aprobación de Transferencia';
    } else {
      return 'Pago de ${deuda.fk_concepto.nombre} - Aprobación de Transferencia';
    }
  }
  
  /// Valida que el payload tenga todos los campos requeridos
  static Map<String, dynamic> validarPayload(Map<String, dynamic> payload) {
    final camposRequeridos = {
      'fk_cliente': 'Cliente',
      'fk_inmueble': 'Inmueble',
      'condicion_venta': 'Condición de venta',
      'total_general': 'Total general',
      'fk_monedas': 'Moneda',
      'fk_establecimientos': 'Establecimiento',
      'fk_modo_pago': 'Modo de pago',
      'fk_tipo_factura': 'Tipo de factura',
      'fk_turno': 'Turno',
      'tipo_emision': 'Tipo de emisión',
      'detalles': 'Detalles',
    };
    
    final camposFaltantes = <String>[];
    final camposInvalidos = <String, String>{};
    
    for (final entry in camposRequeridos.entries) {
      if (!payload.containsKey(entry.key) || payload[entry.key] == null) {
        camposFaltantes.add(entry.value);
      }
      
      // Validaciones específicas
      if (entry.key == 'fk_turno' && payload[entry.key] == null) {
        camposInvalidos[entry.value] = 'No hay un turno activo';
      }
      
      if (entry.key == 'detalles') {
        if (payload[entry.key] is! List || (payload[entry.key] as List).isEmpty) {
          camposInvalidos[entry.value] = 'Los detalles no pueden estar vacíos';
        }
      }
    }
    
    return {
      'valido': camposFaltantes.isEmpty && camposInvalidos.isEmpty,
      'campos_faltantes': camposFaltantes,
      'campos_invalidos': camposInvalidos,
    };
  }
}