
import 'package:myapp/modelo/tipo_operacion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class TipoOperacionCrudimpl {
  Future<List<TipoOperacion>> leerTipoOperacion() async {
    try {
      // 1. Realiza la consulta a tu tabla 'categorias'.
      //    El método .select() sin filtros obtiene todos los registros.
      final List<Map<String, dynamic>> data = await supabase.from('tipo_operacion').select();

      // 2. Verifica si la respuesta no está vacía.
      if (data.isEmpty) {
        // Si no hay categorías, devuelve una lista vacía.
        return [];
      }

      // 3. Convierte cada mapa de la respuesta en un objeto Categoria.
      //    Usamos el factory `Categoria.fromMap` que definimos.
      final List<TipoOperacion> tipoDoc = data.map((mapa) => TipoOperacion.fromMap(mapa)).toList();
      
      return tipoDoc;

    } catch (e) {
      // Es una buena práctica manejar posibles errores.
      print('Error al leer los TipoOperacions: $e');
      // Puedes lanzar el error o devolver una lista vacía.
      return [];
    }
  }
}