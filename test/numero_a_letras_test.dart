import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/util/numero_a_letras.dart';

void main() {
  group('numeroALetras', () {
    final casos = <int, String>{
      0: 'CERO',
      1: 'UNO',
      10: 'DIEZ',
      15: 'QUINCE',
      16: 'DIECISEIS',
      20: 'VEINTE',
      21: 'VEINTIUNO',
      29: 'VEINTINUEVE',
      30: 'TREINTA',
      31: 'TREINTA Y UNO',
      99: 'NOVENTA Y NUEVE',
      100: 'CIEN',
      101: 'CIENTO UNO',
      500: 'QUINIENTOS',
      999: 'NOVECIENTOS NOVENTA Y NUEVE',
      1000: 'MIL',
      1001: 'MIL UNO',
      2000: 'DOS MIL',
      21000: 'VEINTIUN MIL',
      31000: 'TREINTA Y UN MIL',
      25000: 'VEINTICINCO MIL',
      101000: 'CIENTO UN MIL',
      100000: 'CIEN MIL',
      999999: 'NOVECIENTOS NOVENTA Y NUEVE MIL NOVECIENTOS NOVENTA Y NUEVE',
      1000000: 'UN MILLON',
      2000000: 'DOS MILLONES',
      21000000: 'VEINTIUN MILLONES',
      1000001: 'UN MILLON UNO',
      1500000: 'UN MILLON QUINIENTOS MIL',
      1000000000: 'MIL MILLONES',
      1001000000: 'MIL UN MILLONES',
      999999999999:
          'NOVECIENTOS NOVENTA Y NUEVE MIL NOVECIENTOS NOVENTA Y NUEVE '
              'MILLONES NOVECIENTOS NOVENTA Y NUEVE MIL NOVECIENTOS NOVENTA Y NUEVE',
    };
    casos.forEach((n, esperado) {
      test('$n -> $esperado', () => expect(numeroALetras(n), esperado));
    });

    test('negativos llevan MENOS', () {
      expect(numeroALetras(-1500), 'MENOS MIL QUINIENTOS');
    });
  });

  group('guaraniesALetras', () {
    test('arma la frase del total', () {
      expect(guaraniesALetras(25000), 'SON GUARANIES VEINTICINCO MIL');
    });

    test('redondea los decimales al guarani', () {
      expect(guaraniesALetras(1000.4), 'SON GUARANIES MIL');
      expect(guaraniesALetras(999.6), 'SON GUARANIES MIL');
    });

    test('cero', () {
      expect(guaraniesALetras(0), 'SON GUARANIES CERO');
    });
  });
}
