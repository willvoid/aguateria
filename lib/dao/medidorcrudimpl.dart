
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

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // ==================== CREAR MEDIDOR ====================

  Future<bool> crearMedidor(Medidor medidor) async {
  try {
    await supabase.from('medidores').insert({
      'nro': medidor.nro,
      'fecha_instalacion': medidor.fechaInstalacion.toIso8601String(),
      'estado': medidor.estado,
      'fk_inmueble': medidor.inmueble.id,
    });

    return true;
  } catch (e) {
    print('Error al crear medidor: $e');
    return false;
  }
}


  // ==================== LEER TODOS LOS MEDIDORES ====================

  Future<List<Medidor>> leerMedidores() async {
    try {
      final data = await supabase.from('medidores').select('''
        *,
        fk_inmueble (
          *,
          fk_cliente (
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*)
          ),
          fk_categoria_servicio(*)
        )
      ''');

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        final datosInmueble = mapa['fk_inmueble'];
        if (datosInmueble == null) {
          throw Exception('Medidor sin inmueble asignado');
        }

        final datosCliente = datosInmueble['fk_cliente'];

        final cliente = Cliente(
          idCliente: _toInt(datosCliente['id_cliente']),
          razonSocial: datosCliente['razon_social'] ?? '',
          nombreFantasia: datosCliente['nombre_fantasia'] ?? '',
          documento: datosCliente['documento'] ?? '',
          telefono: datosCliente['telefono'] ?? '',
          celular: datosCliente['celular'] ?? '',
          direccion: datosCliente['direccion'] ?? '',
          email: datosCliente['email'] ?? '',
          es_proveedor_del_estado: datosCliente['es_proveedor_del_estado'] ?? false,
          nroCasa: datosCliente['nro_casa'] ?? '',
          estado: datosCliente['estado_cliente'] ?? 'ACTIVO',
          tipoOperacion: TipoOperacion.fromMap(datosCliente['tipo_operacion']),
          tipoDocumento: TipoDocumento.fromMap(datosCliente['tipo_documento']),
          barrio: Barrio.fromMap(datosCliente['barrios']),
        );

        final inmueble = Inmuebles(
          id: _toInt(datosInmueble['id']),
          cod_inmueble: datosInmueble['cod_inmueble'] ?? '',
          estado: datosInmueble['estado'] ?? '',
          direccion: datosInmueble['direccion'] ?? '',
          cliente: cliente,
          categoriaServicio:
              CategoriaServicio.fromMap(datosInmueble['fk_categoria_servicio']),
        );

        return Medidor(
          idMedidor: _toInt(mapa['id_medidor']),
          nro:  mapa['nro']?.toString() ?? '',
          fechaInstalacion: _toDate(mapa['fecha_instalacion']),
          estado: mapa['estado'] ?? 'ACTIVO',
          inmueble: inmueble,
        );
      }).toList();

    } catch (e) {
      print('Error al leer medidores: $e');
      return [];
    }
  }

  // ==================== LEER MEDIDOR POR ID ====================

  Future<Medidor?> leerMedidorPorId(int idMedidor) async {
    try {
      final data = await supabase
          .from('medidores')
          .select('*, fk_inmueble(*)')
          .eq('id_medidor', idMedidor)
          .single();

      return Medidor.fromMap(data);
    } catch (e) {
      print('Error al leer medidor por ID: $e');
      return null;
    }
  }

  // ==================== ACTUALIZAR MEDIDOR ====================

  Future<bool> actualizarMedidor(Medidor medidor) async {
    try {
      await supabase.from('medidores').update({
        'nro': medidor.nro,
        'fecha_instalacion': medidor.fechaInstalacion.toIso8601String(),
        'estado': medidor.estado,
        'fk_inmueble': medidor.inmueble.id,
      }).eq('id_medidor', medidor.idMedidor!);

      return true;
    } catch (e) {
      print('Error al actualizar medidor: $e');
      return false;
    }
  }

  // ==================== ELIMINAR MEDIDOR ====================

  Future<bool> eliminarMedidor(int idMedidor) async {
    try {
      await supabase.from('medidores').delete().eq('id_medidor', idMedidor);
      return true;
    } catch (e) {
      print('Error al eliminar medidor: $e');
      return false;
    }
  }

  // ==================== VERIFICAR NÚMERO DE MEDIDOR ====================

  Future<bool> verificarNumeroMedidorExistente(String nro, {int? idExcluir}) async {
    try {
      var query = supabase.from('medidores').select('id_medidor').eq('nro', nro);

      if (idExcluir != null) {
        query = query.neq('id_medidor', idExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar número de medidor: $e');
      return false;
    }
  }
}
