import 'package:myapp/modelo/empresa/actividad_empresa.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ActividadEmpresaCrudImpl {
  
  // ==================== CREAR RELACIÓN ====================
  Future<ActividadEmpresa?> crearActividadEmpresa(ActividadEmpresa actividad) async {
    try {
      // 1. Insertamos usando solo los IDs
      final Map<String, dynamic> data = await supabase
          .from('actividad_empresa')
          .insert({
            'fk_empresa': actividad.fk_empresa.id_empresa,
            'fk_actividad': actividad.fk_actividad.id_actividad_economica,
          })
          // 2. Al seleccionar, hacemos el JOIN explícito con alias para que coincida con el fromMap
          .select('*, fk_empresa:datos_empresa(*), fk_actividad:actividad_economica(*)')
          .single();

      print('Actividad de empresa asignada exitosamente');
      return ActividadEmpresa.fromMap(data);
    } catch (e) {
      print('Error al crear actividad de empresa: $e');
      return null;
    }
  }

  // ==================== LEER ACTIVIDADES POR EMPRESA (ESENCIAL) ====================
  Future<List<ActividadEmpresa>> leerActividadesPorEmpresa(int idEmpresa) async {
    try {
      final data = await supabase
          .from('actividad_empresa')
          .select('*, fk_empresa:datos_empresa(*), fk_actividad:actividad_economica(*)')
          .eq('fk_empresa', idEmpresa);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      return registros.map((mapa) => ActividadEmpresa.fromMap(mapa)).toList();
    } catch (e) {
      print('Error al leer actividades por empresa: $e');
      return [];
    }
  }

  // ==================== LEER TODAS ====================
  Future<List<ActividadEmpresa>> leerActividadesEmpresa() async {
    try {
      final data = await supabase
          .from('actividad_empresa')
          .select('*, fk_empresa:datos_empresa(*), fk_actividad:actividad_economica(*)');

      if (data == null || data.isEmpty) return [];

      final List<Map<String, dynamic>> registros = List<Map<String, dynamic>>.from(data);
      return registros.map((mapa) => ActividadEmpresa.fromMap(mapa)).toList();
    } catch (e) {
      print('Error al leer actividades de empresa: $e');
      return [];
    }
  }

  // ==================== ELIMINAR RELACIÓN (DESVINCULAR) ====================
  Future<bool> eliminarActividadEmpresa(int id) async {
    try {
      await supabase
          .from('actividad_empresa')
          .delete()
          .eq('id', id);

      print('Relación eliminada exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar relación: $e');
      return false;
    }
  }

  // ==================== LIMPIAR ACTIVIDADES DE UNA EMPRESA ====================
  // Útil para cuando editas una empresa: primero borras las viejas, luego insertas las nuevas
  Future<bool> eliminarTodasPorEmpresa(int idEmpresa) async {
    try {
      await supabase
          .from('actividad_empresa')
          .delete()
          .eq('fk_empresa', idEmpresa);
      return true;
    } catch (e) {
      print('Error al limpiar actividades de empresa: $e');
      return false;
    }
  }
}