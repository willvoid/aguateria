import 'package:flutter/material.dart';
import 'package:myapp/service/facturasend_resultado.dart';
import 'package:myapp/service/facturasend_service.dart';
import 'package:myapp/service/ticket_printer_service.dart';
import 'package:myapp/widget/facturasend_resultado_card.dart';

class FacturaSuccessDialog extends StatefulWidget {
  final Map<String, dynamic> facturaCreada;
  final String clienteNombre;

  const FacturaSuccessDialog({
    Key? key,
    required this.facturaCreada,
    required this.clienteNombre,
  }) : super(key: key);

  @override
  State<FacturaSuccessDialog> createState() => _FacturaSuccessDialogState();
}

class _FacturaSuccessDialogState extends State<FacturaSuccessDialog> {
  bool _imprimiendo = false;
  bool _enviandoFS = false;
  FacturaSendResultado? _resultadoFS;
  String? _errorPreparacion;

  bool get _bloqueado => _imprimiendo || _enviandoFS;

  String _formatearNumeroFactura() {
    try {
      final establecimiento =
          (widget.facturaCreada['fk_establecimientos'] ?? 1)
              .toString()
              .padLeft(3, '0');
      final tipo = (widget.facturaCreada['fk_tipo_factura'] ?? 1)
          .toString()
          .padLeft(3, '0');
      final secuencial = (widget.facturaCreada['nro_secuencial'] ?? 0)
          .toString()
          .padLeft(7, '0');
      return '$establecimiento-$tipo-$secuencial';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatearFecha() {
    try {
      final fecha = DateTime.parse(widget.facturaCreada['fecha_emision']);
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _imprimir(int idFactura) async {
    setState(() => _imprimiendo = true);
    try {
      await TicketPrinterService.imprimirTicket(idFactura);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al imprimir: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  /// Envía la factura a FacturaSend. Un error ANTES de llamar al edge
  /// function (ej. `construirDocumentoDesdeFactura` lanzando por número de
  /// secuencia en 0000000 o factura sin pagos) se trata distinto de un
  /// rechazo del proxy/FacturaSend: el primero es "no pudimos ni preparar el
  /// documento" (`_errorPreparacion`), el segundo es un resultado normal
  /// con `ok: false` (`_resultadoFS`).
  Future<void> _enviarAFacturaSend(int idFactura) async {
    // Guard sincrónico: setState no reconstruye el frame al instante, así
    // que un doble tap antes del próximo render podría disparar dos envíos
    // reales concurrentes para la misma factura si solo dependiéramos del
    // `onPressed: _bloqueado ? null : ...` del botón.
    if (_enviandoFS) return;
    setState(() {
      _enviandoFS = true;
      _errorPreparacion = null;
      _resultadoFS = null;
    });
    try {
      final resultado = await FacturaSendService().enviarFactura(idFactura);
      if (mounted) {
        setState(() => _resultadoFS = resultado);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorPreparacion = e.toString());
      }
    } finally {
      if (mounted) setState(() => _enviandoFS = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final numeroFactura = _formatearNumeroFactura();
    final fecha = _formatearFecha();
    final total =
        (widget.facturaCreada['total_general'] ?? 0.0).toStringAsFixed(0);
    final idFacturaRaw = widget.facturaCreada['id_factura'] ?? 0;
    final idFactura = int.tryParse(idFacturaRaw.toString()) ?? 0;
    final vuelto = (widget.facturaCreada['vuelto'] ?? 0.0).toStringAsFixed(0);

    final enviadoOk = _resultadoFS != null && _resultadoFS!.ok;
    final rechazado = _resultadoFS != null && !_resultadoFS!.ok;

    String labelEnviar;
    if (_enviandoFS) {
      labelEnviar = 'Enviando...';
    } else if (enviadoOk) {
      labelEnviar = 'Enviado';
    } else if (_errorPreparacion != null || rechazado) {
      labelEnviar = 'Reintentar';
    } else {
      labelEnviar = 'Enviar a FacturaSend';
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 450,
          maxHeight: 700,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono de éxito
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                const Text(
                  '¡Factura Creada!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'La factura ha sido guardada exitosamente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Información de la factura
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.shade100,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInfoRow(
                        'N° Factura',
                        numeroFactura,
                        Icons.receipt_long,
                        isHighlight: true,
                      ),
                      const Divider(height: 20),
                      _buildInfoRow('ID', '#$idFactura', Icons.tag),
                      const SizedBox(height: 10),
                      _buildInfoRow('Fecha', fecha, Icons.calendar_today),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        'Cliente',
                        widget.clienteNombre,
                        Icons.person,
                        maxLines: 2,
                      ),
                      const Divider(height: 20),
                      _buildInfoRow(
                        'Total',
                        '$total Gs.',
                        Icons.attach_money,
                        isTotal: true,
                      ),
                      if (double.parse(vuelto) > 0) ...[
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          'Vuelto',
                          '$vuelto Gs.',
                          Icons.money,
                          valueColor: Colors.green.shade700,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botones Cerrar / Imprimir
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _bloqueado ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cerrar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _bloqueado ? null : () => _imprimir(idFactura),
                        icon: _imprimiendo
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print, size: 18),
                        label: Text(_imprimiendo ? 'Cargando...' : 'Imprimir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0085FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Enviar a FacturaSend: fila completa debajo de Cerrar/Imprimir
                // (con maxWidth: 450 tres botones en una fila se superponen).
                // Visualmente secundario (OutlinedButton): Imprimir sigue
                // siendo la acción primaria.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (_bloqueado || enviadoOk)
                        ? null
                        : () => _enviarAFacturaSend(idFactura),
                    icon: _enviandoFS
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(labelEnviar),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: const Color(0xFF0085FF),
                      side: const BorderSide(color: Color(0xFF0085FF)),
                    ),
                  ),
                ),

                // Card de resultado: ámbar (error de preparación), rojo
                // (rechazado por FacturaSend) o verde (aceptado). No ocupa
                // espacio si todavía no hay nada que mostrar.
                FacturaSendResultadoCard(
                  errorPreparacion: _errorPreparacion,
                  resultado: _resultadoFS,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
    bool isTotal = false,
    int maxLines = 1,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: isTotal ? 20 : 18,
          color: isTotal
              ? const Color(0xFF0085FF)
              : isHighlight
                  ? Colors.blue.shade600
                  : Colors.grey.shade600,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isTotal ? 12 : 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isTotal
                      ? 20
                      : isHighlight
                          ? 16
                          : 14,
                  fontWeight: isTotal || isHighlight
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: valueColor ??
                      (isTotal
                          ? const Color(0xFF0085FF)
                          : isHighlight
                              ? Colors.blue.shade600
                              : Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
