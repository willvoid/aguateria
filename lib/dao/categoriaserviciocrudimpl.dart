import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CategoriaServicioCrudImpl {
  
  // ==================== CREAR CATEGORÍA SERVICIO ====================
  Future<CategoriaServicio?> crearCategoriaServicio(CategoriaServicio categoria) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('categoria_servicio')
          .insert({
            'nombre': categoria.nombre,
            'tarifa_fija': categoria.tarifa_fija,
            'm2_min': categoria.m2_min,
            'm2_max': categoria.m2_max,
            'descripcion': categoria.descripcion,
          })
          .select()
          .single();

      print('Categoría de servicio creada exitosamente');
      return CategoriaServicio.fromMap(data);
    } catch (e) {
      print('Error al crear categoría de servicio: $e');
      return null;
    }
  }

  // ==================== LEER TODAS LAS CATEGORÍAS ====================
  Future<List<CategoriaServicio>> leerCategoriasServicio() async {
    try {
      final data = await supabase
          .from('categoria_servicio')
          .select('*');

      if (data == null) {
        print('La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay categorías de servicio en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<CategoriaServicio> categorias = registros.map((mapa) {
        return CategoriaServicio.fromMap(mapa);
      }).toList();

      print('Se cargaron ${categorias.length} categorías de servicio');
      return categorias;
    } catch (e) {
      print('Error al leer categorías de servicio: $e');
      return [];
    }
  }

  // ==================== LEER UNA CATEGORÍA POR ID ====================
  Future<CategoriaServicio?> leerCategoriaServicioPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('categoria_servicio')
          .select('*')
          .eq('id', id)
          .single();

      return CategoriaServicio.fromMap(data);
    } catch (e) {
      print('Error al leer categoría de servicio por ID: $e');
      return null;
    }
  }

  // ==================== BUSCAR CATEGORÍAS ====================
  Future<List<CategoriaServicio>> buscarCategoriasServicio(String busqueda) async {
    try {
      final data = await supabase
          .from('categoria_servicio')
          .select('*')
          .or('nombre.ilike.%$busqueda%,descripcion.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<CategoriaServicio> categorias = registros.map((mapa) {
        return CategoriaServicio.fromMap(mapa);
      }).toList();

      return categorias;
    } catch (e) {
      print('Error al buscar categorías de servicio: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR CATEGORÍA ====================
  Future<bool> actualizarCategoriaServicio(CategoriaServicio categoria) async {
    try {
      await supabase
          .from('categoria_servicio')
          .update({
            'nombre': categoria.nombre,
            'tarifa_fija': categoria.tarifa_fija,
            'm2_min': categoria.m2_min,
            'm2_max': categoria.m2_max,
            'descripcion': categoria.descripcion,
          })
          .eq('id', categoria.id!);

      print('Categoría de servicio actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar categoría de servicio: $e');
      return false;
    }
  }

  // ==================== ELIMINAR CATEGORÍA ====================
  Future<bool> eliminarCategoriaServicio(int id) async {
    try {
      await supabase
          .from('categoria_servicio')
          .delete()
          .eq('id', id);

      print('Categoría de servicio eliminada exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar categoría de servicio: $e');
      return false;
    }
  }

  // ==================== BUSCAR POR RANGO DE M2 ====================
  Future<List<CategoriaServicio>> buscarPorRangoM2(double m2) async {
    try {
      final data = await supabase
          .from('categoria_servicio')
          .select('*')
          .lte('m2_min', m2)
          .gte('m2_max', m2);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<CategoriaServicio> categorias = registros.map((mapa) {
        return CategoriaServicio.fromMap(mapa);
      }).toList();

      return categorias;
    } catch (e) {
      print('Error al buscar categorías por rango de m2: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR RANGO DE TARIFA ====================
  Future<List<CategoriaServicio>> buscarPorRangoTarifa(double tarifaMin, double tarifaMax) async {
    try {
      final data = await supabase
          .from('categoria_servicio')
          .select('*')
          .gte('tarifa_fija', tarifaMin)
          .lte('tarifa_fija', tarifaMax);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<CategoriaServicio> categorias = registros.map((mapa) {
        return CategoriaServicio.fromMap(mapa);
      }).toList();

      return categorias;
    } catch (e) {
      print('Error al buscar categorías por rango de tarifa: $e');
      return [];
    }
  }

  // ==================== VERIFICAR NOMBRE EXISTENTE ====================
  Future<bool> verificarNombreExistente(String nombre, {int? idCategoriaExcluir}) async {
    try {
      var query = supabase
          .from('categoria_servicio')
          .select('id')
          .eq('nombre', nombre);

      if (idCategoriaExcluir != null) {
        query = query.neq('id', idCategoriaExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar nombre: $e');
      return false;
    }
  }

  // ==================== VERIFICAR SOLAPAMIENTO DE RANGOS ====================
  Future<bool> verificarSolapamientoRangos(double m2Min, double m2Max, {int? idCategoriaExcluir}) async {
    try {
      var query = supabase
          .from('categoria_servicio')
          .select('id')
          .or('and(m2_min.lte.$m2Max,m2_max.gte.$m2Min)');

      if (idCategoriaExcluir != null) {
        query = query.neq('id', idCategoriaExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar solapamiento de rangos: $e');
      return false;
    }
  }
}