import 'package:myapp/modelo/tarifa.dart';
import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class TarifaCrudImpl {
  
  // ==================== CREAR TARIFA ====================
  Future<Tarifa?> crearTarifa(Tarifa tarifa) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tarifas')
          .insert({
            'rango_min': tarifa.rango_min,
            'rango_max': tarifa.rango_max,
            'costo_m3': tarifa.costo_m3,
            'fk_categoria_servicio': tarifa.categoriaServicio.id,
          })
          .select()
          .single();

      print('Tarifa creada exitosamente');
      return Tarifa.fromMap(data);
    } catch (e) {
      print('Error al crear tarifa: $e');
      return null;
    }
  }

  // ==================== LEER TODAS LAS TARIFAS ====================
  Future<List<Tarifa>> leerTarifas() async {
    try {
      final data = await supabase
          .from('tarifas')
          .select('''
            *,
            categoria_servicio(*)
          ''');

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay tarifas en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Tarifa> tarifas = registros.map((mapa) {
        return Tarifa(
          id_tarifa: mapa['id_tarifas'],
          rango_min: mapa['rango_min'].toDouble(),
          rango_max: mapa['rango_max'].toDouble(),
          costo_m3: mapa['costo_m3'].toDouble(),
          categoriaServicio: CategoriaServicio.fromMap(mapa['categoria_servicio']),
        );
      }).toList();

      print('Se cargaron ${tarifas.length} tarifas');
      return tarifas;
    } catch (e) {
      print('Error al leer tarifas: $e');
      return [];
    }
  }

  // ==================== LEER UNA TARIFA POR ID ====================
  Future<Tarifa?> leerTarifaPorId(int idTarifa) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('tarifas')
          .select('''
            *,
            categoria_servicio(*)
          ''')
          .eq('id_tarifa', idTarifa)
          .single();

      return Tarifa(
        id_tarifa: data['id_tarifas'],
        rango_min: data['rango_min'].toDouble(),
        rango_max: data['rango_max'].toDouble(),
        costo_m3: data['costo_m3'].toDouble(),
        categoriaServicio: CategoriaServicio.fromMap(data['categoria_servicio']),
      );
    } catch (e) {
      print('Error al leer tarifa por ID: $e');
      return null;
    }
  }

  // ==================== LEER TARIFAS POR CATEGORÍA ====================
  Future<List<Tarifa>> leerTarifasPorCategoria(int idCategoria) async {
    try {
      final data = await supabase
          .from('tarifas')
          .select('''
            *,
            categoria_servicio(*)
          ''')
          .eq('fk_categoria_servicio', idCategoria)
          .order('rango_min', ascending: true);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Tarifa> tarifas = registros.map((mapa) {
        return Tarifa(
          id_tarifa: mapa['id_tarifas'],
          rango_min: mapa['rango_min'].toDouble(),
          rango_max: mapa['rango_max'].toDouble(),
          costo_m3: mapa['costo_m3'].toDouble(),
          categoriaServicio: CategoriaServicio.fromMap(mapa['categoria_servicio']),
        );
      }).toList();

      return tarifas;
    } catch (e) {
      print('Error al leer tarifas por categoría: $e');
      return [];
    }
  }

  // ==================== BUSCAR TARIFA POR CONSUMO ====================
  Future<Tarifa?> buscarTarifaPorConsumo(double consumo, int idCategoria) async {
    try {
      final data = await supabase
          .from('tarifas')
          .select('''
            *,
            categoria_servicio(*)
          ''')
          .eq('fk_categoria_servicio', idCategoria)
          .lte('rango_min', consumo)
          .gte('rango_max', consumo)
          .single();

      return Tarifa(
        id_tarifa: data['id_tarifas'],
        rango_min: data['rango_min'].toDouble(),
        rango_max: data['rango_max'].toDouble(),
        costo_m3: data['costo_m3'].toDouble(),
        categoriaServicio: CategoriaServicio.fromMap(data['categoria_servicio']),
      );
    } catch (e) {
      print('Error al buscar tarifa por consumo: $e');
      return null;
    }
  }

  // ==================== ACTUALIZAR TARIFA ====================
  Future<bool> actualizarTarifa(Tarifa tarifa) async {
    try {
      await supabase
          .from('tarifas')
          .update({
            'rango_min': tarifa.rango_min,
            'rango_max': tarifa.rango_max,
            'costo_m3': tarifa.costo_m3,
            'fk_categoria_servicio': tarifa.categoriaServicio.id,
          })
          .eq('id_tarifa', tarifa.id_tarifa!);

      print('Tarifa actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar tarifa: $e');
      return false;
    }
  }

  // ==================== ELIMINAR TARIFA ====================
  Future<bool> eliminarTarifa(int idTarifa) async {
    try {
      await supabase
          .from('tarifas')
          .delete()
          .eq('id_tarifas', idTarifa);

      print('Tarifa eliminada exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar tarifa: $e');
      return false;
    }
  }

  // ==================== VERIFICAR SOLAPAMIENTO DE RANGOS ====================
  Future<bool> verificarSolapamientoRangos(
    double rangoMin, 
    double rangoMax, 
    int idCategoria,
    {int? idTarifaExcluir}
  ) async {
    try {
      var query = supabase
          .from('tarifas')
          .select('id_tarifas')
          .eq('fk_categoria_servicio', idCategoria)
          .or('rango_min.lte.$rangoMax,rango_max.gte.$rangoMin');

      if (idTarifaExcluir != null) {
        query = query.neq('id_tarifa', idTarifaExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar solapamiento de rangos: $e');
      return false;
    }
  }

  // ==================== CALCULAR COSTO POR CONSUMO ====================
  Future<double?> calcularCostoPorConsumo(double consumo, int idCategoria) async {
    try {
      final tarifa = await buscarTarifaPorConsumo(consumo, idCategoria);
      
      if (tarifa == null) {
        print('No se encontró tarifa para el consumo: $consumo m³');
        return null;
      }

      final costo = consumo * tarifa.costo_m3;
      return costo;
    } catch (e) {
      print('Error al calcular costo: $e');
      return null;
    }
  }
}