import 'package:flutter/material.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/inmuebles.dart';

class ClienteDashboardPage extends StatelessWidget {
  final Cliente cliente;
  final Inmuebles inmueble;

  const ClienteDashboardPage({
    Key? key,
    required this.cliente,
    required this.inmueble,
  }) : super(key: key);

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
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Información del inmueble
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoCard(
                    'Inmueble Seleccionado',
                    Icons.home,
                    [
                      _InfoRow('Código', inmueble.cod_inmueble ?? 'N/A'),
                      _InfoRow('Dirección', inmueble.direccion ?? 'N/A'),
                      _InfoRow('Categoría', inmueble.categoriaServicio?.nombre ?? 'N/A'),
                      _InfoRow('Estado', inmueble.estado ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoCard(
                    'Información Personal',
                    Icons.person,
                    [
                      if (cliente.celular != null && cliente.celular.isNotEmpty)
                        _InfoRow('Celular', cliente.celular),
                      if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
                        _InfoRow('Teléfono', cliente.telefono.toString()),
                      if (cliente.email != null && cliente.email!.isNotEmpty)
                        _InfoRow('Email', cliente.email.toString()),
                      _InfoRow('Barrio', cliente.barrio?.nombre_barrio ?? 'N/A'),
                      _InfoRow('Dirección', cliente.direccion ?? 'N/A'),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botones de acción
                  _buildActionButton(
                    context,
                    'Ver Deudas',
                    Icons.receipt_long,
                    Colors.orange,
                    () {
                      _showComingSoon(context, 'Ver Deudas');
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildActionButton(
                    context,
                    'Historial de Consumo',
                    Icons.water_drop,
                    Colors.blue,
                    () {
                      _showComingSoon(context, 'Historial de Consumo');
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildActionButton(
                    context,
                    'Historial de Pagos',
                    Icons.payment,
                    Colors.green,
                    () {
                      _showComingSoon(context, 'Historial de Pagos');
                    },
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
          ...rows.map((row) => Padding(
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
          )),
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
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Próximamente'),
        content: Text('La función "$feature" estará disponible pronto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  _InfoRow(this.label, this.value);
}