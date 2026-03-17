import 'package:myapp/modelo/contabilidad/tipo_cuenta_contable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class TipoCuentaContableCrudImpl {

  // ==================== CREAR ====================
  Future<TipoCuentaContable?> crear(TipoCuentaContable tipo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_cuenta_contable')
          .insert({
            'nombre': tipo.nombre,
            'descripcion': tipo.descripcion,
          })
          .select()
          .single();

      print('TipoCuentaContable creado exitosamente');
      return TipoCuentaContable.fromMap(data);
    } catch (e) {
      print('Error al crear TipoCuentaContable: $e');
      return null;
    }
  }

  // ==================== LEER TODOS ====================
  Future<List<TipoCuentaContable>> leerTodos() async {
    try {
      final data = await supabase
          .from('tipo_cuenta_contable')
          .select();

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => TipoCuentaContable.fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer TipoCuentaContable: $e');
      return [];
    }
  }

  // ==================== LEER POR ID ====================
  Future<TipoCuentaContable?> leerPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_cuenta_contable')
          .select()
          .eq('id', id)
          .single();

      return TipoCuentaContable.fromMap(data);
    } catch (e) {
      print('Error al leer TipoCuentaContable por ID: $e');
      return null;
    }
  }

  // ==================== ACTUALIZAR ====================
  Future<bool> actualizar(TipoCuentaContable tipo) async {
    try {
      await supabase
          .from('tipo_cuenta_contable')
          .update({
            'nombre': tipo.nombre,
            'descripcion': tipo.descripcion,
          })
          .eq('id', tipo.id!);

      print('TipoCuentaContable actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar TipoCuentaContable: $e');
      return false;
    }
  }

  // ==================== ELIMINAR ====================
  Future<bool> eliminar(int id) async {
    try {
      await supabase
          .from('tipo_cuenta_contable')
          .delete()
          .eq('id', id);

      print('TipoCuentaContable eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar TipoCuentaContable: $e');
      return false;
    }
  }
}