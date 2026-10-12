import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/service/ticket_printer_service.dart';

TicketData _data({double efectivo = 0, double vuelto = 0}) => TicketData(
      razonSocial: 'Aguateria',
      telefono: '',
      direccionCompleta: '',
      ciudad: '',
      rucEmisor: '',
      timbrado: '',
      timbradoFechaFmt: '',
      numeroFactura: '',
      fecha: DateTime(2026, 10, 12),
      rucCliente: '',
      nombreCliente: 'Cliente',
      items: const [],
      totalAbono: 0,
      totalExenta: 0,
      totalIva5: 0,
      totalIva10: 0,
      montoIva5: 0,
      montoIva10: 0,
      importeTotalIva: 0,
      efectivo: efectivo,
      vuelto: vuelto,
    );

void main() {
  group('esTipoTicket', () {
    test('matches "Ticket" ignoring case and spaces', () {
      expect(TicketPrinterService.esTipoTicket('Ticket'), isTrue);
      expect(TicketPrinterService.esTipoTicket('  ticket '), isTrue);
    });

    test('rejects other document types and null', () {
      expect(TicketPrinterService.esTipoTicket('Factura electrónica'), isFalse);
      expect(TicketPrinterService.esTipoTicket('Nota de crédito'), isFalse);
      expect(TicketPrinterService.esTipoTicket(null), isFalse);
    });
  });

  test('formatearNumero pads establishment, type and sequence', () {
    expect(TicketPrinterService.formatearNumero(1, 7, 25), '001-007-0000025');
  });

  group('mostrarEfectivo', () {
    test('is false for transfers (efectivo 0)', () {
      expect(_data().mostrarEfectivo, isFalse);
    });

    test('is true when cash was received', () {
      expect(_data(efectivo: 100000, vuelto: 25000).mostrarEfectivo, isTrue);
    });
  });
}
