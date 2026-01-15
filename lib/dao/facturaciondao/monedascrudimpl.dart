import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MonedaCrudImpl {
  
  // ==================== CREAR MONEDA ====================
  Future<Moneda?> crearMoneda(Moneda moneda) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('monedas')
          .insert({
            'cod_moneda': moneda.cod_moneda,
            'num': moneda.num,
            'dec': moneda.dec,
            'divisa': moneda.divisa,
            'cotizacion_gs': moneda.cotizacion_gs,
          })
          .select()
          .single();

      print('Moneda creada exitosamente');
      return Moneda.fromMap(data);
    } catch (e) {
      print('Error al crear moneda: $e');
      return null;
    }
  }

  // ==================== LEER TODAS LAS MONEDAS ====================
  Future<List<Moneda>> leerMonedas() async {
    try {
      final data = await supabase
          .from('monedas')
          .select();

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay monedas en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Moneda> monedas = registros.map((mapa) {
        return Moneda.fromMap(mapa);
      }).toList();

      print('✓ Se cargaron ${monedas.length} monedas');
      return monedas;
    } catch (e) {
      print('Error al leer monedas: $e');
      return [];
    }
  }

  // ==================== LEER UNA MONEDA POR ID ====================
  Future<Moneda?> leerMonedaPorId(int idMoneda) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('monedas')
          .select()
          .eq('id_monedas', idMoneda)
          .single();

      return Moneda.fromMap(data);
    } catch (e) {
      print('Error al leer moneda por ID: $e');
      return null;
    }
  }

  // ==================== LEER MONEDA POR CÓDIGO ====================
  Future<Moneda?> leerMonedaPorCodigo(int codMoneda) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('monedas')
          .select()
          .eq('cod_moneda', codMoneda)
          .single();

      return Moneda.fromMap(data);
    } catch (e) {
      print('Error al leer moneda por código: $e');
      return null;
    }
  }

  // ==================== BUSCAR MONEDAS ====================
  Future<List<Moneda>> buscarMonedas(String busqueda) async {
    try {
      final data = await supabase
          .from('monedas')
          .select()
          .or('divisa.ilike.%$busqueda%,cod_moneda.eq.${int.tryParse(busqueda) ?? -1}');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Moneda> monedas = registros.map((mapa) {
        return Moneda.fromMap(mapa);
      }).toList();

      return monedas;
    } catch (e) {
      print('Error al buscar monedas: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR MONEDA ====================
  Future<bool> actualizarMoneda(Moneda moneda) async {
    try {
      await supabase
          .from('monedas')
          .update({
            'cod_moneda': moneda.cod_moneda,
            'num': moneda.num,
            'dec': moneda.dec,
            'divisa': moneda.divisa,
            'cotizacion_gs': moneda.cotizacion_gs,
          })
          .eq('id_monedas', moneda.id_monedas!);

      print('Moneda actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar moneda: $e');
      return false;
    }
  }

  // ==================== ACTUALIZAR COTIZACIÓN ====================
  Future<bool> actualizarCotizacion(int idMoneda, double nuevaCotizacion) async {
    try {
      await supabase
          .from('monedas')
          .update({'cotizacion_gs': nuevaCotizacion})
          .eq('id_monedas', idMoneda);

      print('Cotización actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar cotización: $e');
      return false;
    }
  }

  // ==================== ELIMINAR MONEDA ====================
  Future<bool> eliminarMoneda(int idMoneda) async {
    try {
      await supabase
          .from('monedas')
          .delete()
          .eq('id_monedas', idMoneda);

      print('Moneda eliminada exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar moneda: $e');
      return false;
    }
  }

  // ==================== VERIFICAR CÓDIGO MONEDA EXISTENTE ====================
  Future<bool> verificarCodigoMonedaExistente(int codMoneda, {int? idMonedaExcluir}) async {
    try {
      var query = supabase
          .from('monedas')
          .select('id_monedas')
          .eq('cod_moneda', codMoneda);

      if (idMonedaExcluir != null) {
        query = query.neq('id_monedas', idMonedaExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar código de moneda: $e');
      return false;
    }
  }

  // ==================== VERIFICAR DIVISA EXISTENTE ====================
  Future<bool> verificarDivisaExistente(String divisa, {int? idMonedaExcluir}) async {
    try {
      var query = supabase
          .from('monedas')
          .select('id_monedas')
          .eq('divisa', divisa);

      if (idMonedaExcluir != null) {
        query = query.neq('id_monedas', idMonedaExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar divisa: $e');
      return false;
    }
  }
}