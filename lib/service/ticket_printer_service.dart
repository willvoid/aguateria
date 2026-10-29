import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:myapp/dao/facturaciondao/tipo_facturacrudimpl.dart';
import 'package:myapp/service/thermal_printer_service.dart';
import 'package:myapp/util/numero_a_letras.dart';

/// Datos ya procesados de un ticket, independientes del medio de impresión.
class TicketData {
  final String razonSocial;
  final String telefono;
  final String direccionCompleta;
  final String ciudad;
  final String rucEmisor;
  final String timbrado;
  final String timbradoFechaFmt;
  final String numeroFactura;
  final DateTime fecha;
  final String rucCliente;
  final String nombreCliente;
  final List items;
  final double totalAbono;
  final double totalExenta;
  final double totalIva5;
  final double totalIva10;
  final double montoIva5;
  final double montoIva10;
  final double importeTotalIva;
  final double efectivo;
  final double vuelto;

  /// Ticket de uso interno: sin RUC, timbrado ni IVA, para que no pase por factura.
  final bool esInterno;
  final String numeroTicket;

  /// Condición de venta ("Contado" / "Credito"); vacío si la RPC no la trae.
  final String condicionVenta;

  /// Código ISO de la moneda del documento (PYG por defecto).
  final String moneda;

  /// Descripciones de las actividades económicas del emisor.
  final List<String> actividadesEconomicas;

  /// Correo del emisor; vacío si la RPC no lo trae.
  final String emailEmisor;

  /// Fin de vigencia del timbrado ya formateado (dd/MM/yyyy); vacío si no viene.
  final String timbradoFechaFinFmt;

  const TicketData({
    required this.razonSocial,
    required this.telefono,
    required this.direccionCompleta,
    required this.ciudad,
    required this.rucEmisor,
    required this.timbrado,
    required this.timbradoFechaFmt,
    required this.numeroFactura,
    required this.fecha,
    required this.rucCliente,
    required this.nombreCliente,
    required this.items,
    required this.totalAbono,
    required this.totalExenta,
    required this.totalIva5,
    required this.totalIva10,
    required this.montoIva5,
    required this.montoIva10,
    required this.importeTotalIva,
    this.efectivo = 0,
    this.vuelto = 0,
    this.esInterno = false,
    this.numeroTicket = '',
    this.condicionVenta = '',
    this.moneda = 'PYG',
    this.actividadesEconomicas = const [],
    this.emailEmisor = '',
    this.timbradoFechaFinFmt = '',
  });

  /// Solo se muestran efectivo y vuelto cuando hubo cobro en efectivo.
  bool get mostrarEfectivo => efectivo > 0;

  bool get esGuaranies => moneda.trim().isEmpty || moneda.trim().toUpperCase() == 'PYG';

  /// Nombre de la moneda para imprimir. [acentos] false para papel térmico (ASCII).
  String monedaTexto({bool acentos = false}) {
    if (esGuaranies) return acentos ? 'Guaraníes' : 'Guaranies';
    return moneda.trim().toUpperCase();
  }

  /// "SON GUARANIES ..."; vacío si la moneda no es PYG o el importe no se puede escribir.
  String get totalEnLetras => esGuaranies ? guaraniesALetras(totalAbono) : '';

  /// "IVA 10%", "IVA 5%" o "Exenta" según la tasa del ítem; vacío si el ítem no la trae.
  static String textoIvaItem(dynamic item) {
    if (item is! Map) return '';
    final raw = item['iva'];
    final tasa = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    if (tasa == null) return '';
    return tasa == 0 ? 'Exenta' : 'IVA $tasa%';
  }
}

class TicketPrinterService {
  /// El tipo de factura "Ticket" es el documento de uso interno.
  static bool esTipoTicket(String? descripcion) =>
      (descripcion ?? '').trim().toLowerCase() == 'ticket';

  /// Número tal como se muestra en pantalla: establecimiento-tipo-secuencial.
  static String formatearNumero(int establecimiento, int tipo, int secuencial) =>
      '${establecimiento.toString().padLeft(3, '0')}-'
      '${tipo.toString().padLeft(3, '0')}-'
      '${secuencial.toString().padLeft(7, '0')}';

