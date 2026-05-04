import 'package:flutter/material.dart';
import 'package:myapp/dao/facturaciondao/pagocrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/pago.dart';
import 'package:intl/intl.dart';
import 'package:myapp/service/ticket_printer_service.dart';

class PagosPage extends StatefulWidget {
  const PagosPage({Key? key}) : super(key: key);

  @override
  State<PagosPage> createState() => _PagosPageState();
}

class _PagosPageState extends State<PagosPage> {
  final PagoCrudImpl _pagoCrud = PagoCrudImpl();

  List<Pago> pagos = [];
  List<Pago> pagosFiltrados = [];

  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _filtroEstado = 'TODOS';

  final List<String> _estados = ['TODOS', 'PENDIENTE', 'APROBADO', 'RECHAZADO'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarPagos);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      final resultado = await _pagoCrud.leerPagos();

      setState(() {
        pagos = resultado;
        pagos.sort((a, b) {
          final ordenEstados = {'PENDIENTE': 0, 'APROBADO': 1, 'RECHAZADO': 2};
          final ordenA = ordenEstados[a.estado] ?? 3;
          final ordenB = ordenEstados[b.estado] ?? 3;

          if (ordenA != ordenB) return ordenA.compareTo(ordenB);

          if (a.fechaPago != null && b.fechaPago != null) {
            return b.fechaPago!.compareTo(a.fechaPago!);
          }
          return 0;
        });

        pagosFiltrados = pagos;
        _isLoading = false;
      });

      _aplicarFiltros();
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarPagos() => _aplicarFiltros();

