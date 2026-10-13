import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/reportes/data/models/reporte_model.dart';

void main() {
  group('ReporteMensual.fromJson', () {
    test('lee conexion y deuda_anterior', () {
      final r = ReporteMensual.fromJson({
        'id_inmueble': 'A-1',
        'estado_conexion': 'conectado',
        'deuda_total': 150000,
        'conexion': 100000,
        'deuda_anterior': 50000.5,
        'enero': 25000,
      });

      expect(r.conexion, 100000);
      expect(r.deudaAnterior, 50000.5);
      expect(r.deudaTotal, 150000);
      expect(r.meses[0], 25000);
      expect(r.estadoConexion, 'CONECTADO');
    });

    test('conexion y deuda_anterior valen 0 si faltan o son null', () {
      final r = ReporteMensual.fromJson({
        'id_inmueble': 'A-2',
        'conexion': null,
      });

      expect(r.conexion, 0);
      expect(r.deudaAnterior, 0);
      expect(r.meses.length, 12);
    });
  });
}