  /// Imprime directo por Bluetooth si hay una impresora térmica configurada
  /// (Android); en caso contrario abre el diálogo de impresión con un PDF.
  static Future<void> imprimirTicket(int idFactura) async {
    final ticket = await obtenerTicket(idFactura);
    if (ThermalPrinterService.disponible) {
      final impresora = await ThermalPrinterService.impresoraGuardada();
      if (impresora != null) {
        await ThermalPrinterService.imprimir(ticket, impresora);
        return;
      }
    }
    await _imprimirPdf(ticket);
  }

  /// Imprime o muestra el KuDE de una factura ya enviada a FacturaSend.
  /// Si hay una impresora Bluetooth configurada (solo Android), imprime
  /// directo por ahí con el ancho ya guardado (58/80mm) — no pregunta nada.
  /// Si no, cae al PDF (`mostrarKude`), donde sí hace falta elegir el ancho
  /// porque no hay ninguna config previa de la que inferirlo.
  static Future<void> imprimirKude(
    int idFactura, {
    required String cdc,
    required String qrUrl,
    required bool draft,
    bool papel58mmSiNoHayImpresora = false,
  }) async {
    final ticket = await obtenerTicket(idFactura);
    if (ThermalPrinterService.disponible) {
      final impresora = await ThermalPrinterService.impresoraGuardada();
      if (impresora != null) {
        await ThermalPrinterService.imprimir(
          ticket,
          impresora,
          cdc: cdc,
          qrUrl: qrUrl,
          draft: draft,
        );
        return;
      }
    }
    await mostrarKude(
      ticket,
      cdc: cdc,
      qrUrl: qrUrl,
      draft: draft,
      papel58mm: papel58mmSiNoHayImpresora,
    );
  }

  /// Texto no vacío o null. Convierte cualquier valor de la RPC a String limpio.
  static String? _texto(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return (s.isEmpty || s == 'null') ? null : s;
  }

  /// Primer valor no vacío entre [claves] de [mapa] (que puede no ser un Map).
  static String? _primero(dynamic mapa, List<String> claves) {
    if (mapa is! Map) return null;
    for (final k in claves) {
      final v = _texto(mapa[k]);
      if (v != null) return v;
    }
    return null;
  }

