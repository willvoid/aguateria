import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class TipoFacturaCrudImpl {
  
  // ==================== CREAR TIPO FACTURA ====================
  Future<TipoFactura?> crearTipoFactura(TipoFactura tipoFactura) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_factura')
          .insert({
            'descripcion': tipoFactura.descripcion,
          })
          .select()
          .single();

      print('Tipo de factura creado exitosamente');
      return TipoFactura.fromMap(data);
    } catch (e) {
      print('Error al crear tipo de factura: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS TIPOS DE FACTURA ====================
  Future<List<TipoFactura>> leerTiposFactura() async {
    try {
      final data = await supabase
          .from('tipo_factura')
          .select();

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay tipos de factura en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<TipoFactura> tiposFactura = registros.map((mapa) {
        return TipoFactura.fromMap(mapa);
      }).toList();

      print('✓ Se cargaron ${tiposFactura.length} tipos de factura');
      return tiposFactura;
    } catch (e) {
      print('Error al leer tipos de factura: $e');
      return [];
    }
  }

  // ==================== LEER UN TIPO FACTURA POR ID ====================
  Future<TipoFactura?> leerTipoFacturaPorId(int idTipoFactura) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tipo_factura')
          .select()
          .eq('id_tipo_factura', idTipoFactura)
          .single();

      return TipoFactura.fromMap(data);
    } catch (e) {
      print('Error al leer tipo de factura por ID: $e');
      return null;
    }
  }

  // ==================== BUSCAR TIPOS FACTURA ====================
  Future<List<TipoFactura>> buscarTiposFactura(String busqueda) async {
    try {
      final data = await supabase
          .from('tipo_factura')
          .select()
          .ilike('descripcion', '%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<TipoFactura> tiposFactura = registros.map((mapa) {
        return TipoFactura.fromMap(mapa);
      }).toList();

      return tiposFactura;
    } catch (e) {
      print('Error al buscar tipos de factura: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR TIPO FACTURA ====================
  Future<bool> actualizarTipoFactura(TipoFactura tipoFactura) async {
    try {
      await supabase
          .from('tipo_factura')
          .update({
            'descripcion': tipoFactura.descripcion,
          })
          .eq('id_tipo_factura', tipoFactura.id_tipo_factura!);

      print('Tipo de factura actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar tipo de factura: $e');
      return false;
    }
  }

  // ==================== ELIMINAR TIPO FACTURA ====================
  Future<bool> eliminarTipoFactura(int idTipoFactura) async {
    try {
      await supabase
          .from('tipo_factura')
          .delete()
          .eq('id_tipo_factura', idTipoFactura);

      print('Tipo de factura eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar tipo de factura: $e');
      return false;
    }
  }

  // ==================== VERIFICAR DESCRIPCION EXISTENTE ====================
  Future<bool> verificarDescripcionExistente(String descripcion, {int? idTipoFacturaExcluir}) async {
    try {
      var query = supabase
          .from('tipo_factura')
          .select('id_tipo_factura')
          .eq('descripcion', descripcion);

      if (idTipoFacturaExcluir != null) {
        query = query.neq('id_tipo_factura', idTipoFacturaExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar descripción: $e');
      return false;
    }
  }
}