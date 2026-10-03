import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/service/facturasend_resultado.dart';

/// Card de resultado del envío a FacturaSend, mostrada debajo del botón
/// "Enviar a FacturaSend" en `FacturaSuccessDialog`.
///
/// Extraída a un widget aparte para no inflar el diálogo. Stateless: todo el
/// estado (`_errorPreparacion`/`_resultadoFS`) vive en el diálogo, acá solo
/// se recibe y se pinta.
class FacturaSendResultadoCard extends StatelessWidget {
  final String? errorPreparacion;
  final FacturaSendResultado? resultado;

  const FacturaSendResultadoCard({
    Key? key,
    this.errorPreparacion,
    this.resultado,
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
        ],
      ),
    );
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
