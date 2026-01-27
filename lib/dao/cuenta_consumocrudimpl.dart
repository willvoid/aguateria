import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/consumo.dart';
import 'package:myapp/modelo/cuenta_consumo.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/facturacionmodelo/iva.dart';
import 'package:myapp/modelo/facturacionmodelo/unidad_medida.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/medidor.dart';
import 'package:myapp/modelo/tipo_operacion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DeudaCrudImpl {
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

  // ==================== CREAR DEUDA ====================

  Future<bool> crearDeuda(CuentaConsumo deuda) async {
    try {
      await supabase.from('cuentas_consumo').insert({
        'fk_concepto': deuda.fk_concepto.id,
        'descripcion': deuda.descripcion,
        'monto': deuda.monto,
        'estado': deuda.estado,
        'fk_ciclos': deuda.fk_ciclos?.id,
        'fk_inmueble': deuda.fk_inmueble.id,
        'saldo': deuda.saldo,
        'pagado': deuda.pagado,
        'fk_consumos': deuda.fk_consumos?.id_consumos,
      });

      return true;
    } catch (e) {
      print('Error al crear deuda: $e');
      return false;
    }
  }

  // ==================== LEER TODAS LAS DEUDAS ====================

  Future<List<CuentaConsumo>> leerDeudas() async {
    try {
      final data = await supabase
          .from('cuentas_consumo')
          .select('''
        *,
        fk_concepto (
          *,
          fk_iva(*),
          fk_unidad_medida(*),
          fk_servicio(*)
        ),
        fk_ciclos(*),
        fk_inmueble (
          *,
          fk_cliente (
            *,
            tipo_documento(*),
            barrios(*),
            tipo_operacion(*)
          ),
          fk_categoria_servicio(*)
        ),
        fk_consumos (
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
        )
      ''')
          .order('id_deuda', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        return _construirDeuda(mapa);
      }).toList();
    } catch (e) {
      print('Error al leer deudas: $e');
      return [];
    }
  }

  // ==================== LEER DEUDA POR ID ====================

  Future<CuentaConsumo?> leerDeudaPorId(int idDeuda) async {
    try {
      final data = await supabase
          .from('cuentas_consumo')
          .select('''
            *,
            fk_concepto (
              *,
              fk_iva(*),
              fk_unidad_medida(*),
              fk_servicio(*)
            ),
            fk_ciclos(*),
            fk_inmueble (
              *,
              fk_cliente (
                *,
                tipo_documento(*),
                barrios(*),
                tipo_operacion(*)
              ),
              fk_categoria_servicio(*)
            ),
            fk_consumos (
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
            )
          ''')
          .eq('id_deuda', idDeuda)
          .single();

      return _construirDeuda(data);
    } catch (e) {
      print('Error al leer deuda por ID: $e');
      return null;
    }
  }

  // ==================== ACTUALIZAR DEUDA ====================

  Future<bool> actualizarDeuda(CuentaConsumo deuda) async {
    try {
      await supabase
          .from('cuentas_consumo')
          .update({
            'fk_concepto': deuda.fk_concepto.id,
            'descripcion': deuda.descripcion,
            'monto': deuda.monto,
            'estado': deuda.estado,
            'fk_ciclos': deuda.fk_ciclos?.id,
            'fk_inmueble': deuda.fk_inmueble.id,
            'saldo': deuda.saldo,
            'pagado': deuda.pagado,
            'fk_consumos': deuda.fk_consumos?.id_consumos,
          })
          .eq('id_deuda', deuda.id_deuda!);

      return true;
    } catch (e) {
      print('Error al actualizar deuda: $e');
      return false;
    }
  }

  // ==================== ELIMINAR DEUDA ====================

  Future<bool> eliminarDeuda(int idDeuda) async {
    try {
      await supabase.from('cuentas_consumo').delete().eq('id_deuda', idDeuda);
      return true;
    } catch (e) {
      print('Error al eliminar deuda: $e');
      return false;
    }
  }

  // ==================== LEER DEUDAS POR INMUEBLE ====================

  Future<List<CuentaConsumo>> leerDeudasPorInmueble(int idInmueble) async {
    try {
      final data = await supabase
          .from('cuentas_consumo')
          .select('''
            *,
            fk_concepto (
              *,
              fk_iva(*),
              fk_unidad_medida(*),
              fk_servicio(*)
            ),
            fk_ciclos(*),
            fk_inmueble (
              *,
              fk_cliente (
                *,
                tipo_documento(*),
                barrios(*),
                tipo_operacion(*)
              ),
              fk_categoria_servicio(*)
            ),
            fk_consumos (
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
            )
          ''')
          .eq('fk_inmueble', idInmueble)
          .order('id_deuda', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        return _construirDeuda(mapa);
      }).toList();
    } catch (e) {
      print('Error al leer deudas por inmueble: $e');
      return [];
    }
  }

  // ==================== LEER DEUDAS PENDIENTES POR INMUEBLE ====================

  Future<List<CuentaConsumo>> leerDeudasPendientesPorInmueble(
    int idInmueble,
  ) async {
    try {
      final data = await supabase
          .from('cuentas_consumo')
          .select('''
            *,
            fk_concepto (
              *,
              fk_iva(*),
              fk_unidad_medida(*),
              fk_servicio(*)
            ),
            fk_ciclos(*),
            fk_inmueble (
              *,
              fk_cliente (
                *,
                tipo_documento(*),
                barrios(*),
                tipo_operacion(*)
              ),
              fk_categoria_servicio(*)
            ),
            fk_consumos (
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
            )
          ''')
          .eq('fk_inmueble', idInmueble)
          .eq('estado', 'PENDIENTE')
          .order('id_deuda', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        return _construirDeuda(mapa);
      }).toList();
    } catch (e) {
      print('Error al leer deudas pendientes por inmueble: $e');
      return [];
    }
  }

  // ==================== LEER DEUDAS POR CICLO ====================

  Future<List<CuentaConsumo>> leerDeudasPorCiclo(int idCiclo) async {
    try {
      final data = await supabase
          .from('cuentas_consumo')
          .select('''
            *,
            fk_concepto (
              *,
              fk_iva(*),
              fk_unidad_medida(*),
              fk_servicio(*)
            ),
            fk_ciclos(*),
            fk_inmueble (
              *,
              fk_cliente (
                *,
                tipo_documento(*),
                barrios(*),
                tipo_operacion(*)
              ),
              fk_categoria_servicio(*)
            ),
            fk_consumos (
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
            )
          ''')
          .eq('fk_ciclos', idCiclo)
          .order('id_deuda', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        return _construirDeuda(mapa);
      }).toList();
    } catch (e) {
      print('Error al leer deudas por ciclo: $e');
      return [];
    }
  }

  // ==================== CALCULAR TOTAL DEUDAS POR INMUEBLE ====================

  Future<double> calcularTotalDeudasPorInmueble(int idInmueble) async {
    try {
      final deudas = await leerDeudasPendientesPorInmueble(idInmueble);
      return deudas.fold<double>(0.0, (total, deuda) => total + deuda.saldo);
    } catch (e) {
      print('Error al calcular total de deudas: $e');
      return 0.0;
    }
  }

  // ==================== REGISTRAR PAGO ====================

  Future<bool> registrarPago(int idDeuda, double montoPago) async {
    try {
      final deuda = await leerDeudaPorId(idDeuda);
      if (deuda == null) return false;

      final nuevoPagado = deuda.pagado + montoPago;
      final nuevoSaldo = deuda.monto - nuevoPagado;
      final nuevoEstado = nuevoSaldo <= 0 ? 'PAGADO' : 'PENDIENTE';

      await supabase
          .from('cuentas_consumo')
          .update({
            'pagado': nuevoPagado,
            'saldo': nuevoSaldo,
            'estado': nuevoEstado,
          })
          .eq('id_deuda', idDeuda);

      return true;
    } catch (e) {
      print('Error al registrar pago: $e');
      return false;
    }
  }

  // ==================== HELPER PARA CONSTRUIR DEUDA ====================

  CuentaConsumo _construirDeuda(Map<String, dynamic> mapa) {
    // Construir Concepto
    final datosConcepto = mapa['fk_concepto'];
    final concepto = Concepto(
      id: _toInt(datosConcepto['id_concepto']),
      nombre: datosConcepto['nombre'] ?? '',
      arancel: _toDouble(datosConcepto['arancel']),
      descripcion: datosConcepto['descripcion'] ?? '',
      fk_iva: Iva.fromMap(datosConcepto['fk_iva']),
      fk_unidad_medida: UnidadMedida.fromMap(datosConcepto['fk_unidad_medida']),
      estado: datosConcepto['estado'] ?? 'ACTIVO',
      fk_servicio: CategoriaServicio.fromMap(datosConcepto['fk_servicio']),
    );

    // Construir Ciclo (opcional)
    Ciclo? ciclo;
    final datosCiclo = mapa['fk_ciclos'];
    if (datosCiclo != null) {
      ciclo = Ciclo(
        id: _toInt(datosCiclo['id']),
        inicio: _toDate(datosCiclo['inicio']),
        fin: _toDate(datosCiclo['fin']),
        vencimiento: _toDate(datosCiclo['vencimiento']),
        anio: _toInt(datosCiclo['anio']),
        descripcion: datosCiclo['descripcion'] ?? '',
        ciclo: datosCiclo['ciclo'] ?? '',
        estado: datosCiclo['estado'] ?? 'ACTIVO',
      );
    }

    // Construir Inmueble
    final datosInmueble = mapa['fk_inmueble'];
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
      categoriaServicio: CategoriaServicio.fromMap(
        datosInmueble['fk_categoria_servicio'],
      ),
    );

    // Construir Consumo (opcional)
    Consumo? consumo;
    final datosConsumo = mapa['fk_consumos'];
    if (datosConsumo != null) {
      final datosMedidor = datosConsumo['fk_medidores'];
      final datosInmuebleMedidor = datosMedidor['fk_inmueble'];
      final datosClienteMedidor = datosInmuebleMedidor['fk_cliente'];

      final clienteMedidor = Cliente(
        idCliente: _toInt(datosClienteMedidor['id_cliente']),
        razonSocial: datosClienteMedidor['razon_social'] ?? '',
        nombreFantasia: datosClienteMedidor['nombre_fantasia'] ?? '',
        documento: datosClienteMedidor['documento'] ?? '',
        telefono: datosClienteMedidor['telefono'] ?? '',
        celular: datosClienteMedidor['celular'] ?? '',
        direccion: datosClienteMedidor['direccion'] ?? '',
        email: datosClienteMedidor['email'] ?? '',
        es_proveedor_del_estado:
            datosClienteMedidor['es_proveedor_del_estado'] ?? false,
        nroCasa: datosClienteMedidor['nro_casa'] ?? '',
        estado: datosClienteMedidor['estado_cliente'] ?? 'ACTIVO',
        tipoOperacion: TipoOperacion.fromMap(
          datosClienteMedidor['tipo_operacion'],
        ),
        tipoDocumento: TipoDocumento.fromMap(
          datosClienteMedidor['tipo_documento'],
        ),
        barrio: Barrio.fromMap(datosClienteMedidor['barrios']),
      );

      final inmuebleMedidor = Inmuebles(
        id: _toInt(datosInmuebleMedidor['id']),
        cod_inmueble: datosInmuebleMedidor['cod_inmueble'] ?? '',
        estado: datosInmuebleMedidor['estado'] ?? '',
        direccion: datosInmuebleMedidor['direccion'] ?? '',
        cliente: clienteMedidor,
        categoriaServicio: CategoriaServicio.fromMap(
          datosInmuebleMedidor['fk_categoria_servicio'],
        ),
      );

      final medidor = Medidor(
        idMedidor: _toInt(datosMedidor['id_medidor']),
        nro: datosMedidor['nro']?.toString() ?? '',
        fechaInstalacion: _toDate(datosMedidor['fecha_instalacion']),
        estado: datosMedidor['estado'] ?? 'ACTIVO',
        inmueble: inmuebleMedidor,
      );

      consumo = Consumo(
        id_consumos: _toInt(datosConsumo['id_consumos']),
        lectura_anterior: _toDouble(datosConsumo['lectura_anterior']),
        lectura_actual: _toDouble(datosConsumo['lectura_actual']),
        consumo_m3: _toDouble(datosConsumo['consumo_m3']),
        fk_medidores: medidor,
        fk_ciclo: Ciclo.fromMap(datosConsumo['fk_ciclo']),
        estado: datosConsumo['estado'] ?? 'PENDIENTE',
      );
    }

    return CuentaConsumo(
      id_deuda: _toInt(mapa['id_deuda']),
      fk_concepto: concepto,
      descripcion: mapa['descripcion'] ?? '',
      monto: _toDouble(mapa['monto']),
      estado: mapa['estado'] ?? 'PENDIENTE',
      fk_ciclos: ciclo,
      fk_inmueble: inmueble,
      saldo: _toDouble(mapa['saldo']),
      pagado: _toDouble(mapa['pagado']),
      fk_consumos: consumo,
    );
  }
}
