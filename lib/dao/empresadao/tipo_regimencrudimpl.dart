import 'package:myapp/modelo/empresa/tipo_regimen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class TipoRegimenCrudImpl {
  
  // ==================== CREAR TIPO RÉGIMEN ====================
  Future<TipoRegimen?> crearTipoRegimen(TipoRegimen tipo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_regimen')
          .insert({
            'codigo_regimen': tipo.codigo_regimen,
            'descripcion': tipo.descripcion,
          })
          .select()
          .single();

      print('Tipo de régimen creado exitosamente');
      return TipoRegimen.fromMap(data);
    } catch (e) {
      print('Error al crear tipo de régimen: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS TIPOS ====================
  Future<List<TipoRegimen>> leerTiposRegimen() async {
    try {
      final data = await supabase
          .from('tipo_regimen')
          .select('*');

      if (data == null) {
        print('La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay tipos de régimen en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<TipoRegimen> tipos = registros.map((mapa) {
        return TipoRegimen.fromMap(mapa);
      }).toList();

      print('Se cargaron ${tipos.length} tipos de régimen');
      return tipos;
    } catch (e) {
      print('Error al leer tipos de régimen: $e');
      return [];
    }
  }

  // ==================== LEER UN TIPO POR ID ====================
  Future<TipoRegimen?> leerTipoRegimenPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_regimen')
          .select('*')
          .eq('id_regimen', id)
          .single();

      return TipoRegimen.fromMap(data);
    } catch (e) {
      print('Error al leer tipo de régimen por ID: $e');
      return null;
    }
  }

  // ==================== LEER UN TIPO POR CÓDIGO ====================
  Future<TipoRegimen?> leerTipoRegimenPorCodigo(int codigo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_regimen')
          .select('*')
          .eq('codigo_regimen', codigo)
          .single();

      return TipoRegimen.fromMap(data);
    } catch (e) {
      print('Error al leer tipo de régimen por código: $e');
      return null;
    }
  }

  // ==================== BUSCAR TIPOS ====================
  Future<List<TipoRegimen>> buscarTiposRegimen(String busqueda) async {
    try {
      final data = await supabase
          .from('tipo_regimen')
          .select('*')
          .ilike('descripcion', '%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<TipoRegimen> tipos = registros.map((mapa) {
        return TipoRegimen.fromMap(mapa);
      }).toList();

      return tipos;
    } catch (e) {
      print('Error al buscar tipos de régimen: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR TIPO ====================
  Future<bool> actualizarTipoRegimen(TipoRegimen tipo) async {
    try {
      await supabase
          .from('tipo_regimen')
          .update({
            'codigo_regimen': tipo.codigo_regimen,
            'descripcion': tipo.descripcion,
          })
          .eq('id_regimen', tipo.id_regimen!);

      print('Tipo de régimen actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar tipo de régimen: $e');
      return false;
    }
  }

  // ==================== ELIMINAR TIPO ====================
  Future<bool> eliminarTipoRegimen(int id) async {
    try {
      await supabase
          .from('tipo_regimen')
          .delete()
          .eq('id_regimen', id);

      print('Tipo de régimen eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar tipo de régimen: $e');
      return false;
    }
  }

  // ==================== VERIFICAR CÓDIGO EXISTENTE ====================
  Future<bool> verificarCodigoExistente(int codigo, {int? idRegimenExcluir}) async {
    try {
      var query = supabase
          .from('tipo_regimen')
          .select('id_regimen')
          .eq('codigo_regimen', codigo);

      if (idRegimenExcluir != null) {
        query = query.neq('id_regimen', idRegimenExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar código: $e');
      return false;
    }
  }

  // ==================== VERIFICAR DESCRIPCIÓN EXISTENTE ====================
  Future<bool> verificarDescripcionExistente(String descripcion, {int? idRegimenExcluir}) async {
    try {
      var query = supabase
          .from('tipo_regimen')
          .select('id_regimen')
          .eq('descripcion', descripcion);

      if (idRegimenExcluir != null) {
        query = query.neq('id_regimen', idRegimenExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar descripción: $e');
      return false;
    }
  }

  // ==================== CONTAR TIPOS ====================
  Future<int> contarTiposRegimen() async {
    try {
      final data = await supabase
          .from('tipo_regimen')
          .select('id_regimen')
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar tipos de régimen: $e');
      return 0;
    }
  }
}