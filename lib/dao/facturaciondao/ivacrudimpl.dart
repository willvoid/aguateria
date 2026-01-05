import 'package:myapp/modelo/facturacionmodelo/iva.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class IvaCrudImpl {
  Future<List<Iva>> leerIvas() async {
    try {
      // 1. Realiza la consulta a tu tabla 'iva'.
      //    El método .select() sin filtros obtiene todos los registros.
      final List<Map<String, dynamic>> data = await supabase.from('iva').select();

      // 2. Verifica si la respuesta no está vacía.
      if (data.isEmpty) {
        // Si no hay registros de IVA, devuelve una lista vacía.
        return [];
      }

      // 3. Convierte cada mapa de la respuesta en un objeto Iva.
      //    Usamos el factory `Iva.fromMap` que definimos.
      final List<Iva> ivas = data.map((mapa) => Iva.fromMap(mapa)).toList();
      
      return ivas;

    } catch (e) {
      // Es una buena práctica manejar posibles errores.
      print('Error al leer los IVAs: $e');
      // Puedes lanzar el error o devolver una lista vacía.
      return [];
    }
  }

  Future<Iva?> crearIva(Iva iva) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('iva')
          .insert(iva.toMap())
          .select()
          .single();

      return Iva.fromMap(data);
    } catch (e) {
      print('Error al crear el IVA: $e');
      return null;
    }
  }

  Future<bool> actualizarIva(Iva iva) async {
    try {
      await supabase
          .from('iva')
          .update(iva.toMap())
          .eq('id_iva', iva.id!);

      return true;
    } catch (e) {
      print('Error al actualizar el IVA: $e');
      return false;
    }
  }

  Future<bool> eliminarIva(int id) async {
    try {
      await supabase
          .from('iva')
          .delete()
          .eq('id_iva', id);

      return true;
    } catch (e) {
      print('Error al eliminar el IVA: $e');
      return false;
    }
  }
}