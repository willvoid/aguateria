import 'package:flutter/material.dart';
import 'package:myapp/dao/facturaciondao/conceptocrudimpl.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/vista/dashboard_clientes/deudas_clientes_page.dart';
import 'package:myapp/vista/dashboard_clientes/pagar_deuda_dialog.dart';
import 'package:myapp/vista/dashboard_clientes/pagos_clientespage.dart';

class ClienteDashboardPage extends StatelessWidget {
  final Cliente cliente;
  final Inmuebles inmueble;

  const ClienteDashboardPage({
    Key? key,
    required this.cliente,
    required this.inmueble,
  }) : super(key: key);

  // Carga el concepto de consumo y abre PagarDeudaDialog directamente
  Future<void> _abrirPagoAdelantado(BuildContext context) async {
    // Spinner mientras carga el concepto
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cargando...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final concepto = await ConceptoCrudImpl().leerConceptoPorId(1);

      if (!context.mounted) return;
      Navigator.pop(context); // cierra el spinner

      if (concepto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar el concepto de consumo.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Deuda sintética: sin id_deuda ni ciclo
      // El diálogo calculará el total según los ciclos que elija el usuario
      final deudaSintetica = CuentaCobrar(
        id_deuda: null,
        fk_concepto: concepto,
        descripcion: 'Pago Adelantado de Consumo',
        monto: 0,
        estado: 'PENDIENTE',
        fk_ciclos: null,
        fk_inmueble: inmueble,
        saldo: 0,
        pagado: 0,
        fk_consumos: null,
      );

      final resultado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PagarDeudaDialog(
          deuda: deudaSintetica,
          cliente: cliente,
          inmueble: inmueble,
          idUsuario: 1,
          ciclosIniciales: const [],
        ),
      );

      if (!context.mounted) return;

      if (resultado == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Pago adelantado procesado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // cierra el spinner si hay error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir pago adelantado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0085FF),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mi Cuenta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            tooltip: 'Volver al inicio',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header con información del cliente
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0085FF),
                    const Color(0xFF0085FF).withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        cliente.razonSocial.isNotEmpty
                            ? cliente.razonSocial[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Color(0xFF0085FF),
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    cliente.razonSocial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Doc: ${cliente.documento}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoCard('Inmueble Seleccionado', Icons.home, [
                    _InfoRow('Código', inmueble.cod_inmueble ?? 'N/A'),
                    _InfoRow('Dirección', inmueble.direccion ?? 'N/A'),
                    _InfoRow(
                      'Categoría',
                      inmueble.categoriaServicio?.nombre ?? 'N/A',
                    ),
                    _InfoRow('Estado', inmueble.estado ?? 'N/A'),
                  ]),
                  const SizedBox(height: 24),

                  _buildActionButton(
                    context,
                    'Ver Deudas',
                    Icons.receipt_long,
                    Colors.orange,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeudasClientesPage(
                          cliente: cliente,
                          inmueble: inmueble,
                          modo: ModoDeudasClientes.deuda,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── PAGO ADELANTADO ──────────────────────────────────────
                  _buildActionButton(
                    context,
                    'Pago Adelantado',
                    Icons.payments_outlined,
                    const Color(0xFF0085FF),
                    () => _abrirPagoAdelantado(context),
                  ),
                  const SizedBox(height: 12),

                  _buildActionButton(
                    context,
                    'Historial de Consumo',
                    Icons.water_drop,
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeudasClientesPage(
                          cliente: cliente,
                          inmueble: inmueble,
                          modo: ModoDeudasClientes.consumo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionButton(
                    context,
                    'Historial de Pagos',
                    Icons.payment,
                    Colors.green,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PagosClientePage(cliente: cliente),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0085FF), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  _InfoRow(this.label, this.value);
}