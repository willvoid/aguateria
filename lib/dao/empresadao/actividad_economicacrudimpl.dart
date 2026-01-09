import 'package:supabase_flutter/supabase_flutter.dart';
// Asegúrate de importar tu modelo correctamente
import 'package:myapp/modelo/empresa/actividad_economica.dart'; 

final supabase = Supabase.instance.client;

class ActividadEconomicaCrudImpl {
  
  // ==================== CREAR ACTIVIDAD ECONÓMICA ====================
  Future<ActividadEconomica?> crearActividadEconomica(ActividadEconomica actividad) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('actividad_economica') // Asumiendo que este es el nombre de tu tabla
          .insert({
            'codigo_actividad': actividad.codigo_actividad,
            'descripcion_actividad_economica': actividad.descripcion_actividad,
            'es_principal': actividad.es_principal,
          })
          .select()
          .single();

      print('Actividad económica creada exitosamente');
      return ActividadEconomica.fromMap(data);
    } catch (e) {
      print('Error al crear actividad económica: $e');
      return null;
    }
  }

  // ==================== LEER TODAS LAS ACTIVIDADES ====================
  Future<List<ActividadEconomica>> leerActividadesEconomicas() async {
    try {
      final data = await supabase
          .from('actividad_economica')
          .select('*')
          .order('codigo_actividad', ascending: true); // Opcional: ordenar por código

      if (data == null) {
        print('La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay actividades económicas en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<ActividadEconomica> actividades = registros.map((mapa) {
        return ActividadEconomica.fromMap(mapa);
      }).toList();

      print('Se cargaron ${actividades.length} actividades económicas');
      return actividades;
    } catch (e) {
      print('Error al leer actividades económicas: $e');
      return [];
    }
  }

  // ==================== LEER UNA ACTIVIDAD POR ID ====================
  Future<ActividadEconomica?> leerActividadEconomicaPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('actividad_economica')
          .select('*')
          .eq('id_actividad_economica', id)
          .single();

      return ActividadEconomica.fromMap(data);
    } catch (e) {
      print('Error al leer actividad económica por ID: $e');
      return null;
    }
  }

  // ==================== LEER UNA ACTIVIDAD POR CÓDIGO ====================
  Future<ActividadEconomica?> leerActividadEconomicaPorCodigo(int codigo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('actividad_economica')
          .select('*')
          .eq('codigo_actividad', codigo)
          .single();

      return ActividadEconomica.fromMap(data);
    } catch (e) {
      print('Error al leer actividad económica por código: $e');
      return null;
    }
  }

  // ==================== BUSCAR ACTIVIDADES ====================
  Future<List<ActividadEconomica>> buscarActividadesEconomicas(String busqueda) async {
    try {
      final data = await supabase
          .from('actividad_economica')
          .select('*')
          .ilike('descripcion_actividad_economica', '%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<ActividadEconomica> actividades = registros.map((mapa) {
        return ActividadEconomica.fromMap(mapa);
      }).toList();

      return actividades;
    } catch (e) {
      print('Error al buscar actividades económicas: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR ACTIVIDAD ====================
  Future<bool> actualizarActividadEconomica(ActividadEconomica actividad) async {
    try {
      await supabase
          .from('actividad_economica')
          .update({
            'codigo_actividad': actividad.codigo_actividad,
            'descripcion_actividad_economica': actividad.descripcion_actividad,
            'es_principal': actividad.es_principal,
          })
          .eq('id_actividad_economica', actividad.id_actividad_economica!);

      print('Actividad económica actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar actividad económica: $e');
      return false;
    }
  }

  // ==================== ELIMINAR ACTIVIDAD ====================
 Future<bool> eliminarActividadEmpresa(int idEmpresa) async {
  try {
    // Primero verificar cuántas hay
    final existing = await supabase
        .from('actividad_empresa')
        .select('id')
        .eq('fk_empresa', idEmpresa);
    
    print('Eliminando ${existing.length} actividades de empresa $idEmpresa');
    
    await supabase
        .from('actividad_empresa')
        .delete()
        .eq('fk_empresa', idEmpresa);

    print('Relaciones eliminadas exitosamente');
    return true;
  } catch (e) {
    print('Error al eliminar relaciones: $e');
    return false;
  }
}

  // ==================== VERIFICAR CÓDIGO EXISTENTE ====================
  Future<bool> verificarCodigoExistente(int codigo, {int? idActividadExcluir}) async {
    try {
      var query = supabase
          .from('actividad_economica')
          .select('id_actividad_economica')
          .eq('codigo_actividad', codigo);

      if (idActividadExcluir != null) {
        query = query.neq('id_actividad_economica', idActividadExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar código de actividad: $e');
      return false;
    }
  }

  // ==================== VERIFICAR DESCRIPCIÓN EXISTENTE ====================
  Future<bool> verificarDescripcionExistente(String descripcion, {int? idActividadExcluir}) async {
    try {
      var query = supabase
          .from('actividad_economica')
          .select('id_actividad_economica')
          .eq('descripcion_actividad_economica', descripcion);

      if (idActividadExcluir != null) {
        query = query.neq('id_actividad_economica', idActividadExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar descripción de actividad: $e');
      return false;
    }
  }

  // ==================== CONTAR ACTIVIDADES ====================
  Future<int> contarActividadesEconomicas() async {
    try {
      final data = await supabase
          .from('actividad_economica')
          .select('id_actividad_economica')
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar actividades económicas: $e');
      return 0;
    }
  }
}