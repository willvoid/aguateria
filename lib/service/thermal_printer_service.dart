import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:myapp/service/ticket_printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Impresora Bluetooth guardada por el usuario.
class ImpresoraGuardada {
  final String nombre;
  final String direccion;

  /// Caracteres por línea: 32 para papel de 58 mm, 48 para 80 mm.
  final int columnas;

  const ImpresoraGuardada({
    required this.nombre,
    required this.direccion,
    this.columnas = 32,
  });
}

/// Funciones puras de formato de texto para papel térmico (testeables sin dispositivo).
class TicketTextFormatter {
  static const _acentos = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
    '°': 'o', 'º': 'o', 'ª': 'a',
  };

  /// Reemplaza acentos y descarta cualquier caracter fuera de ASCII imprimible.
  static String ascii(String texto) {
    final sb = StringBuffer();
    for (final rune in texto.runes) {
      final ch = String.fromCharCode(rune);
      final mapped = _acentos[ch] ?? ch;
      final code = mapped.codeUnitAt(0);
      if (mapped.length == 1 && code >= 32 && code < 127) sb.write(mapped);
    }
    return sb.toString();
  }

  /// Parte [texto] en líneas de a lo sumo [columnas] caracteres, cortando por palabras.
  static List<String> envolver(String texto, int columnas) {
    final limpio = ascii(texto).trim();
    if (limpio.isEmpty) return [];
    final lineas = <String>[];
    var actual = '';
    for (final palabra in limpio.split(RegExp(r'\s+'))) {
      var p = palabra;
      while (p.length > columnas) {
        if (actual.isNotEmpty) {
          lineas.add(actual);
          actual = '';
        }
        lineas.add(p.substring(0, columnas));
        p = p.substring(columnas);
      }
      if (actual.isEmpty) {
        actual = p;
      } else if (actual.length + 1 + p.length <= columnas) {
        actual = '$actual $p';
      } else {
        lineas.add(actual);
        actual = p;
      }
    }
    if (actual.isNotEmpty) lineas.add(actual);
    return lineas;
  }

  /// Texto a la izquierda y valor a la derecha en una línea de [columnas].
  static String izquierdaDerecha(String izq, String der, int columnas) {
    final i = ascii(izq);
    final d = ascii(der);
    final espacio = columnas - i.length - d.length;
    if (espacio >= 1) return '$i${' ' * espacio}$d';
    final maxIzq = columnas - d.length - 1;
    if (maxIzq < 1) return d.length > columnas ? d.substring(0, columnas) : d;
    return '${i.substring(0, maxIzq)} $d';
  }

  static String separador(int columnas, [String ch = '-']) => ch * columnas;
}

class ThermalPrinterService {
  static const _kNombre = 'impresora_nombre';
  static const _kDireccion = 'impresora_direccion';
  static const _kColumnas = 'impresora_columnas';

  /// La impresión Bluetooth directa solo aplica en Android.
  static bool get disponible =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static BlueThermalPrinter get _bt => BlueThermalPrinter.instance;

