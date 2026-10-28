import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/service/facturasend_resultado.dart';
import 'package:myapp/service/thermal_printer_service.dart';
import 'package:myapp/service/ticket_printer_service.dart';

/// Card de resultado del envío a FacturaSend, mostrada debajo del botón
/// "Enviar a FacturaSend" en `FacturaSuccessDialog`.
///
/// Extraída a un widget aparte para no inflar el diálogo. Stateless: todo el
/// estado (`_errorPreparacion`/`_resultadoFS`) vive en el diálogo, acá solo
/// se recibe y se pinta.
class FacturaSendResultadoCard extends StatelessWidget {
  final String? errorPreparacion;
  final FacturaSendResultado? resultado;
  final int idFactura;

  const FacturaSendResultadoCard({
    Key? key,
    this.errorPreparacion,
    this.resultado,
    required this.idFactura,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (errorPreparacion != null) {
      return _buildCard(
        color: Colors.amber,
        icon: Icons.warning_amber_rounded,
        child: Text(
          errorPreparacion!,
          style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
        ),
      );
    }

    final resultado = this.resultado;
    if (resultado == null) return const SizedBox.shrink();

    if (!resultado.ok) {
      final mensajes = resultado.mensajesError;
      return _buildCard(
        color: Colors.red,
        icon: Icons.error_outline_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: mensajes.isEmpty
              ? [
                  Text(
                    'FacturaSend rechazó el documento.',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                  ),
                ]
              : mensajes
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: SelectableText(
                        '• $m',
                        style:
                            TextStyle(fontSize: 13, color: Colors.red.shade900),
                      ),
                    ),
                  )
                  .toList(),
        ),
      );
    }

    // Éxito.
    final cdc = resultado.cdc;
    final loteId = resultado.loteId;
    return _buildCard(
      color: Colors.green,
      icon: Icons.check_circle_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: resultado.draft
                  ? Colors.orange.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              resultado.draft ? 'BORRADOR' : 'REAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: resultado.draft
                    ? Colors.orange.shade800
                    : Colors.green.shade800,
              ),
            ),
          ),
          if (cdc != null) ...[
            const SizedBox(height: 8),
            Text(
              'CDC',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    cdc,
                    style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  color: Colors.green.shade700,
                  tooltip: 'Copiar CDC',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: cdc));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('CDC copiado'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
          if (loteId != null) ...[
            const SizedBox(height: 4),
            Text(
              'Lote: $loteId',
              style: TextStyle(fontSize: 12, color: Colors.green.shade800),
            ),
          ],
          if (resultado.xml != null || (cdc != null && resultado.qrUrl != null)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (resultado.xml != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => _mostrarXml(
                      context,
                      resultado.xml!,
                      cdc ?? 'documento',
                    ),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Ver XML'),
                    style: _estiloBotonSecundario,
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _descargarXml(
                      context,
                      resultado.xml!,
                      cdc ?? 'documento',
                    ),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Descargar XML'),
                    style: _estiloBotonSecundario,
                  ),
                ],
                if (cdc != null && resultado.qrUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _mostrarKude(
                      context,
                      cdc: cdc,
                      qrUrl: resultado.qrUrl!,
                      draft: resultado.draft,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Ver KuDE'),
                    style: _estiloBotonSecundario,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Guarda el XML como archivo. En web dispara la descarga del navegador;
  /// en Android/desktop abre el diálogo nativo de guardar/compartir.
  Future<void> _descargarXml(
    BuildContext context,
    String xml,
    String cdc,
  ) async {
    try {
      await FileSaver.instance.saveFile(
        name: 'factura_$cdc',
        bytes: utf8.encode(xml),
        ext: 'xml',
        mimeType: MimeType.other,
        customMimeType: 'application/xml',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo descargar el XML: $e')),
        );
      }
    }
  }

  void _mostrarXml(BuildContext context, String xml, String cdc) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'XML del documento',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined, size: 18),
                    tooltip: 'Descargar XML',
                    onPressed: () => _descargarXml(context, xml, cdc),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copiar XML',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: xml));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('XML copiado'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    xml,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle get _estiloBotonSecundario => OutlinedButton.styleFrom(
        foregroundColor: Colors.green.shade800,
        side: BorderSide(color: Colors.green.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        visualDensity: VisualDensity.compact,
      );

  /// Arma y muestra el KuDE (representación gráfica con CDC + QR) de la
  /// factura ya enviada, reusando el mismo layout del ticket interno
  /// (`TicketPrinterService`).
  Future<void> _mostrarKude(
    BuildContext context, {
    required String cdc,
    required String qrUrl,
    required bool draft,
  }) async {
    // Si hay impresora Bluetooth configurada, imprimirKude va directo por
    // ahí con el ancho que ya está guardado — no hace falta preguntar nada.
    // Solo se pregunta cuando de verdad va a caer al PDF (sin esa config
    // previa de la que inferir el ancho).
    bool papel58mm = false;
    if (!ThermalPrinterService.disponible ||
        await ThermalPrinterService.impresoraGuardada() == null) {
      if (!context.mounted) return;
      final elegido = await showDialog<bool>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Ancho de papel'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('80 mm'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('58 mm'),
            ),
          ],
        ),
      );
      if (elegido == null) return;
      papel58mm = elegido;
    }
    if (!context.mounted) return;

    try {
      await TicketPrinterService.imprimirKude(
        idFactura,
        cdc: cdc,
        qrUrl: qrUrl,
        draft: draft,
        papel58mmSiNoHayImpresora: papel58mm,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el KuDE: $e')),
        );
      }
    }
  }

  Widget _buildCard({
    required MaterialColor color,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.shade100, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color.shade600),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
