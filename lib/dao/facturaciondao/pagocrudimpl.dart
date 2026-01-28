import 'package:myapp/modelo/facturacionmodelo/factura.dart';
import 'package:myapp/modelo/facturacionmodelo/pago.dart';
import 'package:myapp/modelo/usuario/usuario.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class PagoCrudImpl {
  
  // ==================== CREAR PAGO ====================
  Future<Pago?> crearPago(Pago pago) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('pagos')
          .insert({
            'fecha_pago': pago.fechaPago?.toIso8601String(),
            'fk_factura': pago.factura?.id_factura,
            'comprobante_url': pago.comprobanteUrl,
            'monto': pago.monto,
            'estado': pago.estado,
            'payload_creacion': pago.payloadCreacion,
            'fk_usuario': pago.usuario?.id_usuario,
            'motivo_rechazo': pago.motivoRechazo,
          })
          .select()
          .single();

      print('Pago creado exitosamente');
      return Pago.fromMap(data);
    } catch (e) {
      print('Error al crear pago: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS PAGOS ====================
  Future<List<Pago>> leerPagos() async {
    try {
      final data = await supabase
          .from('pagos')
          .select('''
            *,
            facturas(*),
            usuario(*)
          ''');

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay pagos en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Pago> pagos = registros.map((mapa) {
        return Pago(
          idPago: mapa['id_pago'],
          fechaPago: mapa['fecha_pago'] != null 
              ? DateTime.parse(mapa['fecha_pago']) 
              : null,
          factura: mapa['facturas'] != null 
              ? Factura.fromMap(mapa['facturas']) 
              : null,
          comprobanteUrl: mapa['comprobante_url'],
          monto: (mapa['monto'] as num).toDouble(),
          estado: mapa['estado'] ?? 'PENDIENTE',
          payloadCreacion: mapa['payload_creacion'] as Map<String, dynamic>?,
          usuario: mapa['usuario'] != null 
              ? Usuario.fromMap(mapa['usuario']) 
              : null,
          motivoRechazo: mapa['motivo_rechazo'],
        );
      }).toList();

      print('✓ Se cargaron ${pagos.length} pagos');
      return pagos;
    } catch (e) {
      print('Error al leer pagos: $e');
      return [];
    }
  }

  // ==================== LEER UN PAGO POR ID ====================
  Future<Pago?> leerPagoPorId(int idPago) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('pagos')
          .select('''
            *,
            facturas(*),
            usuario(*)
          ''')
          .eq('id_pago', idPago)
          .single();

      return Pago(
        idPago: data['id_pago'],
        fechaPago: data['fecha_pago'] != null 
            ? DateTime.parse(data['fecha_pago']) 
            : null,
        factura: data['facturas'] != null 
            ? Factura.fromMap(data['facturas']) 
            : null,
        comprobanteUrl: data['comprobante_url'],
        monto: (data['monto'] as num).toDouble(),
        estado: data['estado'] ?? 'PENDIENTE',
        payloadCreacion: data['payload_creacion'] as Map<String, dynamic>?,
        usuario: data['usuario'] != null 
            ? Usuario.fromMap(data['usuario']) 
            : null,
        motivoRechazo: data['motivo_rechazo'],
      );
    } catch (e) {
      print('Error al leer pago por ID: $e');
      return null;
    }
  }

  // ==================== BUSCAR PAGOS ====================
  Future<List<Pago>> buscarPagos(String busqueda) async {
    try {
      final data = await supabase
          .from('pagos')
          .select('''
            *,
            facturas(*),
            usuario(*)
          ''')
          .or('comprobante_url.ilike.%$busqueda%,estado.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Pago> pagos = registros.map((mapa) {
        return Pago(
          idPago: mapa['id_pago'],
          fechaPago: mapa['fecha_pago'] != null 
              ? DateTime.parse(mapa['fecha_pago']) 
              : null,
          factura: mapa['facturas'] != null 
              ? Factura.fromMap(mapa['facturas']) 
              : null,
          comprobanteUrl: mapa['comprobante_url'],
          monto: (mapa['monto'] as num).toDouble(),
          estado: mapa['estado'] ?? 'PENDIENTE',
          payloadCreacion: mapa['payload_creacion'] as Map<String, dynamic>?,
          usuario: mapa['usuario'] != null 
              ? Usuario.fromMap(mapa['usuario']) 
              : null,
          motivoRechazo: mapa['motivo_rechazo'],
        );
      }).toList();

      return pagos;
    } catch (e) {
      print('Error al buscar pagos: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR PAGO ====================
  Future<bool> actualizarPago(Pago pago) async {
    try {
      await supabase
          .from('pagos')
          .update({
            'fecha_pago': pago.fechaPago?.toIso8601String(),
            'fk_factura': pago.factura?.id_factura,
            'comprobante_url': pago.comprobanteUrl,
            'monto': pago.monto,
            'estado': pago.estado,
            'payload_creacion': pago.payloadCreacion,
            'fk_usuario': pago.usuario?.id_usuario,
            'motivo_rechazo': pago.motivoRechazo,
          })
          .eq('id_pago', pago.idPago!);

      print('Pago actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar pago: $e');
      return false;
    }
  }

  // ==================== ELIMINAR PAGO ====================
  Future<bool> eliminarPago(int idPago) async {
    try {
      await supabase
          .from('pagos')
          .delete()
          .eq('id_pago', idPago);

      print('Pago eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar pago: $e');
      return false;
    }
  }

  // ==================== LEER PAGOS POR FACTURA ====================
  Future<List<Pago>> leerPagosPorFactura(int idFactura) async {
    try {
      final data = await supabase
          .from('pagos')
          .select('''
            *,
            facturas(*),
            usuario(*)
          ''')
          .eq('fk_factura', idFactura);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Pago> pagos = registros.map((mapa) {
        return Pago(
          idPago: mapa['id_pago'],
          fechaPago: mapa['fecha_pago'] != null 
              ? DateTime.parse(mapa['fecha_pago']) 
              : null,
          factura: mapa['facturas'] != null 
              ? Factura.fromMap(mapa['facturas']) 
              : null,
          comprobanteUrl: mapa['comprobante_url'],
          monto: (mapa['monto'] as num).toDouble(),
          estado: mapa['estado'] ?? 'PENDIENTE',
          payloadCreacion: mapa['payload_creacion'] as Map<String, dynamic>?,
          usuario: mapa['usuario'] != null 
              ? Usuario.fromMap(mapa['usuario']) 
              : null,
          motivoRechazo: mapa['motivo_rechazo'],
        );
      }).toList();

      return pagos;
    } catch (e) {
      print('Error al leer pagos por factura: $e');
      return [];
    }
  }

  // ==================== LEER PAGOS POR USUARIO ====================
  Future<List<Pago>> leerPagosPorUsuario(int idUsuario) async {
    try {
      final data = await supabase
          .from('pagos')
          .select('''
            *,
            facturas(*),
            usuario(*)
          ''')
          .eq('fk_usuario', idUsuario);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Pago> pagos = registros.map((mapa) {
        return Pago(
          idPago: mapa['id_pago'],
          fechaPago: mapa['fecha_pago'] != null 
              ? DateTime.parse(mapa['fecha_pago']) 
              : null,
          factura: mapa['facturas'] != null 
              ? Factura.fromMap(mapa['facturas']) 
              : null,
          comprobanteUrl: mapa['comprobante_url'],
          monto: (mapa['monto'] as num).toDouble(),
          estado: mapa['estado'] ?? 'PENDIENTE',
          payloadCreacion: mapa['payload_creacion'] as Map<String, dynamic>?,
          usuario: mapa['usuario'] != null 
              ? Usuario.fromMap(mapa['usuario']) 
              : null,
          motivoRechazo: mapa['motivo_rechazo'],
        );
      }).toList();

      return pagos;
    } catch (e) {
      print('Error al leer pagos por usuario: $e');
      return [];
    }
  }

  // ==================== LEER PAGOS POR ESTADO ====================
  Future<List<Pago>> leerPagosPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('pagos')
          .select('''
            *,
            facturas(*),
            usuario(*)
          ''')
          .eq('estado', estado);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Pago> pagos = registros.map((mapa) {
        return Pago(
          idPago: mapa['id_pago'],
          fechaPago: mapa['fecha_pago'] != null 
              ? DateTime.parse(mapa['fecha_pago']) 
              : null,
          factura: mapa['facturas'] != null 
              ? Factura.fromMap(mapa['facturas']) 
              : null,
          comprobanteUrl: mapa['comprobante_url'],
          monto: (mapa['monto'] as num).toDouble(),
          estado: mapa['estado'] ?? 'PENDIENTE',
          payloadCreacion: mapa['payload_creacion'] as Map<String, dynamic>?,
          usuario: mapa['usuario'] != null 
              ? Usuario.fromMap(mapa['usuario']) 
              : null,
          motivoRechazo: mapa['motivo_rechazo'],
        );
      }).toList();

      return pagos;
    } catch (e) {
      print('Error al leer pagos por estado: $e');
      return [];
    }
  }

  // ==================== CAMBIAR ESTADO PAGO ====================
  Future<bool> cambiarEstadoPago(int idPago, String nuevoEstado, {String? motivoRechazo}) async {
    try {
      final updateData = {
        'estado': nuevoEstado,
      };

      // Solo agregar motivo de rechazo si se proporciona
      if (motivoRechazo != null) {
        updateData['motivo_rechazo'] = motivoRechazo;
      }

      await supabase
          .from('pagos')
          .update(updateData)
          .eq('id_pago', idPago);

      print('Estado del pago actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al cambiar estado del pago: $e');
      return false;
    }
  }

  // ==================== APROBAR PAGO CON FUNCIÓN RPC ====================
  /// Aprueba un pago y genera automáticamente la factura usando la función RPC de Supabase
  /// 
  /// [idPago] - ID del pago a aprobar
  /// [idUsuarioAdmin] - ID del usuario administrador que aprueba el pago
  /// 
  /// Retorna un Map con la respuesta de la función RPC que incluye:
  /// - success: bool indicando si fue exitoso
  /// - factura: objeto con los datos de la factura generada
  /// - error: mensaje de error si falló
  /// 
  /// Ejemplo de uso:
  /// ```dart
  /// final resultado = await _pagoCrud.aprobarPagoConRPC(
  ///   idPago: 123,
  ///   idUsuarioAdmin: 1,
  /// );
  /// 
  /// if (resultado['success'] == true) {
  ///   final facturaId = resultado['factura']['id_factura'];
  ///   print('Factura generada: $facturaId');
  /// } else {
  ///   print('Error: ${resultado['error']}');
  /// }
  /// ```
  Future<Map<String, dynamic>> aprobarPagoConRPC({
    required int idPago,
    required int idUsuarioAdmin,
  }) async {
    try {
      print('🔄 Aprobando pago #$idPago con usuario admin #$idUsuarioAdmin');
      
      // Primero verificar que el pago tenga un payload válido
      final pago = await leerPagoPorId(idPago);
      
      if (pago == null) {
        return {
          'success': false,
          'error': 'El pago no existe',
        };
      }
      
      if (pago.payloadCreacion == null) {
        return {
          'success': false,
          'error': 'El pago no tiene información de facturación (payload_creacion es null)',
        };
      }
      
      // Verificar campos requeridos en el payload
      final payload = pago.payloadCreacion!;
      final camposRequeridos = [
        'fk_cliente',
        'fk_inmueble',
        'condicion_venta',
        'total_general',
        'fk_monedas',
        'fk_establecimientos',
        'fk_modo_pago',
        'fk_tipo_factura',
        'fk_turno',
        'tipo_emision',
      ];
      
      final camposFaltantes = <String>[];
      for (final campo in camposRequeridos) {
        if (!payload.containsKey(campo) || payload[campo] == null) {
          camposFaltantes.add(campo);
        }
      }
      
      if (camposFaltantes.isNotEmpty) {
        return {
          'success': false,
          'error': 'El payload del pago está incompleto. Faltan los siguientes campos: ${camposFaltantes.join(", ")}',
          'missing_fields': camposFaltantes,
        };
      }
      
      // Verificar que tenga detalles
      if (!payload.containsKey('detalles') || payload['detalles'] == null) {
        return {
          'success': false,
          'error': 'El pago no tiene detalles de facturación',
        };
      }
      
      print('✅ Payload validado correctamente');
      print('📋 Payload: ${payload.toString()}');
      
      final response = await supabase.rpc(
        'aprobar_pago_transferencia',
        params: {
          'p_id_pago': idPago,
          'p_id_usuario_admin': idUsuarioAdmin,
        },
      );

      print('✅ Respuesta RPC: $response');
      
      if (response is Map<String, dynamic>) {
        return response;
      } else {
        return {
          'success': true,
          'data': response,
        };
      }
    } catch (e) {
      print('❌ Error al aprobar pago con RPC: $e');
      
      // Extraer mensaje de error más legible
      String errorMsg = e.toString();
      if (e.toString().contains('violates not-null constraint')) {
        final match = RegExp(r'column "(\w+)"').firstMatch(e.toString());
        if (match != null) {
          final campo = match.group(1);
          errorMsg = 'Falta el campo requerido: $campo en el payload del pago';
        }
      }
      
      return {
        'success': false,
        'error': errorMsg,
      };
    }
  }
  
  // ==================== VALIDAR PAYLOAD DE PAGO ====================
  /// Valida que un pago tenga toda la información necesaria para generar una factura
  /// 
  /// [idPago] - ID del pago a validar
  /// 
  /// Retorna un Map con:
  /// - valid: bool indicando si el payload es válido
  /// - missing_fields: lista de campos faltantes (si aplica)
  /// - error: mensaje de error (si aplica)
  Future<Map<String, dynamic>> validarPayloadPago(int idPago) async {
    try {
      final pago = await leerPagoPorId(idPago);
      
      if (pago == null) {
        return {
          'valid': false,
          'error': 'El pago no existe',
        };
      }
      
      if (pago.payloadCreacion == null) {
        return {
          'valid': false,
          'error': 'El pago no tiene payload_creacion',
        };
      }
      
      final payload = pago.payloadCreacion!;
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
        'detalles': 'Detalles de la factura',
      };
      
      final camposFaltantes = <String, String>{};
      for (final entry in camposRequeridos.entries) {
        if (!payload.containsKey(entry.key) || payload[entry.key] == null) {
          camposFaltantes[entry.key] = entry.value;
        }
      }
      
      if (camposFaltantes.isNotEmpty) {
        return {
          'valid': false,
          'missing_fields': camposFaltantes,
          'error': 'Faltan campos requeridos: ${camposFaltantes.values.join(", ")}',
        };
      }
      
      // Verificar que detalles sea un array no vacío
      if (payload['detalles'] is! List || (payload['detalles'] as List).isEmpty) {
        return {
          'valid': false,
          'error': 'El pago no tiene detalles de facturación',
        };
      }
      
      return {
        'valid': true,
        'payload': payload,
      };
    } catch (e) {
      return {
        'valid': false,
        'error': 'Error al validar payload: $e',
      };
    }
  }

  // ==================== ASOCIAR FACTURA A PAGO ====================
  Future<bool> asociarFacturaAPago(int idPago, int idFactura) async {
    try {
      await supabase
          .from('pagos')
          .update({'fk_factura': idFactura})
          .eq('id_pago', idPago);

      print('Factura asociada al pago exitosamente');
      return true;
    } catch (e) {
      print('Error al asociar factura al pago: $e');
      return false;
    }
  }

  // ==================== LEER PAGOS POR RANGO DE FECHAS ====================
  Future<List<Pago>> leerPagosPorRangoFechas(DateTime fechaInicio, DateTime fechaFin) async {
    try {
      final data = await supabase
          .from('pagos')
          .select('''
            *,
            facturas(*),
            usuario(*)
          ''')
          .gte('fecha_pago', fechaInicio.toIso8601String())
          .lte('fecha_pago', fechaFin.toIso8601String())
          .order('fecha_pago', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Pago> pagos = registros.map((mapa) {
        return Pago(
          idPago: mapa['id_pago'],
          fechaPago: mapa['fecha_pago'] != null 
              ? DateTime.parse(mapa['fecha_pago']) 
              : null,
          factura: mapa['facturas'] != null 
              ? Factura.fromMap(mapa['facturas']) 
              : null,
          comprobanteUrl: mapa['comprobante_url'],
          monto: (mapa['monto'] as num).toDouble(),
          estado: mapa['estado'] ?? 'PENDIENTE',
          payloadCreacion: mapa['payload_creacion'] as Map<String, dynamic>?,
          usuario: mapa['usuario'] != null 
              ? Usuario.fromMap(mapa['usuario']) 
              : null,
          motivoRechazo: mapa['motivo_rechazo'],
        );
      }).toList();

      return pagos;
    } catch (e) {
      print('Error al leer pagos por rango de fechas: $e');
      return [];
    }
  }

  // ==================== CALCULAR TOTAL PAGOS POR ESTADO ====================
  Future<double> calcularTotalPagosPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('pagos')
          .select('monto')
          .eq('estado', estado);

      if (data == null || data.isEmpty) {
        return 0.0;
      }

      double total = 0.0;
      for (var pago in data) {
        total += (pago['monto'] as num).toDouble();
      }

      return total;
    } catch (e) {
      print('Error al calcular total de pagos: $e');
      return 0.0;
    }
  }

  // ==================== LEER PAGOS SIN FACTURA ASIGNADA ====================
  Future<List<Pago>> leerPagosSinFactura() async {
    try {
      final data = await supabase
          .from('pagos')
          .select('''
            *,
            usuario(*)
          ''')
          .isFilter('fk_factura', null);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Pago> pagos = registros.map((mapa) {
        return Pago(
          idPago: mapa['id_pago'],
          fechaPago: mapa['fecha_pago'] != null 
              ? DateTime.parse(mapa['fecha_pago']) 
              : null,
          factura: null,
          comprobanteUrl: mapa['comprobante_url'],
          monto: (mapa['monto'] as num).toDouble(),
          estado: mapa['estado'] ?? 'PENDIENTE',
          payloadCreacion: mapa['payload_creacion'] as Map<String, dynamic>?,
          usuario: mapa['usuario'] != null 
              ? Usuario.fromMap(mapa['usuario']) 
              : null,
          motivoRechazo: mapa['motivo_rechazo'],
        );
      }).toList();

      return pagos;
    } catch (e) {
      print('Error al leer pagos sin factura: $e');
      return [];
    }
  }
}