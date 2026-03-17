import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/contabilidad/asiento.dart';
import 'package:myapp/modelo/empresa/dato_empresa.dart';
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
      // Convertir a UTC para que coincida con el timezone en que Supabase guarda
      final data = await supabase
          .from('asientos')
          .select(_select)
          .gte('fecha', desde.toUtc().toIso8601String())
          .lte('fecha', hasta.toUtc().toIso8601String())
          .order('fecha', ascending: false);

      if (data == null || data.isEmpty) {
        print('⚠️ asientos: sin datos en el rango ${desde.toUtc()} - ${hasta.toUtc()}');
        return [];
      }

      print('✓ asientos encontrados: ${data.length}');
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
  final estMap = m['establecimientos'];

  // fk_barrio y fk_empresa llegan como int (solo ID), no como objetos anidados
  // Se construye Establecimiento directamente sin intentar parsear esas relaciones
  final Establecimiento sucursal = estMap != null
      ? Establecimiento(
          id_establecimiento: estMap['id_establecimiento'],
          codigo_establecimiento: estMap['codigo_establecimiento'] ?? '',
          direccion: estMap['direccion'] ?? '',
          numero_casa: estMap['numero_casa'] ?? '',
          complemento_direccion_1: estMap['complemento_direccion_1'] ?? '',
          complemento_direccion_2: estMap['complemento_direccion_2'],
          telefono: estMap['telefono'],
          email: estMap['email'],
          denominacion: estMap['denominacion'] ?? '',
          estado_establecimiento: estMap['estado_establecimiento'] ?? '',
          fk_barrio: Barrio.vacio(),
          fk_empresa: DatoEmpresa.vacio(),
        )
      : Establecimiento.vacio();

  return Asientos(
    id: m['id'],
    fecha: DateTime.parse(m['fecha']),
    descripcion: m['descripcion'],
    nroAsiento: m['nro_asiento'],
    sucursal: sucursal,
    estado: m['estado'],
    origenTipo: m['origen_tipo'],
    fkOrigen: m['fk_origen'],
  );
}
}