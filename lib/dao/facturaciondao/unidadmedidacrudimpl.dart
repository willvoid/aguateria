import 'package:myapp/modelo/facturacionmodelo/unidad_medida.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class UnidadMedidaCrudImpl {
  Future<List<UnidadMedida>> leerUnidadesMedida() async {
    try {
      // 1. Realiza la consulta a tu tabla 'unidades_medida'.
      //    El método .select() sin filtros obtiene todos los registros.
      final List<Map<String, dynamic>> data = await supabase.from('unidades_medida').select();

      // 2. Verifica si la respuesta no está vacía.
      if (data.isEmpty) {
        // Si no hay unidades de medida, devuelve una lista vacía.
        return [];
      }

      // 3. Convierte cada mapa de la respuesta en un objeto UnidadMedida.
      //    Usamos el factory `UnidadMedida.fromMap` que definimos.
      final List<UnidadMedida> unidades = data.map((mapa) => UnidadMedida.fromMap(mapa)).toList();
      
      return unidades;

    } catch (e) {
      // Es una buena práctica manejar posibles errores.
      print('Error al leer las Unidades de Medida: $e');
      // Puedes lanzar el error o devolver una lista vacía.
      return [];
    }
  }

  Future<UnidadMedida?> crearUnidadMedida(UnidadMedida unidad) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('unidades_medida')
          .insert(unidad.toMap())
          .select()
          .single();

      return UnidadMedida.fromMap(data);
    } catch (e) {
      print('Error al crear la Unidad de Medida: $e');
      return null;
    }
  }

  Future<bool> actualizarUnidadMedida(UnidadMedida unidad) async {
    try {
      await supabase
          .from('unidades_medida')
          .update(unidad.toMap())
          .eq('id_unidades', unidad.id!);

      return true;
    } catch (e) {
      print('Error al actualizar la Unidad de Medida: $e');
      return false;
    }
  }

  Future<bool> eliminarUnidadMedida(int id) async {
    try {
      await supabase
          .from('unidades_medida')
          .delete()
          .eq('id_unidades', id);

      return true;
    } catch (e) {
      print('Error al eliminar la Unidad de Medida: $e');
      return false;
    }
  }
}