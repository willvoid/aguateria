import 'package:myapp/modelo/contabilidad/cuenta_contable.dart';
import 'package:myapp/modelo/contabilidad/tipo_cuenta_contable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CuentasContablesCrudImpl {

  static const String _select = '''
    *,
    tipo_cuenta_contable(*),
    padre:cuentas_contables!fk_cuenta_padre(
      *,
      tipo_cuenta_contable(*)
    )
  ''';

  // ==================== CREAR ====================
  Future<CuentasContables?> crear(CuentasContables cuenta) async {
    try {
      final Map<String, dynamic> insertData = {
        'nombre': cuenta.nombre,
        'codigo': cuenta.codigo,
        'fk_tipo_cuenta': cuenta.tipoCuenta.id,
        'imputable': cuenta.imputable,
      };

      if (cuenta.cuentaPadre != null) {
        insertData['fk_cuenta_padre'] = cuenta.cuentaPadre!.id;
      }

      final Map<String, dynamic> data = await supabase
          .from('cuentas_contables')
          .insert(insertData)
          .select(_select)
          .single();

      print('CuentasContables creada exitosamente');
      return _fromMapConRelaciones(data);
    } catch (e) {
      print('Error al crear CuentasContables: $e');
      return null;
    }
  }

  // ==================== LEER TODAS ====================
  Future<List<CuentasContables>> leerTodas() async {
    try {
      final data = await supabase
          .from('cuentas_contables')
          .select(_select);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMapConRelaciones(m))
          .toList();
    } catch (e) {
      print('Error al leer CuentasContables: $e');
      return [];
    }
  }

  // ==================== LEER POR ID ====================
  Future<CuentasContables?> leerPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('cuentas_contables')
          .select(_select)
          .eq('id', id)
          .single();

      return _fromMapConRelaciones(data);
    } catch (e) {
      print('Error al leer CuentasContables por ID: $e');
      return null;
    }
  }

  // ==================== LEER POR TIPO ====================
  Future<List<CuentasContables>> leerPorTipo(int idTipo) async {
    try {
      final data = await supabase
          .from('cuentas_contables')
          .select(_select)
          .eq('fk_tipo_cuenta', idTipo);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMapConRelaciones(m))
          .toList();
    } catch (e) {
      print('Error al leer CuentasContables por tipo: $e');
      return [];
    }
  }

  // ==================== LEER IMPUTABLES ====================
  Future<List<CuentasContables>> leerImputables() async {
    try {
      final data = await supabase
          .from('cuentas_contables')
          .select(_select)
          .eq('imputable', true);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMapConRelaciones(m))
          .toList();
    } catch (e) {
      print('Error al leer cuentas imputables: $e');
      return [];
    }
  }

  // ==================== BUSCAR ====================
  Future<List<CuentasContables>> buscar(String busqueda) async {
    try {
      final data = await supabase
          .from('cuentas_contables')
          .select(_select)
          .or('nombre.ilike.%$busqueda%,codigo.ilike.%$busqueda%');

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMapConRelaciones(m))
          .toList();
    } catch (e) {
      print('Error al buscar CuentasContables: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR ====================
  Future<bool> actualizar(CuentasContables cuenta) async {
    try {
      final Map<String, dynamic> updateData = {
        'nombre': cuenta.nombre,
        'codigo': cuenta.codigo,
        'fk_tipo_cuenta': cuenta.tipoCuenta.id,
        'imputable': cuenta.imputable,
      };

      if (cuenta.cuentaPadre != null) {
        updateData['fk_cuenta_padre'] = cuenta.cuentaPadre!.id;
      }

      await supabase
          .from('cuentas_contables')
          .update(updateData)
          .eq('id', cuenta.id!);

      print('CuentasContables actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar CuentasContables: $e');
      return false;
    }
  }

  // ==================== ELIMINAR ====================
  Future<bool> eliminar(int id) async {
    try {
      await supabase
          .from('cuentas_contables')
          .delete()
          .eq('id', id);

      print('CuentasContables eliminada exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar CuentasContables: $e');
      return false;
    }
  }

  // ==================== HELPER PRIVADO ====================
  CuentasContables _fromMapConRelaciones(Map<String, dynamic> m) {
    return CuentasContables(
      id: m['id'],
      nombre: m['nombre'],
      codigo: m['codigo'],
      tipoCuenta: TipoCuentaContable.fromMap(m['tipo_cuenta_contable']),
      imputable: m['imputable'],
      cuentaPadre: m['padre'] != null
          ? CuentasContables(
              id: m['padre']['id'],
              nombre: m['padre']['nombre'],
              codigo: m['padre']['codigo'],
              tipoCuenta: TipoCuentaContable.fromMap(m['padre']['tipo_cuenta_contable']),
              imputable: m['padre']['imputable'],
            )
          : null,
    );
  }
}