  void _aplicarFiltros() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      pagosFiltrados = pagos.where((pago) {
        if (_filtroEstado != 'TODOS' && pago.estado != _filtroEstado) {
          return false;
        }
        if (query.isEmpty) return true;

        return pago.idPago.toString().contains(query) ||
            pago.monto.toString().contains(query) ||
            (pago.usuario?.nombre.toLowerCase().contains(query) ?? false) ||
            (pago.factura?.id_factura.toString().contains(query) ?? false) ||
            (pago.comprobanteUrl?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _mostrarDetallesPago(Pago pago) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => _DialogoDetallesPago(
        pago: pago,
        onAprobar: () async {
          Navigator.of(dialogContext).pop();
          await _aprobarPago(pago);
        },
        onRechazar: () async {
          Navigator.of(dialogContext).pop();
          await _mostrarDialogoRechazo(pago);
        },
      ),
    );
  }

  // ── Mostrar payload de factura ────────────────────────────────────────────
  void _mostrarPayloadFactura(Pago pago) {
    showDialog(
      context: context,
      builder: (context) => _DialogoPayloadFactura(pago: pago),
    );
  }

  Future<void> _aprobarPago(Pago pago) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Aprobación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Está seguro de aprobar el pago #${pago.idPago}?'),
            const SizedBox(height: 8),
            Text('Monto: ${_formatoMoneda(pago.monto)}'),
            const SizedBox(height: 8),
            if (pago.usuario != null) Text('Usuario: ${pago.usuario!.nombre}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se generará automáticamente la factura asociada',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aprobar y Generar Factura'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Aprobando pago y generando factura...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      final idUsuarioAdmin = 1;

      final resultado = await _pagoCrud.aprobarPagoConRPC(
        idPago: pago.idPago!,
        idUsuarioAdmin: idUsuarioAdmin,
      );

      Navigator.pop(context);

      if (resultado['success'] == true) {
        await _cargarDatos();

        final facturaId = resultado['factura']?['id_factura'];
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Pago Aprobado'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('El pago ha sido aprobado exitosamente.'),
                const SizedBox(height: 16),
                if (facturaId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Factura Generada',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 4),
                        Text('ID: #$facturaId'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (facturaId != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await TicketPrinterService.imprimirTicket(facturaId);
                    } catch (e) {
                      _mostrarError('Error al imprimir: $e');
                    }
                  },
                  icon: Icon(Icons.print),
                  label: Text('Imprimir Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text('Aceptar'),
              ),
            ],
          ),
        );
      } else {
        final error = resultado['error'] ?? 'Error desconocido';
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Error al Aprobar Pago'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No se pudo aprobar el pago:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: SelectableText(error,
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError('Error inesperado: $e');
    }
  }

  Future<void> _mostrarDialogoRechazo(Pago pago) async {
    final TextEditingController motivoController = TextEditingController();

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rechazar Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pago #${pago.idPago} - ${_formatoMoneda(pago.monto)}'),
            SizedBox(height: 16),
            TextField(
              controller: motivoController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Motivo del rechazo *',
                hintText: 'Ingrese el motivo del rechazo',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (motivoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Debe ingresar un motivo de rechazo'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, {
                'confirmar': true,
                'motivo': motivoController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Rechazar'),
          ),
        ],
      ),
    );

    if (resultado?['confirmar'] == true) {
      await _rechazarPago(pago, resultado!['motivo']);
    }
  }

  Future<void> _rechazarPago(Pago pago, String motivo) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    final idUsuarioAdmin = 1;

    final resultado = await _pagoCrud.rechazarPagoConRPC(
      idPago: pago.idPago!,
      motivo: motivo,
      idUsuarioAdmin: idUsuarioAdmin,
    );

    Navigator.pop(context);

    if (resultado['success'] == true) {
      await _cargarDatos();
      _mostrarExito('Pago rechazado correctamente');
    } else {
      final error = resultado['error'] ?? 'Error desconocido';
      _mostrarError('Error al rechazar el pago: $error');
    }
  } catch (e) {
    Navigator.pop(context);
    _mostrarError('Error inesperado: $e');
  }
}

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatoMoneda(double monto) {
    final formato = NumberFormat.currency(symbol: '₲', decimalDigits: 0);
    return formato.format(monto);
  }

  String _formatoFecha(DateTime? fecha) {
    if (fecha == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'PENDIENTE':
        return Colors.orange;
      case 'APROBADO':
        return Colors.green;
      case 'RECHAZADO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por ID, monto, usuario...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _filtroEstado,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Estado',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  items: _estados.map((estado) {
                    return DropdownMenuItem(
                        value: estado, child: Text(estado));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _filtroEstado = value!);
                    _aplicarFiltros();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _cargarDatos,
                icon: Icon(Icons.refresh),
                tooltip: 'Recargar',
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildEstadistica(
                'Pendientes',
                pagos.where((p) => p.estado == 'PENDIENTE').length,
                Colors.orange,
              ),
              SizedBox(width: 16),
              _buildEstadistica(
                'Aprobados',
                pagos.where((p) => p.estado == 'APROBADO').length,
                Colors.green,
              ),
              SizedBox(width: 16),
              _buildEstadistica(
                'Rechazados',
                pagos.where((p) => p.estado == 'RECHAZADO').length,
                Colors.red,
              ),
            ],
          ),
          SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : pagosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay pagos para mostrar',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Fecha')),
                                DataColumn(label: Text('Usuario')),
                                DataColumn(label: Text('Monto')),
                                DataColumn(label: Text('Factura')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Info Factura')), // ← RENOMBRADO
                                DataColumn(label: Text('Comprobante')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: pagosFiltrados.map((pago) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('#${pago.idPago}')),
                                    DataCell(
                                        Text(_formatoFecha(pago.fechaPago))),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          pago.usuario?.nombre ?? 'Sin usuario',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatoMoneda(pago.monto),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        pago.factura != null
                                            ? '#${pago.factura!.id_factura}'
                                            : 'Sin factura',
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getColorEstado(pago.estado)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          pago.estado,
                                          style: TextStyle(
                                            color: _getColorEstado(pago.estado),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // ✅ NUEVO: botón que abre el diálogo de payload
                                    DataCell(
                                      pago.payloadCreacion != null
                                          ? Tooltip(
                                              message: 'Ver datos de factura',
                                              child: InkWell(
                                                onTap: () =>
                                                    _mostrarPayloadFactura(pago),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Container(
                                                  padding:
                                                      EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                    border: Border.all(
                                                        color:
                                                            Colors.blue.shade200),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .receipt_long_outlined,
                                                        size: 14,
                                                        color:
                                                            Colors.blue.shade700,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Ver',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .blue.shade700,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Tooltip(
                                              message:
                                                  'Sin información de factura',
                                              child: Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.orange.shade400,
                                                size: 20,
                                              ),
                                            ),
                                    ),

                                    DataCell(
                                      pago.comprobanteUrl != null
                                          ? IconButton(
                                              icon: Icon(Icons.image,
                                                  color: Color(0xFF0085FF)),
                                              onPressed: () =>
                                                  _mostrarImagenComprobante(
                                                      pago.comprobanteUrl!),
                                              tooltip: 'Ver comprobante',
                                            )
                                          : Text('-'),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.visibility,
                                                size: 18,
                                                color: Color(0xFF0085FF)),
                                            onPressed: () =>
                                                _mostrarDetallesPago(pago),
                                            tooltip: 'Ver detalles',
                                          ),
                                          if (pago.estado == 'PENDIENTE') ...[
                                            IconButton(
                                              icon: Icon(
                                                  Icons.check_circle,
                                                  size: 18,
                                                  color: Colors.green),
                                              onPressed: () =>
                                                  _aprobarPago(pago),
                                              tooltip: 'Aprobar',
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.cancel,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _mostrarDialogoRechazo(pago),
                                              tooltip: 'Rechazar',
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadistica(String label, int cantidad, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              cantidad.toString(),
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarImagenComprobante(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF0085FF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.image, color: Theme.of(context).cardColor),
                    const SizedBox(width: 12),
                    Text(
                      'Comprobante de Pago',
                      style: TextStyle(
                          color: Theme.of(context).cardColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Theme.of(context).cardColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              SizedBox(height: 8),
                              Text('Error al cargar la imagen'),
                            ],
                          ),
                        );
                      },
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ============================================================================
// DIÁLOGO DE PAYLOAD DE FACTURA
// ============================================================================

class _DialogoPayloadFactura extends StatelessWidget {
  final Pago pago;

  const _DialogoPayloadFactura({required this.pago});

  String _formatoMoneda(double monto) {
    final formato = NumberFormat.currency(symbol: '₲', decimalDigits: 0);
    return formato.format(monto);
  }

  @override
  Widget build(BuildContext context) {
    final payload = pago.payloadCreacion!;

    // ── Extraer datos del payload ──────────────────────────────────────────
    final fkCliente = payload['fk_cliente']?.toString() ?? '-';
    final fkInmueble = payload['fk_inmueble']?.toString() ?? '-';
    final totalGeneral =
        double.tryParse(payload['total_general']?.toString() ?? '0') ?? 0.0;
    final totalGravado10 =
        double.tryParse(payload['total_gravado_10']?.toString() ?? '0') ?? 0.0;
    final totalGravado5 =
        double.tryParse(payload['total_gravado_5']?.toString() ?? '0') ?? 0.0;
    final totalExenta =
        double.tryParse(payload['total_exenta']?.toString() ?? '0') ?? 0.0;
    final totalIva =
        double.tryParse(payload['total_iva']?.toString() ?? '0') ?? 0.0;
    final observacion =
        payload['observacion']?.toString() ?? '';
    final detalles =
        (payload['detalles'] as List<dynamic>?) ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0085FF),
                    Colors.blue.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long,
                        color: Theme.of(context).cardColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información de Factura',
                          style: TextStyle(
                            color: Theme.of(context).cardColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Pago #${pago.idPago} · ${_formatoMoneda(pago.monto)}',
                          style: TextStyle(
                              color: Theme.of(context).cardColor.withOpacity(0.7), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).cardColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Contenido scrolleable ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Datos generales ──────────────────────────────────────
                    _SeccionTitulo(
                      icono: Icons.info_outline,
                      titulo: 'Datos Generales',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _FilaInfo(
                            icono: Icons.person_outline,
                            label: 'Cliente',
                            valor: 'ID: $fkCliente',
                            primero: true,
                          ),
                          _Divisor(),
                          _FilaInfo(
                            icono: Icons.home_outlined,
                            label: 'Inmueble',
                            valor: 'ID: $fkInmueble',
                          ),
                          if (observacion.isNotEmpty) ...[
                            _Divisor(),
                            _FilaInfo(
                              icono: Icons.notes_outlined,
                              label: 'Observación',
                              valor: observacion,
                              ultimo: true,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Detalles de factura ──────────────────────────────────
                    _SeccionTitulo(
                      icono: Icons.list_alt_outlined,
                      titulo: 'Detalle de Items',
                      badge: detalles.length.toString(),
                    ),
                    const SizedBox(height: 12),

                    if (detalles.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade600),
                            const SizedBox(width: 12),
                            const Text('No hay detalles de items disponibles'),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            // Cabecera tabla
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.06),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Expanded(
                                    flex: 4,
                                    child: Text('Descripción',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF374151))),
                                  ),
                                  SizedBox(width: 8),
                                  SizedBox(
                                    width: 60,
                                    child: Text('IVA',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF374151))),
                                  ),
                                  SizedBox(width: 8),
                                  SizedBox(
                                    width: 110,
                                    child: Text('Monto',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF374151))),
                                  ),
                                ],
                              ),
                            ),
                            // Filas de detalles
                            ...detalles.asMap().entries.map((entry) {
                              final i = entry.key;
                              final detalle =
                                  entry.value as Map<String, dynamic>;
                              final descripcion =
                                  detalle['descripcion']?.toString() ??
                                      'Sin descripción';
                              final monto = double.tryParse(
                                      detalle['monto']?.toString() ?? '0') ??
                                  0.0;
                              final iva =
                                  detalle['iva_aplicado']?.toString() ?? '0';
                              final esPar = i % 2 == 0;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: esPar
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  borderRadius: i == detalles.length - 1
                                      ? const BorderRadius.only(
                                          bottomLeft: Radius.circular(10),
                                          bottomRight: Radius.circular(10),
                                        )
                                      : null,
                                  border: Border(
                                    top: BorderSide(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        descripcion,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF1F2937)),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 60,
                                      child: Center(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '$iva%',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        _formatoMoneda(monto),
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                    SizedBox(height: 24),

                    // ── Resumen de totales ───────────────────────────────────
                    _SeccionTitulo(
                      icono: Icons.calculate_outlined,
                      titulo: 'Resumen de Totales',
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade50,
                            Colors.blue.shade100.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          if (totalGravado10 > 0)
                            _FilaTotalSimple(
                                label: 'Base gravada 10%',
                                valor: _formatoMoneda(totalGravado10)),
                          if (totalGravado5 > 0)
                            _FilaTotalSimple(
                                label: 'Base gravada 5%',
                                valor: _formatoMoneda(totalGravado5)),
                          if (totalExenta > 0)
                            _FilaTotalSimple(
                                label: 'Exenta',
                                valor: _formatoMoneda(totalExenta)),
                          if (totalIva > 0)
                            _FilaTotalSimple(
                                label: 'IVA',
                                valor: _formatoMoneda(totalIva)),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),
                          // Total general destacado
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL GENERAL',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                _formatoMoneda(totalGeneral),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0085FF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border:
                    Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares del diálogo ───────────────────────────────────────────

class _SeccionTitulo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? badge;

  _SeccionTitulo({
    required this.icono,
    required this.titulo,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 18, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        if (badge != null) ...[
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).cardColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilaInfo extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;
  final bool primero;
  final bool ultimo;

  const _FilaInfo({
    required this.icono,
    required this.label,
    required this.valor,
    this.primero = false,
    this.ultimo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icono, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divisor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.grey.shade200);
  }
}

class _FilaTotalSimple extends StatelessWidget {
  final String label;
  final String valor;

  _FilaTotalSimple({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(valor,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
        ],
      ),
    );
  }
}

// ============================================================================
// DIÁLOGO DE DETALLES DEL PAGO (sin cambios)
// ============================================================================

class _DialogoDetallesPago extends StatelessWidget {
  final Pago pago;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  _DialogoDetallesPago({
    required this.pago,
    required this.onAprobar,
    required this.onRechazar,
  });

  String _formatoMoneda(double monto) {
    final formato = NumberFormat.currency(symbol: '₲', decimalDigits: 0);
    return formato.format(monto);
  }

  String _formatoFecha(DateTime? fecha) {
    if (fecha == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF0085FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: Theme.of(context).cardColor),
                  const SizedBox(width: 12),
                  Text(
                    'Detalles del Pago #${pago.idPago}',
                    style: TextStyle(
                        color: Theme.of(context).cardColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).cardColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('ID Pago', '#${pago.idPago}'),
                    _buildInfoRow('Fecha', _formatoFecha(pago.fechaPago)),
                    _buildInfoRow('Monto', _formatoMoneda(pago.monto)),
                    _buildInfoRow('Estado', pago.estado),
                    if (pago.usuario != null)
                      _buildInfoRow('Usuario', pago.usuario!.nombre),
                    if (pago.factura != null)
                      _buildInfoRow('Factura', '#${pago.factura!.id_factura}'),
                      _buildInfoRow('Cliente', pago.fk_cliente.razonSocial),
                    if (pago.motivoRechazo != null) ...[
                      const Divider(height: 24),
                      const Text('Motivo de Rechazo:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(pago.motivoRechazo!,
                            style:
                                TextStyle(color: Colors.red.shade900)),
                      ),
                    ],
                    if (pago.comprobanteUrl != null) ...[
                      const Divider(height: 24),
                      const Text('Comprobante:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          pago.comprobanteUrl!,
                          fit: BoxFit.contain,
                          height: 300,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline, size: 48),
                                    SizedBox(height: 8),
                                    Text('Error al cargar imagen'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (pago.estado == 'PENDIENTE')
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border:
                      Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onRechazar,
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Rechazar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: onAprobar,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }
}