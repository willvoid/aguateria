import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/medidor.dart';
import 'package:myapp/modelo/tipo_operacion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MedidorCrudImpl {
  
  // ==================== CREAR MEDIDOR ====================
  Future<Medidor?> crearMedidor(Medidor medidor) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('medidores')
          .insert({
            'nro': medidor.nro,
            'fecha_instalacion': medidor.fechaInstalacion.toIso8601String(),
            'estado': medidor.estado,
            'fk_inmueble': medidor.inmueble.id,
          })
          .select('''
            *,
            fk_inmueble(*)
          ''')
          .single();

      print('Medidor creado exitosamente');
      return Medidor.fromMap(data);
    } catch (e) {
      print('Error al crear medidor: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS MEDIDORES ====================
  Future<List<Medidor>> leerMedidores() async {
    try {
      final data = await supabase
          .from('medidores')
          .select('''
            *,
            fk_inmueble (
              *,
              fk_cliente (
                *, 
                tipo_documento(*),
                barrios(*),
                tipo_operacion(*)
              ),
              fk_categoria_servicio (*)
            )
          ''');

      if (data == null) return [];

      final List<dynamic> registros = data as List<dynamic>;

      return registros.map((mapa) {
        // 1. Extraemos los datos anidados para escribir menos código
        final datosInmueble = mapa['fk_inmueble'];
        
        // Protección extra: Si el medidor no tiene inmueble asignado (es null)
        if (datosInmueble == null) {
             throw Exception("Medidor ${mapa['nro']} tiene el inmueble nulo");
        }

        final datosCliente = datosInmueble['fk_cliente'];

        // 2. Construimos el Cliente con protección contra nulos (?? '')
        final clienteObj = Cliente(
          idCliente: datosCliente['id_cliente'],
          razonSocial: datosCliente['razon_social'] ?? '', // Si es null, pone ''
          nombreFantasia: datosCliente['nombre_fantasia'] ?? '', 
          documento: datosCliente['documento'] ?? '',
          telefono: datosCliente['telefono'] ?? '',
          celular: datosCliente['celular'] ?? '',
          direccion: datosCliente['direccion'] ?? '',
          email: datosCliente['email'] ?? '',
          // Campos booleanos o numéricos
          es_proveedor_del_estado: datosCliente['es_proveedor_del_estado'] ?? false,
          nroCasa: datosCliente['nro_casa'] ?? '', 
          estado: datosCliente['estado_cliente'] ?? 'ACTIVO',
          // Objetos anidados del cliente
          tipoOperacion: TipoOperacion.fromMap(datosCliente['tipo_operacion']),
          tipoDocumento: TipoDocumento.fromMap(datosCliente['tipo_documento']),
          barrio: Barrio.fromMap(datosCliente['barrios']),
        );

        // 3. Construimos el Inmueble
        final inmuebleObj = Inmuebles(
          id: datosInmueble['id'],
          cod_inmueble: datosInmueble['cod_inmueble'] ?? '',
          estado: datosInmueble['estado'] ?? '',
          direccion: datosInmueble['direccion'] ?? '',
          cliente: clienteObj,
          categoriaServicio: CategoriaServicio.fromMap(datosInmueble['fk_categoria_servicio']),
        );

        // 4. Retornamos el Medidor
        return Medidor(
          idMedidor: mapa['id_medidor'],
          nro: mapa['nro'],
          // Manejo seguro de fecha
          fechaInstalacion: mapa['fecha_instalacion'] != null 
              ? DateTime.parse(mapa['fecha_instalacion']) 
              : DateTime.now(),
          estado: mapa['estado'] ?? 'ACTIVO',
          inmueble: inmuebleObj,
        );
      }).toList();

    } catch (e) {
      print('Error al leer medidores: $e');
      return [];
    }
  }

  // ==================== LEER UN MEDIDOR POR ID ====================
  Future<Medidor?> leerMedidorPorId(int idMedidor) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('medidores')
          .select('''
            *,
            fk_inmueble(*)
          ''')
          .eq('id_medidor', idMedidor)
          .single();

      return Medidor.fromMap(data);
    } catch (e) {
      print('Error al leer medidor por ID: $e');
      return null;
    }
  }

  // ==================== BUSCAR MEDIDORES ====================
  Future<List<Medidor>> buscarMedidores(String busqueda) async {
    try {
      final data = await supabase
          .from('medidores')
          .select('''
            *,
            fk_inmueble(*)
          ''')
          .or('nro.ilike.%$busqueda%,estado.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Medidor> medidores = registros.map((mapa) {
        return Medidor.fromMap(mapa);
      }).toList();

      return medidores;
    } catch (e) {
      print('Error al buscar medidores: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR MEDIDOR ====================
  Future<bool> actualizarMedidor(Medidor medidor) async {
    try {
      await supabase
          .from('medidores')
          .update({
            'nro': medidor.nro,
            'fecha_instalacion': medidor.fechaInstalacion.toIso8601String(),
            'estado': medidor.estado,
            'fk_inmueble': medidor.inmueble.id,
          })
          .eq('id_medidor', medidor.idMedidor!);

      print('Medidor actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar medidor: $e');
      return false;
    }
  }

  // ==================== ELIMINAR MEDIDOR ====================
  Future<bool> eliminarMedidor(int idMedidor) async {
    try {
      await supabase
          .from('medidores')
          .delete()
          .eq('id_medidor', idMedidor);

      print('Medidor eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar medidor: $e');
      return false;
    }
  }

  // ==================== LEER MEDIDORES POR INMUEBLE ====================
  Future<List<Medidor>> leerMedidoresPorInmueble(int idInmueble) async {
    try {
      final data = await supabase
          .from('medidores')
          .select('''
            *,
            fk_inmueble(*)
          ''')
          .eq('fk_inmueble', idInmueble);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Medidor> medidores = registros.map((mapa) {
        return Medidor.fromMap(mapa);
      }).toList();

      return medidores;
    } catch (e) {
      print('Error al leer medidores por inmueble: $e');
      return [];
    }
  }

  // ==================== LEER MEDIDORES POR ESTADO ====================
  Future<List<Medidor>> leerMedidoresPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('medidores')
          .select('''
            *,
            fk_inmueble(*)
          ''')
          .eq('estado', estado);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Medidor> medidores = registros.map((mapa) {
        return Medidor.fromMap(mapa);
      }).toList();

      return medidores;
    } catch (e) {
      print('Error al leer medidores por estado: $e');
      return [];
    }
  }

  // ==================== CAMBIAR ESTADO MEDIDOR ====================
  Future<bool> cambiarEstadoMedidor(int idMedidor, String nuevoEstado) async {
    try {
      await supabase
          .from('medidores')
          .update({'estado': nuevoEstado})
          .eq('id_medidor', idMedidor);

      print('Estado del medidor actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al cambiar estado del medidor: $e');
      return false;
    }
  }

  // ==================== VERIFICAR NÚMERO DE MEDIDOR EXISTENTE ====================
  Future<bool> verificarNumeroMedidorExistente(int nro, {int? idMedidorExcluir}) async {
    try {
      var query = supabase
          .from('medidores')
          .select('id_medidor')
          .eq('nro', nro);

      if (idMedidorExcluir != null) {
        query = query.neq('id_medidor', idMedidorExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar número de medidor: $e');
      return false;
    }
  }

  // ==================== LEER MEDIDORES POR FECHA DE INSTALACIÓN ====================
  Future<List<Medidor>> leerMedidoresPorFechaInstalacion(DateTime fechaInicio, DateTime fechaFin) async {
    try {
      final data = await supabase
          .from('medidores')
          .select('''
            *,
            fk_inmueble(*)
          ''')
          .gte('fecha_instalacion', fechaInicio.toIso8601String())
          .lte('fecha_instalacion', fechaFin.toIso8601String());

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Medidor> medidores = registros.map((mapa) {
        return Medidor.fromMap(mapa);
      }).toList();

      return medidores;
    } catch (e) {
      print('Error al leer medidores por fecha de instalación: $e');
      return [];
    }
  }
}