import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:myapp/dao/empresadao/establecimientocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/apertura_cierre_cajacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/modo_pagocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/monedascrudimpl.dart';
import 'package:myapp/dao/facturaciondao/motivo_emisioncrudimpl.dart';
import 'package:myapp/dao/facturaciondao/tipo_facturacrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/factura.dart';
import 'package:myapp/modelo/facturacionmodelo/motivo_emision.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class FacturaCrudImpl {
  final ClienteCrudImpl _clienteCrud = ClienteCrudImpl();
  final EstablecimientoCrudImpl _establecimientoCrud = EstablecimientoCrudImpl();
  final AperturaCierreCajaCrudImpl _aperturaCrud = AperturaCierreCajaCrudImpl();
  final ModoPagoCrudImpl _modoPagoCrud = ModoPagoCrudImpl();
  final MonedaCrudImpl _monedaCrud = MonedaCrudImpl();
  final MotivoEmisionCrudImpl _motivoCrud = MotivoEmisionCrudImpl();
  final TipoFacturaCrudImpl _tipoFacturaCrud = TipoFacturaCrudImpl();

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // ==================== CREAR FACTURA ====================

  Future<Factura?> crearFactura(Factura factura) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('facturas')
          .insert({
            'fecha_emision': factura.fecha_emision.toIso8601String(),
            'fk_cliente': factura.fk_cliente.idCliente,
            'codicion_venta': factura.codicion_venta,
            'total_gravado_10': factura.total_gravado_10,
            'total_gravado_5': factura.total_gravado_5,
            'total_exenta': factura.total_exenta,
            'total_iva': factura.total_iva,
            'total_general': factura.total_general,
            'observacion': factura.observacion,
            'fk_monedas': factura.fk_monedas.id_monedas,
            'fk_establecimientos': factura.fk_establecimientos.id_establecimiento,
            'fk_modo_pago': factura.fk_modo_pago.id_modo_pago,
            'fk_tipo_factura': factura.fk_tipo_factura.id_tipo_factura,
            'nro_secuencial': factura.nro_secuencial,
            'fk_turno': factura.fk_turno.id_turno,
            'tipo_emision': factura.tipo_emision,
            'fk_motivo': factura.fk_motivo?.id_motivos,
            'fk_factura_asociada': factura.fk_factura_asociada?.id_factura,
            'efectivo': factura.efectivo,
            'vuelto': factura.vuelto,
            'descuento_global': factura.descuento_global,
          })
          .select()
          .single();

      print('Factura creada exitosamente');
      return await _convertirFactura(data);
    } catch (e) {
      print('Error al crear factura: $e');
      return null;
    }
  }

  // ==================== LEER TODAS LAS FACTURAS ====================

  Future<List<Factura>> leerFacturas() async {
    try {
      final data = await supabase
          .from('facturas')
          .select()
          .order('fecha_emision', ascending: false);

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay facturas en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Factura> facturas = [];
      
      for (var mapa in registros) {
        try {
          final factura = await _convertirFactura(mapa);
          facturas.add(factura);
        } catch (e) {
          print('Error al convertir factura: $e');
          continue;
        }
      }

      print('✓ Se cargaron ${facturas.length} facturas');
      return facturas;
    } catch (e) {
      print('Error al leer facturas: $e');
      return [];
    }
  }

  // ==================== LEER FACTURA POR ID ====================

  Future<Factura?> leerFacturaPorId(int idFactura) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('facturas')
          .select()
          .eq('id_factura', idFactura)
          .single();

      return await _convertirFactura(data);
    } catch (e) {
      print('Error al leer factura por ID: $e');
      return null;
    }
  }

  // ==================== LEER FACTURAS POR CLIENTE ====================

  Future<List<Factura>> leerFacturasPorCliente(int idCliente) async {
    try {
      final data = await supabase
          .from('facturas')
          .select()
          .eq('fk_cliente', idCliente)
          .order('fecha_emision', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Factura> facturas = [];
      
      for (var mapa in registros) {
        try {
          final factura = await _convertirFactura(mapa);
          facturas.add(factura);
        } catch (e) {
          print('Error al convertir factura: $e');
          continue;
        }
      }

      return facturas;
    } catch (e) {
      print('Error al leer facturas por cliente: $e');
      return [];
    }
  }

  // ==================== LEER FACTURAS POR ESTABLECIMIENTO ====================

  Future<List<Factura>> leerFacturasPorEstablecimiento(int idEstablecimiento) async {
    try {
      final data = await supabase
          .from('facturas')
          .select()
          .eq('fk_establecimientos', idEstablecimiento)
          .order('fecha_emision', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Factura> facturas = [];
      
      for (var mapa in registros) {
        try {
          final factura = await _convertirFactura(mapa);
          facturas.add(factura);
        } catch (e) {
          print('Error al convertir factura: $e');
          continue;
        }
      }

      return facturas;
    } catch (e) {
      print('Error al leer facturas por establecimiento: $e');
      return [];
    }
  }

  // ==================== LEER FACTURAS POR TURNO ====================

  Future<List<Factura>> leerFacturasPorTurno(int idTurno) async {
    try {
      final data = await supabase
          .from('facturas')
          .select()
          .eq('fk_turno', idTurno)
          .order('fecha_emision', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Factura> facturas = [];
      
      for (var mapa in registros) {
        try {
          final factura = await _convertirFactura(mapa);
          facturas.add(factura);
        } catch (e) {
          print('Error al convertir factura: $e');
          continue;
        }
      }

      return facturas;
    } catch (e) {
      print('Error al leer facturas por turno: $e');
      return [];
    }
  }

  // ==================== LEER FACTURAS POR RANGO DE FECHAS ====================

  Future<List<Factura>> leerFacturasPorRangoFechas(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final data = await supabase
          .from('facturas')
          .select()
          .gte('fecha_emision', fechaInicio.toIso8601String())
          .lte('fecha_emision', fechaFin.toIso8601String())
          .order('fecha_emision', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Factura> facturas = [];
      
      for (var mapa in registros) {
        try {
          final factura = await _convertirFactura(mapa);
          facturas.add(factura);
        } catch (e) {
          print('Error al convertir factura: $e');
          continue;
        }
      }

      return facturas;
    } catch (e) {
      print('Error al leer facturas por rango de fechas: $e');
      return [];
    }
  }

  // ==================== LEER FACTURAS POR TIPO ====================

  Future<List<Factura>> leerFacturasPorTipo(int idTipoFactura) async {
    try {
      final data = await supabase
          .from('facturas')
          .select()
          .eq('fk_tipo_factura', idTipoFactura)
          .order('fecha_emision', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Factura> facturas = [];
      
      for (var mapa in registros) {
        try {
          final factura = await _convertirFactura(mapa);
          facturas.add(factura);
        } catch (e) {
          print('Error al convertir factura: $e');
          continue;
        }
      }

      return facturas;
    } catch (e) {
      print('Error al leer facturas por tipo: $e');
      return [];
    }
  }

  // ==================== BUSCAR FACTURAS ====================

  Future<List<Factura>> buscarFacturas(String busqueda) async {
    try {
      final data = await supabase
          .from('facturas')
          .select()
          .or('nro_secuencial.eq.${int.tryParse(busqueda) ?? -1},observacion.ilike.%$busqueda%')
          .order('fecha_emision', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Factura> facturas = [];
      
      for (var mapa in registros) {
        try {
          final factura = await _convertirFactura(mapa);
          facturas.add(factura);
        } catch (e) {
          print('Error al convertir factura: $e');
          continue;
        }
      }

      return facturas;
    } catch (e) {
      print('Error al buscar facturas: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR FACTURA ====================

  Future<bool> actualizarFactura(Factura factura) async {
    try {
      await supabase
          .from('facturas')
          .update({
            'fecha_emision': factura.fecha_emision.toIso8601String(),
            'fk_cliente': factura.fk_cliente.idCliente,
            'codicion_venta': factura.codicion_venta,
            'total_gravado_10': factura.total_gravado_10,
            'total_gravado_5': factura.total_gravado_5,
            'total_exenta': factura.total_exenta,
            'total_iva': factura.total_iva,
            'total_general': factura.total_general,
            'observacion': factura.observacion,
            'fk_monedas': factura.fk_monedas.id_monedas,
            'fk_establecimientos': factura.fk_establecimientos.id_establecimiento,
            'fk_modo_pago': factura.fk_modo_pago.id_modo_pago,
            'fk_tipo_factura': factura.fk_tipo_factura.id_tipo_factura,
            'nro_secuencial': factura.nro_secuencial,
            'fk_turno': factura.fk_turno.id_turno,
            'tipo_emision': factura.tipo_emision,
            'fk_motivo': factura.fk_motivo?.id_motivos,
            'fk_factura_asociada': factura.fk_factura_asociada?.id_factura,
            'efectivo': factura.efectivo,
            'vuelto': factura.vuelto,
            'descuento_global': factura.descuento_global,
          })
          .eq('id_factura', factura.id_factura!);

      print('Factura actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar factura: $e');
      return false;
    }
  }

  // ==================== ANULAR FACTURA ====================

  Future<bool> anularFactura(int idFactura) async {
    try {
      // Aquí podrías implementar lógica adicional como:
      // - Crear una nota de crédito automáticamente
      // - Cambiar un estado de la factura a "ANULADA"
      // Por ahora, simplemente eliminamos el registro
      await supabase
          .from('facturas')
          .delete()
          .eq('id_factura', idFactura);

      print('Factura anulada exitosamente');
      return true;
    } catch (e) {
      print('Error al anular factura: $e');
      return false;
    }
  }

  // ==================== OBTENER PRÓXIMO NÚMERO SECUENCIAL ====================

  Future<int> obtenerProximoSecuencial(int idEstablecimiento, int idTipoFactura) async {
    try {
      final data = await supabase
          .from('facturas')
          .select('nro_secuencial')
          .eq('fk_establecimientos', idEstablecimiento)
          .eq('fk_tipo_factura', idTipoFactura)
          .order('nro_secuencial', ascending: false)
          .limit(1);

      if (data.isEmpty) {
        return 1; // Primera factura
      }

      final ultimoNumero = _toInt(data.first['nro_secuencial']);
      return ultimoNumero + 1;
    } catch (e) {
      print('Error al obtener próximo secuencial: $e');
      return 1;
    }
  }

  // ==================== CALCULAR TOTALES POR TURNO ====================

  Future<Map<String, double>> calcularTotalesPorTurno(int idTurno) async {
    try {
      final facturas = await leerFacturasPorTurno(idTurno);

      double totalGeneral = 0;
      double totalEfectivo = 0;
      double totalIVA = 0;

      for (var factura in facturas) {
        totalGeneral += factura.total_general;
        totalEfectivo += factura.efectivo;
        totalIVA += factura.total_iva;
      }

      return {
        'total_general': totalGeneral,
        'total_efectivo': totalEfectivo,
        'total_iva': totalIVA,
        'cantidad_facturas': facturas.length.toDouble(),
      };
    } catch (e) {
      print('Error al calcular totales por turno: $e');
      return {
        'total_general': 0,
        'total_efectivo': 0,
        'total_iva': 0,
        'cantidad_facturas': 0,
      };
    }
  }

  // ==================== VERIFICAR FACTURA ASOCIADA ====================

  Future<bool> facturaEstaAsociada(int idFactura) async {
    try {
      final data = await supabase
          .from('facturas')
          .select('id_factura')
          .eq('fk_factura_asociada', idFactura)
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar factura asociada: $e');
      return false;
    }
  }

  // ==================== MÉTODO AUXILIAR PARA CONVERTIR ====================

  Future<Factura> _convertirFactura(Map<String, dynamic> mapa) async {
    // Extraer IDs
    final idCliente = _toInt(mapa['fk_cliente']);
    final idEstablecimiento = _toInt(mapa['fk_establecimientos']);
    final idTurno = _toInt(mapa['fk_turno']);
    final idModoPago = _toInt(mapa['fk_modo_pago']);
    final idMoneda = _toInt(mapa['fk_monedas']);
    final idTipoFactura = _toInt(mapa['fk_tipo_factura']);
    final idMotivo = mapa['fk_motivo'] != null ? _toInt(mapa['fk_motivo']) : null;
    final idFacturaAsociada = mapa['fk_factura_asociada'] != null 
        ? _toInt(mapa['fk_factura_asociada']) 
        : null;

    // Cargar entidades relacionadas
    final cliente = await _clienteCrud.leerClientePorId(idCliente);
    final establecimiento = await _establecimientoCrud.leerEstablecimientoPorId(idEstablecimiento);
    final turno = await _aperturaCrud.leerAperturaPorId(idTurno);
    final modoPago = await _modoPagoCrud.leerModoPagoPorId(idModoPago);
    final moneda = await _monedaCrud.leerMonedaPorId(idMoneda);
    final tipoFactura = await _tipoFacturaCrud.leerTipoFacturaPorId(idTipoFactura);
    
    MotivoEmision? motivo;
    if (idMotivo != null) {
      motivo = await _motivoCrud.leerMotivoEmisionPorId(idMotivo);
    }

    Factura? facturaAsociada;
    if (idFacturaAsociada != null) {
      facturaAsociada = await leerFacturaPorId(idFacturaAsociada);
    }

    // Validaciones
    if (cliente == null) throw Exception('Cliente con ID $idCliente no encontrado');
    if (establecimiento == null) throw Exception('Establecimiento con ID $idEstablecimiento no encontrado');
    if (turno == null) throw Exception('Turno con ID $idTurno no encontrado');
    if (modoPago == null) throw Exception('Modo de pago con ID $idModoPago no encontrado');
    if (moneda == null) throw Exception('Moneda con ID $idMoneda no encontrada');
    if (tipoFactura == null) throw Exception('Tipo de factura con ID $idTipoFactura no encontrado');

    return Factura(
      id_factura: _toInt(mapa['id_factura']),
      fecha_emision: _toDate(mapa['fecha_emision']),
      fk_cliente: cliente,
      codicion_venta: _toInt(mapa['codicion_venta']),
      total_gravado_10: _toDouble(mapa['total_gravado_10']),
      total_gravado_5: _toDouble(mapa['total_gravado_5']),
      total_exenta: _toDouble(mapa['total_exenta']),
      total_iva: _toDouble(mapa['total_iva']),
      total_general: _toDouble(mapa['total_general']),
      observacion: mapa['observacion'] ?? '',
      fk_monedas: moneda,
      fk_establecimientos: establecimiento,
      fk_modo_pago: modoPago,
      fk_tipo_factura: tipoFactura,
      nro_secuencial: _toInt(mapa['nro_secuencial']),
      fk_turno: turno,
      tipo_emision: _toInt(mapa['tipo_emision']),
      fk_motivo: motivo,
      fk_factura_asociada: facturaAsociada,
      efectivo: _toDouble(mapa['efectivo']),
      vuelto: _toDouble(mapa['vuelto']),
      descuento_global: _toDouble(mapa['descuento_global']),
    );
  }
}