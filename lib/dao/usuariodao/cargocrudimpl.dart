import 'package:myapp/modelo/usuario/cargo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CargoCrudImpl {

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ==================== CREAR CARGO ====================

  Future<Cargo?> crearCargo(Cargo cargo) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('cargo')
          .insert({
            'cargo': cargo.nombre,
            'descripcion_cargo': cargo.descripcion_cargo,
          })
          .select()
          .single();

      print('Cargo creado exitosamente');
      return Cargo.fromMap(data);
    } catch (e) {
      print('Error al crear cargo: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS CARGOS ====================

  Future<List<Cargo>> leerCargos() async {
    try {
      final data = await supabase
          .from('cargo')
          .select();

      if (data == null) {
        print('La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay cargos en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Cargo> cargos = registros.map((mapa) {
        return Cargo(
          id_cargo: _toInt(mapa['id_cargo']),
          nombre: mapa['cargo'] ?? '',
          descripcion_cargo: mapa['descripcion_cargo'] ?? '',
        );
      }).toList();

      print('Se cargaron ${cargos.length} cargos');
      return cargos;
    } catch (e) {
      print('Error al leer cargos: $e');
      return [];
    }
  }

  // ==================== LEER CARGO POR ID ====================

  Future<Cargo?> leerCargoPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('cargo')
          .select()
          .eq('id_cargo', id)
          .single();

      return Cargo.fromMap(data);
    } catch (e) {
      print('Error al leer cargo por ID: $e');
      return null;
    }
  }

  // ==================== LEER CARGO POR NOMBRE ====================

  Future<Cargo?> leerCargoPorNombre(String nombre) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('cargo')
          .select()
          .eq('cargo', nombre)
          .single();

      return Cargo.fromMap(data);
    } catch (e) {
      print('Error al leer cargo por nombre: $e');
      return null;
    }
  }

  // ==================== BUSCAR CARGOS ====================

  Future<List<Cargo>> buscarCargos(String busqueda) async {
    try {
      final data = await supabase
          .from('cargo')
          .select()
          .or('nombre.ilike.%$busqueda%,descripcion_cargo.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Cargo> cargos = registros.map((mapa) {
        return Cargo.fromMap(mapa);
      }).toList();

      return cargos;
    } catch (e) {
      print('Error al buscar cargos: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR CARGO ====================

  Future<bool> actualizarCargo(Cargo cargo) async {
    try {
      await supabase
          .from('cargo')
          .update({
            'cargo': cargo.nombre,
            'descripcion_cargo': cargo.descripcion_cargo,
          })
          .eq('id_cargo', cargo.id_cargo!);

      print('Cargo actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar cargo: $e');
      return false;
    }
  }

  // ==================== ELIMINAR CARGO ====================

  Future<bool> eliminarCargo(int id) async {
    try {
      await supabase
          .from('cargo')
          .delete()
          .eq('id_cargo', id);

      print('Cargo eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar cargo: $e');
      return false;
    }
  }

  // ==================== VERIFICAR NOMBRE EXISTENTE ====================

  Future<bool> verificarNombreExistente(String nombre, {int? idCargoExcluir}) async {
    try {
      var query = supabase
          .from('cargo')
          .select('id_cargo')
          .eq('cargo', nombre);

      if (idCargoExcluir != null) {
        query = query.neq('id_cargo', idCargoExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar nombre de cargo: $e');
      return false;
    }
  }

  // ==================== VERIFICAR SI CARGO TIENE EMPLEADOS ====================

  Future<bool> cargoTieneEmpleados(int idCargo) async {
    try {
      // Verificar si hay empleados asociados a este cargo
      final data = await supabase
          .from('empleados')
          .select('id_empleado')
          .eq('fk_cargo', idCargo)
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar empleados del cargo: $e');
      return false;
    }
  }

  // ==================== CONTAR CARGOS ====================

  Future<int> contarCargos() async {
    try {
      final data = await supabase
          .from('cargo')
          .select('id_cargo')
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar cargos: $e');
      return 0;
    }
  }

  // ==================== CONTAR EMPLEADOS POR CARGO ====================

  Future<int> contarEmpleadosPorCargo(int idCargo) async {
    try {
      final data = await supabase
          .from('empleados')
          .select('id_empleado')
          .eq('fk_cargo', idCargo)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar empleados por cargo: $e');
      return 0;
    }
  }

  // ==================== ORDENAR CARGOS POR NOMBRE ====================

  Future<List<Cargo>> leerCargosOrdenados({bool ascendente = true}) async {
    try {
      final data = await supabase
          .from('cargo')
          .select()
          .order('cargo', ascending: ascendente);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Cargo> cargos = registros.map((mapa) {
        return Cargo.fromMap(mapa);
      }).toList();

      return cargos;
    } catch (e) {
      print('Error al leer cargos ordenados: $e');
      return [];
    }
  }

  // ==================== OBTENER CARGOS ACTIVOS (SIN EMPLEADOS) ====================

  Future<List<Cargo>> obtenerCargosDisponibles() async {
    try {
      // Obtener todos los cargos que no tienen empleados asignados
      final todosCargos = await leerCargos();
      final cargosDisponibles = <Cargo>[];

      for (var cargo in todosCargos) {
        final tieneEmpleados = await cargoTieneEmpleados(cargo.id_cargo!);
        if (!tieneEmpleados) {
          cargosDisponibles.add(cargo);
        }
      }

      return cargosDisponibles;
    } catch (e) {
      print('Error al obtener cargos disponibles: $e');
      return [];
    }
  }

  // ==================== OBTENER ESTADÍSTICAS DE CARGOS ====================

  Future<Map<String, dynamic>> obtenerEstadisticasCargos() async {
    try {
      final totalCargos = await contarCargos();
      final cargos = await leerCargos();

      int cargosConEmpleados = 0;
      int cargosVacios = 0;

      for (var cargo in cargos) {
        final tieneEmpleados = await cargoTieneEmpleados(cargo.id_cargo!);
        if (tieneEmpleados) {
          cargosConEmpleados++;
        } else {
          cargosVacios++;
        }
      }

      return {
        'total_cargos': totalCargos,
        'cargos_con_empleados': cargosConEmpleados,
        'cargos_sin_empleados': cargosVacios,
      };
    } catch (e) {
      print('Error al obtener estadísticas de cargos: $e');
      return {
        'total_cargos': 0,
        'cargos_con_empleados': 0,
        'cargos_sin_empleados': 0,
      };
    }
  }
}