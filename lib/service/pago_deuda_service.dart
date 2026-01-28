import 'package:myapp/dao/configuracion_sistema_crudimpl.dart';
import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/facturacionmodelo/facturacion_payload.dart';
import 'package:myapp/service/factura_rpc_service.dart';
import 'package:myapp/dao/facturaciondao/apertura_cierre_cajacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/facturacrudimpl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';

final supabase = Supabase.instance.client;

class PagoDeudaService {
  final FacturaRpcService _facturaRpcService = FacturaRpcService();
  final ConfiguracionSistemaCrudImpl _configCrud =
      ConfiguracionSistemaCrudImpl();
  final AperturaCierreCajaCrudImpl _aperturaCrud = AperturaCierreCajaCrudImpl();
  final FacturaCrudImpl _facturaCrud = FacturaCrudImpl();

  /// Carga los ciclos disponibles para deudas de consumo
  /// Retorna los ciclos que NO han sido facturados aún para este inmueble
  Future<List<Ciclo>> cargarCiclosDisponiblesConsumo(int idInmueble) async {
    try {
      // Obtener todos los ciclos activos
      final ciclosResponse = await supabase
          .from('ciclos')
          .select('*')
          .eq('estado', 'ACTIVO')
          .order('inicio', ascending: true);

      if (ciclosResponse.isEmpty) return [];

      final List<Ciclo> ciclos = ciclosResponse
          .map((c) => Ciclo.fromMap(c))
          .toList();

      // Obtener ciclos que ya tienen deuda pagada o facturada para este inmueble
      final detallesResponse = await supabase
          .from('detalle_factura')
          .select('''
            fk_ciclo,
            factura:fk_factura!inner(fk_inmueble)
          ''')
          .eq('factura.fk_inmueble', idInmueble)
          .eq('fk_concepto', 1) // Solo consumo
          .not('fk_ciclo', 'is', null);

      final Set<int> ciclosPagados = detallesResponse
          .map((d) => d['fk_ciclo'] as int)
          .toSet();

      // Filtrar ciclos que NO están pagados
      return ciclos.where((c) => !ciclosPagados.contains(c.id)).toList();
    } catch (e) {
      print('Error al cargar ciclos disponibles: $e');
      return [];
    }
  }

  /// Calcula los totales basados en el monto y tasa de IVA
  Map<String, double> calcularTotales(double montoTotal, int tasaIva) {
    double totalGravado10 = 0.0;
    double totalGravado5 = 0.0;
    double totalExenta = 0.0;
    double totalIva = 0.0;

    if (tasaIva == 10) {
      // Fórmula Paraguay: IVA = montoTotal × (tasa/100) / (1 + tasa/100)
      final iva = montoTotal * (10 / 100) / (1 + 10 / 100);
      final base = montoTotal - iva;

      totalGravado10 = base;
      totalIva = iva;
    } else if (tasaIva == 5) {
      final iva = montoTotal * (5 / 100) / (1 + 5 / 100);
      final base = montoTotal - iva;

      totalGravado5 = base;
      totalIva = iva;
    } else {
      // Exenta (0% IVA)
      totalExenta = montoTotal;
    }

    return {
      'totalGravado10': double.parse(totalGravado10.toStringAsFixed(2)),
      'totalGravado5': double.parse(totalGravado5.toStringAsFixed(2)),
      'totalExenta': double.parse(totalExenta.toStringAsFixed(2)),
      'totalIva': double.parse(totalIva.toStringAsFixed(2)),
      'totalGeneral': double.parse(montoTotal.toStringAsFixed(2)),
    };
  }

