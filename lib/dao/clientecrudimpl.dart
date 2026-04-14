import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/tipo_operacion.dart';
import 'package:myapp/modelo/empresa/tipo_contribuyente.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ClienteCrudImpl {
  
  // ==================== CREAR CLIENTE ====================
  Future<Cliente?> crearCliente(Cliente cliente) async {
    try {
      final Map<String, dynamic> insertData = {
        'razon_social': cliente.razonSocial,
        'nombre_fantasia': cliente.nombreFantasia,
        'documento': cliente.documento,
        'telefono': cliente.telefono,
        'celular': cliente.celular,
        'direccion': cliente.direccion,
        'es_proveedor_del_estado': cliente.es_proveedor_del_estado,
        'email': cliente.email,
        'nro_casa': cliente.nroCasa,
        'fk_tipo_operacion': cliente.tipoOperacion.id_tipo_operacion,
        'estado_cliente': cliente.estado,
        'fk_tipo_documento': cliente.tipoDocumento?.cod_tipo_documento,
        'fk_barrios': cliente.barrio.cod_barrio,
      };

      // Solo agregar tipo_contribuyente si no es null
      if (cliente.tipo_contribuyente != null) {
        insertData['tipo_contribuyente'] = cliente.tipo_contribuyente!.id_tipo_contribuyente;
      }

      final Map<String, dynamic> data = await supabase
          .from('clientes')
          .insert(insertData)
          .select('''
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*),
            tipo_contribuyente(*)
          ''')
          .single();

      print('Cliente creado exitosamente');
      return Cliente.fromMap(data);
    } catch (e) {
      print('Error al crear cliente: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS CLIENTES ====================
  Future<List<Cliente>> leerClientes() async {
    try {
      final data = await supabase
          .from('clientes')
          .select('''
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*),
            tipo_contribuyente(*)
          ''');

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay clientes en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Cliente> clientes = registros.map((mapa) {
       try {
    return Cliente(
      idCliente: mapa['id_cliente'],
      razonSocial: mapa['razon_social'] ?? '',
      nombreFantasia: mapa['nombre_fantasia'],
      documento: mapa['documento'] ?? '',
      telefono: mapa['telefono'],
      celular: mapa['celular'] ?? '',
      direccion: mapa['direccion'],
      es_proveedor_del_estado: mapa['es_proveedor_del_estado'] ?? false,
      email: mapa['email'],
      nroCasa: mapa['nro_casa'] ?? 0,
      tipoOperacion: mapa['tipo_operacion'] != null
          ? TipoOperacion.fromMap(mapa['tipo_operacion'])
          : TipoOperacion.vacio(),
      estado: mapa['estado_cliente'] ?? '',
      tipoDocumento: mapa['tipo_documento'] != null
          ? TipoDocumento.fromMap(mapa['tipo_documento'])
          : null,
      barrio: mapa['barrios'] != null
          ? Barrio.fromMap(mapa['barrios'])
          : Barrio.vacio(),
      tipo_contribuyente: mapa['tipo_contribuyente'] != null
          ? TipoContribuyente.fromMap(mapa['tipo_contribuyente'])
          : null,
    );
  } catch (e) {
    print('❌ Error en cliente id=${mapa['id_cliente']}: $e');
    print('   tipo_operacion: ${mapa['tipo_operacion']}');
    print('   barrios: ${mapa['barrios']}');
    print('   tipo_documento: ${mapa['tipo_documento']}');
    rethrow;
  }
      }).toList();

      print('✓ Se cargaron ${clientes.length} clientes');
      return clientes;
    } catch (e) {
      print('Error al leer clientes: $e');
      return [];
    }
  }

  // ==================== LEER UN CLIENTE POR ID ====================
  Future<Cliente?> leerClientePorId(int idCliente) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('clientes')
          .select('''
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*),
            tipo_contribuyente(*)
          ''')
          .eq('id_cliente', idCliente)
          .single();

      return Cliente(
        idCliente: data['id_cliente'],
        razonSocial: data['razon_social'],
        nombreFantasia: data['nombre_fantasia'],
        documento: data['documento'],
        telefono: data['telefono'],
        celular: data['celular'],
        direccion: data['direccion'],
        es_proveedor_del_estado: data['es_proveedor_del_estado'],
        email: data['email'],
        nroCasa: data['nro_casa'],
        tipoOperacion: TipoOperacion.fromMap(data['tipo_operacion']),
        estado: data['estado_cliente'],
        tipoDocumento: TipoDocumento.fromMap(data['tipo_documento']),
        barrio: Barrio.fromMap(data['barrios']),
        tipo_contribuyente: data['tipo_contribuyente'] != null
            ? TipoContribuyente.fromMap(data['tipo_contribuyente'])
            : null,
      );
    } catch (e) {
      print('Error al leer cliente por ID: $e');
      return null;
    }
  }

  // ==================== BUSCAR CLIENTES ====================
  Future<List<Cliente>> buscarClientes(String busqueda) async {
    try {
      final data = await supabase
          .from('clientes')
          .select('''
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*),
            tipo_contribuyente(*)
          ''')
          .or('razon_social.ilike.%$busqueda%,documento.ilike.%$busqueda%,celular.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Cliente> clientes = registros.map((mapa) {
        return Cliente(
          idCliente: mapa['id_cliente'],
          razonSocial: mapa['razon_social'],
          nombreFantasia: mapa['nombre_fantasia'],
          documento: mapa['documento'],
          telefono: mapa['telefono'],
          celular: mapa['celular'],
          direccion: mapa['direccion'],
          es_proveedor_del_estado: mapa['es_proveedor_del_estado'],
          email: mapa['email'],
          nroCasa: mapa['nro_casa'],
          tipoOperacion: TipoOperacion.fromMap(mapa['tipo_operacion']),
          estado: mapa['estado_cliente'],
          tipoDocumento: TipoDocumento.fromMap(mapa['tipo_documento']),
          barrio: Barrio.fromMap(mapa['barrios']),
          tipo_contribuyente: mapa['tipo_contribuyente'] != null
              ? TipoContribuyente.fromMap(mapa['tipo_contribuyente'])
              : null,
        );
      }).toList();

      return clientes;
    } catch (e) {
      print('Error al buscar clientes: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR CLIENTE ====================
  Future<bool> actualizarCliente(Cliente cliente) async {
    try {
      final Map<String, dynamic> updateData = {
        'razon_social': cliente.razonSocial,
        'nombre_fantasia': cliente.nombreFantasia,
        'documento': cliente.documento,
        'telefono': cliente.telefono,
        'celular': cliente.celular,
        'direccion': cliente.direccion,
        'es_proveedor_del_estado': cliente.es_proveedor_del_estado,
        'email': cliente.email,
        'nro_casa': cliente.nroCasa,
        'fk_tipo_operacion': cliente.tipoOperacion.id_tipo_operacion,
        'estado_cliente': cliente.estado,
        'fk_tipo_documento': cliente.tipoDocumento?.cod_tipo_documento,
        'fk_barrios': cliente.barrio.cod_barrio,
      };

      // Solo agregar tipo_contribuyente si no es null
      if (cliente.tipo_contribuyente != null) {
        updateData['tipo_contribuyente'] = cliente.tipo_contribuyente!.id_tipo_contribuyente;
      }

      await supabase
          .from('clientes')
          .update(updateData)
          .eq('id_cliente', cliente.idCliente!);

      print('Cliente actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar cliente: $e');
      return false;
    }
  }

  // ==================== ELIMINAR CLIENTE ====================
  Future<bool> eliminarCliente(int idCliente) async {
    try {
      await supabase
          .from('clientes')
          .delete()
          .eq('id_cliente', idCliente);

      print('Cliente eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar cliente: $e');
      return false;
    }
  }

  // ==================== LEER CLIENTES POR BARRIO ====================
  Future<List<Cliente>> leerClientesPorBarrio(int idBarrio) async {
    try {
      final data = await supabase
          .from('clientes')
          .select('''
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*),
            tipo_contribuyente(*)
          ''')
          .eq('fk_barrios', idBarrio);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Cliente> clientes = registros.map((mapa) {
        return Cliente(
          idCliente: mapa['id_cliente'],
          razonSocial: mapa['razon_social'],
          nombreFantasia: mapa['nombre_fantasia'],
          documento: mapa['documento'],
          telefono: mapa['telefono'],
          celular: mapa['celular'],
          direccion: mapa['direccion'],
          es_proveedor_del_estado: mapa['es_proveedor_del_estado'],
          email: mapa['email'],
          nroCasa: mapa['nro_casa'],
          tipoOperacion: TipoOperacion.fromMap(mapa['tipo_operacion']),
          estado: mapa['estado_cliente'],
          tipoDocumento: TipoDocumento.fromMap(mapa['tipo_documento']),
          barrio: Barrio.fromMap(mapa['barrios']),
          tipo_contribuyente: mapa['tipo_contribuyente'] != null
              ? TipoContribuyente.fromMap(mapa['tipo_contribuyente'])
              : null,
        );
      }).toList();

      return clientes;
    } catch (e) {
      print('Error al leer clientes por barrio: $e');
      return [];
    }
  }

  // ==================== LEER CLIENTES POR ESTADO ====================
  Future<List<Cliente>> leerClientesPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('clientes')
          .select('''
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*),
            tipo_contribuyente(*)
          ''')
          .eq('estado_cliente', estado);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Cliente> clientes = registros.map((mapa) {
        return Cliente(
          idCliente: mapa['id_cliente'],
          razonSocial: mapa['razon_social'],
          nombreFantasia: mapa['nombre_fantasia'],
          documento: mapa['documento'],
          telefono: mapa['telefono'],
          celular: mapa['celular'],
          direccion: mapa['direccion'],
          es_proveedor_del_estado: mapa['es_proveedor_del_estado'],
          email: mapa['email'],
          nroCasa: mapa['nro_casa'],
          tipoOperacion: TipoOperacion.fromMap(mapa['tipo_operacion']),
          estado: mapa['estado_cliente'],
          tipoDocumento: TipoDocumento.fromMap(mapa['tipo_documento']),
          barrio: Barrio.fromMap(mapa['barrios']),
          tipo_contribuyente: mapa['tipo_contribuyente'] != null
              ? TipoContribuyente.fromMap(mapa['tipo_contribuyente'])
              : null,
        );
      }).toList();

      return clientes;
    } catch (e) {
      print('Error al leer clientes por estado: $e');
      return [];
    }
  }

  // ==================== CAMBIAR ESTADO CLIENTE ====================
  Future<bool> cambiarEstadoCliente(int idCliente, String nuevoEstado) async {
    try {
      await supabase
          .from('clientes')
          .update({'estado_cliente': nuevoEstado})
          .eq('id_cliente', idCliente);

      print('Estado del cliente actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al cambiar estado del cliente: $e');
      return false;
    }
  }

  // ==================== VERIFICAR DOCUMENTO EXISTENTE ====================
  Future<bool> verificarDocumentoExistente(String documento, {int? idClienteExcluir}) async {
    try {
      var query = supabase
          .from('clientes')
          .select('id_cliente')
          .eq('documento', documento);

      if (idClienteExcluir != null) {
        query = query.neq('id_cliente', idClienteExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar documento: $e');
      return false;
    }
  }

  // ==================== BUSCAR CLIENTE POR DOCUMENTO EXACTO ====================
Future<Cliente?> buscarClientePorDocumento(String documento) async {
  try {
    final data = await supabase
        .from('clientes')
        .select('''
          *,
          tipo_documento(*),
          barrios(*),
          tipo_operacion(*),
          tipo_contribuyente(*)
        ''')
        .eq('documento', documento)
        .maybeSingle();

    if (data == null) return null;

    return Cliente(
      idCliente: data['id_cliente'],
      razonSocial: data['razon_social'],
      nombreFantasia: data['nombre_fantasia'],
      documento: data['documento'],
      telefono: data['telefono'],
      celular: data['celular'],
      direccion: data['direccion'],
      es_proveedor_del_estado: data['es_proveedor_del_estado'],
      email: data['email'],
      nroCasa: data['nro_casa'],
      tipoOperacion: TipoOperacion.fromMap(data['tipo_operacion']),
      estado: data['estado_cliente'],
      tipoDocumento: TipoDocumento.fromMap(data['tipo_documento']),
      barrio: Barrio.fromMap(data['barrios']),
      tipo_contribuyente: data['tipo_contribuyente'] != null
          ? TipoContribuyente.fromMap(data['tipo_contribuyente'])
          : null,
    );
  } catch (e) {
    print('Error al buscar cliente por documento: $e');
    return null;
  }
}

  Future<bool> actualizarEmailCliente(int idCliente, String email) async {
    try {
      await supabase
          .from('clientes')
          .update({'email': email})
          .eq('id_cliente', idCliente);
      return true;
    } catch (e) {
      print('Error al actualizar email: $e');
      return false;
    }
  }

}