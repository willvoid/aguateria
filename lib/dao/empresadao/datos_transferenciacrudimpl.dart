import 'package:myapp/modelo/empresa/datos_transferencia.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DatosTransferenciaCrudImpl {

  // ==================== CREAR ====================
  Future<DatosTransferencia?> crearDatosTransferencia(DatosTransferencia datos) async {
    try {
      await supabase
          .from('datos_transferencia')
          .insert({
            'alias': datos.alias,
            'titular_cuenta': datos.titular_cuenta,
            'banco': datos.banco,
            'ci': datos.ci,
            'num_cuenta': datos.num_cuenta,
            'fk_sucursal': datos.fk_sucursal.id_establecimiento,
            'nro_giro': datos.nro_giro,
            'ci_giro': datos.ci_giro,
          });

      print('DatosTransferencia creado exitosamente');
      return datos;
    } catch (e) {
      print('Error al crear datos de transferencia: $e');
      return null;
    }
  }

  // ==================== LEER TODOS ====================
  Future<List<DatosTransferencia>> leerDatosTransferencia() async {
    try {
      final data = await supabase
          .from('datos_transferencia')
          .select('''
            *,
            fk_sucursal (
              *,
              fk_barrio(*),
              fk_empresa(*, fk_contribuyente(*), fk_regimen(*))
            )
          ''');

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((mapa) => _fromMap(mapa))
          .toList();
    } catch (e) {
      print('Error al leer datos de transferencia: $e');
      return [];
    }
  }

  // ==================== LEER POR ID ====================
  Future<DatosTransferencia?> leerDatosTransferenciaPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('datos_transferencia')
          .select('''
            *,
            fk_sucursal (
              *,
              fk_barrio(*),
              fk_empresa(*, fk_contribuyente(*), fk_regimen(*))
            )
          ''')
          .eq('id', id)
          .single();

      return _fromMap(data);
    } catch (e) {
      print('Error al leer datos de transferencia por ID: $e');
      return null;
    }
  }

  // ==================== LEER POR SUCURSAL ====================
  Future<List<DatosTransferencia>> leerDatosTransferenciaPorSucursal(int idSucursal) async {
    try {
      final data = await supabase
          .from('datos_transferencia')
          .select('''
            *,
            fk_sucursal (
              *,
              fk_barrio(*),
              fk_empresa(*, fk_contribuyente(*), fk_regimen(*))
            )
          ''')
          .eq('fk_sucursal', idSucursal);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((mapa) => _fromMap(mapa))
          .toList();
    } catch (e) {
      print('Error al leer datos de transferencia por sucursal: $e');
      return [];
    }
  }

  // ==================== BUSCAR ====================
  Future<List<DatosTransferencia>> buscarDatosTransferencia(String busqueda) async {
    try {
      final data = await supabase
          .from('datos_transferencia')
          .select('''
            *,
            fk_sucursal (
              *,
              fk_barrio(*),
              fk_empresa(*, fk_contribuyente(*), fk_regimen(*))
            )
          ''')
          .or('alias.ilike.%$busqueda%,titular_cuenta.ilike.%$busqueda%,banco.ilike.%$busqueda%');

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((mapa) => _fromMap(mapa))
          .toList();
    } catch (e) {
      print('Error al buscar datos de transferencia: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR ====================
  Future<bool> actualizarDatosTransferencia(DatosTransferencia datos) async {
    try {
      await supabase
          .from('datos_transferencia')
          .update({
            'alias': datos.alias,
            'titular_cuenta': datos.titular_cuenta,
            'banco': datos.banco,
            'ci': datos.ci,
            'num_cuenta': datos.num_cuenta,
            'fk_sucursal': datos.fk_sucursal.id_establecimiento,
            'nro_giro': datos.nro_giro,
            'ci_giro': datos.ci_giro,
          })
          .eq('id', datos.id);

      print('DatosTransferencia actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar datos de transferencia: $e');
      return false;
    }
  }

  // ==================== ELIMINAR ====================
  Future<bool> eliminarDatosTransferencia(int id) async {
    try {
      await supabase
          .from('datos_transferencia')
          .delete()
          .eq('id', id);

      print('DatosTransferencia eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar datos de transferencia: $e');
      return false;
    }
  }

  // ==================== VERIFICAR CUENTA EXISTENTE ====================
  Future<bool> verificarCuentaExistente(String numCuenta, {int? idExcluir}) async {
    try {
      var query = supabase
          .from('datos_transferencia')
          .select('id')
          .eq('num_cuenta', numCuenta);

      if (idExcluir != null) {
        query = query.neq('id', idExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar número de cuenta: $e');
      return false;
    }
  }

  // ==================== HELPER PRIVADO ====================
  DatosTransferencia _fromMap(Map<String, dynamic> mapa) {
    final datosSucursal = mapa['fk_sucursal'];

    if (datosSucursal == null) {
      throw Exception('Dato de transferencia sin sucursal asignada');
    }

    return DatosTransferencia(
      id: mapa['id'],
      alias: mapa['alias'],
      titular_cuenta: mapa['titular_cuenta'] ?? '',
      banco: mapa['banco'] ?? '',
      ci: mapa['ci'] ?? '',
      num_cuenta: mapa['num_cuenta'] ?? '',
      fk_sucursal: Establecimiento.fromMap(datosSucursal),
      nro_giro: mapa['nro_giro'],
      ci_giro: mapa['ci_giro'],
    );
  }
}