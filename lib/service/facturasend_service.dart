import 'package:myapp/dao/facturaciondao/facturacrudimpl.dart';
import 'package:myapp/service/facturasend_resultado.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Flujo real: arma el documento SIFEN de una factura ya creada y lo manda
/// al edge function real `facturasend-enviar-factura`.
///
/// No toca el camino crítico de creación de facturas (`FacturaRpcService`,
/// RPC `crear_factura_completa`) — solo lee datos de una factura que ya
/// existe. Botón manual, no automático: ver `dialogo_exito_factura.dart`.
class FacturaSendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Arma el documento SIFEN de la factura [idFactura] reusando
  /// `get_factura_json_sifen` (la misma RPC que usa `TicketPrinterService`
  /// para imprimir el ticket), así el documento enviado nunca se
  /// desincroniza de lo que el usuario ve impreso.
  Future<Map<String, dynamic>> construirDocumentoDesdeFactura(
    int idFactura,
  ) async {
    // 1. RPC (misma fuente que el ticket impreso) y 2. lookup liviano de
    //    Cliente para los campos que faltan (FacturaCrudImpl.leerFacturaPorId
    //    ya hidrata fk_cliente) — son independientes. Se arrancan los dos
    //    antes de esperar (sin Future.wait: los tipos de retorno difieren y
    //    PostgrestFilterBuilder no infiere bien como Future<dynamic> ahí).
    final rpcFuture = _supabase.rpc(
      'get_factura_json_sifen',
      params: {'p_id_factura': idFactura},
    );
    final facturaFuture = FacturaCrudImpl().leerFacturaPorId(idFactura);
    final json = await rpcFuture;
    final factura = await facturaFuture;

    // Mismo guard que TicketPrinterService.obtenerTicket para esta misma RPC
    // (lib/service/ticket_printer_service.dart) — sin esto, un null acá
    // revienta más abajo con un NoSuchMethodError críptico en vez de un
    // mensaje claro.
    if (json == null || json['data'] == null) {
      throw Exception('No se obtuvo el documento SIFEN de la factura #$idFactura');
    }
    final data = Map<String, dynamic>.from(json['data']);

    if (factura == null) {
      throw Exception('No se pudo cargar la factura #$idFactura');
    }
    final cliente = factura.fk_cliente;

    // 3. Parches confirmados contra la API real de FacturaSend. La RPC
    // (v_factura_detalle_completo) no incluye numeroCasa en el bloque
    // cliente en absoluto — confirmado leyendo su SQL.
    final clienteData = Map<String, dynamic>.from(data['cliente']);
    clienteData['tipoOperacion'] =
        clienteData['contribuyente'] == true ? 1 : 2;
    clienteData['documentoTipo'] =
        cliente.tipoDocumento?.cod_tipo_documento ?? 1;
    clienteData['documentoNumero'] = cliente.documento;
    clienteData['numeroCasa'] = cliente.nroCasa.toString();
    clienteData['pais'] = 'PRY';
    clienteData['paisDescripcion'] = 'Paraguay';
    data['cliente'] = clienteData;

    data['tipoTransaccion'] =
        1; // TODO: confirmar si debería ser 2 (prestación de servicios) para agua
    data['tipoImpuesto'] = 1;
    data['factura'] = {'presencia': 1};

    // La RPC saca condicion.entregas de la tabla `pagos` (fk_factura), pero
    // esa tabla solo se llena en el flujo de pago de deudas
    // (pago_deuda_service.dart) — una factura normal al contado, creada vía
    // FacturaRpcService/crear_factura_completa, NUNCA inserta ahí; el monto
    // en efectivo queda directo en Factura.efectivo. Confirmado probando
    // contra una factura real: entregas vino vacío para el caso más común,
    // no para un caso raro. Si la RPC no trajo ninguna entrega, se arma una
    // sintética a partir de la factura ya cargada.
    //
    // El tipo de entrega se fuerza a 1 (efectivo) en los dos casos: la RPC
    // hardcodea 21 (su comentario dice "21 es efectivo en SIFEN"), pero
    // nuestra prueba real del PoC mostró que FacturaSend acepta tipo:1 — se
    // prioriza la evidencia empírica. Si en el futuro aparece un modo de
    // pago no-efectivo, esto necesita una tabla de mapeo real en vez de
    // forzar 1 (ver plan: hay una contradicción sin resolver en el codebase
    // sobre qué id de modo_pago es realmente "efectivo").
    final condicion = Map<String, dynamic>.from(data['condicion']);
    final entregasRaw = condicion['entregas'] as List?;
    final entregas = (entregasRaw == null || entregasRaw.isEmpty)
        ? [
            {
              'tipo': 1,
              'monto': factura.total_general.round().toString(),
              'moneda': 'PYG',
              'cambio': 0,
            },
          ]
        : entregasRaw
            .map((e) => {...Map<String, dynamic>.from(e), 'tipo': 1})
            .toList();
    condicion['entregas'] = entregas;
    data['condicion'] = condicion;

    // nro_secuencial=0 (numero "0000000") significa que la factura no tiene
    // secuencial asignado todavía — no debería pasar en una factura ya creada
    // por el flujo normal, pero se valida por las dudas.
    if (data['numero'] == '0000000') {
      throw Exception(
        'La factura #$idFactura no tiene número de secuencia asignado',
      );
    }

    return data; // 'params' de la RPC se descarta: no va en el body del documento
  }

  /// Envía la factura [idFactura] a FacturaSend a través del edge function
  /// real `facturasend-enviar-factura`. [qr] pide a FacturaSend que incluya
  /// el QR en la respuesta.
  Future<FacturaSendResultado> enviarFactura(
    int idFactura, {
    bool qr = false,
  }) async {
    final documento = await construirDocumentoDesdeFactura(idFactura);

    try {
      final res = await _supabase.functions.invoke(
        'facturasend-enviar-factura',
        body: {'idFactura': idFactura, 'documento': documento, 'qr': qr},
      );
      return FacturaSendResultado.fromInvokeResponse(res.data);
    } on FunctionException catch (e) {
      return FacturaSendResultado(
        ok: false,
        error:
            'Error del edge function (${e.status}): ${e.details ?? e.reasonPhrase}',
      );
    } catch (e) {
      return FacturaSendResultado(
        ok: false,
        error: 'Error inesperado al enviar a FacturaSend: $e',
      );
    }
  }
}
