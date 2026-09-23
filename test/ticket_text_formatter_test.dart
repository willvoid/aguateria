import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/service/thermal_printer_service.dart';

void main() {
  test('ascii strips accents and non-ASCII', () {
    expect(TicketTextFormatter.ascii('Facturación Ñandú €'), 'Facturacion Nandu ');
  });

  test('envolver wraps by words and never exceeds columns', () {
    final lines = TicketTextFormatter.envolver('Consumo de agua mes de enero 2026', 16);
    expect(lines.every((l) => l.length <= 16), isTrue);
    expect(lines.join(' '), 'Consumo de agua mes de enero 2026');
  });

  test('envolver splits words longer than a line', () {
    expect(TicketTextFormatter.envolver('ABCDEFGHIJ', 4), ['ABCD', 'EFGH', 'IJ']);
  });

  test('izquierdaDerecha fills to exactly the column width', () {
    final l = TicketTextFormatter.izquierdaDerecha('TOTAL', '50.000', 32);
    expect(l.length, 32);
    expect(l.startsWith('TOTAL'), isTrue);
    expect(l.endsWith('50.000'), isTrue);
  });

  test('izquierdaDerecha truncates left side when too long', () {
    final l = TicketTextFormatter.izquierdaDerecha('X' * 40, '1.000', 32);
    expect(l.length, 32);
    expect(l.endsWith(' 1.000'), isTrue);
  });
}
