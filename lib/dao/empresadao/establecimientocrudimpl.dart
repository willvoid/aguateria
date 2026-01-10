import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/empresa/dato_empresa.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class EstablecimientoCrudImpl {

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ==================== CREAR ESTABLECIMIENTO ====================

  Future<Establecimiento?> crearEstablecimiento(Establecimiento establecimiento) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('establecimientos')
          .insert({
            'codigo_establecimiento': establecimiento.codigo_establecimiento,
            'direccion': establecimiento.direccion,
            'numero_casa': establecimiento.numero_casa,
            'complemento_direccion_1': establecimiento.complemento_direccion_1,
            'complemento_direccion_2': establecimiento.complemento_direccion_2,
            'telefono': establecimiento.telefono,
            'email': establecimiento.email,
            'denominacion': establecimiento.denominacion,
            'estado_establecimiento': establecimiento.estado_establecimiento,
            'fk_barrio': establecimiento.fk_barrio.cod_barrio,
            'fk_empresa': establecimiento.fk_empresa.id_empresa,
          })
          .select('*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*))')
          .single();

      print('Establecimiento creado exitosamente');
      return Establecimiento.fromMap(data);
    } catch (e) {
      print('Error al crear establecimiento: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS ESTABLECIMIENTOS ====================

  Future<List<Establecimiento>> leerEstablecimientos() async {
    try {
      final data = await supabase
          .from('establecimientos')
          .select('*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*))');

      if (data == null) {
        print('La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay establecimientos en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Establecimiento> establecimientos = registros.map((mapa) {
        final datosBarrio = mapa['fk_barrio'];
        final datosEmpresa = mapa['fk_empresa'];

        if (datosBarrio == null || datosEmpresa == null) {
          throw Exception('Establecimiento sin barrio o empresa asignada');
        }

        return Establecimiento(
          id_establecimiento: _toInt(mapa['id_establecimiento']),
          codigo_establecimiento: mapa['codigo_establecimiento'] ?? '',
          direccion: mapa['direccion'] ?? '',
          numero_casa: mapa['numero_casa'] ?? '',
          complemento_direccion_1: mapa['complemento_direccion_1'] ?? '',
          complemento_direccion_2: mapa['complemento_direccion_2'],
          telefono: mapa['telefono'],
          email: mapa['email'],
          denominacion: mapa['denominacion'] ?? '',
          estado_establecimiento: mapa['estado_establecimiento'] ?? 'ACTIVO',
          fk_barrio: Barrio.fromMap(datosBarrio),
          fk_empresa: DatoEmpresa.fromMap(datosEmpresa),
        );
      }).toList();

      print('Se cargaron ${establecimientos.length} establecimientos');
      return establecimientos;
    } catch (e) {
      print('Error al leer establecimientos: $e');
      return [];
    }
  }

  // ==================== LEER ESTABLECIMIENTO POR ID ====================

  Future<Establecimiento?> leerEstablecimientoPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('establecimientos')
          .select('*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*))')
          .eq('id_establecimiento', id)
          .single();

      return Establecimiento.fromMap(data);
    } catch (e) {
      print('Error al leer establecimiento por ID: $e');
      return null;
    }
  }

  // ==================== LEER ESTABLECIMIENTO POR CÓDIGO ====================

  Future<Establecimiento?> leerEstablecimientoPorCodigo(String codigo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('establecimientos')
          .select('*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*))')
          .eq('codigo_establecimiento', codigo)
          .single();

      return Establecimiento.fromMap(data);
    } catch (e) {
      print('Error al leer establecimiento por código: $e');
      return null;
    }
  }

  // ==================== BUSCAR ESTABLECIMIENTOS ====================

  Future<List<Establecimiento>> buscarEstablecimientos(String busqueda) async {
    try {
      final data = await supabase
          .from('establecimientos')
          .select('*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*))')
          .or('codigo_establecimiento.ilike.%$busqueda%,denominacion.ilike.%$busqueda%,direccion.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Establecimiento> establecimientos = registros.map((mapa) {
        return Establecimiento.fromMap(mapa);
      }).toList();

      return establecimientos;
    } catch (e) {
      print('Error al buscar establecimientos: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR EMPRESA ====================

  Future<List<Establecimiento>> buscarPorEmpresa(int idEmpresa) async {
    try {
      final data = await supabase
          .from('establecimientos')
          .select('*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*))')
          .eq('fk_empresa', idEmpresa);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Establecimiento> establecimientos = registros.map((mapa) {
        return Establecimiento.fromMap(mapa);
      }).toList();

      return establecimientos;
    } catch (e) {
      print('Error al buscar establecimientos por empresa: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR BARRIO ====================

  Future<List<Establecimiento>> buscarPorBarrio(int idBarrio) async {
    try {
      final data = await supabase
          .from('establecimientos')
          .select('*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*))')
          .eq('fk_barrio', idBarrio);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Establecimiento> establecimientos = registros.map((mapa) {
        return Establecimiento.fromMap(mapa);
      }).toList();

      return establecimientos;
    } catch (e) {
      print('Error al buscar establecimientos por barrio: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR ESTADO ====================

  Future<List<Establecimiento>> buscarPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('establecimientos')
          .select('*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*))')
          .eq('estado_establecimiento', estado);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Establecimiento> establecimientos = registros.map((mapa) {
        return Establecimiento.fromMap(mapa);
      }).toList();

      return establecimientos;
    } catch (e) {
      print('Error al buscar establecimientos por estado: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR ESTABLECIMIENTO ====================

  Future<bool> actualizarEstablecimiento(Establecimiento establecimiento) async {
    try {
      await supabase
          .from('establecimientos')
          .update({
            'codigo_establecimiento': establecimiento.codigo_establecimiento,
            'direccion': establecimiento.direccion,
            'numero_casa': establecimiento.numero_casa,
            'complemento_direccion_1': establecimiento.complemento_direccion_1,
            'complemento_direccion_2': establecimiento.complemento_direccion_2,
            'telefono': establecimiento.telefono,
            'email': establecimiento.email,
            'denominacion': establecimiento.denominacion,
            'estado_establecimiento': establecimiento.estado_establecimiento,
            'fk_barrio': establecimiento.fk_barrio.cod_barrio,
            'fk_empresa': establecimiento.fk_empresa.id_empresa,
          })
          .eq('id_establecimiento', establecimiento.id_establecimiento!);

      print('Establecimiento actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar establecimiento: $e');
      return false;
    }
  }

  // ==================== CAMBIAR ESTADO ESTABLECIMIENTO ====================

  Future<bool> cambiarEstadoEstablecimiento(int idEstablecimiento, String nuevoEstado) async {
    try {
      await supabase
          .from('establecimientos')
          .update({'estado_establecimiento': nuevoEstado})
          .eq('id_establecimiento', idEstablecimiento);

      print('Estado de establecimiento actualizado a: $nuevoEstado');
      return true;
    } catch (e) {
      print('Error al cambiar estado de establecimiento: $e');
      return false;
    }
  }

  // ==================== ELIMINAR ESTABLECIMIENTO ====================

  Future<bool> eliminarEstablecimiento(int id) async {
    try {
      await supabase
          .from('establecimientos')
          .delete()
          .eq('id_establecimiento', id);

      print('Establecimiento eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar establecimiento: $e');
      return false;
    }
  }

  // ==================== VERIFICAR CÓDIGO EXISTENTE ====================

  Future<bool> verificarCodigoExistente(String codigo, {int? idEstablecimientoExcluir}) async {
    try {
      var query = supabase
          .from('establecimientos')
          .select('id_establecimiento')
          .eq('codigo_establecimiento', codigo);

      if (idEstablecimientoExcluir != null) {
        query = query.neq('id_establecimiento', idEstablecimientoExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar código de establecimiento: $e');
      return false;
    }
  }

  // ==================== VERIFICAR EMAIL EXISTENTE ====================

  Future<bool> verificarEmailExistente(String email, {int? idEstablecimientoExcluir}) async {
    try {
      var query = supabase
          .from('establecimientos')
          .select('id_establecimiento')
          .eq('email', email);

      if (idEstablecimientoExcluir != null) {
        query = query.neq('id_establecimiento', idEstablecimientoExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar email: $e');
      return false;
    }
  }

  // ==================== CONTAR ESTABLECIMIENTOS ====================

  Future<int> contarEstablecimientos() async {
    try {
      final data = await supabase
          .from('establecimientos')
          .select('id_establecimiento')
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar establecimientos: $e');
      return 0;
    }
  }

  // ==================== CONTAR ESTABLECIMIENTOS POR ESTADO ====================

  Future<int> contarEstablecimientosPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('establecimientos')
          .select('id_establecimiento')
          .eq('estado_establecimiento', estado)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar establecimientos por estado: $e');
      return 0;
    }
  }

  // ==================== CONTAR ESTABLECIMIENTOS POR EMPRESA ====================

  Future<int> contarEstablecimientosPorEmpresa(int idEmpresa) async {
    try {
      final data = await supabase
          .from('establecimientos')
          .select('id_establecimiento')
          .eq('fk_empresa', idEmpresa)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar establecimientos por empresa: $e');
      return 0;
    }
  }
}