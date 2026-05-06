import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:myapp/reportes/data/models/reporte_model.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;

class ReporteScreen extends StatefulWidget {
  const ReporteScreen({Key? key}) : super(key: key);

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> {
  List<ReporteMensual> _datos = [];
  bool _isLoading = true;

  final List<String> _mesesHeaders = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPT',
    'OCT',
    'NOV',
    'DICIEM',
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final response = await Supabase.instance.client
          .from('reporte_deudas_mensuales')
          .select();

      final lista = (response as List)
          .map((item) => ReporteMensual.fromJson(item))
          .toList();

      setState(() {
        _datos = lista;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar reporte: $e')));
    }
  }

  Widget _buildCelda(
    String texto,
    double ancho, {
    bool esCabecera = false,
    Color? colorTexto,
    bool isBold = false,
  }) {
    return Container(
      width: ancho,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: esCabecera ? Colors.blue[200] : Colors.white,
        border: Border.all(color: Colors.black54, width: 0.5),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontWeight: esCabecera || isBold
              ? FontWeight.bold
              : FontWeight.normal,
          fontSize: 12,
          color: colorTexto ?? Colors.black,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reporte de Deudas')),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _generarYDescargarPDF,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.picture_as_pdf, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _datos.isEmpty
          ? const Center(child: Text('No hay datos para mostrar'))
          : Padding(
              padding: const EdgeInsets.all(8.0),
              // ← ÚNICO CAMBIO: ScrollConfiguration envuelve los dos scrolls
              child: ScrollConfiguration(
                behavior: _AllScrollBehavior(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- CABECERA ---
                        Row(
                          children: [
                            _buildCelda('ID INMUEBLE', 90, esCabecera: true),
                            _buildCelda('ESTADO', 110, esCabecera: true),
                            _buildCelda(
                              'NOMBRES Y APELLIDOS',
                              200,
                              esCabecera: true,
                            ),
                            _buildCelda('N° DE CEDULA', 100, esCabecera: true),
                            _buildCelda('N° DE CELULAR', 120, esCabecera: true),
                            _buildCelda('DEUDA', 90, esCabecera: true),
                            ..._mesesHeaders.map(
                              (m) => _buildCelda(m, 80, esCabecera: true),
                            ),
                          ],
                        ),

                        // --- DATOS ---
                        ...List.generate(_datos.length, (index) {
                          final reporte = _datos[index];
                          final bool estaCortado =
                              reporte.estadoConexion == 'DESCONECTADO';
                          final Color colorEstado = estaCortado
                              ? Colors.red
                              : Colors.green;

                          return Row(
                            children: [
                              _buildCelda(reporte.idInmueble, 90),
                              _buildCelda(
                                reporte.estadoConexion,
                                110,
                                colorTexto: colorEstado,
                                isBold: true,
                              ),
                              _buildCelda(reporte.nombres ?? '', 200),
                              _buildCelda(reporte.cedula ?? '', 100),
                              _buildCelda(reporte.celular ?? '', 120),
                              _buildCelda(
                                reporte.deudaTotal.toStringAsFixed(0),
                                90,
                              ),
                              ...reporte.meses.map((monto) {
                                return _buildCelda(
                                  monto == 0 ? '0' : monto.toStringAsFixed(0),
                                  80,
                                );
                              }).toList(),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _generarYDescargarPDF() async {
    final pdf = pw.Document();

    pw.Widget _buildPdfCelda(
      String texto, {
      PdfColor color = PdfColors.black,
      bool isBold = false,
      bool isHeader = false,
    }) {
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.all(4),
        color: isHeader ? PdfColors.blue200 : null,
        child: pw.Text(
          texto,
          style: pw.TextStyle(
            color: color,
            fontSize: 7,
            fontWeight: isBold || isHeader
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Reporte de Deudas Mensuales',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(100),
                3: const pw.FixedColumnWidth(50),
                4: const pw.FixedColumnWidth(60),
                5: const pw.FixedColumnWidth(40),
              },
              children: [
                pw.TableRow(
                  children: [
                    _buildPdfCelda('ID INMUEBLE', isHeader: true),
                    _buildPdfCelda('ESTADO', isHeader: true),
                    _buildPdfCelda('NOMBRES Y APELLIDOS', isHeader: true),
                    _buildPdfCelda('CÉDULA', isHeader: true),
                    _buildPdfCelda('CELULAR', isHeader: true),
                    _buildPdfCelda('DEUDA', isHeader: true),
                    ..._mesesHeaders.map(
                      (m) => _buildPdfCelda(m, isHeader: true),
                    ),
                  ],
                ),
                ...List.generate(_datos.length, (index) {
                  final reporte = _datos[index];
                  final estaCortado = reporte.estadoConexion == 'DESCONECTADO';
                  final colorEstado = estaCortado
                      ? PdfColors.red
                      : PdfColors.green;

                  return pw.TableRow(
                    children: [
                      _buildPdfCelda(reporte.idInmueble),
                      _buildPdfCelda(
                        reporte.estadoConexion,
                        color: colorEstado,
                        isBold: true,
                      ),
                      _buildPdfCelda(reporte.nombres ?? ''),
                      _buildPdfCelda(reporte.cedula ?? ''),
                      _buildPdfCelda(reporte.celular ?? ''),
                      _buildPdfCelda(reporte.deudaTotal.toStringAsFixed(0)),
                      ...reporte.meses.map((monto) {
                        return _buildPdfCelda(
                          monto == 0 ? '0' : monto.toStringAsFixed(0),
                        );
                      }).toList(),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Deudas.pdf',
    );
  }
}

class _AllScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}
