/// Resultado del envío de un documento a FacturaSend.
///
/// Compartido entre el PoC (`facturasend_test_service.dart`) y el flujo real
/// (`facturasend_service.dart`) para que ambos lean la respuesta del proxy
/// de la misma forma.
class FacturaSendResultado {
  final bool ok;
  final int? upstreamStatus;
  final bool draft;
  final Map<String, dynamic>? facturasend;
  final String? error;

  FacturaSendResultado({
    required this.ok,
    this.upstreamStatus,
    this.draft = true,
    this.facturasend,
    this.error,
  });

  /// Parsea la respuesta cruda de `supabase.functions.invoke(...).data`.
  factory FacturaSendResultado.fromInvokeResponse(dynamic data) {
    if (data is! Map) {
      return FacturaSendResultado(
        ok: false,
        error: 'Respuesta inesperada del servidor',
      );
    }

    final resultado = Map<String, dynamic>.from(data);

    return FacturaSendResultado(
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
  }

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

  /// Lista cruda de errores de negocio reportados por FacturaSend, si los hay.
  List<dynamic> get errores {
    final e = facturasend?['errores'];
    if (e is List) return e;
    return [];
  }

  /// Mensajes de error legibles para mostrar en la UI, juntando todas las
  /// fuentes posibles (error del proxy, error/message de negocio de
  /// FacturaSend, lista de `errores`), de-duplicados preservando el orden.
  List<String> get mensajesError {
    final mensajes = <String>[];

    if (error != null) mensajes.add(error!);

    final fs = facturasend;
    if (fs != null) {
      final fsError = fs['error'];
      final fsMessage = fs['message'];
      if (fsError is String && fsError.isNotEmpty) {
        mensajes.add(fsError);
      } else if (fsMessage is String && fsMessage.isNotEmpty) {
        mensajes.add(fsMessage);
      }
    }

    for (final e in errores) {
      if (e is String) {
        mensajes.add(e);
      } else if (e is Map) {
        mensajes.add(
          (e['error'] ?? e['mensaje'] ?? e['descripcion'] ?? e.toString())
              .toString(),
        );
      } else {
        mensajes.add(e.toString());
      }
    }

    final vistos = <String>{};
    final resultado = <String>[];
    for (final m in mensajes) {
      if (vistos.add(m)) resultado.add(m);
    }
    return resultado;
  }
}