  /// Procesa el pago de una deuda
  Future<Map<String, dynamic>> procesarPagoDeuda({
    required CuentaCobrar deuda,
    required Cliente cliente,
    required Inmuebles inmueble,
    required List<Ciclo> ciclosSeleccionados, // Para consumo: ciclos a pagar
    required double efectivo,
    required int idUsuario,
    int? idModoPago, // NUEVO: ID del modo de pago seleccionado (opcional)
  }) async {
    try {
      // 1. Cargar configuración del sistema
      final config = await _configCrud.leerConfiguracionActual();

      if (config == null) {
        throw Exception('No se encontró configuración del sistema');
      }

      // 2. Verificar caja abierta
      final cajaAbierta = await _aperturaCrud.verificarCajaAbiertaUsuario(
        idUsuario,
      );

      if (!cajaAbierta) {
        throw Exception('Debe abrir una caja antes de procesar pagos');
      }

      // 3. Obtener apertura activa
      final aperturas = await _aperturaCrud.leerAperturasPorUsuario(idUsuario);
      final cajaActiva = aperturas.firstWhere(
        (a) => a.cierre == null,
        orElse: () => throw Exception('No hay caja abierta'),
      );

      // 4. Construir detalles según tipo de deuda
      final esConsumo = deuda.fk_concepto.id == 1;
      List<DetallePayload> detalles;
      double montoTotal = 0.0;

      if (esConsumo && ciclosSeleccionados.isNotEmpty) {
        // CONSUMO: Un detalle por cada ciclo seleccionado
        // El monto viene del CONCEPTO (arancel), no del ciclo
        final montoPorCiclo = deuda.fk_concepto.arancel;

        detalles = ciclosSeleccionados.map((ciclo) {
          montoTotal += montoPorCiclo;
          return DetallePayload(
            fkConcepto: deuda.fk_concepto.id!,
            monto: montoPorCiclo, // Monto del concepto (arancel)
            descripcion: 'Consumo ${ciclo.descripcion ?? ciclo.ciclo}',
            ivaAplicado: deuda.fk_concepto.fk_iva.valor,
            subtotal: montoPorCiclo,
            estado: 'ACTIVO',
            cantidad: 1.0,
            fkCiclo: ciclo.id,
            fkDeudas: deuda.id_deuda,
            fkConsumos:
                null, // Ajustar según tu lógica si tienes consumo asociado
          );
        }).toList();
      } else {
        // CONEXIÓN u OTRO: Un solo detalle con el saldo total de la deuda
        montoTotal = deuda.saldo;
        detalles = [
          DetallePayload(
            fkConcepto: deuda.fk_concepto.id!,
            monto: deuda.saldo,
            descripcion: deuda.descripcion,
            ivaAplicado: deuda.fk_concepto.fk_iva.valor,
            subtotal: deuda.saldo,
            estado: 'ACTIVO',
            cantidad: 1.0,
            fkCiclo: deuda.fk_ciclos?.id,
            fkDeudas: deuda.id_deuda,
            fkConsumos: deuda.fk_consumos?.id_consumos,
          ),
        ];
      }

      // 5. Calcular totales
      final totales = calcularTotales(
        montoTotal,
        deuda.fk_concepto.fk_iva.valor,
      );

      // 6. Obtener número secuencial
      final nroSecuencial = await _facturaCrud.obtenerProximoSecuencial(
        config.establecimiento_default.id_establecimiento!,
        config.tipo_factura_default.id_tipo_factura!,
      );

      // 7. Calcular vuelto
      final vuelto = efectivo - totales['totalGeneral']!;

      // 8. NUEVO: Determinar el modo de pago a usar
      // Si se proporcionó idModoPago, usarlo; si no, usar el default de config
      final modoPagoAUsar = idModoPago ?? config.modo_pago_default.id_modo_pago!;

      // 9. Construir payload
      final payload = FacturaPayload(
        fechaEmision: DateTime.now().toUtc().toIso8601String(),
        fkCliente: cliente.idCliente!,
        fkInmueble: inmueble.id!,
        condicionVenta: config.condicion_venta_default,
        totalGravado10: totales['totalGravado10']!,
        totalGravado5: totales['totalGravado5']!,
        totalExenta: totales['totalExenta']!,
        totalIva: totales['totalIva']!,
        totalGeneral: totales['totalGeneral']!,
        observacion: esConsumo
            ? 'Pago de consumo - ${ciclosSeleccionados.length} ciclo(s)'
            : 'Pago de ${deuda.fk_concepto.nombre}',
        fkMonedas: config.moneda_default.id_monedas!,
        fkEstablecimientos: config.establecimiento_default.id_establecimiento!,
        fkModoPago: modoPagoAUsar, // MODIFICADO: Usar el modo de pago seleccionado
        fkTipoFactura: config.tipo_factura_default.id_tipo_factura!,
        nroSecuencial: nroSecuencial,
        fkTurno: cajaActiva.id_turno!,
        tipoEmision: 1,
        fkMotivo: null,
        fkFacturaAsociada: null,
        efectivo: efectivo,
        vuelto: vuelto,
        descuentoGlobal: 0.0,
        detalles: detalles,
      );

      // 10. Llamar a la RPC
      final facturaCreada = await _facturaRpcService.guardarFacturaRpc(payload);

      return facturaCreada;
    } catch (e) {
      print('❌ Error al procesar pago de deuda: $e');
      rethrow;
    }
  }

  /// Valida que se pueda procesar el pago
  String? validarPago({
    required CuentaCobrar deuda,
    required List<Ciclo> ciclosSeleccionados,
    required double efectivo,
  }) {
    final esConsumo = deuda.fk_concepto.id == 1;

    if (esConsumo && ciclosSeleccionados.isEmpty) {
      return 'Debe seleccionar al menos un ciclo para pagar';
    }

    double montoTotal = 0.0;

    if (esConsumo) {
      // El monto viene del arancel del concepto, multiplicado por cantidad de ciclos
      final montoPorCiclo = deuda.fk_concepto.arancel;
      montoTotal = montoPorCiclo * ciclosSeleccionados.length;
    } else {
      // Para no-consumo, usar el saldo de la deuda
      montoTotal = deuda.saldo;
    }

    if (efectivo < montoTotal) {
      return 'El efectivo debe ser mayor o igual al total a pagar';
    }

    if (efectivo <= 0) {
      return 'El efectivo debe ser mayor a 0';
    }

    return null; // Sin errores
  }

  /// Obtiene el historial de pagos de una deuda
  Future<List<Map<String, dynamic>>> obtenerHistorialPagos(int idDeuda) async {
    try {
      final response = await supabase
          .from('detalle_factura')
          .select('''
            *,
            factura:fk_factura(
              id_factura,
              fecha_emision,
              total_general,
              nro_secuencial
            )
          ''')
          .eq('fk_deudas', idDeuda)
          .order('id_detalle', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener historial de pagos: $e');
      return [];
    }
  }
}