  /// dd/MM/yyyy si [v] es una fecha ISO; si no se puede parsear, el texto original.
  static String _fechaCorta(String? v) {
    if (v == null) return '';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(v));
    } catch (_) {
      return v;
    }
  }

  /// Descripciones de actividad económica. Acepta una lista de {codigo, descripcion},
  /// una lista de textos, un mapa suelto o un texto.
  static List<String> _actividades(dynamic params) {
    if (params is! Map) return const [];
    dynamic crudo;
    for (final k in const [
      'actividadesEconomicas',
      'actividades_economicas',
      'actividadEconomica',
      'actividad_economica',
    ]) {
      if (params[k] != null) {
        crudo = params[k];
        break;
      }
    }
    final lista = crudo is List ? crudo : (crudo == null ? const [] : [crudo]);
    final res = <String>[];
    for (final a in lista) {
      final d = a is Map
          ? _primero(a, const ['descripcion', 'actividadEconomicaDescripcion', 'nombre'])
          : _texto(a);
      if (d != null && !res.contains(d)) res.add(d);
    }
    return res;
  }

  /// 1 = Contado, 2 = Crédito (campo `condicion.tipo` de la factura).
  static String _condicionVenta(dynamic condicion) {
    if (condicion is! Map) return '';
    final raw = condicion['tipo'];
    final tipo = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    if (tipo == 1) return 'Contado';
    if (tipo == 2) return 'Credito';
    return '';
  }

  static Future<TicketData> obtenerTicket(int idFactura) async {
    // 1. Obtener JSON desde la BD
    final response = await Supabase.instance.client.rpc(
      'get_factura_json_sifen',
      params: {'p_id_factura': idFactura}, // Aseguramos el nombre param estándar; en caso de usar otro cambiarlo
    );

    if (response == null) {
      throw Exception('No se obtuvo respuesta del ticket');
    }

    final Map<String, dynamic> json = response is Map ? response as Map<String, dynamic> : Map<String, dynamic>.from(response);

    final params = json['params'] ?? {};
    final data = json['data'] ?? {};
    final cliente = data['cliente'] ?? {};
    final establecimientos = params['establecimientos'] as List? ?? [];
    final items = data['items'] as List? ?? [];

    final razonSocial = params['razonSocial'] ?? 'Nombre de Empresa';
    final rucEmisor = params['ruc'] ?? '';
    final timbrado = params['timbradoNumero'] ?? '';
    final timbradoFechaStr = params['timbradoFecha'] ?? '';
    final direccion = establecimientos.isNotEmpty ? establecimientos[0]['direccion'] ?? '' : '';
    final compDir1 = establecimientos.isNotEmpty ? (establecimientos[0]['complemento_direccion_1'] ?? establecimientos[0]['complementoDireccion1'] ?? '') : '';
    final compDir2 = establecimientos.isNotEmpty ? (establecimientos[0]['complemento_direccion_2'] ?? establecimientos[0]['complementoDireccion2'] ?? '') : '';
    final ciudad = establecimientos.isNotEmpty ? (establecimientos[0]['ciudadDescripcion'] ?? establecimientos[0]['ciudad_descripcion'] ?? '') : '';
    final telefono = establecimientos.isNotEmpty ? (establecimientos[0]['telefono'] ?? params['telefono'] ?? '') : '';

    String direccionCompleta = direccion;
    if (compDir1.isNotEmpty) direccionCompleta += ' $compDir1';
    if (compDir2.isNotEmpty) direccionCompleta += ' $compDir2';

    String timbradoFechaFmt = timbradoFechaStr;
    try {
      if (timbradoFechaStr.isNotEmpty) {
        DateTime tF = DateTime.parse(timbradoFechaStr);
        timbradoFechaFmt = DateFormat('dd/MM/yyyy').format(tF);
      }
    } catch (_) {}

    final numero = data['numero'] ?? '0000000';
    final est = data['establecimiento'] ?? '000';
    final pto = data['punto'] ?? '000';
    final numeroFactura = '$est-$pto-$numero';

    final fechaStr = data['fecha'] ?? '';
    DateTime fecha = DateTime.now();
    try {
      fecha = DateTime.parse(fechaStr);
    } catch (_) {}

    final rucCliente = cliente['ruc'] ?? '';
    final nombreCliente = cliente['razonSocial'] ?? 'Consumidor Final';

    // Campos extra del KuDE. Las claves exactas de la RPC no están confirmadas,
    // así que se prueban varias; si ninguna existe el campo queda vacío y no se imprime.
    final est0 = establecimientos.isNotEmpty ? establecimientos[0] : null;
    final emailEmisor = _primero(est0, const ['email', 'correo', 'correoElectronico']) ??
        _primero(params, const ['email', 'correo', 'emailEmisor', 'correoElectronico']) ??
        '';
    final timbradoFechaFinFmt = _fechaCorta(_primero(params, const [
      'timbradoFechaFin',
      'timbradoFechaVencimiento',
      'timbradoVencimiento',
      'timbradoFechaFinVigencia',
      'timbradoFin',
    ]));
    final moneda = _primero(data, const ['moneda']) ?? _primero(params, const ['moneda']) ?? 'PYG';
    final condicionVenta = _condicionVenta(data['condicion']);
    final actividadesEconomicas = _actividades(params);

    // Totales
    double totalAbono = 0;
    double totalExenta = 0;
    double totalIva5 = 0;
    double totalIva10 = 0;
    
    for (var item in items) {
      double subtotal = ((item['cantidad'] ?? 0) * (item['precioUnitario'] ?? 0)).toDouble();
      totalAbono += subtotal;
      
      int iva = item['iva'] ?? 0;
      if (iva == 5) {
        totalIva5 += subtotal;
      } else if (iva == 10) {
        totalIva10 += subtotal;
      } else {
        totalExenta += subtotal;
      }
    }

    // Calcular montos de iva.
    final montoIva5 = totalIva5 / 21;
    final montoIva10 = totalIva10 / 11;
    final importeTotalIva = montoIva5 + montoIva10;

    // No se asume que el RPC traiga efectivo/vuelto ni el tipo: se leen de la factura.
    final fila = await Supabase.instance.client
        .from('facturas')
        .select('efectivo, vuelto, nro_secuencial, fk_establecimientos, fk_tipo_factura')
        .eq('id_factura', idFactura)
        .single();
    final idTipo = (fila['fk_tipo_factura'] as num).toInt();
    final tipo = await TipoFacturaCrudImpl().leerTipoFacturaPorId(idTipo);
    final esInterno = esTipoTicket(tipo?.descripcion);
    final numeroTicket = formatearNumero(
      (fila['fk_establecimientos'] as num).toInt(),
      idTipo,
      (fila['nro_secuencial'] as num).toInt(),
    );
    final efectivo = (fila['efectivo'] as num?)?.toDouble() ?? 0;
    final vuelto = (fila['vuelto'] as num?)?.toDouble() ?? 0;

    return TicketData(
      razonSocial: razonSocial.toString(),
      telefono: telefono.toString(),
      direccionCompleta: direccionCompleta.toString(),
      ciudad: ciudad.toString(),
      rucEmisor: rucEmisor.toString(),
      timbrado: timbrado.toString(),
      timbradoFechaFmt: timbradoFechaFmt.toString(),
      numeroFactura: numeroFactura,
      fecha: fecha,
      rucCliente: rucCliente.toString(),
      nombreCliente: nombreCliente.toString(),
      items: items,
      totalAbono: totalAbono,
      totalExenta: totalExenta,
      totalIva5: totalIva5,
      totalIva10: totalIva10,
      montoIva5: montoIva5,
      montoIva10: montoIva10,
      importeTotalIva: importeTotalIva,
      efectivo: efectivo,
      vuelto: vuelto < 0 ? 0 : vuelto,
      esInterno: esInterno,
      numeroTicket: numeroTicket,
      condicionVenta: condicionVenta,
      moneda: moneda,
      actividadesEconomicas: actividadesEconomicas,
      emailEmisor: emailEmisor,
      timbradoFechaFinFmt: timbradoFechaFinFmt,
    );
  }

  /// Genera y muestra (diálogo de impresión/guardado) el KuDE — la
  /// representación gráfica del Documento Electrónico, con el CDC y el QR
  /// de verificación de SIFEN ya dibujados. Reusa el mismo layout que el
  /// ticket interno (`_buildContenido`), a diferencia de ese, acá sí es un
  /// documento con validez fiscal (o un borrador, según [draft]).
  ///
  /// [cdc] y [qrUrl] salen de `FacturaSendResultado` después de un envío
  /// exitoso a FacturaSend (`resultado.cdc`, `resultado.qrUrl`).
  ///
  /// [papel58mm] independiente del ancho configurado para la impresora
  /// Bluetooth (esa config solo aplica a `ThermalPrinterService`, que ni
  /// existe en web) — es el ancho del PDF generado acá.
  static Future<void> mostrarKude(
    TicketData t, {
    required String cdc,
    required String qrUrl,
    required bool draft,
    bool papel58mm = false,
  }) async {
    final pageFormat = papel58mm ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(8),
        build: (pw.Context context) => _buildContenido(
          t,
          cdc: cdc,
          qrUrl: qrUrl,
          draft: draft,
          compacto: papel58mm,
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'KuDE_${t.numeroFactura}.pdf',
      format: pageFormat,
    );
  }

  /// Agrupa el CDC de 44 dígitos en bloques de 4 para la presentación
  /// estándar del KuDE (ej. "0103 4567 8900 ...").
  static String _formatearCdc(String cdc) {
    final buffer = StringBuffer();
    for (var i = 0; i < cdc.length; i += 4) {
      if (i > 0) buffer.write(' ');
      buffer.write(cdc.substring(i, i + 4 > cdc.length ? cdc.length : i + 4));
    }
    return buffer.toString();
  }

  /// Restituye los acentos a la frase de [guaraniesALetras] (que es ASCII para
  /// papel térmico) para el PDF.
  static String _letrasConAcentos(String texto) => texto
      .replaceAll('GUARANIES', 'GUARANÍES')
      .replaceAll('DIECISEIS', 'DIECISÉIS')
      .replaceAll('VEINTIDOS', 'VEINTIDÓS')
      .replaceAll('VEINTITRES', 'VEINTITRÉS')
      .replaceAll('VEINTISEIS', 'VEINTISÉIS')
      .replaceAll(RegExp(r'\bMILLON\b'), 'MILLÓN');

  static Future<void> _imprimirPdf(TicketData t) async {
    final numeroFactura = t.numeroFactura;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) => _buildContenido(t),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: t.esInterno ? 'Ticket_Interno_${t.numeroTicket}.pdf' : 'Ticket_Factura_$numeroFactura.pdf',
      format: PdfPageFormat.roll80,
    );
  }

  /// Arma el contenido del PDF, compartido entre el ticket interno
  /// (`_imprimirPdf`, sin valor fiscal) y el KuDE real (`mostrarKude`, con
  /// CDC + QR). Cuando [cdc] no es null se agrega el bloque de CDC/QR y
  /// cambia el pie de página para reflejar que es (o será, si [draft]) un
  /// documento con validez fiscal.
  static pw.Widget _buildContenido(
    TicketData t, {
    String? cdc,
    String? qrUrl,
    bool draft = false,
    bool compacto = false,
  }) {
    // En 58mm la tabla de ítems (4 columnas) queda muy ajustada con el
    // mismo tamaño de 80mm — se achica un punto ahí y el QR, el resto del
    // layout (textos centrados de una sola línea) entra bien igual.
    final fsItem = compacto ? 7.0 : 8.0;
    final qrSize = compacto ? 90.0 : 110.0;
    final razonSocial = t.razonSocial;
    final telefono = t.telefono;
    final direccionCompleta = t.direccionCompleta;
    final ciudad = t.ciudad;
    final rucEmisor = t.rucEmisor;
    final timbrado = t.timbrado;
    final timbradoFechaFmt = t.timbradoFechaFmt;
    final numeroFactura = t.numeroFactura;
    final fecha = t.fecha;
    final rucCliente = t.rucCliente;
    final nombreCliente = t.nombreCliente;
    final items = t.items;
    final totalAbono = t.totalAbono;
    final totalExenta = t.totalExenta;
    final totalIva5 = t.totalIva5;
    final totalIva10 = t.totalIva10;
    final montoIva5 = t.montoIva5;
    final montoIva10 = t.montoIva10;
    final importeTotalIva = t.importeTotalIva;
    final esInterno = t.esInterno;

    final formatMoneda = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

    return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Encabezado
              pw.Center(
                child: pw.Text(
                  razonSocial,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (telefono.isNotEmpty)
                pw.Center(
                  child: pw.Text('TELEFONO: $telefono', style: const pw.TextStyle(fontSize: 8)),
                ),
              if (!esInterno && t.emailEmisor.isNotEmpty)
                pw.Center(
                  child: pw.Text('EMAIL: ${t.emailEmisor}', style: const pw.TextStyle(fontSize: 8)),
                ),
              if (direccionCompleta.isNotEmpty)
                pw.Center(
                  child: pw.Text('DIRECCION: $direccionCompleta', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                ),
              if (ciudad.isNotEmpty)
                pw.Center(
                  child: pw.Text('LOCALIDAD $ciudad', style: const pw.TextStyle(fontSize: 8)),
                ),
              if (!esInterno) ...[
                if (t.actividadesEconomicas.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      'ACTIVIDAD ECONÓMICA: ${t.actividadesEconomicas.join(' / ')}',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                pw.Center(
                  child: pw.Text('RUC: $rucEmisor', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Center(
                  child: pw.Text('IVA INCLUIDO', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Center(
                  child: pw.Text('Timbrado: $timbrado', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.SizedBox(height: 5),
                if (timbradoFechaFmt.isNotEmpty)
                  pw.Center(
                    child: pw.Text('Inicio de vigencia: $timbradoFechaFmt', style: const pw.TextStyle(fontSize: 8)),
                  ),
                if (t.timbradoFechaFinFmt.isNotEmpty)
                  pw.Center(
                    child: pw.Text('Fin de vigencia: ${t.timbradoFechaFinFmt}', style: const pw.TextStyle(fontSize: 8)),
                  ),
              ],
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  esInterno ? 'TICKET DE USO INTERNO' : 'FACTURA ELECTRÓNICA: $numeroFactura',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (esInterno)
                pw.Center(
                  child: pw.Text('N°: ${t.numeroTicket}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
              pw.Center(
                child: pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(fecha)}', style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.SizedBox(height: 10),

              // Cliente
              if (!esInterno)
                pw.Text('RUC/C.I.: $rucCliente', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Cliente: $nombreCliente', style: const pw.TextStyle(fontSize: 8)),
              if (!esInterno) ...[
                if (t.condicionVenta.isNotEmpty)
                  pw.Text(
                    'Condición de venta: ${t.condicionVenta == 'Credito' ? 'Crédito' : t.condicionVenta}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                pw.Text('Moneda: ${t.monedaTexto(acentos: true)}', style: const pw.TextStyle(fontSize: 8)),
              ],
              
              // Separador
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),

              // Cabecera de items
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('DESCRIPCION', style: pw.TextStyle(fontSize: fsItem, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('CANT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: fsItem, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('PRECIO', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: fsItem, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: fsItem, fontWeight: pw.FontWeight.bold))),
                ]
              ),
              pw.SizedBox(height: 5),

              // Detalles
              ...items.map((item) {
                double cant = (item['cantidad'] ?? 0).toDouble();
                double precio = (item['precioUnitario'] ?? 0).toDouble();
                double objTotal = cant * precio;
                String desc = item['descripcion'] ?? 'Item';
                final iva = esInterno ? '' : TicketData.textoIvaItem(item);

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: iva.isEmpty
                            ? pw.Text(desc, style: pw.TextStyle(fontSize: fsItem))
                            : pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(desc, style: pw.TextStyle(fontSize: fsItem)),
                                  pw.Text(iva, style: pw.TextStyle(fontSize: fsItem - 1)),
                                ],
                              ),
                      ),
                      pw.Expanded(flex: 1, child: pw.Text(cant.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: fsItem))),
                      pw.Expanded(flex: 2, child: pw.Text(formatMoneda.format(precio), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: fsItem))),
                      pw.Expanded(flex: 2, child: pw.Text(formatMoneda.format(objTotal), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: fsItem))),
                    ],
                  ),
                );
              }).toList(),

              // Separador Totales
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL A PAGAR Gs:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(formatMoneda.format(totalAbono), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]
              ),
              if (!esInterno && t.totalEnLetras.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(_letrasConAcentos(t.totalEnLetras), style: const pw.TextStyle(fontSize: 8)),
              ],

              if (t.mostrarEfectivo) ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('EFECTIVO Gs:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(formatMoneda.format(t.efectivo), style: const pw.TextStyle(fontSize: 9)),
                  ]
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('VUELTO Gs:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(formatMoneda.format(t.vuelto), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
              ],

              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),

              // Detalle de IVA (no aplica al ticket interno)
              if (!esInterno) ...[
              pw.Center(
                child: pw.Text('Liquidación del IVA', style: const pw.TextStyle(fontSize: 8, decoration: pw.TextDecoration.underline)),
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Exentas:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(formatMoneda.format(totalExenta), style: const pw.TextStyle(fontSize: 8)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Gravadas 5%:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(formatMoneda.format(totalIva5), style: const pw.TextStyle(fontSize: 8)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Gravadas 10%:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(formatMoneda.format(totalIva10), style: const pw.TextStyle(fontSize: 8)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total IVA 5%:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(formatMoneda.format(montoIva5), style: const pw.TextStyle(fontSize: 8)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total IVA 10%:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(formatMoneda.format(montoIva10), style: const pw.TextStyle(fontSize: 8)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Gral. IVA:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(formatMoneda.format(importeTotalIva), style: const pw.TextStyle(fontSize: 8)),
                ]
              ),

              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              ],
              pw.SizedBox(height: 10),

              // Footer
              if (cdc != null) ...[
                pw.Center(
                  child: pw.Text(
                    'Representación gráfica del Documento Electrónico (KuDE)',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                if (draft) ...[
                  pw.SizedBox(height: 3),
                  pw.Center(
                    child: pw.Text(
                      'BORRADOR — SIN VALIDEZ FISCAL',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
                if (!esInterno) ...[
                  pw.SizedBox(height: 3),
                  pw.Center(
                    child: pw.Text(
                      'Consulte la validez de este Documento Electrónico con el número de CDC impreso abajo en https://ekuatia.set.gov.py/consultas',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                ],
              ] else
                pw.Center(
                  child: pw.Text(
                    esInterno ? 'Sin valor fiscal. No válido como factura.' : 'Ticket sin valor fiscal.',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic),
                  ),
                ),
              if (cdc != null && qrUrl != null) ...[
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: qrUrl,
                    width: qrSize,
                    height: qrSize,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'CDC: ${_formatearCdc(cdc)}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),
              ],
              if (cdc != null && !esInterno) ...[
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'ESTE DOCUMENTO ES UNA REPRESENTACIÓN GRÁFICA DE UN DOCUMENTO ELECTRÓNICO (XML)',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),
              ],
              pw.SizedBox(height: 20),
            ],
          );
  }
}
