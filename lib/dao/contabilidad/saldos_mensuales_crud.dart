import 'package:myapp/modelo/contabilidad/cuenta_contable.dart';
import 'package:myapp/modelo/contabilidad/saldo_mensual.dart';
import 'package:myapp/modelo/contabilidad/tipo_cuenta_contable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SaldosMensualesCrudImpl {

  static const String _select = '''
    *,
    cuentas_contables(
      *,
      tipo_cuenta_contable(*),
      padre:cuentas_contables!fk_cuenta_padre(
        *,
        tipo_cuenta_contable(*)
      )
    )
  ''';

  // ==================== CREAR ====================
  Future<SaldosMensuales?> crear(SaldosMensuales saldo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('saldos_mensuales')
          .insert({
            'fk_cuenta': saldo.cuenta.id,
            'mes': saldo.mes,
            'anio': saldo.anio,
            'saldo_debe_acumulado': saldo.saldoDebeAcumulado,
            'saldo_haber_acumulado': saldo.saldoHaberAcumulado,
            'saldo_final': saldo.saldoFinal,
          })
          .select(_select)
          .single();

      print('SaldoMensual creado exitosamente');
      return _fromMap(data);
    } catch (e) {
      print('Error al crear SaldoMensual: $e');
      return null;
    }
  }

  // ==================== LEER TODOS ====================
  Future<List<SaldosMensuales>> leerTodos() async {
    try {
      final data = await supabase
          .from('saldos_mensuales')
          .select(_select)
          .order('anio', ascending: false)
          .order('mes', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer SaldosMensuales: $e');
      return [];
    }
  }

  // ==================== LEER POR ID ====================
  Future<SaldosMensuales?> leerPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('saldos_mensuales')
          .select(_select)
          .eq('id', id)
          .single();

      return _fromMap(data);
    } catch (e) {
      print('Error al leer SaldoMensual por ID: $e');
      return null;
    }
  }

  // ==================== LEER POR MES Y AÑO ====================
  Future<List<SaldosMensuales>> leerPorMesAnio(int mes, int anio) async {
    try {
      final data = await supabase
          .from('saldos_mensuales')
          .select(_select)
          .eq('mes', mes)
          .eq('anio', anio);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer saldos por mes/año: $e');
      return [];
    }
  }

  // ==================== LEER POR CUENTA ====================
  Future<List<SaldosMensuales>> leerPorCuenta(int idCuenta) async {
    try {
      final data = await supabase
          .from('saldos_mensuales')
          .select(_select)
          .eq('fk_cuenta', idCuenta)
          .order('anio', ascending: false)
          .order('mes', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer saldos por cuenta: $e');
      return [];
    }
  }

  // ==================== LEER POR CUENTA, MES Y AÑO ====================
  Future<SaldosMensuales?> leerPorCuentaMesAnio(int idCuenta, int mes, int anio) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('saldos_mensuales')
          .select(_select)
          .eq('fk_cuenta', idCuenta)
          .eq('mes', mes)
          .eq('anio', anio)
          .single();

      return _fromMap(data);
    } catch (e) {
      print('Error al leer saldo por cuenta/mes/año: $e');
      return null;
    }
  }

  // ==================== LEER POR AÑO ====================
  Future<List<SaldosMensuales>> leerPorAnio(int anio) async {
    try {
      final data = await supabase
          .from('saldos_mensuales')
          .select(_select)
          .eq('anio', anio)
          .order('mes', ascending: true);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer saldos por año: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR ====================
  Future<bool> actualizar(SaldosMensuales saldo) async {
    try {
      await supabase
          .from('saldos_mensuales')
          .update({
            'fk_cuenta': saldo.cuenta.id,
            'mes': saldo.mes,
            'anio': saldo.anio,
            'saldo_debe_acumulado': saldo.saldoDebeAcumulado,
            'saldo_haber_acumulado': saldo.saldoHaberAcumulado,
            'saldo_final': saldo.saldoFinal,
          })
          .eq('id', saldo.id!);

      print('SaldoMensual actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar SaldoMensual: $e');
      return false;
    }
  }

  // ==================== ELIMINAR ====================
  Future<bool> eliminar(int id) async {
    try {
      await supabase
          .from('saldos_mensuales')
          .delete()
          .eq('id', id);

      print('SaldoMensual eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar SaldoMensual: $e');
      return false;
    }
  }

  // ==================== HELPER PRIVADO ====================
  SaldosMensuales _fromMap(Map<String, dynamic> m) {
    final cuentaMap = m['cuentas_contables'];

    return SaldosMensuales(
      id: m['id'],
      cuenta: CuentasContables(
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
      mes: m['mes'],
      anio: m['anio'],
      saldoDebeAcumulado: (m['saldo_debe_acumulado'] as num).toDouble(),
      saldoHaberAcumulado: (m['saldo_haber_acumulado'] as num).toDouble(),
      saldoFinal: (m['saldo_final'] as num).toDouble(),
    );
  }
}