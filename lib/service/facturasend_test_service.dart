import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/modelo/cliente.dart';

/// PoC aislado: envía documentos de prueba (borrador) a FacturaSend a través
/// del edge function proxy `facturasend-test`.
///
/// No integrado al flujo real de facturación (`FacturaRpcService`).
class FacturaSendTestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Construye un documento de ejemplo para probar el envío a FacturaSend.
  ///
  /// Shape confirmado contra la API real de FacturaSend (sin wrapper
  /// `data`/`params` — el body va plano en la raíz, ver
  /// https://facturasend.com.py/documentacion/ejemplo-de-json-por-tipo-de-documento/).
  ///
  /// Si se pasa un [cliente] real, mapea sus campos al bloque `cliente` del
  /// JSON. Si no, usa un consumidor final ficticio de ejemplo.
  Map<String, dynamic> construirDocumentoDePrueba({Cliente? cliente}) {
    const precioUnitario = 50000;
    const cantidad = 1;
    const totalItem = precioUnitario * cantidad;

    return {
      'tipoDocumento': 1,
      'establecimiento': '001',
      'punto': '001',
      'numero': 1,
      'descripcion': 'Documento de prueba PoC FacturaSend',
      'observacion': 'Prueba de conexión',
      'fecha': DateTime.now().toIso8601String().split('.').first,
      'tipoEmision': 1,
      'tipoTransaccion': 1,
      'tipoImpuesto': 1,
      'moneda': 'PYG',
      'cliente': _mapearCliente(cliente),
      'factura': {'presencia': 1},
      'condicion': {
        'tipo': 1,
        'entregas': [
          {
            'tipo': 1,
            'monto': totalItem.toString(),
            'moneda': 'PYG',
            'cambio': 0,
          },
        ],
      },
      'items': [
        {
          'codigo': 'SERV-AGUA',
          'descripcion': 'Servicio de agua potable (prueba)',
          'unidadMedida': 77,
          'cantidad': cantidad,
          'precioUnitario': precioUnitario,
          'ivaTipo': 1,
          'ivaProporcion': 100,
          'iva': 10,
        },
      ],
    };
  }

  /// Mapea un [Cliente] real al bloque `cliente` esperado por FacturaSend.
  /// Si [cliente] es null, devuelve un consumidor final ficticio de ejemplo.
  ///
  /// `tipoOperacion` sigue el enum de FacturaSend (no el `codigo_tipo_operacion`
  /// del modelo local, que es otra cosa): 1=B2B, 2=B2C, 4=B2F. Un receptor
  /// "No Contribuyente" exige 2 o 4 — acá se usa 1 solo si el cliente también
  /// es contribuyente.
  ///
  /// Los códigos geográficos (ciudad/país) no tienen equivalente en el
  /// modelo `Cliente` (que guarda `barrio`, no códigos DGEEC de SIFEN), así
  /// que quedan con un valor de ejemplo editable en la pantalla.
  Map<String, dynamic> _mapearCliente(Cliente? cliente) {
    if (cliente == null) {
      return {
        'contribuyente': false,
        'tipoOperacion': 2,
        'razonSocial': 'Cliente de Prueba',
        'direccion': 'Dirección de prueba',
        'numeroCasa': '0',
        'ciudad': 3344,
        'ciudadDescripcion': 'PASO ITA (INDIGENA)',
        'pais': 'PRY',
        'paisDescripcion': 'Paraguay',
        'documentoTipo': 1,
        'documentoNumero': '0',
        'email': 'prueba@aguateria.com.py',
      };
    }

    final esContribuyente = cliente.tieneContribuyente;

    return {
      'contribuyente': esContribuyente,
      'tipoOperacion': esContribuyente ? 1 : 2,
      'razonSocial': cliente.razonSocial,
      if (cliente.nombreFantasia != null)
        'nombreFantasia': cliente.nombreFantasia,
      'direccion': cliente.direccion ?? 'Sin dirección registrada',
      'numeroCasa': cliente.nroCasa.toString(),
      'ciudad': 3344,
      'ciudadDescripcion': 'PASO ITA (INDIGENA)',
      'pais': 'PRY',
      'paisDescripcion': 'Paraguay',
      if (esContribuyente) 'ruc': cliente.documento,
      'documentoTipo': cliente.tipoDocumento?.cod_tipo_documento ?? 1,
      'documentoNumero': cliente.documento,
      if (cliente.email != null) 'email': cliente.email,
    };
  }

  /// Envía el [documento] al edge function `facturasend-test`.
  ///
  /// [qr] pide a FacturaSend que incluya el QR en la respuesta (se manda
  /// como query flag real hacia FacturaSend, no como campo del documento).
  Future<FacturaSendTestResultado> enviar(
    Map<String, dynamic> documento, {
    bool qr = false,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'facturasend-test',
        body: {'documento': documento, 'qr': qr},
      );

      final data = response.data;
      if (data is! Map) {
        return FacturaSendTestResultado(
          ok: false,
          error: 'Respuesta inesperada del servidor',
        );
      }

      final resultado = Map<String, dynamic>.from(data);

      return FacturaSendTestResultado(
        ok: resultado['ok'] == true,
        upstreamStatus: resultado['upstreamStatus'] is int
            ? resultado['upstreamStatus'] as int
            : null,
        draft: resultado['draft'] == true,
        facturasend: resultado['facturasend'] is Map
            ? Map<String, dynamic>.from(resultado['facturasend'] as Map)
            : null,
        error: resultado['error']?.toString(),
      );
    } on FunctionException catch (e) {
      return FacturaSendTestResultado(
        ok: false,
        error: 'Error del edge function (${e.status}): ${e.details ?? e.reasonPhrase}',
      );
    } catch (e) {
      return FacturaSendTestResultado(
        ok: false,
        error: 'Error inesperado al enviar a FacturaSend: $e',
      );
    }
  }
}

/// Resultado del envío de prueba a FacturaSend.
class FacturaSendTestResultado {
  final bool ok;
  final int? upstreamStatus;
  final bool draft;
  final Map<String, dynamic>? facturasend;
  final String? error;

  FacturaSendTestResultado({
    required this.ok,
    this.upstreamStatus,
    this.draft = true,
    this.facturasend,
    this.error,
  });

  /// CDC del documento generado (dentro de `result.deList[0].cdc`), si existe.
  String? get cdc {
    final result = facturasend?['result'];
    if (result is Map) {
      final deList = result['deList'];
      if (deList is List && deList.isNotEmpty) {
        final primero = deList.first;
        if (primero is Map) return primero['cdc']?.toString();
      }
    }
    return null;
  }

  /// ID del lote creado (`result.loteId`), si existe.
  String? get loteId {
    final result = facturasend?['result'];
    if (result is Map) return result['loteId']?.toString();
    return null;
  }

  /// Lista de errores de negocio reportados por FacturaSend, si los hay.
  List<dynamic> get errores {
    final e = facturasend?['errores'];
    if (e is List) return e;
    return [];
  }
}
