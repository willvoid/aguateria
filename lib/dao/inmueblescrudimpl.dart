import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class InmuebleCrudImpl {

  final ClienteCrudImpl _clienteCrud = ClienteCrudImpl();

  // Trae todos los clientes una sola vez y los indexa por ID para no
  // hacer N queries individuales en cada listado
  Future<Map<int, Cliente>> _clientesPorId() async {
    final lista = await _clienteCrud.leerClientes();
    return { for (final c in lista) c.idCliente!: c };
  }

  // ==================== CREAR INMUEBLE ====================
  Future<Inmuebles?> crearInmueble(Inmuebles inmueble) async {
    try {
      final data = await supabase
          .from('inmuebles')
          .insert({
            'cod_inmueble': inmueble.cod_inmueble,
            'estado': inmueble.estado,
            'direccion': inmueble.direccion,
            'fk_cliente': inmueble.cliente.idCliente,
            'fk_categoria_servicio': inmueble.categoriaServicio.id,
          })
          .select('''
            *,
            fk_categoria_servicio(*)
          ''')
          .single();

      // El cliente ya lo tenemos en el objeto original
      print('Inmueble creado exitosamente');
      return Inmuebles(
        id: data['id'],
        cod_inmueble: data['cod_inmueble'],
        estado: data['estado'],
        direccion: data['direccion'],
        cliente: inmueble.cliente,
        categoriaServicio: CategoriaServicio.fromMap(data['fk_categoria_servicio']),
      );
    } catch (e) {
      print('Error al crear inmueble: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS INMUEBLES ====================
  Future<List<Inmuebles>> leerInmuebles() async {
    try {
      final results = await Future.wait(<Future<dynamic>>[
        supabase.from('inmuebles').select('*, fk_categoria_servicio(*)'),
        _clientesPorId(),
      ]);

      final rows = results[0] as List<dynamic>;
      final clientesMap = results[1] as Map<int, Cliente>;

      if (rows.isEmpty) {
        print('ℹ️ No hay inmuebles en la base de datos');
        return [];
      }

      final inmuebles = <Inmuebles>[];
      for (final row in rows) {
        final idCliente = row['fk_cliente'] as int;
        final cliente = clientesMap[idCliente];
        if (cliente == null) {
          print('⚠️ Cliente $idCliente no encontrado, omitiendo inmueble ${row['id']}');
          continue;
        }
        inmuebles.add(Inmuebles(
          id: row['id'],
          cod_inmueble: row['cod_inmueble'],
          estado: row['estado'],
          direccion: row['direccion'],
          cliente: cliente,
          categoriaServicio: CategoriaServicio.fromMap(row['fk_categoria_servicio']),
        ));
      }

      print('✓ Se cargaron ${inmuebles.length} inmuebles');
      return inmuebles;
    } catch (e) {
      print('Error al leer inmuebles: $e');
      return [];
    }
  }

  // ==================== LEER UN INMUEBLE POR ID ====================
  Future<Inmuebles?> leerInmueblePorId(int idInmueble) async {
    try {
      final data = await supabase
          .from('inmuebles')
          .select('*, fk_categoria_servicio(*)')
          .eq('id', idInmueble)
          .single();

      final cliente = await _clienteCrud.leerClientePorId(data['fk_cliente'] as int);
      if (cliente == null) throw Exception('Cliente no encontrado');

      return Inmuebles(
        id: data['id'],
        cod_inmueble: data['cod_inmueble'],
        estado: data['estado'],
        direccion: data['direccion'],
        cliente: cliente,
        categoriaServicio: CategoriaServicio.fromMap(data['fk_categoria_servicio']),
      );
    } catch (e) {
      print('Error al leer inmueble por ID: $e');
      return null;
    }
  }

  // ==================== BUSCAR INMUEBLES ====================
  Future<List<Inmuebles>> buscarInmuebles(String busqueda) async {
    try {
      final results = await Future.wait(<Future<dynamic>>[
        supabase
            .from('inmuebles')
            .select('*, fk_categoria_servicio(*)')
            .or('cod_inmueble.ilike.%$busqueda%,direccion.ilike.%$busqueda%'),
        _clientesPorId(),
      ]);

      final rows = results[0] as List<dynamic>;
      final clientesMap = results[1] as Map<int, Cliente>;

      if (rows.isEmpty) return [];

      final inmuebles = <Inmuebles>[];
      for (final row in rows) {
        final cliente = clientesMap[row['fk_cliente'] as int];
        if (cliente == null) continue;
        inmuebles.add(Inmuebles(
          id: row['id'],
          cod_inmueble: row['cod_inmueble'],
          estado: row['estado'],
          direccion: row['direccion'],
          cliente: cliente,
          categoriaServicio: CategoriaServicio.fromMap(row['fk_categoria_servicio']),
        ));
      }
      return inmuebles;
    } catch (e) {
      print('Error al buscar inmuebles: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR INMUEBLE ====================
  Future<bool> actualizarInmueble(Inmuebles inmueble) async {
    try {
      await supabase
          .from('inmuebles')
          .update({
            'cod_inmueble': inmueble.cod_inmueble,
            'estado': inmueble.estado,
            'direccion': inmueble.direccion,
            'fk_cliente': inmueble.cliente.idCliente,
            'fk_categoria_servicio': inmueble.categoriaServicio.id,
          })
          .eq('id', inmueble.id!);

      print('Inmueble actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar inmueble: $e');
      return false;
    }
  }

  // ==================== ELIMINAR INMUEBLE ====================
  Future<bool> eliminarInmueble(int idInmueble) async {
    try {
      await supabase.from('inmuebles').delete().eq('id', idInmueble);
      print('Inmueble eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar inmueble: $e');
      return false;
    }
  }

  // ==================== LEER INMUEBLES POR CLIENTE ====================
  Future<List<Inmuebles>> leerInmueblesPorCliente(int idCliente) async {
    try {
      final results = await Future.wait(<Future<dynamic>>[
        supabase
            .from('inmuebles')
            .select('*, fk_categoria_servicio(*)')
            .eq('fk_cliente', idCliente),
        _clienteCrud.leerClientePorId(idCliente),
      ]);

      final rows = results[0] as List<dynamic>;
      final cliente = results[1] as Cliente?;

      if (rows.isEmpty || cliente == null) return [];

      return rows.map((row) => Inmuebles(
        id: row['id'],
        cod_inmueble: row['cod_inmueble'],
        estado: row['estado'],
        direccion: row['direccion'],
        cliente: cliente,
        categoriaServicio: CategoriaServicio.fromMap(row['fk_categoria_servicio']),
      )).toList();
    } catch (e) {
      print('Error al leer inmuebles por cliente: $e');
      return [];
    }
  }

  // ==================== LEER INMUEBLES POR CATEGORÍA ====================
  Future<List<Inmuebles>> leerInmueblesPorCategoria(int idCategoria) async {
    try {
      final results = await Future.wait(<Future<dynamic>>[
        supabase
            .from('inmuebles')
            .select('*, fk_categoria_servicio(*)')
            .eq('fk_categoria_servicio', idCategoria),
        _clientesPorId(),
      ]);

      final rows = results[0] as List<dynamic>;
      final clientesMap = results[1] as Map<int, Cliente>;

      if (rows.isEmpty) return [];

      final inmuebles = <Inmuebles>[];
      for (final row in rows) {
        final cliente = clientesMap[row['fk_cliente'] as int];
        if (cliente == null) continue;
        inmuebles.add(Inmuebles(
          id: row['id'],
          cod_inmueble: row['cod_inmueble'],
          estado: row['estado'],
          direccion: row['direccion'],
          cliente: cliente,
          categoriaServicio: CategoriaServicio.fromMap(row['fk_categoria_servicio']),
        ));
      }
      return inmuebles;
    } catch (e) {
      print('Error al leer inmuebles por categoría: $e');
      return [];
    }
  }

  // ==================== LEER INMUEBLES POR ESTADO ====================
  Future<List<Inmuebles>> leerInmueblesPorEstado(String estado) async {
    try {
      final results = await Future.wait(<Future<dynamic>>[
        supabase
            .from('inmuebles')
            .select('*, fk_categoria_servicio(*)')
            .eq('estado', estado),
        _clientesPorId(),
      ]);

      final rows = results[0] as List<dynamic>;
      final clientesMap = results[1] as Map<int, Cliente>;

      if (rows.isEmpty) return [];

      final inmuebles = <Inmuebles>[];
      for (final row in rows) {
        final cliente = clientesMap[row['fk_cliente'] as int];
        if (cliente == null) continue;
        inmuebles.add(Inmuebles(
          id: row['id'],
          cod_inmueble: row['cod_inmueble'],
          estado: row['estado'],
          direccion: row['direccion'],
          cliente: cliente,
          categoriaServicio: CategoriaServicio.fromMap(row['fk_categoria_servicio']),
        ));
      }
      return inmuebles;
    } catch (e) {
      print('Error al leer inmuebles por estado: $e');
      return [];
    }
  }

  // ==================== CAMBIAR ESTADO INMUEBLE ====================
  Future<bool> cambiarEstadoInmueble(int idInmueble, String nuevoEstado) async {
    try {
      await supabase
          .from('inmuebles')
          .update({'estado': nuevoEstado})
          .eq('id', idInmueble);
      print('Estado del inmueble actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al cambiar estado del inmueble: $e');
      return false;
    }
  }

  // ==================== VERIFICAR CÓDIGO EXISTENTE ====================
  Future<bool> verificarCodigoExistente(String codigo, {int? idInmuebleExcluir}) async {
    try {
      var query = supabase
          .from('inmuebles')
          .select('id')
          .eq('cod_inmueble', codigo);

      if (idInmuebleExcluir != null) {
        query = query.neq('id', idInmuebleExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar código: $e');
      return false;
    }
  }

  // ==================== CONTAR INMUEBLES POR CLIENTE ====================
  Future<int> contarInmueblesPorCliente(int idCliente) async {
    try {
      final data = await supabase
          .from('inmuebles')
          .select('id')
          .eq('fk_cliente', idCliente);
      return data.length;
    } catch (e) {
      print('Error al contar inmuebles: $e');
      return 0;
    }
  }
}