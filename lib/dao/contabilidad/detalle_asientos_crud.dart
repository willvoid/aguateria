import 'package:myapp/modelo/contabilidad/asiento.dart';
import 'package:myapp/modelo/contabilidad/cuenta_contable.dart';
import 'package:myapp/modelo/contabilidad/detalle_asiento.dart';
import 'package:myapp/modelo/contabilidad/tipo_cuenta_contable.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DetalleAsientosCrudImpl {

  static const String _select = '''
    *,
    cuentas_contables(
      *,
      tipo_cuenta_contable(*),
      padre:cuentas_contables!fk_cuenta_padre(
        *,
        tipo_cuenta_contable(*)
      )
    ),
    asientos(
      *,
      establecimientos(*)
    )
  ''';

  // ==================== CREAR ====================
  Future<DetalleAsientos?> crear(DetalleAsientos detalle) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('detalle_asientos')
          .insert({
            'fk_cuenta_contables': detalle.cuentaContable.id,
            'fk_asientos': detalle.asiento.id,
            'debe': detalle.debe,
            'haber': detalle.haber,
          })
          .select(_select)
          .single();

      print('DetalleAsiento creado exitosamente');
      return _fromMap(data);
    } catch (e) {
      print('Error al crear DetalleAsiento: $e');
      return null;
    }
  }

  // ==================== CREAR MÚLTIPLES (para un asiento completo) ====================
  Future<bool> crearVarios(List<DetalleAsientos> detalles) async {
    try {
      final List<Map<String, dynamic>> insertData = detalles.map((d) => {
        'fk_cuenta_contables': d.cuentaContable.id,
        'fk_asientos': d.asiento.id,
        'debe': d.debe,
        'haber': d.haber,
      }).toList();

      await supabase
          .from('detalle_asientos')
          .insert(insertData);

      print('${detalles.length} detalles de asiento creados exitosamente');
      return true;
    } catch (e) {
      print('Error al crear detalles de asiento: $e');
      return false;
    }
  }

  // ==================== LEER TODOS ====================
  Future<List<DetalleAsientos>> leerTodos() async {
    try {
      final data = await supabase
          .from('detalle_asientos')
          .select(_select);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer DetalleAsientos: $e');
      return [];
    }
  }

  // ==================== LEER POR ID ====================
  Future<DetalleAsientos?> leerPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('detalle_asientos')
          .select(_select)
          .eq('id', id)
          .single();

      return _fromMap(data);
    } catch (e) {
      print('Error al leer DetalleAsiento por ID: $e');
      return null;
    }
  }

  // ==================== LEER POR ASIENTO ====================
  Future<List<DetalleAsientos>> leerPorAsiento(int idAsiento) async {
    try {
      final data = await supabase
          .from('detalle_asientos')
          .select(_select)
          .eq('fk_asientos', idAsiento);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer detalles por asiento: $e');
      return [];
    }
  }

  // ==================== LEER POR CUENTA CONTABLE ====================
  Future<List<DetalleAsientos>> leerPorCuenta(int idCuenta) async {
    try {
      final data = await supabase
          .from('detalle_asientos')
          .select(_select)
          .eq('fk_cuenta_contables', idCuenta);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer detalles por cuenta: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR ====================
  Future<bool> actualizar(DetalleAsientos detalle) async {
    try {
      await supabase
          .from('detalle_asientos')
          .update({
            'fk_cuenta_contables': detalle.cuentaContable.id,
            'fk_asientos': detalle.asiento.id,
            'debe': detalle.debe,
            'haber': detalle.haber,
          })
          .eq('id', detalle.id!);

      print('DetalleAsiento actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar DetalleAsiento: $e');
      return false;
    }
  }

  // ==================== ELIMINAR ====================
  Future<bool> eliminar(int id) async {
    try {
      await supabase
          .from('detalle_asientos')
          .delete()
          .eq('id', id);

      print('DetalleAsiento eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar DetalleAsiento: $e');
      return false;
    }
  }

  // ==================== ELIMINAR POR ASIENTO ====================
  Future<bool> eliminarPorAsiento(int idAsiento) async {
    try {
      await supabase
          .from('detalle_asientos')
          .delete()
          .eq('fk_asientos', idAsiento);

      print('Detalles del asiento eliminados exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar detalles por asiento: $e');
      return false;
    }
  }

  // ==================== HELPER PRIVADO ====================
  DetalleAsientos _fromMap(Map<String, dynamic> m) {
    final cuentaMap = m['cuentas_contables'];
    final asientoMap = m['asientos'];

    return DetalleAsientos(
      id: m['id'],
      cuentaContable: CuentasContables(
        id: cuentaMap['id'],
        nombre: cuentaMap['nombre'],
        codigo: cuentaMap['codigo'],
        tipoCuenta: TipoCuentaContable.fromMap(cuentaMap['tipo_cuenta_contable']),
        imputable: cuentaMap['imputable'],
        cuentaPadre: cuentaMap['padre'] != null
            ? CuentasContables(
                id: cuentaMap['padre']['id'],
                nombre: cuentaMap['padre']['nombre'],
                codigo: cuentaMap['padre']['codigo'],
                tipoCuenta: TipoCuentaContable.fromMap(cuentaMap['padre']['tipo_cuenta_contable']),
                imputable: cuentaMap['padre']['imputable'],
              )
            : null,
      ),
      asiento: Asientos(
        id: asientoMap['id'],
        fecha: DateTime.parse(asientoMap['fecha']),
        descripcion: asientoMap['descripcion'],
        nroAsiento: asientoMap['nro_asiento'],
        sucursal: Establecimiento.fromMap(asientoMap['establecimientos']),
        estado: asientoMap['estado'],
        origenTipo: asientoMap['origen_tipo'],
        fkOrigen: asientoMap['fk_origen'],
      ),
      debe: (m['debe'] as num).toDouble(),
      haber: (m['haber'] as num).toDouble(),
    );
  }
}