import 'package:myapp/modelo/facturacionmodelo/motivo_emision.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MotivoEmisionCrudImpl {
  
  // ==================== CREAR MOTIVO EMISIÓN ====================
  Future<MotivoEmision?> crearMotivoEmision(MotivoEmision motivoEmision) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('motivos_emision')
          .insert({
            'descripcion': motivoEmision.descripcion,
          })
          .select()
          .single();

      print('Motivo de emisión creado exitosamente');
      return MotivoEmision.fromMap(data);
    } catch (e) {
      print('Error al crear motivo de emisión: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS MOTIVOS EMISIÓN ====================
  Future<List<MotivoEmision>> leerMotivosEmision() async {
    try {
      final data = await supabase
          .from('motivos_emision')
          .select();

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay motivos de emisión en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<MotivoEmision> motivosEmision = registros.map((mapa) {
        return MotivoEmision.fromMap(mapa);
      }).toList();

      print('✓ Se cargaron ${motivosEmision.length} motivos de emisión');
      return motivosEmision;
    } catch (e) {
      print('Error al leer motivos de emisión: $e');
      return [];
    }
  }

  // ==================== LEER UN MOTIVO EMISIÓN POR ID ====================
  Future<MotivoEmision?> leerMotivoEmisionPorId(int idMotivo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('motivos_emision')
          .select()
          .eq('id_motivos', idMotivo)
          .single();

      return MotivoEmision.fromMap(data);
    } catch (e) {
      print('Error al leer motivo de emisión por ID: $e');
      return null;
    }
  }

  // ==================== BUSCAR MOTIVOS EMISIÓN ====================
  Future<List<MotivoEmision>> buscarMotivosEmision(String busqueda) async {
    try {
      final data = await supabase
          .from('motivos_emision')
          .select()
          .ilike('descripcion', '%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<MotivoEmision> motivosEmision = registros.map((mapa) {
        return MotivoEmision.fromMap(mapa);
      }).toList();

      return motivosEmision;
    } catch (e) {
      print('Error al buscar motivos de emisión: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR MOTIVO EMISIÓN ====================
  Future<bool> actualizarMotivoEmision(MotivoEmision motivoEmision) async {
    try {
      await supabase
          .from('motivos_emision')
          .update({
            'descripcion': motivoEmision.descripcion,
          })
          .eq('id_motivos', motivoEmision.id_motivos!);

      print('Motivo de emisión actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar motivo de emisión: $e');
      return false;
    }
  }

  // ==================== ELIMINAR MOTIVO EMISIÓN ====================
  Future<bool> eliminarMotivoEmision(int idMotivo) async {
    try {
      await supabase
          .from('motivos_emision')
          .delete()
          .eq('id_motivos', idMotivo);

      print('Motivo de emisión eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar motivo de emisión: $e');
      return false;
    }
  }

  // ==================== VERIFICAR DESCRIPCIÓN EXISTENTE ====================
  Future<bool> verificarDescripcionExistente(String descripcion, {int? idMotivoExcluir}) async {
    try {
      var query = supabase
          .from('motivos_emision')
          .select('id_motivos')
          .eq('descripcion', descripcion);

      if (idMotivoExcluir != null) {
        query = query.neq('id_motivos', idMotivoExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar descripción: $e');
      return false;
    }
  }
}