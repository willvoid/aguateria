import 'package:myapp/modelo/contabilidad/asiento.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AsientosCrudImpl {

  static const String _select = '''
    *,
    establecimientos(*)
  ''';

  // ==================== CREAR ====================
  Future<Asientos?> crear(Asientos asiento) async {
    try {
      final Map<String, dynamic> insertData = {
        'fecha': asiento.fecha.toIso8601String(),
        'descripcion': asiento.descripcion,
        'nro_asiento': asiento.nroAsiento,
        'fk_sucursal': asiento.sucursal.id_establecimiento,
        'estado': asiento.estado,
        'origen_tipo': asiento.origenTipo,
        'fk_origen': asiento.fkOrigen,
      };

      final Map<String, dynamic> data = await supabase
          .from('asientos')
          .insert(insertData)
          .select(_select)
          .single();

      print('Asiento creado exitosamente');
      return _fromMap(data);
    } catch (e) {
      print('Error al crear asiento: $e');
      return null;
    }
  }

  // ==================== LEER TODOS ====================
  Future<List<Asientos>> leerTodos() async {
    try {
      final data = await supabase
          .from('asientos')
          .select(_select)
          .order('fecha', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer asientos: $e');
      return [];
    }
  }

  // ==================== LEER POR ID ====================
  Future<Asientos?> leerPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('asientos')
          .select(_select)
          .eq('id', id)
          .single();

      return _fromMap(data);
    } catch (e) {
      print('Error al leer asiento por ID: $e');
      return null;
    }
  }

  // ==================== LEER POR SUCURSAL ====================
  Future<List<Asientos>> leerPorSucursal(int idSucursal) async {
    try {
      final data = await supabase
          .from('asientos')
          .select(_select)
          .eq('fk_sucursal', idSucursal)
          .order('fecha', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer asientos por sucursal: $e');
      return [];
    }
  }

  // ==================== LEER POR ESTADO ====================
  Future<List<Asientos>> leerPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('asientos')
          .select(_select)
          .eq('estado', estado)
          .order('fecha', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer asientos por estado: $e');
      return [];
    }
  }

  // ==================== LEER POR RANGO DE FECHAS ====================
  Future<List<Asientos>> leerPorRangoFechas(DateTime desde, DateTime hasta) async {
    try {
      final data = await supabase
          .from('asientos')
          .select(_select)
          .gte('fecha', desde.toIso8601String())
          .lte('fecha', hasta.toIso8601String())
          .order('fecha', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer asientos por rango de fechas: $e');
      return [];
    }
  }

  // ==================== LEER POR ORIGEN ====================
  Future<List<Asientos>> leerPorOrigen(String origenTipo, int fkOrigen) async {
    try {
      final data = await supabase
          .from('asientos')
          .select(_select)
          .eq('origen_tipo', origenTipo)
          .eq('fk_origen', fkOrigen)
          .order('fecha', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data)
          .map((m) => _fromMap(m))
          .toList();
    } catch (e) {
      print('Error al leer asientos por origen: $e');
      return [];
    }
  }

  // ==================== CAMBIAR ESTADO ====================
  Future<bool> cambiarEstado(int id, String nuevoEstado) async {
    try {
      await supabase
          .from('asientos')
          .update({'estado': nuevoEstado})
          .eq('id', id);

      print('Estado del asiento actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al cambiar estado del asiento: $e');
      return false;
    }
  }

  // ==================== ACTUALIZAR ====================
  Future<bool> actualizar(Asientos asiento) async {
    try {
      await supabase
          .from('asientos')
          .update({
            'fecha': asiento.fecha.toIso8601String(),
            'descripcion': asiento.descripcion,
            'nro_asiento': asiento.nroAsiento,
            'fk_sucursal': asiento.sucursal.id_establecimiento,
            'estado': asiento.estado,
            'origen_tipo': asiento.origenTipo,
            'fk_origen': asiento.fkOrigen,
          })
          .eq('id', asiento.id!);

      print('Asiento actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar asiento: $e');
      return false;
    }
  }

  // ==================== ELIMINAR ====================
  Future<bool> eliminar(int id) async {
    try {
      await supabase
          .from('asientos')
          .delete()
          .eq('id', id);

      print('Asiento eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar asiento: $e');
      return false;
    }
  }

  // ==================== HELPER PRIVADO ====================
  Asientos _fromMap(Map<String, dynamic> m) {
    return Asientos(
      id: m['id'],
      fecha: DateTime.parse(m['fecha']),
      descripcion: m['descripcion'],
      nroAsiento: m['nro_asiento'],
      sucursal: Establecimiento.fromMap(m['establecimientos']),
      estado: m['estado'],
      origenTipo: m['origen_tipo'],
      fkOrigen: m['fk_origen'],
    );
  }
}