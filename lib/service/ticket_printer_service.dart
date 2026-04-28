import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TicketPrinterService {
  static Future<void> imprimirTicket(int idFactura) async {
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

    final formatMoneda = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
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
              if (direccionCompleta.isNotEmpty)
                pw.Center(
                  child: pw.Text('DIRECCION: $direccionCompleta', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                ),
              if (ciudad.isNotEmpty)
                pw.Center(
                  child: pw.Text('LOCALIDAD $ciudad', style: const pw.TextStyle(fontSize: 8)),
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
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text('FACTURA ELECTRÓNICA: $numeroFactura', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(fecha)}', style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.SizedBox(height: 10),
              
              // Cliente
              pw.Text('RUC/C.I.: $rucCliente', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Cliente: $nombreCliente', style: const pw.TextStyle(fontSize: 8)),
              
              // Separador
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),

              // Cabecera de items
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('DESCRIPCION', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('CANT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('PRECIO', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ]
              ),
              pw.SizedBox(height: 5),

              // Detalles
              ...items.map((item) {
                double cant = (item['cantidad'] ?? 0).toDouble();
                double precio = (item['precioUnitario'] ?? 0).toDouble();
                double objTotal = cant * precio;
                String desc = item['descripcion'] ?? 'Item';
                
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(desc, style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 1, child: pw.Text(cant.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 2, child: pw.Text(formatMoneda.format(precio), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 2, child: pw.Text(formatMoneda.format(objTotal), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
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

              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),

              // Detalle de IVA
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
              pw.SizedBox(height: 10),

              // Footer
              pw.Center(
                child: pw.Text('Ticket sin valor fiscal.', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Ticket_Factura_$numeroFactura.pdf',
    );
  }
}
