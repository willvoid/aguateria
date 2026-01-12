import 'package:myapp/modelo/empresa/timbrado.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class TimbradoCrudImpl {

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ==================== CREAR TIMBRADO ====================

  Future<Timbrado?> crearTimbrado(Timbrado timbrado) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('timbrados')
          .insert({
            'timbrado': timbrado.timbrado,
            'inicio': timbrado.inicio.toIso8601String(),
            'vencimiento': timbrado.vencimiento.toIso8601String(),
            'estado': timbrado.estado,
            'fk_establecimiento': timbrado.fk_establecimiento.id_establecimiento,
          })
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .single();

      print('Timbrado creado exitosamente');
      return Timbrado.fromMap(data);
    } catch (e) {
      print('Error al crear timbrado: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS TIMBRADOS ====================

  Future<List<Timbrado>> leerTimbrados() async {
    try {
      final data = await supabase
          .from('timbrados')
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))');

      if (data == null) {
        print('La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay timbrados en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Timbrado> timbrados = registros.map((mapa) {
        final datosEstablecimiento = mapa['fk_establecimiento'];

        if (datosEstablecimiento == null) {
          throw Exception('Timbrado sin establecimiento asignado');
        }

        return Timbrado(
          id_timbrado: _toInt(mapa['id_timbrado']),
          timbrado: mapa['timbrado'] ?? '',
          inicio: DateTime.parse(mapa['inicio']),
          vencimiento: DateTime.parse(mapa['vencimiento']),
          estado: mapa['estado'] ?? 'ACTIVO',
          fk_establecimiento: Establecimiento.fromMap(datosEstablecimiento),
        );
      }).toList();

      print('Se cargaron ${timbrados.length} timbrados');
      return timbrados;
    } catch (e) {
      print('Error al leer timbrados: $e');
      return [];
    }
  }

  // ==================== LEER TIMBRADO POR ID ====================

  Future<Timbrado?> leerTimbradoPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('timbrados')
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('id_timbrado', id)
          .single();

      return Timbrado.fromMap(data);
    } catch (e) {
      print('Error al leer timbrado por ID: $e');
      return null;
    }
  }

  // ==================== LEER TIMBRADO POR NÚMERO ====================

  Future<Timbrado?> leerTimbradoPorNumero(String numeroTimbrado) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('timbrados')
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('timbrado', numeroTimbrado)
          .single();

      return Timbrado.fromMap(data);
    } catch (e) {
      print('Error al leer timbrado por número: $e');
      return null;
    }
  }

  // ==================== BUSCAR TIMBRADOS ====================

  Future<List<Timbrado>> buscarTimbrados(String busqueda) async {
    try {
      final data = await supabase
          .from('timbrados')
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .ilike('timbrado', '%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Timbrado> timbrados = registros.map((mapa) {
        return Timbrado.fromMap(mapa);
      }).toList();

      return timbrados;
    } catch (e) {
      print('Error al buscar timbrados: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR ESTABLECIMIENTO ====================

  Future<List<Timbrado>> buscarPorEstablecimiento(int idEstablecimiento) async {
    try {
      final data = await supabase
          .from('timbrados')
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('fk_establecimiento', idEstablecimiento);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Timbrado> timbrados = registros.map((mapa) {
        return Timbrado.fromMap(mapa);
      }).toList();

      return timbrados;
    } catch (e) {
      print('Error al buscar timbrados por establecimiento: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR ESTADO ====================

  Future<List<Timbrado>> buscarPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('timbrados')
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('estado', estado);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Timbrado> timbrados = registros.map((mapa) {
        return Timbrado.fromMap(mapa);
      }).toList();

      return timbrados;
    } catch (e) {
      print('Error al buscar timbrados por estado: $e');
      return [];
    }
  }

  // ==================== BUSCAR TIMBRADOS VIGENTES ====================

  Future<List<Timbrado>> buscarTimbradosVigentes() async {
    try {
      final ahora = DateTime.now().toIso8601String();
      
      final data = await supabase
          .from('timbrados')
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('estado', 'ACTIVO')
          .lte('inicio', ahora)
          .gte('vencimiento', ahora);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Timbrado> timbrados = registros.map((mapa) {
        return Timbrado.fromMap(mapa);
      }).toList();

      return timbrados;
    } catch (e) {
      print('Error al buscar timbrados vigentes: $e');
      return [];
    }
  }

  // ==================== BUSCAR TIMBRADOS VENCIDOS ====================

  Future<List<Timbrado>> buscarTimbradosVencidos() async {
    try {
      final ahora = DateTime.now().toIso8601String();
      
      final data = await supabase
          .from('timbrados')
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .lt('vencimiento', ahora);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Timbrado> timbrados = registros.map((mapa) {
        return Timbrado.fromMap(mapa);
      }).toList();

      return timbrados;
    } catch (e) {
      print('Error al buscar timbrados vencidos: $e');
      return [];
    }
  }

  // ==================== BUSCAR TIMBRADOS PROXIMOS A VENCER ====================

  Future<List<Timbrado>> buscarTimbradosProximosVencer(int diasAntes) async {
    try {
      final ahora = DateTime.now();
      final fechaLimite = ahora.add(Duration(days: diasAntes));
      
      final data = await supabase
          .from('timbrados')
          .select('*, fk_establecimiento(*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*)))')
          .eq('estado', 'ACTIVO')
          .gte('vencimiento', ahora.toIso8601String())
          .lte('vencimiento', fechaLimite.toIso8601String());

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Timbrado> timbrados = registros.map((mapa) {
        return Timbrado.fromMap(mapa);
      }).toList();

      return timbrados;
    } catch (e) {
      print('Error al buscar timbrados próximos a vencer: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR TIMBRADO ====================

  Future<bool> actualizarTimbrado(Timbrado timbrado) async {
    try {
      await supabase
          .from('timbrados')
          .update({
            'timbrado': timbrado.timbrado,
            'inicio': timbrado.inicio.toIso8601String(),
            'vencimiento': timbrado.vencimiento.toIso8601String(),
            'estado': timbrado.estado,
            'fk_establecimiento': timbrado.fk_establecimiento.id_establecimiento,
          })
          .eq('id_timbrado', timbrado.id_timbrado!);

      print('Timbrado actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar timbrado: $e');
      return false;
    }
  }

  // ==================== CAMBIAR ESTADO TIMBRADO ====================

  Future<bool> cambiarEstadoTimbrado(int idTimbrado, String nuevoEstado) async {
    try {
      await supabase
          .from('timbrados')
          .update({'estado': nuevoEstado})
          .eq('id_timbrado', idTimbrado);

      print('Estado de timbrado actualizado a: $nuevoEstado');
      return true;
    } catch (e) {
      print('Error al cambiar estado de timbrado: $e');
      return false;
    }
  }

  // ==================== ELIMINAR TIMBRADO ====================

  Future<bool> eliminarTimbrado(int id) async {
    try {
      await supabase
          .from('timbrados')
          .delete()
          .eq('id_timbrado', id);

      print('Timbrado eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar timbrado: $e');
      return false;
    }
  }

  // ==================== VERIFICAR TIMBRADO EXISTENTE ====================

  Future<bool> verificarTimbradoExistente(String numeroTimbrado, {int? idTimbradoExcluir}) async {
    try {
      var query = supabase
          .from('timbrados')
          .select('id_timbrado')
          .eq('timbrado', numeroTimbrado);

      if (idTimbradoExcluir != null) {
        query = query.neq('id_timbrado', idTimbradoExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar timbrado existente: $e');
      return false;
    }
  }

  // ==================== VERIFICAR SUPERPOSICIÓN DE FECHAS ====================

  Future<bool> verificarSuperposicionFechas(
    int idEstablecimiento,
    DateTime inicio,
    DateTime vencimiento,
    {int? idTimbradoExcluir}
  ) async {
    try {
      var query = supabase
          .from('timbrados')
          .select('id_timbrado')
          .eq('fk_establecimiento', idEstablecimiento)
          .eq('estado', 'ACTIVO')
          .or('inicio.lte.${vencimiento.toIso8601String()},vencimiento.gte.${inicio.toIso8601String()}');

      if (idTimbradoExcluir != null) {
        query = query.neq('id_timbrado', idTimbradoExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar superposición de fechas: $e');
      return false;
    }
  }

  // ==================== CONTAR TIMBRADOS ====================

  Future<int> contarTimbrados() async {
    try {
      final data = await supabase
          .from('timbrados')
          .select('id_timbrado')
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar timbrados: $e');
      return 0;
    }
  }

  // ==================== CONTAR TIMBRADOS POR ESTADO ====================

  Future<int> contarTimbradosPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('timbrados')
          .select('id_timbrado')
          .eq('estado', estado)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar timbrados por estado: $e');
      return 0;
    }
  }

  // ==================== CONTAR TIMBRADOS POR ESTABLECIMIENTO ====================

  Future<int> contarTimbradosPorEstablecimiento(int idEstablecimiento) async {
    try {
      final data = await supabase
          .from('timbrados')
          .select('id_timbrado')
          .eq('fk_establecimiento', idEstablecimiento)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar timbrados por establecimiento: $e');
      return 0;
    }
  }

  // ==================== CONTAR TIMBRADOS VIGENTES ====================

  Future<int> contarTimbradosVigentes() async {
    try {
      final ahora = DateTime.now().toIso8601String();
      
      final data = await supabase
          .from('timbrados')
          .select('id_timbrado')
          .eq('estado', 'ACTIVO')
          .lte('inicio', ahora)
          .gte('vencimiento', ahora)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar timbrados vigentes: $e');
      return 0;
    }
  }

  // ==================== CONTAR TIMBRADOS VENCIDOS ====================

  Future<int> contarTimbradosVencidos() async {
    try {
      final ahora = DateTime.now().toIso8601String();
      
      final data = await supabase
          .from('timbrados')
          .select('id_timbrado')
          .lt('vencimiento', ahora)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar timbrados vencidos: $e');
      return 0;
    }
  }
}