  static Future<ImpresoraGuardada?> impresoraGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final direccion = prefs.getString(_kDireccion);
    if (direccion == null || direccion.isEmpty) return null;
    return ImpresoraGuardada(
      nombre: prefs.getString(_kNombre) ?? direccion,
      direccion: direccion,
      columnas: prefs.getInt(_kColumnas) ?? 32,
    );
  }

  static Future<void> guardarImpresora(ImpresoraGuardada impresora) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNombre, impresora.nombre);
    await prefs.setString(_kDireccion, impresora.direccion);
    await prefs.setInt(_kColumnas, impresora.columnas);
  }

  static Future<void> olvidarImpresora() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNombre);
    await prefs.remove(_kDireccion);
    await prefs.remove(_kColumnas);
    try {
      await _bt.disconnect();
    } catch (_) {}
  }

  /// Dispositivos ya emparejados en los ajustes Bluetooth del sistema.
  static Future<List<BluetoothDevice>> listarEmparejadas() => _bt.getBondedDevices();

  static Future<void> _conectar(ImpresoraGuardada impresora) async {
    if (await _bt.isConnected == true) return;
    final emparejadas = await _bt.getBondedDevices();
    final device = emparejadas.where((d) => d.address == impresora.direccion).firstOrNull;
    if (device == null) {
      throw Exception(
        'La impresora "${impresora.nombre}" no está emparejada. Empareje el dispositivo en los ajustes Bluetooth.',
      );
    }
    await _bt.connect(device);
  }

  /// Imprime una página de prueba corta.
  static Future<void> imprimirPrueba(ImpresoraGuardada impresora) async {
    await _conectar(impresora);
    await _enviar(impresora, () async {
      await _bt.printCustom('PRUEBA DE IMPRESION', 1, 1);
      await _bt.printCustom(
        TicketTextFormatter.separador(impresora.columnas),
        0,
        0,
      );
      await _bt.printCustom('Impresora: ${TicketTextFormatter.ascii(impresora.nombre)}', 0, 0);
      await _bt.printCustom('Columnas: ${impresora.columnas}', 0, 0);
      await _bt.printNewLine();
      await _bt.printNewLine();
      await _bt.printNewLine();
    });
  }

  static Future<void> imprimir(TicketData t, ImpresoraGuardada impresora) async {
    final cols = impresora.columnas;
    final moneda = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);
    final f = TicketTextFormatter.izquierdaDerecha;

    Future<void> centrado(String texto, {int size = 0}) async {
      for (final linea in TicketTextFormatter.envolver(texto, cols)) {
        await _bt.printCustom(linea, size, 1);
      }
    }

    Future<void> izq(String texto) async {
      for (final linea in TicketTextFormatter.envolver(texto, cols)) {
        await _bt.printCustom(linea, 0, 0);
      }
    }

    Future<void> par(String a, String b) => _bt.printCustom(f(a, b, cols), 0, 0);
    Future<void> sep() => _bt.printCustom(TicketTextFormatter.separador(cols), 0, 0);

    await _conectar(impresora);
    await _enviar(impresora, () async {
      await centrado(t.razonSocial, size: 1);
      if (t.telefono.isNotEmpty) await centrado('TELEFONO: ${t.telefono}');
      if (t.direccionCompleta.isNotEmpty) await centrado('DIRECCION: ${t.direccionCompleta}');
      if (t.ciudad.isNotEmpty) await centrado('LOCALIDAD ${t.ciudad}');
      await centrado('RUC: ${t.rucEmisor}');
      await centrado('IVA INCLUIDO');
      await centrado('Timbrado: ${t.timbrado}');
      if (t.timbradoFechaFmt.isNotEmpty) {
        await centrado('Inicio de vigencia: ${t.timbradoFechaFmt}');
      }
      await centrado('FACTURA ELECTRONICA', size: 1);
      await centrado(t.numeroFactura, size: 1);
      await centrado('Fecha: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(t.fecha)}');
      await _bt.printNewLine();

      await izq('RUC/C.I.: ${t.rucCliente}');
      await izq('Cliente: ${t.nombreCliente}');
      await sep();

      for (final item in t.items) {
        final cant = ((item['cantidad'] ?? 0) as num).toDouble();
        final precio = ((item['precioUnitario'] ?? 0) as num).toDouble();
        await izq((item['descripcion'] ?? 'Item').toString());
        await par(
          '${cant.toStringAsFixed(0)} x ${moneda.format(precio)}',
          moneda.format(cant * precio),
        );
      }
      await sep();

      await _bt.printCustom(f('TOTAL Gs:', moneda.format(t.totalAbono), cols), 1, 0);
      await sep();

      await centrado('Liquidacion del IVA');
      await par('Total Exentas:', moneda.format(t.totalExenta));
      await par('Total Gravadas 5%:', moneda.format(t.totalIva5));
      await par('Total Gravadas 10%:', moneda.format(t.totalIva10));
      await par('Total IVA 5%:', moneda.format(t.montoIva5));
      await par('Total IVA 10%:', moneda.format(t.montoIva10));
      await par('Total Gral. IVA:', moneda.format(t.importeTotalIva));
      await sep();

      await centrado('Ticket sin valor fiscal.', size: 1);
      await _bt.printNewLine();
      await _bt.printNewLine();
      await _bt.printNewLine();
    });
  }

  /// Ejecuta [trabajo]; si la conexión estaba caída reconecta una vez y reintenta.
  static Future<void> _enviar(
    ImpresoraGuardada impresora,
    Future<void> Function() trabajo,
  ) async {
    try {
      await trabajo();
    } catch (_) {
      try {
        await _bt.disconnect();
      } catch (_) {}
      await _conectar(impresora);
      await trabajo();
    }
  }
}
