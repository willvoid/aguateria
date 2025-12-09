

import 'package:myapp/modelo/barrio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class BarrioCrudImpl {
  Future<List<Barrio>> leerBarrios() async {
    try {
      // 1. Realiza la consulta a tu tabla 'categorias'.
      //    El método .select() sin filtros obtiene todos los registros.
      final List<Map<String, dynamic>> data = await supabase.from('barrios').select();

      // 2. Verifica si la respuesta no está vacía.
      if (data.isEmpty) {
        // Si no hay categorías, devuelve una lista vacía.
        return [];
      }

      // 3. Convierte cada mapa de la respuesta en un objeto Categoria.
      //    Usamos el factory `Categoria.fromMap` que definimos.
      final List<Barrio> barrio = data.map((mapa) => Barrio.fromMap(mapa)).toList();
      
      return barrio;

    } catch (e) {
      // Es una buena práctica manejar posibles errores.
      print('Error al leer los Barrios: $e');
      // Puedes lanzar el error o devolver una lista vacía.
      return [];
    }
  }
}