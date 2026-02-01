import 'package:myapp/dao/consumocrudimpl.dart';
import 'package:myapp/dao/cuenta_cobrarcrudimpl.dart';
import 'package:myapp/dao/facturaciondao/ciclocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/conceptocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/facturacrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/detalle_factura.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/consumo.dart';
import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DetalleFacturaCrudImpl {
  final FacturaCrudImpl _facturaCrud = FacturaCrudImpl();
  final ConceptoCrudImpl _conceptoCrud = ConceptoCrudImpl();
  final ConsumoCrudImpl _consumoCrud = ConsumoCrudImpl();
  final CuentaCobrarCrudImpl _deudaCrud = CuentaCobrarCrudImpl();
  final CicloCrudImpl _cicloCrud = CicloCrudImpl();

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

  // ==================== BUSCAR DEUDA COINCIDENTE ====================

  Future<int?> _buscarDeudaCoincidente({
    required int idInmueble,
    required int idConcepto,
    int? idCiclo,
  }) async {
    try {
      var query = supabase
          .from('deudas')
          .select('id_deuda')
          .eq('fk_inmueble', idInmueble)
          .eq('fk_concepto', idConcepto)
          .eq('estado', 'PENDIENTE');

      // Si hay ciclo, agregarlo al filtro
      if (idCiclo != null) {
        query = query.eq('fk_ciclos', idCiclo);
      }

      final data = await query.limit(1);

      if (data.isNotEmpty) {
        return _toInt(data.first['id_deuda']);
      }

      return null;
    } catch (e) {
      print('Error al buscar deuda coincidente: $e');
      return null;
    }
  }

  // ==================== CREAR DETALLE FACTURA ====================

  Future<DetalleFactura?> crearDetalleFactura(DetalleFactura detalle) async {
    try {
      // Validar que tenga factura asignada
      if (detalle.fk_factura == null ||
          detalle.fk_factura!.id_factura == null) {
        print(
          'Error: El detalle debe tener una factura asignada antes de guardar',
        );
        return null;
      }

      // Buscar deuda coincidente si aplica
      int? idDeuda;
      if (detalle.fk_factura!.fk_inmueble.id != null) {
        idDeuda = await _buscarDeudaCoincidente(
          idInmueble: detalle.fk_factura!.fk_inmueble.id!,
          idConcepto: detalle.fk_concepto.id!,
          idCiclo: detalle.fk_ciclo?.id,
        );
      }

      final Map<String, dynamic> data = await supabase
          .from('detalle_factura')
          .insert({
            'fk_factura': detalle.fk_factura!.id_factura,
            'fk_concepto': detalle.fk_concepto.id,
            'monto': detalle.monto,
            'descripcion': detalle.descripcion,
            'iva_aplicado': detalle.iva_aplicado,
            'subtotal': detalle.subtotal,
            'estado': detalle.estado,
            'cantidad': detalle.cantidad,
            'fk_consumos': detalle.fk_consumos?.id_consumos,
            'fk_deudas': idDeuda ?? detalle.fk_deudas?.id_deuda,
            'fk_ciclo': detalle.fk_ciclo?.id,
          })
          .select()
          .single();

      print('Detalle de factura creado exitosamente');
      return await _convertirDetalle(data);
    } catch (e) {
      print('Error al crear detalle de factura: $e');
      return null;
    }
  }

  // ==================== CREAR MÚLTIPLES DETALLES ====================

  Future<bool> crearDetallesFactura(List<DetalleFactura> detalles) async {
    try {
      final List<Map<String, dynamic>> datosDetalles = [];

      for (var detalle in detalles) {
        // Validar que tenga factura asignada
        if (detalle.fk_factura == null ||
            detalle.fk_factura!.id_factura == null) {
          print('Error: Todos los detalles deben tener una factura asignada');
          return false;
        }

        // Buscar deuda coincidente para cada detalle
        int? idDeuda;
        if (detalle.fk_factura!.fk_inmueble.id != null) {
          idDeuda = await _buscarDeudaCoincidente(
            idInmueble: detalle.fk_factura!.fk_inmueble.id!,
            idConcepto: detalle.fk_concepto.id!,
            idCiclo: detalle.fk_ciclo?.id,
          );
        }

        datosDetalles.add({
          'fk_factura': detalle.fk_factura!.id_factura,
          'fk_concepto': detalle.fk_concepto.id,
          'monto': detalle.monto,
          'descripcion': detalle.descripcion,
          'iva_aplicado': detalle.iva_aplicado,
          'subtotal': detalle.subtotal,
          'estado': detalle.estado,
          'cantidad': detalle.cantidad,
          'fk_consumos': detalle.fk_consumos?.id_consumos,
          'fk_deudas': idDeuda ?? detalle.fk_deudas?.id_deuda,
          'fk_ciclo': detalle.fk_ciclo?.id,
        });
      }

      await supabase.from('detalle_factura').insert(datosDetalles);

      print('${detalles.length} detalles de factura creados exitosamente');
      return true;
    } catch (e) {
      print('Error al crear detalles de factura: $e');
      return false;
    }
  }
  // ==================== LEER TODOS LOS DETALLES ====================

  Future<List<DetalleFactura>> leerDetallesFactura() async {
    try {
      final data = await supabase
          .from('detalle_factura')
          .select()
          .order('id_detalle', ascending: false);

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay detalles de factura en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros =
          List<Map<String, dynamic>>.from(data);

      final List<DetalleFactura> detalles = [];

      for (var mapa in registros) {
        try {
          final detalle = await _convertirDetalle(mapa);
          detalles.add(detalle);
        } catch (e) {
          print('Error al convertir detalle: $e');
          continue;
        }
      }

      print('✓ Se cargaron ${detalles.length} detalles de factura');
      return detalles;
    } catch (e) {
      print('Error al leer detalles de factura: $e');
      return [];
    }
  }

  // ==================== LEER DETALLE POR ID ====================

  Future<DetalleFactura?> leerDetallePorId(int idDetalle) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('detalle_factura')
          .select()
          .eq('id_detalle', idDetalle)
          .single();

      return await _convertirDetalle(data);
    } catch (e) {
      print('Error al leer detalle por ID: $e');
      return null;
    }
  }

  // ==================== LEER DETALLES POR FACTURA ====================

  Future<List<DetalleFactura>> leerDetallesPorFactura(int idFactura) async {
    try {
      final data = await supabase
          .from('detalle_factura')
          .select()
          .eq('fk_factura', idFactura)
          .order('id_detalle', ascending: true);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros =
          List<Map<String, dynamic>>.from(data);

      final List<DetalleFactura> detalles = [];

      for (var mapa in registros) {
        try {
          final detalle = await _convertirDetalle(mapa);
          detalles.add(detalle);
        } catch (e) {
          print('Error al convertir detalle: $e');
          continue;
        }
      }

      return detalles;
    } catch (e) {
      print('Error al leer detalles por factura: $e');
      return [];
    }
  }

  // ==================== LEER DETALLES POR CONCEPTO ====================

  Future<List<DetalleFactura>> leerDetallesPorConcepto(int idConcepto) async {
    try {
      final data = await supabase
          .from('detalle_factura')
          .select()
          .eq('fk_concepto', idConcepto)
          .order('id_detalle', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros =
          List<Map<String, dynamic>>.from(data);

      final List<DetalleFactura> detalles = [];

      for (var mapa in registros) {
        try {
          final detalle = await _convertirDetalle(mapa);
          detalles.add(detalle);
        } catch (e) {
          print('Error al convertir detalle: $e');
          continue;
        }
      }

      return detalles;
    } catch (e) {
      print('Error al leer detalles por concepto: $e');
      return [];
    }
  }

  // ==================== LEER DETALLES POR CONSUMO ====================

  Future<List<DetalleFactura>> leerDetallesPorConsumo(int idConsumo) async {
    try {
      final data = await supabase
          .from('detalle_factura')
          .select()
          .eq('fk_consumos', idConsumo);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros =
          List<Map<String, dynamic>>.from(data);

      final List<DetalleFactura> detalles = [];

      for (var mapa in registros) {
        try {
          final detalle = await _convertirDetalle(mapa);
          detalles.add(detalle);
        } catch (e) {
          print('Error al convertir detalle: $e');
          continue;
        }
      }

      return detalles;
    } catch (e) {
      print('Error al leer detalles por consumo: $e');
      return [];
    }
  }

  // ==================== LEER DETALLES POR DEUDA ====================

  Future<List<DetalleFactura>> leerDetallesPorDeuda(int idDeuda) async {
    try {
      final data = await supabase
          .from('detalle_factura')
          .select()
          .eq('fk_deudas', idDeuda);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros =
          List<Map<String, dynamic>>.from(data);

      final List<DetalleFactura> detalles = [];

      for (var mapa in registros) {
        try {
          final detalle = await _convertirDetalle(mapa);
          detalles.add(detalle);
        } catch (e) {
          print('Error al convertir detalle: $e');
          continue;
        }
      }

      return detalles;
    } catch (e) {
      print('Error al leer detalles por deuda: $e');
      return [];
    }
  }

  // ==================== LEER DETALLES POR CICLO ====================

  Future<List<DetalleFactura>> leerDetallesPorCiclo(int idCiclo) async {
    try {
      final data = await supabase
          .from('detalle_factura')
          .select()
          .eq('fk_ciclo', idCiclo);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros =
          List<Map<String, dynamic>>.from(data);

      final List<DetalleFactura> detalles = [];

      for (var mapa in registros) {
        try {
          final detalle = await _convertirDetalle(mapa);
          detalles.add(detalle);
        } catch (e) {
          print('Error al convertir detalle: $e');
          continue;
        }
      }

      return detalles;
    } catch (e) {
      print('Error al leer detalles por ciclo: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR DETALLE ====================

  Future<bool> actualizarDetalleFactura(DetalleFactura detalle) async {
    try {
      // Validar que tenga factura asignada
      if (detalle.fk_factura == null ||
          detalle.fk_factura!.id_factura == null) {
        print('Error: El detalle debe tener una factura asignada');
        return false;
      }

      await supabase
          .from('detalle_factura')
          .update({
            'fk_factura': detalle.fk_factura!.id_factura,
            'fk_concepto': detalle.fk_concepto.id,
            'monto': detalle.monto,
            'descripcion': detalle.descripcion,
            'iva_aplicado': detalle.iva_aplicado,
            'subtotal': detalle.subtotal,
            'estado': detalle.estado,
            'cantidad': detalle.cantidad,
            'fk_consumos': detalle.fk_consumos?.id_consumos,
            'fk_deudas': detalle.fk_deudas?.id_deuda,
            'fk_ciclo': detalle.fk_ciclo?.id,
          })
          .eq('id_detalle', detalle.id_detalle!);

      print('Detalle de factura actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar detalle de factura: $e');
      return false;
    }
  }

  // ==================== CAMBIAR ESTADO DETALLE ====================

  Future<bool> cambiarEstadoDetalle(int idDetalle, String nuevoEstado) async {
    try {
      await supabase
          .from('detalle_factura')
          .update({'estado': nuevoEstado})
          .eq('id_detalle', idDetalle);

      print('Estado del detalle actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al cambiar estado del detalle: $e');
      return false;
    }
  }

  // ==================== ELIMINAR DETALLE ====================

  Future<bool> eliminarDetalleFactura(int idDetalle) async {
    try {
      await supabase
          .from('detalle_factura')
          .delete()
          .eq('id_detalle', idDetalle);

      print('Detalle de factura eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar detalle de factura: $e');
      return false;
    }
  }

  // ==================== ELIMINAR DETALLES POR FACTURA ====================

  Future<bool> eliminarDetallesPorFactura(int idFactura) async {
    try {
      await supabase
          .from('detalle_factura')
          .delete()
          .eq('fk_factura', idFactura);

      print('Detalles de factura eliminados exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar detalles de factura: $e');
      return false;
    }
  }

  // ==================== CALCULAR TOTAL POR FACTURA ====================

  Future<double> calcularTotalPorFactura(int idFactura) async {
    try {
      final detalles = await leerDetallesPorFactura(idFactura);

      double total = 0;
      for (var detalle in detalles) {
        total += detalle.subtotal;
      }

      return total;
    } catch (e) {
      print('Error al calcular total por factura: $e');
      return 0.0;
    }
  }

  // ==================== CONTAR DETALLES POR FACTURA ====================

  Future<int> contarDetallesPorFactura(int idFactura) async {
    try {
      final data = await supabase
          .from('detalle_factura')
          .select('id_detalle')
          .eq('fk_factura', idFactura)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar detalles por factura: $e');
      return 0;
    }
  }

  // ==================== VERIFICAR SI CONSUMO ESTÁ FACTURADO ====================

  Future<bool> consumoEstaFacturado(int idConsumo) async {
    try {
      final data = await supabase
          .from('detalle_factura')
          .select('id_detalle')
          .eq('fk_consumos', idConsumo)
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar consumo facturado: $e');
      return false;
    }
  }

  // ==================== VERIFICAR SI DEUDA ESTÁ FACTURADA ====================

  Future<bool> deudaEstaFacturada(int idDeuda) async {
    try {
      final data = await supabase
          .from('detalle_factura')
          .select('id_detalle')
          .eq('fk_deudas', idDeuda)
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar deuda facturada: $e');
      return false;
    }
  }

  // ==================== MÉTODO AUXILIAR PARA CONVERTIR ====================

  Future<DetalleFactura> _convertirDetalle(Map<String, dynamic> mapa) async {
    final idFactura = _toInt(mapa['fk_factura']);
    final idConcepto = _toInt(mapa['fk_concepto']);
    final idConsumo = mapa['fk_consumos'] != null
        ? _toInt(mapa['fk_consumos'])
        : null;
    final idDeuda = mapa['fk_deudas'] != null
        ? _toInt(mapa['fk_deudas'])
        : null;
    final idCiclo = mapa['fk_ciclo'] != null ? _toInt(mapa['fk_ciclo']) : null;

    final factura = await _facturaCrud.leerFacturaPorId(idFactura);
    final concepto = await _conceptoCrud.leerConceptoPorId(idConcepto);

    Consumo? consumo;
    if (idConsumo != null) {
      consumo = await _consumoCrud.leerConsumoPorId(idConsumo);
    }

    CuentaCobrar? deuda;
    if (idDeuda != null) {
      deuda = await _deudaCrud.leerDeudaPorId(idDeuda);
    }

    Ciclo? ciclo;
    if (idCiclo != null) {
      ciclo = await _cicloCrud.leerCicloPorId(idCiclo);
    }

    if (factura == null) {
      throw Exception('Factura con ID $idFactura no encontrada');
    }
    if (concepto == null) {
      throw Exception('Concepto con ID $idConcepto no encontrado');
    }

    return DetalleFactura(
      id_detalle: _toInt(mapa['id_detalle']),
      fk_factura: factura,
      fk_concepto: concepto,
      monto: _toDouble(mapa['monto']),
      descripcion: mapa['descripcion'] ?? '',
      iva_aplicado: _toInt(mapa['iva_aplicado']),
      subtotal: _toDouble(mapa['subtotal']),
      estado: mapa['estado'] ?? 'ACTIVO',
      cantidad: _toDouble(mapa['cantidad']),
      fk_consumos: consumo,
      fk_deudas: deuda,
      fk_ciclo: ciclo,
    );
  }
}
