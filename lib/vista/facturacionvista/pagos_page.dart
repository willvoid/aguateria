import 'package:flutter/material.dart';
import 'package:myapp/dao/facturaciondao/pagocrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/pago.dart';
import 'package:intl/intl.dart';

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
        // Ordenar por estado: PENDIENTE, APROBADO, RECHAZADO
        pagos.sort((a, b) {
          final ordenEstados = {'PENDIENTE': 0, 'APROBADO': 1, 'RECHAZADO': 2};
          final ordenA = ordenEstados[a.estado] ?? 3;
          final ordenB = ordenEstados[b.estado] ?? 3;
          
          if (ordenA != ordenB) {
            return ordenA.compareTo(ordenB);
          }
          
          // Si tienen el mismo estado, ordenar por fecha (más reciente primero)
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

  void _filtrarPagos() {
    _aplicarFiltros();
  }

  void _aplicarFiltros() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      pagosFiltrados = pagos.where((pago) {
        // Filtro por estado
        if (_filtroEstado != 'TODOS' && pago.estado != _filtroEstado) {
          return false;
        }
        
        // Filtro por búsqueda
        if (query.isEmpty) {
          return true;
        }
        
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

  Future<void> _aprobarPago(Pago pago) async {
    // Mostrar diálogo de confirmación
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
            if (pago.usuario != null)
              Text('Usuario: ${pago.usuario!.nombre}'),
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

      // TODO: Obtener el ID del usuario admin actual del contexto/sesión
      // Por ahora usamos un ID temporal - debes reemplazar esto con el ID real del usuario logueado
      final idUsuarioAdmin = 1; // REEMPLAZAR CON EL ID DEL USUARIO LOGUEADO

      // Llamar a la función RPC de Supabase
      final resultado = await _pagoCrud.aprobarPagoConRPC(
        idPago: pago.idPago!,
        idUsuarioAdmin: idUsuarioAdmin,
      );

      Navigator.pop(context); // Cerrar loading

      if (resultado['success'] == true) {
        await _cargarDatos();
        
        // Mostrar diálogo de éxito con información de la factura
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
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
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
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      } else {
        final error = resultado['error'] ?? 'Error desconocido';
        
        // Mostrar diálogo de error con más detalles
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
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
                const Text(
                  'No se pudo aprobar el pago:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: SelectableText(
                    error,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                if (resultado.containsKey('missing_fields')) ...[
                  const Text(
                    'Campos faltantes:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ...((resultado['missing_fields'] as List?)?.map((field) => 
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 6, color: Colors.red),
                          const SizedBox(width: 6),
                          Text('$field', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ) ?? []),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El pago no fue creado con toda la información necesaria para generar la factura.',
                            style: TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
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
        title: const Text('Rechazar Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pago #${pago.idPago} - ${_formatoMoneda(pago.monto)}'),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              maxLines: 3,
              decoration: const InputDecoration(
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (motivoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
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
            child: const Text('Rechazar'),
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
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final exito = await _pagoCrud.cambiarEstadoPago(
        pago.idPago!,
        'RECHAZADO',
        motivoRechazo: motivo,
      );

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        _mostrarExito('Pago rechazado');
      } else {
        _mostrarError('Error al rechazar el pago');
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError('Error: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
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
      padding: const EdgeInsets.all(24),
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
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _estados.map((estado) {
                    return DropdownMenuItem(
                      value: estado,
                      child: Text(estado),
                    );
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
                icon: const Icon(Icons.refresh),
                tooltip: 'Recargar',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Estadísticas rápidas
          Row(
            children: [
              _buildEstadistica(
                'Pendientes',
                pagos.where((p) => p.estado == 'PENDIENTE').length,
                Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildEstadistica(
                'Aprobados',
                pagos.where((p) => p.estado == 'APROBADO').length,
                Colors.green,
              ),
              const SizedBox(width: 16),
              _buildEstadistica(
                'Rechazados',
                pagos.where((p) => p.estado == 'RECHAZADO').length,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : pagosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay pagos para mostrar',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Fecha')),
                                DataColumn(label: Text('Usuario')),
                                DataColumn(label: Text('Monto')),
                                DataColumn(label: Text('Factura')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Info')),
                                DataColumn(label: Text('Comprobante')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: pagosFiltrados.map((pago) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('#${pago.idPago}')),
                                    DataCell(Text(_formatoFecha(pago.fechaPago))),
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
                                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getColorEstado(pago.estado).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
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
                                    DataCell(
                                      Tooltip(
                                        message: pago.payloadCreacion != null 
                                            ? 'Tiene información de facturación' 
                                            : 'No tiene información de facturación',
                                        child: Icon(
                                          pago.payloadCreacion != null 
                                              ? Icons.check_circle 
                                              : Icons.warning,
                                          color: pago.payloadCreacion != null 
                                              ? Colors.green 
                                              : Colors.orange,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      pago.comprobanteUrl != null
                                          ? IconButton(
                                              icon: const Icon(Icons.image, color: Color(0xFF0085FF)),
                                              onPressed: () => _mostrarImagenComprobante(pago.comprobanteUrl!),
                                              tooltip: 'Ver comprobante',
                                            )
                                          : const Text('-'),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility, size: 18, color: Color(0xFF0085FF)),
                                            onPressed: () => _mostrarDetallesPago(pago),
                                            tooltip: 'Ver detalles',
                                          ),
                                          if (pago.estado == 'PENDIENTE') ...[
                                            IconButton(
                                              icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                                              onPressed: () => _aprobarPago(pago),
                                              tooltip: 'Aprobar',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                              onPressed: () => _mostrarDialogoRechazo(pago),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cantidad.toString(),
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF0085FF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      'Comprobante de Pago',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
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
                              Icon(Icons.error_outline, size: 48, color: Colors.red),
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

class _DialogoDetallesPago extends StatelessWidget {
  final Pago pago;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  const _DialogoDetallesPago({
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
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0085FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Detalles del Pago #${pago.idPago}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
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
                    if (pago.motivoRechazo != null) ...[
                      const Divider(height: 24),
                      const Text(
                        'Motivo de Rechazo:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          pago.motivoRechazo!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                    if (pago.comprobanteUrl != null) ...[
                      const Divider(height: 24),
                      const Text(
                        'Comprobante:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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
                              child: CircularProgressIndicator(),
                            );
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
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }
}