import 'package:flutter/material.dart';

class FacturaSuccessDialog extends StatelessWidget {
  final Map<String, dynamic> facturaCreada;
  final String clienteNombre;
  final VoidCallback? onImprimir;

  const FacturaSuccessDialog({
    Key? key,
    required this.facturaCreada,
    required this.clienteNombre,
    this.onImprimir,
  }) : super(key: key);

  String _formatearNumeroFactura() {
    try {
      final establecimiento = (facturaCreada['fk_establecimientos'] ?? 1)
          .toString()
          .padLeft(3, '0');
      final tipo =
          (facturaCreada['fk_tipo_factura'] ?? 1).toString().padLeft(3, '0');
      final secuencial =
          (facturaCreada['nro_secuencial'] ?? 0).toString().padLeft(7, '0');
      return '$establecimiento-$tipo-$secuencial';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatearFecha() {
    try {
      final fecha = DateTime.parse(facturaCreada['fecha_emision']);
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final numeroFactura = _formatearNumeroFactura();
    final fecha = _formatearFecha();
    final total = (facturaCreada['total_general'] ?? 0.0).toStringAsFixed(0);
    final idFactura = facturaCreada['id_factura'] ?? 0;
    final vuelto = (facturaCreada['vuelto'] ?? 0.0).toStringAsFixed(0);

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
                        clienteNombre,
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

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cerrar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (onImprimir != null) {
                            onImprimir!();
                          }
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('Imprimir'),
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
                  fontSize: isTotal ? 20 : isHighlight ? 16 : 14,
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