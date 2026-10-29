/// Conversión de importes enteros a letras (español, mayúsculas, sin acentos
/// para que sirva tal cual en papel térmico ESC/POS).
const int _maximo = 999999999999;

const _unidades = [
  '', 'UNO', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE',
];
const _especiales = [
  'DIEZ', 'ONCE', 'DOCE', 'TRECE', 'CATORCE', 'QUINCE',
  'DIECISEIS', 'DIECISIETE', 'DIECIOCHO', 'DIECINUEVE',
];
const _decenas = [
  '', '', 'VEINTE', 'TREINTA', 'CUARENTA', 'CINCUENTA',
  'SESENTA', 'SETENTA', 'OCHENTA', 'NOVENTA',
];
const _centenas = [
  '', 'CIENTO', 'DOSCIENTOS', 'TRESCIENTOS', 'CUATROCIENTOS', 'QUINIENTOS',
  'SEISCIENTOS', 'SETECIENTOS', 'OCHOCIENTOS', 'NOVECIENTOS',
];

/// 1..999. Con [apocope] el final "UNO" pasa a "UN" (UN MIL, UN MILLON).
String _menorMil(int n, {required bool apocope}) {
  if (n == 100) return 'CIEN';
  final partes = <String>[];
  final c = n ~/ 100;
  final r = n % 100;
  if (c > 0) partes.add(_centenas[c]);
  if (r >= 10 && r < 20) {
    partes.add(_especiales[r - 10]);
  } else if (r >= 20 && r < 30) {
    final u = r % 10;
    partes.add(u == 0 ? 'VEINTE' : 'VEINTI${_unidad(u, apocope)}');
  } else if (r >= 30) {
    final d = r ~/ 10;
    final u = r % 10;
    partes.add(u == 0 ? _decenas[d] : '${_decenas[d]} Y ${_unidad(u, apocope)}');
  } else if (r > 0) {
    partes.add(_unidad(r, apocope));
  }
  return partes.join(' ');
}

String _unidad(int u, bool apocope) => (apocope && u == 1) ? 'UN' : _unidades[u];

/// 1..999.999.
String _miles(int n, {required bool apocope}) {
  final miles = n ~/ 1000;
  final resto = n % 1000;
  final partes = <String>[];
  if (miles == 1) {
    partes.add('MIL');
  } else if (miles > 1) {
    partes.add('${_menorMil(miles, apocope: true)} MIL');
  }
  if (resto > 0) partes.add(_menorMil(resto, apocope: apocope));
  return partes.join(' ');
}

/// Escribe [n] en letras. Admite hasta 999.999.999.999 (en valor absoluto).
String numeroALetras(int n) {
  if (n.abs() > _maximo) {
    throw RangeError.range(n, -_maximo, _maximo, 'n');
  }
  if (n == 0) return 'CERO';
  if (n < 0) return 'MENOS ${numeroALetras(-n)}';
  final millones = n ~/ 1000000;
  final resto = n % 1000000;
  final partes = <String>[];
  if (millones == 1) {
    partes.add('UN MILLON');
  } else if (millones > 1) {
    partes.add('${_miles(millones, apocope: true)} MILLONES');
  }
  if (resto > 0) partes.add(_miles(resto, apocope: false));
  return partes.join(' ');
}

/// Frase del total en guaraníes ("SON GUARANIES VEINTICINCO MIL"). Redondea al
/// guaraní; devuelve cadena vacía si el importe excede lo representable, para
/// que quien imprime simplemente omita la línea.
String guaraniesALetras(num importe) {
  final entero = importe.round();
  if (entero.abs() > _maximo) return '';
  return 'SON GUARANIES ${numeroALetras(entero)}';
}
