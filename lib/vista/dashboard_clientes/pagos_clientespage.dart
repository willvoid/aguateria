import 'package:flutter/material.dart';
import 'package:myapp/dao/facturaciondao/pagocrudimpl.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/facturacionmodelo/pago.dart';
import 'package:intl/intl.dart';

class PagosClientePage extends StatefulWidget {
  final Cliente cliente;

  const PagosClientePage({
    Key? key,
    required this.cliente,
  }) : super(key: key);

  @override
  State<PagosClientePage> createState() => _PagosClientePageState();
}

class _PagosClientePageState extends State<PagosClientePage> {
  final PagoCrudImpl _pagoCrud = PagoCrudImpl();
  bool _isLoading = true;
  List<Pago> _pagos = [];
  String _filtroEstado = 'TODOS';
  final NumberFormat _formatoMoneda = NumberFormat.currency(
    symbol: 'Gs. ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  Future<void> _cargarPagos() async {
    setState(() => _isLoading = true);

    try {
      final pagos = await _pagoCrud.leerPagosPorCliente(
        widget.cliente.idCliente!,
      );

      setState(() {
        _pagos = pagos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar pagos: $e')),
        );
      }
    }
  }

  List<Pago> get _pagosFiltrados {
    if (_filtroEstado == 'TODOS') return _pagos;
    return _pagos.where((p) => p.estado == _filtroEstado).toList();
  }

  int get _cantidadAprobados {
    return _pagos.where((p) => p.estado == 'APROBADO').length;
  }

  int get _cantidadPendientes {
    return _pagos.where((p) => p.estado == 'PENDIENTE').length;
  }

  int get _cantidadRechazados {
    return _pagos.where((p) => p.estado == 'RECHAZADO').length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0085FF),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mis Pagos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPagos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header con resumen
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
                      // Cliente
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.cliente.razonSocial} ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Estadísticas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildEstadistica(
                            'Aprobados',
                            _cantidadAprobados.toString(),
                            Icons.check_circle,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildEstadistica(
                            'Total',
                            _pagos.length.toString(),
                            Icons.receipt_long,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildEstadistica(
                            'Pendientes',
                            _cantidadPendientes.toString(),
                            Icons.pending_actions,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filtros
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_list,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFiltroChip('TODOS'),
                              const SizedBox(width: 8),
                              _buildFiltroChip('PENDIENTE'),
                              const SizedBox(width: 8),
                              _buildFiltroChip('APROBADO'),
                              const SizedBox(width: 8),
                              _buildFiltroChip('RECHAZADO'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de pagos
                Expanded(
                  child: _pagosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payment,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay pagos',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _filtroEstado == 'TODOS'
                                    ? 'No se encontraron pagos registrados'
                                    : 'No se encontraron pagos con este filtro',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _cargarPagos,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pagosFiltrados.length,
                            itemBuilder: (context, index) {
                              final pago = _pagosFiltrados[index];
                              return _buildPagoCard(pago);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEstadistica(String label, String valor, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String filtro) {
    final isSelected = _filtroEstado == filtro;

    String label;
    switch (filtro) {
      case 'TODOS':
        label = 'Todos';
        break;
      case 'PENDIENTE':
        label = 'Pendientes';
        break;
      case 'APROBADO':
        label = 'Aprobados';
        break;
      case 'RECHAZADO':
        label = 'Rechazados';
        break;
      default:
        label = filtro;
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filtroEstado = filtro;
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: const Color(0xFF0085FF).withOpacity(0.2),
      checkmarkColor: const Color(0xFF0085FF),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0085FF) : const Color(0xFF6B7280),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildPagoCard(Pago pago) {
    Color estadoColor;
    IconData estadoIcon;
    String estadoTexto;

    switch (pago.estado) {
      case 'APROBADO':
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle;
        estadoTexto = 'APROBADO';
        break;
      case 'RECHAZADO':
        estadoColor = Colors.red;
        estadoIcon = Icons.cancel;
        estadoTexto = 'RECHAZADO';
        break;
      case 'PENDIENTE':
      default:
        estadoColor = Colors.orange;
        estadoIcon = Icons.pending;
        estadoTexto = 'EN VERIFICACIÓN';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pago.estado == 'RECHAZADO'
              ? Colors.red.withOpacity(0.3)
              : Colors.grey[200]!,
          width: pago.estado == 'RECHAZADO' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _mostrarDetallePago(pago),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(estadoIcon, color: estadoColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pago.fk_modo_pago.descripcion ?? 'Modo de pago',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pago.fechaPago != null
                                ? 'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(pago.fechaPago!)}'
                                : 'Sin fecha registrada',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (pago.factura != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Factura #${pago.factura!.id_factura}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Monto y estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monto',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatoMoneda.format(pago.monto),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        estadoTexto,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: estadoColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // Comprobante
                if (pago.comprobanteUrl != null &&
                    pago.comprobanteUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Comprobante adjunto',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],

                // Motivo de rechazo
                if (pago.estado == 'RECHAZADO' &&
                    pago.motivoRechazo != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Motivo: ${pago.motivoRechazo}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Indicador de procesamiento para pendientes
                if (pago.estado == 'PENDIENTE') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pago en proceso de verificación',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetallePago(Pago pago) {
    Color estadoColor;
    String estadoTexto;

    switch (pago.estado) {
      case 'APROBADO':
        estadoColor = Colors.green;
        estadoTexto = 'APROBADO';
        break;
      case 'RECHAZADO':
        estadoColor = Colors.red;
        estadoTexto = 'RECHAZADO';
        break;
      default:
        estadoColor = Colors.orange;
        estadoTexto = 'EN VERIFICACIÓN';
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle visual
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Detalle del Pago',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Badge de estado
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: estadoColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    estadoTexto,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: estadoColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Detalles
              _buildDetalleRow(
                'Monto',
                _formatoMoneda.format(pago.monto),
              ),
              _buildDetalleRow(
                'Modo de Pago',
                pago.fk_modo_pago.descripcion ?? 'N/A',
              ),
              _buildDetalleRow(
                'Fecha de Pago',
                pago.fechaPago != null
                    ? DateFormat('dd/MM/yyyy HH:mm').format(pago.fechaPago!)
                    : 'No registrada',
              ),
              if (pago.factura != null)
                _buildDetalleRow(
                  'Factura Nº',
                  '${pago.factura!.id_factura}',
                ),
              if (pago.comprobanteUrl != null &&
                  pago.comprobanteUrl!.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Comprobante',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _verImagenCompleta(context, pago.comprobanteUrl!),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      color: Colors.grey[50],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            pago.comprobanteUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                  color: const Color(0xFF0085FF),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    size: 40, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  'No se pudo cargar la imagen',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Overlay con ícono de zoom
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (pago.usuario != null)
                _buildDetalleRow(
                  'Registrado por',
                  '${pago.usuario!.nombre} ',
                ),
              if (pago.motivoRechazo != null)
                _buildDetalleRow('Motivo de Rechazo', pago.motivoRechazo!),

              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verImagenCompleta(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Comprobante'),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image,
                        size: 64, color: Colors.white54),
                    const SizedBox(height: 16),
                    Text(
                      'No se pudo cargar la imagen',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}