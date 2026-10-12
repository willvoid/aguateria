import 'package:flutter_test/flutter_test.dart';
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
}
