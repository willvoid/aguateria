import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ModoPagoCrudImpl {
  
  // ==================== CREAR MODO PAGO ====================
  Future<ModoPago?> crearModoPago(ModoPago modoPago) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('modo_pago')
          .insert({
            'descripcion': modoPago.descripcion,
          })
          .select()
          .single();

      print('Modo de pago creado exitosamente');
      return ModoPago.fromMap(data);
    } catch (e) {
      print('Error al crear modo de pago: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS MODOS DE PAGO ====================
  Future<List<ModoPago>> leerModosPago() async {
    try {
      final data = await supabase
          .from('modo_pago')
          .select();

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay modos de pago en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<ModoPago> modosPago = registros.map((mapa) {
        return ModoPago.fromMap(mapa);
      }).toList();

      print('✓ Se cargaron ${modosPago.length} modos de pago');
      return modosPago;
    } catch (e) {
      print('Error al leer modos de pago: $e');
      return [];
    }
  }

  // ==================== LEER UN MODO DE PAGO POR ID ====================
  Future<ModoPago?> leerModoPagoPorId(int idModoPago) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('modo_pago')
          .select()
          .eq('id_modo_pago', idModoPago)
          .single();

      return ModoPago.fromMap(data);
    } catch (e) {
      print('Error al leer modo de pago por ID: $e');
      return null;
    }
  }

  // ==================== BUSCAR MODOS DE PAGO ====================
  Future<List<ModoPago>> buscarModosPago(String busqueda) async {
    try {
      final data = await supabase
          .from('modo_pago')
          .select()
          .ilike('descripcion', '%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<ModoPago> modosPago = registros.map((mapa) {
        return ModoPago.fromMap(mapa);
      }).toList();

      return modosPago;
    } catch (e) {
      print('Error al buscar modos de pago: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR MODO DE PAGO ====================
  Future<bool> actualizarModoPago(ModoPago modoPago) async {
    try {
      await supabase
          .from('modo_pago')
          .update({
            'descripcion': modoPago.descripcion,
          })
          .eq('id_modo_pago', modoPago.id_modo_pago!);

      print('Modo de pago actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar modo de pago: $e');
      return false;
    }
  }

  // ==================== ELIMINAR MODO DE PAGO ====================
  Future<bool> eliminarModoPago(int idModoPago) async {
    try {
      await supabase
          .from('modo_pago')
          .delete()
          .eq('id_modo_pago', idModoPago);

      print('Modo de pago eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar modo de pago: $e');
      return false;
    }
  }

  // ==================== VERIFICAR DESCRIPCIÓN EXISTENTE ====================
  Future<bool> verificarDescripcionExistente(String descripcion, {int? idModoPagoExcluir}) async {
    try {
      var query = supabase
          .from('modo_pago')
          .select('id_modo_pago')
          .eq('descripcion', descripcion);

      if (idModoPagoExcluir != null) {
        query = query.neq('id_modo_pago', idModoPagoExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar descripción: $e');
      return false;
    }
  }
}