import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/consumo.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/medidor.dart';
import 'package:myapp/modelo/tipo_operacion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ConsumoCrudImpl {

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // ==================== CREAR CONSUMO ====================

  Future<bool> crearConsumo(Consumo consumo) async {
    try {
      await supabase.from('consumos').insert({
        'lectura_anterior': consumo.lectura_anterior,
        'lectura_actual': consumo.lectura_actual,
        'consumo_m3': consumo.consumo_m3,
        'fk_medidores': consumo.fk_medidores.idMedidor,
        'fk_ciclo': consumo.fk_ciclo.id,
        'estado': consumo.estado,
      });

      return true;
    } catch (e) {
      print('Error al crear consumo: $e');
      return false;
    }
  }

  // ==================== LEER TODOS LOS CONSUMOS ====================

  Future<List<Consumo>> leerConsumos() async {
    try {
      final data = await supabase.from('consumos').select('''
        *,
        fk_medidores (
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
        ),
        fk_ciclo(*)
      ''').order('id_consumos', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        final datosMedidor = mapa['fk_medidores'];
        final datosCiclo = mapa['fk_ciclo'];

        if (datosMedidor == null || datosCiclo == null) {
          throw Exception('Consumo con relaciones incompletas');
        }

        // Construir Medidor con todas sus relaciones
        final datosInmueble = datosMedidor['fk_inmueble'];
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
          categoriaServicio: CategoriaServicio.fromMap(datosInmueble['fk_categoria_servicio']),
        );

        final medidor = Medidor(
          idMedidor: _toInt(datosMedidor['id_medidor']),
          nro: datosMedidor['nro']?.toString() ?? '',
          fechaInstalacion: _toDate(datosMedidor['fecha_instalacion']),
          estado: datosMedidor['estado'] ?? 'ACTIVO',
          inmueble: inmueble,
        );

        // Construir Ciclo
        final ciclo = Ciclo(
          id: _toInt(datosCiclo['id']),
          inicio: _toDate(datosCiclo['inicio']),
          fin: _toDate(datosCiclo['fin']),
          vencimiento: _toDate(datosCiclo['vencimiento']),
          anio: _toInt(datosCiclo['anio']),
          descripcion: datosCiclo['descripcion'] ?? '',
          ciclo: datosCiclo['ciclo'] ?? '',
          estado: datosCiclo['estado'] ?? 'ACTIVO',
        );

        return Consumo(
          id_consumos: _toInt(mapa['id_consumos']),
          lectura_anterior: _toDouble(mapa['lectura_anterior']),
          lectura_actual: _toDouble(mapa['lectura_actual']),
          consumo_m3: _toDouble(mapa['consumo_m3']),
          fk_medidores: medidor,
          fk_ciclo: ciclo,
          estado: mapa['estado'] ?? 'PENDIENTE',
        );
      }).toList();

    } catch (e) {
      print('Error al leer consumos: $e');
      return [];
    }
  }

  // ==================== LEER CONSUMO POR ID ====================

  Future<Consumo?> leerConsumoPorId(int idConsumo) async {
    try {
      final data = await supabase
          .from('consumos')
          .select('''
            *,
            fk_medidores (
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
            ),
            fk_ciclo(*)
          ''')
          .eq('id_consumos', idConsumo)
          .single();

      return Consumo.fromMap(data);
    } catch (e) {
      print('Error al leer consumo por ID: $e');
      return null;
    }
  }

  // ==================== ACTUALIZAR CONSUMO ====================

  Future<bool> actualizarConsumo(Consumo consumo) async {
    try {
      await supabase.from('consumos').update({
        'lectura_anterior': consumo.lectura_anterior,
        'lectura_actual': consumo.lectura_actual,
        'consumo_m3': consumo.consumo_m3,
        'fk_medidores': consumo.fk_medidores.idMedidor,
        'fk_ciclo': consumo.fk_ciclo.id,
        'estado': consumo.estado,
      }).eq('id_consumos', consumo.id_consumos!);

      return true;
    } catch (e) {
      print('Error al actualizar consumo: $e');
      return false;
    }
  }

  // ==================== ELIMINAR CONSUMO ====================

  Future<bool> eliminarConsumo(int idConsumo) async {
    try {
      await supabase.from('consumos').delete().eq('id_consumos', idConsumo);
      return true;
    } catch (e) {
      print('Error al eliminar consumo: $e');
      return false;
    }
  }

  // ==================== VERIFICAR CONSUMO EXISTENTE ====================

  Future<bool> verificarConsumoExistente(int idMedidor, int idCiclo, {int? idExcluir}) async {
    try {
      var query = supabase
          .from('consumos')
          .select('id_consumos')
          .eq('fk_medidores', idMedidor)
          .eq('fk_ciclo', idCiclo);

      if (idExcluir != null) {
        query = query.neq('id_consumos', idExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar consumo existente: $e');
      return false;
    }
  }

  // ==================== LEER CONSUMOS POR MEDIDOR ====================

  Future<List<Consumo>> leerConsumosPorMedidor(int idMedidor) async {
    try {
      final data = await supabase
          .from('consumos')
          .select('''
            *,
            fk_medidores (
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
            ),
            fk_ciclo(*)
          ''')
          .eq('fk_medidores', idMedidor)
          .order('id_consumos', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        return Consumo.fromMap(mapa);
      }).toList();

    } catch (e) {
      print('Error al leer consumos por medidor: $e');
      return [];
    }
  }

  // ==================== LEER CONSUMOS POR CICLO ====================

  Future<List<Consumo>> leerConsumosPorCiclo(int idCiclo) async {
    try {
      final data = await supabase
          .from('consumos')
          .select('''
            *,
            fk_medidores (
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
            ),
            fk_ciclo(*)
          ''')
          .eq('fk_ciclo', idCiclo)
          .order('id_consumos', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        return Consumo.fromMap(mapa);
      }).toList();

    } catch (e) {
      print('Error al leer consumos por ciclo: $e');
      return [];
    }
  }

  // ==================== LEER ÚLTIMA LECTURA DE UN MEDIDOR ====================

  Future<double?> leerUltimaLectura(int idMedidor) async {
    try {
      final data = await supabase
          .from('consumos')
          .select('lectura_actual')
          .eq('fk_medidores', idMedidor)
          .order('id_consumos', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;

      return _toDouble(data['lectura_actual']);
    } catch (e) {
      print('Error al leer última lectura: $e');
      return null;
    }
  }

  // ==================== CALCULAR CONSUMO ====================

  double calcularConsumo(double lecturaAnterior, double lecturaActual) {
    return lecturaActual - lecturaAnterior;
  }
}