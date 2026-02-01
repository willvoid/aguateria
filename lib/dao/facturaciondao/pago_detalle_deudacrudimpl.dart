import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/facturacionmodelo/pago.dart';
import 'package:myapp/modelo/facturacionmodelo/pago_detalle_deuda.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class PagoDetalleDeudaCrudImpl {
  
  // ==================== HELPER: CONSTRUIR PAGO DETALLE DEUDA DESDE MAPA ====================
  PagoDetalleDeuda _construirPagoDetalleDeudaDesdeMap(Map<String, dynamic> mapa) {
    // Parsear pago
    Pago? pago;
    if (mapa['pagos'] != null) {
      try {
        pago = Pago.fromMap(mapa['pagos']);
      } catch (e) {
        print('🔴 ERROR al parsear PAGO en detalle #${mapa['id']}');
        print('   Error: $e');
        print('   Datos de pago: ${mapa['pagos']}');
      }
    }

    // Parsear cuenta por cobrar
    CuentaCobrar? deuda;
    if (mapa['cuenta_cobrar'] != null) {
      try {
        deuda = CuentaCobrar.fromMap(mapa['cuenta_cobrar']);
      } catch (e) {
        print('🔴 ERROR al parsear CUENTA_COBRAR en detalle #${mapa['id']}');
        print('   Error: $e');
        print('   Datos de deuda: ${mapa['cuenta_cobrar']}');
      }
    }

    return PagoDetalleDeuda(
      id: mapa['id'],
      fk_pago: pago!,
      fk_deuda: deuda!,
      monto_aplicado: (mapa['monto_aplicado'] as num).toDouble(),
    );
  }

  // ==================== CREAR PAGO DETALLE DEUDA ====================
  Future<PagoDetalleDeuda?> crearPagoDetalleDeuda(PagoDetalleDeuda detalle) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('pago_detalle_deuda')
          .insert({
            'fk_pago': detalle.fk_pago.idPago,
            'fk_deuda': detalle.fk_deuda.id_deuda,
            'monto_aplicado': detalle.monto_aplicado,
          })
          .select('''
            *,
            pagos(
              *,
              facturas(*),
              fk_usuario (
                *,
                fk_cargo:cargo(*),
                fk_tipo_doc:tipo_documento(*)
              ),
              clientes(
                *,
                tipo_documento(*),
                barrios(*),
                tipo_operacion(*)
              ),
              modo_pago(*)
            ),
            cuenta_cobrar(*)
          ''')
          .single();

      print('Pago detalle deuda creado exitosamente');
      return _construirPagoDetalleDeudaDesdeMap(data);
    } catch (e) {
      print('Error al crear pago detalle deuda: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS DETALLES ====================
  Future<List<PagoDetalleDeuda>> leerPagoDetalleDeudas() async {
    try {
      final data = await supabase.from('pago_detalle_deuda').select('''
        *,
        pagos(
          *,
          facturas(*),
          fk_usuario (
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ),
          clientes(
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*)
          ),
          modo_pago(*)
        ),
        cuenta_cobrar(*)
      ''');

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay detalles de pago en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<PagoDetalleDeuda> detalles = [];
      for (var mapa in registros) {
        try {
          detalles.add(_construirPagoDetalleDeudaDesdeMap(mapa));
        } catch (e) {
          print('❌ Error en detalle #${mapa['id']}: $e');
          continue;
        }
      }

      print('✓ Se cargaron ${detalles.length} detalles de pago');
      return detalles;
    } catch (e) {
      print('Error al leer detalles de pago: $e');
      return [];
    }
  }

  // ==================== LEER UN DETALLE POR ID ====================
  Future<PagoDetalleDeuda?> leerPagoDetalleDeudaPorId(int id) async {
    try {
      final data = await supabase.from('pago_detalle_deuda').select('''
        *,
        pagos(
          *,
          facturas(*),
          fk_usuario (
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ),
          clientes(
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*)
          ),
          modo_pago(*)
        ),
        cuenta_cobrar(*)
      ''').eq('id', id).single();

      return _construirPagoDetalleDeudaDesdeMap(data);
    } catch (e) {
      print('Error al leer detalle por ID: $e');
      return null;
    }
  }

  // ==================== LEER DETALLES POR PAGO ====================
  Future<List<PagoDetalleDeuda>> leerDetallesPorPago(int idPago) async {
    try {
      final data = await supabase.from('pago_detalle_deuda').select('''
        *,
        pagos(
          *,
          facturas(*),
          fk_usuario (
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ),
          clientes(
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*)
          ),
          modo_pago(*)
        ),
        cuenta_cobrar(*)
      ''').eq('fk_pago', idPago);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<PagoDetalleDeuda> detalles = [];
      for (var mapa in registros) {
        try {
          detalles.add(_construirPagoDetalleDeudaDesdeMap(mapa));
        } catch (e) {
          print('❌ Error al procesar detalle #${mapa['id']}: $e');
          continue;
        }
      }

      return detalles;
    } catch (e) {
      print('Error al leer detalles por pago: $e');
      return [];
    }
  }

  // ==================== LEER DETALLES POR DEUDA ====================
  Future<List<PagoDetalleDeuda>> leerDetallesPorDeuda(int idDeuda) async {
    try {
      final data = await supabase.from('pago_detalle_deuda').select('''
        *,
        pagos(
          *,
          facturas(*),
          fk_usuario (
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ),
          clientes(
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*)
          ),
          modo_pago(*)
        ),
        cuenta_cobrar(*)
      ''').eq('fk_deuda', idDeuda);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<PagoDetalleDeuda> detalles = [];
      for (var mapa in registros) {
        try {
          detalles.add(_construirPagoDetalleDeudaDesdeMap(mapa));
        } catch (e) {
          print('❌ Error al procesar detalle #${mapa['id']}: $e');
          continue;
        }
      }

      return detalles;
    } catch (e) {
      print('Error al leer detalles por deuda: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR DETALLE ====================
  Future<bool> actualizarPagoDetalleDeuda(PagoDetalleDeuda detalle) async {
    try {
      await supabase
          .from('pago_detalle_deuda')
          .update({
            'fk_pago': detalle.fk_pago.idPago,
            'fk_deuda': detalle.fk_deuda.id_deuda,
            'monto_aplicado': detalle.monto_aplicado,
          })
          .eq('id', detalle.id!);

      print('Detalle de pago actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar detalle: $e');
      return false;
    }
  }

  // ==================== ELIMINAR DETALLE ====================
  Future<bool> eliminarPagoDetalleDeuda(int id) async {
    try {
      await supabase
          .from('pago_detalle_deuda')
          .delete()
          .eq('id', id);

      print('Detalle de pago eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar detalle: $e');
      return false;
    }
  }

  // ==================== ELIMINAR DETALLES POR PAGO ====================
  Future<bool> eliminarDetallesPorPago(int idPago) async {
    try {
      await supabase
          .from('pago_detalle_deuda')
          .delete()
          .eq('fk_pago', idPago);

      print('Detalles del pago eliminados exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar detalles por pago: $e');
      return false;
    }
  }

  // ==================== CALCULAR TOTAL APLICADO A DEUDA ====================
  Future<double> calcularTotalAplicadoADeuda(int idDeuda) async {
    try {
      final data = await supabase
          .from('pago_detalle_deuda')
          .select('monto_aplicado')
          .eq('fk_deuda', idDeuda);

      if (data == null || data.isEmpty) {
        return 0.0;
      }

      double total = 0.0;
      for (var detalle in data) {
        total += (detalle['monto_aplicado'] as num).toDouble();
      }

      return total;
    } catch (e) {
      print('Error al calcular total aplicado: $e');
      return 0.0;
    }
  }

  // ==================== CALCULAR TOTAL APLICADO DE PAGO ====================
  Future<double> calcularTotalAplicadoDePago(int idPago) async {
    try {
      final data = await supabase
          .from('pago_detalle_deuda')
          .select('monto_aplicado')
          .eq('fk_pago', idPago);

      if (data == null || data.isEmpty) {
        return 0.0;
      }

      double total = 0.0;
      for (var detalle in data) {
        total += (detalle['monto_aplicado'] as num).toDouble();
      }

      return total;
    } catch (e) {
      print('Error al calcular total aplicado de pago: $e');
      return 0.0;
    }
  }

  // ==================== VERIFICAR SI PAGO TIENE DETALLES ====================
  Future<bool> pagoTieneDetalles(int idPago) async {
    try {
      final data = await supabase
          .from('pago_detalle_deuda')
          .select('id')
          .eq('fk_pago', idPago)
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar detalles del pago: $e');
      return false;
    }
  }

  // ==================== CREAR MÚLTIPLES DETALLES (TRANSACCIÓN) ====================
  Future<bool> crearMultiplesDetalles(List<PagoDetalleDeuda> detalles) async {
    try {
      final List<Map<String, dynamic>> datosParaInsertar = detalles.map((detalle) {
        return {
          'fk_pago': detalle.fk_pago.idPago,
          'fk_deuda': detalle.fk_deuda.id_deuda,
          'monto_aplicado': detalle.monto_aplicado,
        };
      }).toList();

      await supabase
          .from('pago_detalle_deuda')
          .insert(datosParaInsertar);

      print('${detalles.length} detalles de pago creados exitosamente');
      return true;
    } catch (e) {
      print('Error al crear múltiples detalles: $e');
      return false;
    }
  }
}