import 'package:myapp/modelo/empresa/caja.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CajaCrudImpl {

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ==================== CREAR CAJA ====================

  Future<Caja?> crearCaja(Caja caja) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('caja')
          .insert({
            'nro_caja': caja.nro_caja,
            'descripcion_caja': caja.descripcion_caja,
            'fk_establecimientos': caja.fk_establecimiento.id_establecimiento,
          })
          .select('*, fk_establecimientos(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .single();

      print('Caja creada exitosamente');
      return Caja.fromMap(data);
    } catch (e) {
      print('Error al crear caja: $e');
      return null;
    }
  }

  // ==================== LEER TODAS LAS CAJAS ====================

  Future<List<Caja>> leerCajas() async {
    try {
      final data = await supabase
          .from('caja')
          .select('*, fk_establecimientos(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))');

      if (data == null) {
        print('La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay cajas en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Caja> cajas = registros.map((mapa) {
        final datosEstablecimiento = mapa['fk_establecimientos'];

        if (datosEstablecimiento == null) {
          throw Exception('Caja sin establecimiento asignado');
        }

        return Caja(
          id_caja: _toInt(mapa['id_caja']),
          nro_caja: _toInt(mapa['nro_caja']),
          descripcion_caja: mapa['descripcion_caja'],
          fk_establecimiento: Establecimiento.fromMap(datosEstablecimiento),
        );
      }).toList();

      print('Se cargaron ${cajas.length} cajas');
      return cajas;
    } catch (e) {
      print('Error al leer cajas: $e');
      return [];
    }
  }

  // ==================== LEER CAJA POR ID ====================

  Future<Caja?> leerCajaPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('caja')
          .select('*, fk_establecimientos(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('id_caja', id)
          .single();

      return Caja.fromMap(data);
    } catch (e) {
      print('Error al leer caja por ID: $e');
      return null;
    }
  }

  // ==================== LEER CAJA POR NÚMERO ====================

  Future<Caja?> leerCajaPorNumero(int numeroCaja, int idEstablecimiento) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('caja')
          .select('*, fk_establecimientos(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('nro_caja', numeroCaja)
          .eq('fk_establecimientos', idEstablecimiento)
          .single();

      return Caja.fromMap(data);
    } catch (e) {
      print('Error al leer caja por número: $e');
      return null;
    }
  }

  // ==================== BUSCAR CAJAS ====================

  Future<List<Caja>> buscarCajas(String busqueda) async {
    try {
      final data = await supabase
          .from('caja')
          .select('*, fk_establecimientos(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .or('nro_caja.eq.${int.tryParse(busqueda) ?? -1},descripcion_caja.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Caja> cajas = registros.map((mapa) {
        return Caja.fromMap(mapa);
      }).toList();

      return cajas;
    } catch (e) {
      print('Error al buscar cajas: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR ESTABLECIMIENTO ====================

  Future<List<Caja>> buscarPorEstablecimiento(int idEstablecimiento) async {
    try {
      final data = await supabase
          .from('caja')
          .select('*, fk_establecimientos(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('fk_establecimientos', idEstablecimiento);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Caja> cajas = registros.map((mapa) {
        return Caja.fromMap(mapa);
      }).toList();

      return cajas;
    } catch (e) {
      print('Error al buscar cajas por establecimiento: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR EMPRESA ====================

  Future<List<Caja>> buscarPorEmpresa(int idEmpresa) async {
    try {
      final data = await supabase
          .from('caja')
          .select('*, fk_establecimientos!inner(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('fk_establecimiento.fk_empresa', idEmpresa);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Caja> cajas = registros.map((mapa) {
        return Caja.fromMap(mapa);
      }).toList();

      return cajas;
    } catch (e) {
      print('Error al buscar cajas por empresa: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR CAJA ====================

  Future<bool> actualizarCaja(Caja caja) async {
    try {
      await supabase
          .from('caja')
          .update({
            'nro_caja': caja.nro_caja,
            'descripcion_caja': caja.descripcion_caja,
            'fk_establecimientos': caja.fk_establecimiento.id_establecimiento,
          })
          .eq('id_caja', caja.id_caja!);

      print('Caja actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar caja: $e');
      return false;
    }
  }

  // ==================== ELIMINAR CAJA ====================

  Future<bool> eliminarCaja(int id) async {
    try {
      await supabase
          .from('caja')
          .delete()
          .eq('id_caja', id);

      print('Caja eliminada exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar caja: $e');
      return false;
    }
  }

  // ==================== VERIFICAR NÚMERO CAJA EXISTENTE ====================

  Future<bool> verificarNumeroCajaExistente(
    int numeroCaja,
    int idEstablecimiento,
    {int? idCajaExcluir}
  ) async {
    try {
      var query = supabase
          .from('caja')
          .select('id_caja')
          .eq('nro_caja', numeroCaja)
          .eq('fk_establecimientos', idEstablecimiento);

      if (idCajaExcluir != null) {
        query = query.neq('id_caja', idCajaExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar número de caja: $e');
      return false;
    }
  }

  // ==================== CONTAR CAJAS ====================

  Future<int> contarCajas() async {
    try {
      final data = await supabase
          .from('caja')
          .select('id_caja')
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar cajas: $e');
      return 0;
    }
  }

  // ==================== CONTAR CAJAS POR ESTABLECIMIENTO ====================

  Future<int> contarCajasPorEstablecimiento(int idEstablecimiento) async {
    try {
      final data = await supabase
          .from('caja')
          .select('id_caja')
          .eq('fk_establecimientos', idEstablecimiento)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar cajas por establecimiento: $e');
      return 0;
    }
  }

  // ==================== CONTAR CAJAS POR EMPRESA ====================

  Future<int> contarCajasPorEmpresa(int idEmpresa) async {
    try {
      final data = await supabase
          .from('caja')
          .select('id_caja, fk_establecimiento!inner(fk_empresa)')
          .eq('fk_establecimientos.fk_empresa', idEmpresa)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar cajas por empresa: $e');
      return 0;
    }
  }

  // ==================== OBTENER PRÓXIMO NÚMERO DE CAJA ====================

  Future<int> obtenerProximoNumeroCaja(int idEstablecimiento) async {
    try {
      final data = await supabase
          .from('caja')
          .select('nro_caja')
          .eq('fk_establecimientos', idEstablecimiento)
          .order('nro_caja', ascending: false)
          .limit(1);

      if (data.isEmpty) {
        return 1; // Primera caja
      }

      final ultimoNumero = _toInt(data.first['nro_caja']);
      return ultimoNumero + 1;
    } catch (e) {
      print('Error al obtener próximo número de caja: $e');
      return 1;
    }
  }

  // ==================== VERIFICAR SI CAJA TIENE MOVIMIENTOS ====================

  Future<bool> cajaTieneMovimientos(int idCaja) async {
    try {
      // Verificar si hay movimientos asociados a esta caja
      // Esto dependerá de tu estructura de base de datos
      // Ejemplo: si tienes una tabla 'movimientos_caja'
      final data = await supabase
          .from('movimientos_caja')
          .select('id_movimiento')
          .eq('fk_caja', idCaja)
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar movimientos de caja: $e');
      return false;
    }
  }

  // ==================== OBTENER CAJAS DISPONIBLES ====================

  Future<List<Caja>> obtenerCajasDisponibles(int idEstablecimiento) async {
    try {
      // Obtener cajas que no están siendo usadas actualmente
      // Esto dependerá de tu lógica de negocio
      // Ejemplo básico: todas las cajas del establecimiento
      return await buscarPorEstablecimiento(idEstablecimiento);
    } catch (e) {
      print('Error al obtener cajas disponibles: $e');
      return [];
    }
  }
}