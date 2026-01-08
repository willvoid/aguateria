import 'package:myapp/modelo/empresa/tipo_contribuyente.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class TipoContribuyenteCrudImpl {
  
  // ==================== CREAR TIPO CONTRIBUYENTE ====================
  Future<TipoContribuyente?> crearTipoContribuyente(TipoContribuyente tipo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_contribuyente')
          .insert({
            'codigo_contribuyente': tipo.codigo_contribuyente,
            'descripcion': tipo.descripcion,
          })
          .select()
          .single();

      print('Tipo de contribuyente creado exitosamente');
      return TipoContribuyente.fromMap(data);
    } catch (e) {
      print('Error al crear tipo de contribuyente: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS TIPOS ====================
  Future<List<TipoContribuyente>> leerTiposContribuyente() async {
    try {
      final data = await supabase
          .from('tipo_contribuyente')
          .select('*');

      if (data == null) {
        print('La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay tipos de contribuyente en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<TipoContribuyente> tipos = registros.map((mapa) {
        return TipoContribuyente.fromMap(mapa);
      }).toList();

      print('Se cargaron ${tipos.length} tipos de contribuyente');
      return tipos;
    } catch (e) {
      print('Error al leer tipos de contribuyente: $e');
      return [];
    }
  }

  // ==================== LEER UN TIPO POR ID ====================
  Future<TipoContribuyente?> leerTipoContribuyentePorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_contribuyente')
          .select('*')
          .eq('id_tipo_contribuyente', id)
          .single();

      return TipoContribuyente.fromMap(data);
    } catch (e) {
      print('Error al leer tipo de contribuyente por ID: $e');
      return null;
    }
  }

  // ==================== LEER UN TIPO POR CÓDIGO ====================
  Future<TipoContribuyente?> leerTipoContribuyentePorCodigo(int codigo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_contribuyente')
          .select('*')
          .eq('codigo_contribuyente', codigo)
          .single();

      return TipoContribuyente.fromMap(data);
    } catch (e) {
      print('Error al leer tipo de contribuyente por código: $e');
      return null;
    }
  }

  // ==================== BUSCAR TIPOS ====================
  Future<List<TipoContribuyente>> buscarTiposContribuyente(String busqueda) async {
    try {
      final data = await supabase
          .from('tipo_contribuyente')
          .select('*')
          .ilike('descripcion', '%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<TipoContribuyente> tipos = registros.map((mapa) {
        return TipoContribuyente.fromMap(mapa);
      }).toList();

      return tipos;
    } catch (e) {
      print('Error al buscar tipos de contribuyente: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR TIPO ====================
  Future<bool> actualizarTipoContribuyente(TipoContribuyente tipo) async {
    try {
      await supabase
          .from('tipo_contribuyente')
          .update({
            'codigo_contribuyente': tipo.codigo_contribuyente,
            'descripcion': tipo.descripcion,
          })
          .eq('id_tipo_contribuyente', tipo.id_tipo_contribuyente!);

      print('Tipo de contribuyente actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar tipo de contribuyente: $e');
      return false;
    }
  }

  // ==================== ELIMINAR TIPO ====================
  Future<bool> eliminarTipoContribuyente(int id) async {
    try {
      await supabase
          .from('tipo_contribuyente')
          .delete()
          .eq('id_tipo_contribuyente', id);

      print('Tipo de contribuyente eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar tipo de contribuyente: $e');
      return false;
    }
  }

  // ==================== VERIFICAR CÓDIGO EXISTENTE ====================
  Future<bool> verificarCodigoExistente(int codigo, {int? idTipoExcluir}) async {
    try {
      var query = supabase
          .from('tipo_contribuyente')
          .select('id_tipo_contribuyente')
          .eq('codigo_contribuyente', codigo);

      if (idTipoExcluir != null) {
        query = query.neq('id_tipo_contribuyente', idTipoExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar código: $e');
      return false;
    }
  }

  // ==================== VERIFICAR DESCRIPCIÓN EXISTENTE ====================
  Future<bool> verificarDescripcionExistente(String descripcion, {int? idTipoExcluir}) async {
    try {
      var query = supabase
          .from('tipo_contribuyente')
          .select('id_tipo_contribuyente')
          .eq('descripcion', descripcion);

      if (idTipoExcluir != null) {
        query = query.neq('id_tipo_contribuyente', idTipoExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar descripción: $e');
      return false;
    }
  }

  // ==================== CONTAR TIPOS ====================
  Future<int> contarTiposContribuyente() async {
    try {
      final data = await supabase
          .from('tipo_contribuyente')
          .select('id_tipo_contribuyente')
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar tipos de contribuyente: $e');
      return 0;
    }
  }
}