import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/modelo/tipo_operacion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class InmuebleCrudImpl {
  
  // ==================== CREAR INMUEBLE ====================
  Future<Inmuebles?> crearInmueble(Inmuebles inmueble) async {
    try {
      final Map<String, dynamic> data = await supabase
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
            fk_cliente(*,
              tipo_documento(*),
              barrios(*),
              tipo_operacion(*)
            ),
            fk_categoria_servicio(*)
          ''')
          .single();

      print('Inmueble creado exitosamente');
      return Inmuebles.fromMap(data);
    } catch (e) {
      print('Error al crear inmueble: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS INMUEBLES ====================
  Future<List<Inmuebles>> leerInmuebles() async {
    try {
      final data = await supabase
          .from('inmuebles')
          .select('''
            *,
            fk_cliente(*,
              tipo_documento(*),
              barrios(*),
              tipo_operacion(*)
            ),
            fk_categoria_servicio(*)
          ''');

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay inmuebles en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Inmuebles> inmuebles = registros.map((mapa) {
        return Inmuebles(
          id: mapa['id'],
          cod_inmueble: mapa['cod_inmueble'],
          estado: mapa['estado'],
          direccion: mapa['direccion'],
          cliente: Cliente(
            idCliente: mapa['fk_cliente']['id_cliente'],
            razonSocial: mapa['fk_cliente']['razon_social'],
            nombreFantasia: mapa['fk_cliente']['nombre_fantasia'],
            documento: mapa['fk_cliente']['documento'],
            telefono: mapa['fk_cliente']['telefono'],
            celular: mapa['fk_cliente']['celular'],
            direccion: mapa['fk_cliente']['direccion'],
            es_proveedor_del_estado: mapa['fk_cliente']['es_proveedor_del_estado'],
            email: mapa['fk_cliente']['email'],
            nroCasa: mapa['fk_cliente']['nro_casa'],
            tipoOperacion: TipoOperacion.fromMap(mapa['fk_cliente']['tipo_operacion']),
            estado: mapa['fk_cliente']['estado_cliente'],
            tipoDocumento: TipoDocumento.fromMap(mapa['fk_cliente']['tipo_documento']),
            barrio: Barrio.fromMap(mapa['fk_cliente']['barrios']),
          ),
          categoriaServicio: CategoriaServicio.fromMap(mapa['fk_categoria_servicio']),
        );
      }).toList();

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
      final Map<String, dynamic> data = await supabase
          .from('inmuebles')
          .select('''
            *,
            fk_cliente(*,
              tipo_documento(*),
              barrios(*),
              tipo_operacion(*)
            ),
            fk_categoria_servicio(*)
          ''')
          .eq('id', idInmueble)
          .single();

      return Inmuebles(
        id: data['id'],
        cod_inmueble: data['cod_inmueble'],
        estado: data['estado'],
        direccion: data['direccion'],
        cliente: Cliente(
          idCliente: data['fk_cliente']['id_cliente'],
          razonSocial: data['fk_cliente']['razon_social'],
          nombreFantasia: data['fk_cliente']['nombre_fantasia'],
          documento: data['fk_cliente']['documento'],
          telefono: data['fk_cliente']['telefono'],
          celular: data['fk_cliente']['celular'],
          direccion: data['fk_cliente']['direccion'],
          es_proveedor_del_estado: data['fk_cliente']['es_proveedor_del_estado'],
          email: data['fk_cliente']['email'],
          nroCasa: data['fk_cliente']['nro_casa'],
          tipoOperacion: TipoOperacion.fromMap(data['fk_cliente']['tipo_operacion']),
          estado: data['fk_cliente']['estado_cliente'],
          tipoDocumento: TipoDocumento.fromMap(data['fk_cliente']['tipo_documento']),
          barrio: Barrio.fromMap(data['fk_cliente']['barrios']),
        ),
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
      final data = await supabase
          .from('inmuebles')
          .select('''
            *,
            fk_cliente(*,
              tipo_documento(*),
              barrios(*),
              tipo_operacion(*)
            ),
            fk_categoria_servicio(*)
          ''')
          .or('cod_inmueble.ilike.%$busqueda%,direccion.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Inmuebles> inmuebles = registros.map((mapa) {
        return Inmuebles(
          id: mapa['id'],
          cod_inmueble: mapa['cod_inmueble'],
          estado: mapa['estado'],
          direccion: mapa['direccion'],
          cliente: Cliente(
            idCliente: mapa['fk_cliente']['id_cliente'],
            razonSocial: mapa['fk_cliente']['razon_social'],
            nombreFantasia: mapa['fk_cliente']['nombre_fantasia'],
            documento: mapa['fk_cliente']['documento'],
            telefono: mapa['fk_cliente']['telefono'],
            celular: mapa['fk_cliente']['celular'],
            direccion: mapa['fk_cliente']['direccion'],
            es_proveedor_del_estado: mapa['fk_cliente']['es_proveedor_del_estado'],
            email: mapa['fk_cliente']['email'],
            nroCasa: mapa['fk_cliente']['nro_casa'],
            tipoOperacion: TipoOperacion.fromMap(mapa['fk_cliente']['tipo_operacion']),
            estado: mapa['fk_cliente']['estado_cliente'],
            tipoDocumento: TipoDocumento.fromMap(mapa['fk_cliente']['tipo_documento']),
            barrio: Barrio.fromMap(mapa['fk_cliente']['barrios']),
          ),
          categoriaServicio: CategoriaServicio.fromMap(mapa['fk_categoria_servicio']),
        );
      }).toList();

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
      await supabase
          .from('inmuebles')
          .delete()
          .eq('id', idInmueble);

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
      final data = await supabase
          .from('inmuebles')
          .select('''
            *,
            fk_cliente(*,
              tipo_documento(*),
              barrios(*),
              tipo_operacion(*)
            ),
            fk_categoria_servicio(*)
          ''')
          .eq('fk_cliente', idCliente);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Inmuebles> inmuebles = registros.map((mapa) {
        return Inmuebles(
          id: mapa['id'],
          cod_inmueble: mapa['cod_inmueble'],
          estado: mapa['estado'],
          direccion: mapa['direccion'],
          cliente: Cliente(
            idCliente: mapa['fk_cliente']['id_cliente'],
            razonSocial: mapa['fk_cliente']['razon_social'],
            nombreFantasia: mapa['fk_cliente']['nombre_fantasia'],
            documento: mapa['fk_cliente']['documento'],
            telefono: mapa['fk_cliente']['telefono'],
            celular: mapa['fk_cliente']['celular'],
            direccion: mapa['fk_cliente']['direccion'],
            es_proveedor_del_estado: mapa['fk_cliente']['es_proveedor_del_estado'],
            email: mapa['fk_cliente']['email'],
            nroCasa: mapa['fk_cliente']['nro_casa'],
            tipoOperacion: TipoOperacion.fromMap(mapa['fk_cliente']['tipo_operacion']),
            estado: mapa['fk_cliente']['estado_cliente'],
            tipoDocumento: TipoDocumento.fromMap(mapa['fk_cliente']['tipo_documento']),
            barrio: Barrio.fromMap(mapa['fk_cliente']['barrios']),
          ),
          categoriaServicio: CategoriaServicio.fromMap(mapa['fk_categoria_servicio']),
        );
      }).toList();

      return inmuebles;
    } catch (e) {
      print('Error al leer inmuebles por cliente: $e');
      return [];
    }
  }

  // ==================== LEER INMUEBLES POR CATEGORÍA ====================
  Future<List<Inmuebles>> leerInmueblesPorCategoria(int idCategoria) async {
    try {
      final data = await supabase
          .from('inmuebles')
          .select('''
            *,
            fk_cliente(*,
              tipo_documento(*),
              barrios(*),
              tipo_operacion(*)
            ),
            fk_categoria_servicio(*)
          ''')
          .eq('fk_categoria_servicio', idCategoria);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Inmuebles> inmuebles = registros.map((mapa) {
        return Inmuebles(
          id: mapa['id'],
          cod_inmueble: mapa['cod_inmueble'],
          estado: mapa['estado'],
          direccion: mapa['direccion'],
          cliente: Cliente(
            idCliente: mapa['fk_cliente']['id_cliente'],
            razonSocial: mapa['fk_cliente']['razon_social'],
            nombreFantasia: mapa['fk_cliente']['nombre_fantasia'],
            documento: mapa['fk_cliente']['documento'],
            telefono: mapa['fk_cliente']['telefono'],
            celular: mapa['fk_cliente']['celular'],
            direccion: mapa['fk_cliente']['direccion'],
            es_proveedor_del_estado: mapa['fk_cliente']['es_proveedor_del_estado'],
            email: mapa['fk_cliente']['email'],
            nroCasa: mapa['fk_cliente']['nro_casa'],
            tipoOperacion: TipoOperacion.fromMap(mapa['fk_cliente']['tipo_operacion']),
            estado: mapa['fk_cliente']['estado_cliente'],
            tipoDocumento: TipoDocumento.fromMap(mapa['fk_cliente']['tipo_documento']),
            barrio: Barrio.fromMap(mapa['fk_cliente']['barrios']),
          ),
          categoriaServicio: CategoriaServicio.fromMap(mapa['fk_categoria_servicio']),
        );
      }).toList();

      return inmuebles;
    } catch (e) {
      print('Error al leer inmuebles por categoría: $e');
      return [];
    }
  }

  // ==================== LEER INMUEBLES POR ESTADO ====================
  Future<List<Inmuebles>> leerInmueblesPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('inmuebles')
          .select('''
            *,
            fk_cliente(*,
              tipo_documento(*),
              barrios(*),
              tipo_operacion(*)
            ),
            fk_categoria_servicio(*)
          ''')
          .eq('estado', estado);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Inmuebles> inmuebles = registros.map((mapa) {
        return Inmuebles(
          id: mapa['id'],
          cod_inmueble: mapa['cod_inmueble'],
          estado: mapa['estado'],
          direccion: mapa['direccion'],
          cliente: Cliente(
            idCliente: mapa['fk_cliente']['id_cliente'],
            razonSocial: mapa['fk_cliente']['razon_social'],
            nombreFantasia: mapa['fk_cliente']['nombre_fantasia'],
            documento: mapa['fk_cliente']['documento'],
            telefono: mapa['fk_cliente']['telefono'],
            celular: mapa['fk_cliente']['celular'],
            direccion: mapa['fk_cliente']['direccion'],
            es_proveedor_del_estado: mapa['fk_cliente']['es_proveedor_del_estado'],
            email: mapa['fk_cliente']['email'],
            nroCasa: mapa['fk_cliente']['nro_casa'],
            tipoOperacion: TipoOperacion.fromMap(mapa['fk_cliente']['tipo_operacion']),
            estado: mapa['fk_cliente']['estado_cliente'],
            tipoDocumento: TipoDocumento.fromMap(mapa['fk_cliente']['tipo_documento']),
            barrio: Barrio.fromMap(mapa['fk_cliente']['barrios']),
          ),
          categoriaServicio: CategoriaServicio.fromMap(mapa['fk_categoria_servicio']),
        );
      }).toList();

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