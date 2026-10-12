import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/dao/configuracion_sistema_crudimpl.dart';
import 'package:myapp/dao/facturaciondao/apertura_cierre_cajacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/facturacrudimpl.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/configuracion_sistema.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/facturacionmodelo/apertura_cierre_caja.dart';
import 'package:myapp/modelo/facturacionmodelo/facturacion_payload.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';
import 'package:myapp/service/factura_rpc_service.dart';
import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/facturacionmodelo/iva.dart';
import 'package:myapp/modelo/facturacionmodelo/unidad_medida.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/service/pago_deuda_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Concepto _concepto({int id = 2, bool permiteCuotas = true}) => Concepto(
      id: id,
      nombre: 'Conexion',
      arancel: 0,
      descripcion: 'Conexion',
      fk_iva: Iva.vacio(),
      fk_unidad_medida: UnidadMedida.vacio(),
      estado: 'ACTIVO',
      fk_servicio: CategoriaServicio.vacio(),
      permiteCuotas: permiteCuotas,
    );

CuentaCobrar _deuda({double saldo = 500000, Concepto? concepto}) =>
    CuentaCobrar(
      fk_concepto: concepto ?? _concepto(),
      descripcion: 'Conexion',
      monto: saldo,
      estado: 'PENDIENTE',
      fk_ciclos: null,
      fk_inmueble: Inmuebles(
        id: 1,
        cod_inmueble: 'I-1',
        estado: 'ACTIVO',
        direccion: 'Calle 1',
        categoriaServicio: CategoriaServicio.vacio(),
      ),
      saldo: saldo,
      pagado: 0,
      fk_consumos: null,
    );

// ── Fakes: only the members PagoDeudaService reads are implemented ──────────

class _FakeEstablecimiento extends Fake implements Establecimiento {
  @override
  int? get id_establecimiento => 1;
}

class _FakeMoneda extends Fake implements Moneda {
  @override
  int? get id_monedas => 1;
}

class _FakeModoPago extends Fake implements ModoPago {
  @override
  int? get id_modo_pago => 1;
}

class _FakeTipoFactura extends Fake implements TipoFactura {
  @override
  int? get id_tipo_factura => 1;
}

class _FakeConfig extends Fake implements ConfiguracionSistema {
  @override
  Establecimiento get establecimiento_default => _FakeEstablecimiento();
  @override
  Moneda get moneda_default => _FakeMoneda();
  @override
  ModoPago get modo_pago_default => _FakeModoPago();
  @override
  TipoFactura get tipo_factura_default => _FakeTipoFactura();
  @override
  int get condicion_venta_default => 1;
}

class _FakeTurno extends Fake implements AperturaCierreCaja {
  @override
  int? get id_turno => 7;
  @override
  DateTime? get cierre => null;
}

class _FakeCliente extends Fake implements Cliente {
  @override
  int? get idCliente => 3;
}

class _FakeConfigCrud extends Fake implements ConfiguracionSistemaCrudImpl {
  @override
  Future<ConfiguracionSistema?> leerConfiguracionActual() async =>
      _FakeConfig();
}

class _FakeCajaCrud extends Fake implements AperturaCierreCajaCrudImpl {
  @override
  Future<bool> verificarCajaAbiertaUsuario(int idUsuario) async => true;
  @override
  Future<List<AperturaCierreCaja>> leerAperturasPorUsuario(
    int idUsuario,
  ) async =>
      [_FakeTurno()];
}

class _FakeFacturaCrud extends Fake implements FacturaCrudImpl {
  @override
  Future<int> obtenerProximoSecuencial(
    int idEstablecimiento,
    int idTipoFactura,
  ) async =>
      1;
}

class _CapturingRpc extends Fake implements FacturaRpcService {
  FacturaPayload? payload;
  @override
  Future<Map<String, dynamic>> guardarFacturaRpc(FacturaPayload p) async {
    payload = p;
    return {};
  }
}

void main() {
  late PagoDeudaService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'http://localhost', anonKey: 'test');
    service = PagoDeudaService();
  });

  group('Concepto.permiteCuotas', () {
    test('defaults to false', () {
      expect(_concepto(permiteCuotas: false).permiteCuotas, isFalse);
    });

    test('toMap includes the flag', () {
      expect(_concepto().toMap()['permite_cuotas'], isTrue);
    });

    test('fromMap reads the flag and treats a missing column as false', () {
      final base = _concepto().toMap();

      expect(Concepto.fromMap(base).permiteCuotas, isTrue);

      base.remove('permite_cuotas');
      expect(Concepto.fromMap(base).permiteCuotas, isFalse);
    });
  });

  group('PagoDeudaService.validarPago with montoAPagar', () {
    String? validar(double? monto, {double efectivo = 1000}) =>
        service.validarPago(
          deuda: _deuda(),
          ciclosSeleccionados: const [],
          efectivo: efectivo,
          montoAPagar: monto,
        );

    test('accepts a partial payment below the saldo', () {
      expect(validar(50000), isNull);
    });

    test('accepts a payment equal to the saldo', () {
      expect(validar(500000), isNull);
    });

    test('rejects a payment above the saldo', () {
      expect(validar(500001), isNotNull);
    });

    test('rejects zero and negative payments', () {
      expect(validar(0), isNotNull);
      expect(validar(-1), isNotNull);
    });

    test('without montoAPagar keeps the previous behaviour', () {
      expect(validar(null), isNull);
      expect(validar(null, efectivo: 0), isNotNull);
    });
  });

  group('PagoDeudaService.procesarPagoDeuda with montoAPagar', () {
    late _CapturingRpc rpc;
    late PagoDeudaService svc;

    setUp(() {
      rpc = _CapturingRpc();
      svc = PagoDeudaService(
        facturaRpcService: rpc,
        configCrud: _FakeConfigCrud(),
        aperturaCrud: _FakeCajaCrud(),
        facturaCrud: _FakeFacturaCrud(),
      );
    });

    Future<void> pagar(CuentaCobrar deuda, {double? monto}) =>
        svc.procesarPagoDeuda(
          deuda: deuda,
          cliente: _FakeCliente(),
          inmueble: deuda.fk_inmueble,
          ciclosSeleccionados: const [],
          efectivo: monto ?? deuda.saldo,
          idUsuario: 1,
          montoAPagar: monto,
        );

    test('invoices only the partial amount, not the full saldo', () async {
      await pagar(_deuda(), monto: 50000);

      final p = rpc.payload!;
      expect(p.totalGeneral, 50000);
      expect(p.detalles, hasLength(1));
      expect(p.detalles.first.monto, 50000);
      expect(p.detalles.first.subtotal, 50000);
      expect(p.detalles.first.fkDeudas, _deuda().id_deuda);
      expect(p.vuelto, 0);
    });

    test('invoices the full saldo when no montoAPagar is given', () async {
      await pagar(_deuda());

      expect(rpc.payload!.totalGeneral, 500000);
      expect(rpc.payload!.detalles.first.monto, 500000);
    });

    test('throws and sends nothing for zero or above-saldo amounts', () async {
      await expectLater(pagar(_deuda(), monto: 0), throwsException);
      await expectLater(pagar(_deuda(), monto: 500001), throwsException);
      expect(rpc.payload, isNull);
    });
  });
}
