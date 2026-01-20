import 'package:flutter/material.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/deuda.dart';
import 'package:myapp/dao/deudacrudimpl.dart';
import 'package:intl/intl.dart';

class DeudasClientesPage extends StatefulWidget {
  final Cliente cliente;
  final Inmuebles inmueble;

  const DeudasClientesPage({
    Key? key,
    required this.cliente,
    required this.inmueble,
  }) : super(key: key);

  @override
  State<DeudasClientesPage> createState() => _DeudasClientesPageState();
}

class _DeudasClientesPageState extends State<DeudasClientesPage> {
  final DeudaCrudImpl _deudaCrud = DeudaCrudImpl();
  bool _isLoading = true;
  List<Deuda> _deudas = [];
  String _filtroEstado = 'TODAS';
  final NumberFormat _formatoMoneda = NumberFormat.currency(
    symbol: 'Gs. ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargarDeudas();
  }

  Future<void> _cargarDeudas() async {
    setState(() => _isLoading = true);

    try {
      final deudas = await _deudaCrud.leerDeudasPorInmueble(widget.inmueble.id!);
      
      setState(() {
        _deudas = deudas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar deudas: $e')),
        );
      }
    }
  }

  List<Deuda> get _deudasFiltradas {
    if (_filtroEstado == 'TODAS') return _deudas;
    if (_filtroEstado == 'PENDIENTES') {
      return _deudas.where((d) => d.estado == 'PENDIENTE').toList();
    }
    if (_filtroEstado == 'PAGADO') {
      return _deudas.where((d) => d.estado == 'PAGADO').toList();
    }
    return _deudas.where((d) => d.estado == _filtroEstado).toList();
  }

  double get _totalDeuda {
    return _deudasFiltradas
        .where((d) => d.estado == 'PENDIENTE')
        .fold(0.0, (sum, deuda) => sum + deuda.saldo);
  }

  int get _cantidadPendientes {
    return _deudas.where((d) => d.estado == 'PENDIENTE').length;
  }

  int get _cantidadPagadas {
    return _deudas.where((d) => d.estado == 'PAGADO').length;
  }

  bool _estaVencida(Deuda deuda) {
    if (deuda.fk_ciclos == null) return false;
    return deuda.estado == 'PENDIENTE' && 
           deuda.fk_ciclos!.vencimiento.isBefore(DateTime.now());
  }

  int _diasVencidos(Deuda deuda) {
    if (!_estaVencida(deuda)) return 0;
    return DateTime.now().difference(deuda.fk_ciclos!.vencimiento).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0085FF),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mis Deudas'),
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
                      // Inmueble
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
                              Icons.home,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Inmueble: ${widget.inmueble.cod_inmueble ?? 'N/A'}',
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

                      // Total adeudado
                      const Text(
                        'Total Adeudado',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatoMoneda.format(_totalDeuda),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Estadísticas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildEstadistica(
                            'Pendientes',
                            _cantidadPendientes.toString(),
                            Icons.pending_actions,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildEstadistica(
                            'Total',
                            _deudas.length.toString(),
                            Icons.receipt_long,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildEstadistica(
                            'Pagadas',
                            _cantidadPagadas.toString(),
                            Icons.check_circle,
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
                              _buildFiltroChip('TODAS'),
                              const SizedBox(width: 8),
                              _buildFiltroChip('PENDIENTES'),
                              const SizedBox(width: 8),
                              _buildFiltroChip('PAGADO'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de deudas
                Expanded(
                  child: _deudasFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay deudas',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _filtroEstado == 'TODAS'
                                    ? '¡Felicidades! No tienes deudas pendientes'
                                    : 'No se encontraron deudas con este filtro',
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
                          onRefresh: _cargarDeudas,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _deudasFiltradas.length,
                            itemBuilder: (context, index) {
                              final deuda = _deudasFiltradas[index];
                              return _buildDeudaCard(deuda);
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
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String filtro) {
    final isSelected = _filtroEstado == filtro;
    return FilterChip(
      label: Text(
        filtro == 'TODAS' ? 'Todas' :
        filtro == 'PENDIENTES' ? 'Pendientes' :
        'Pagadas',
      ),
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

  Widget _buildDeudaCard(Deuda deuda) {
    Color estadoColor;
    IconData estadoIcon;
    String estadoTexto;
    final estaVencida = _estaVencida(deuda);

    if (deuda.estado == 'PAGADO') {
      estadoColor = Colors.green;
      estadoIcon = Icons.check_circle;
      estadoTexto = 'PAGADA';
    } else if (estaVencida) {
      estadoColor = Colors.red;
      estadoIcon = Icons.warning;
      estadoTexto = 'VENCIDA';
    } else {
      estadoColor = Colors.orange;
      estadoIcon = Icons.pending;
      estadoTexto = 'PENDIENTE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: estaVencida
              ? Colors.red.withOpacity(0.3)
              : Colors.grey[200]!,
          width: estaVencida ? 2 : 1,
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
          onTap: () => _mostrarDetalleDeuda(deuda),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        estadoIcon,
                        color: estadoColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deuda.fk_concepto.nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (deuda.descripcion.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              deuda.descripcion,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          if (deuda.fk_ciclos != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ciclo: ${deuda.fk_ciclos!.descripcion}',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deuda.estado == 'PAGADO' ? 'Pagado' : 'Saldo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatoMoneda.format(
                            deuda.estado == 'PAGADO' ? deuda.monto : deuda.saldo
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (deuda.estado == 'PENDIENTE' && deuda.pagado > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Pagado: ${_formatoMoneda.format(deuda.pagado)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                        if (deuda.fk_ciclos != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Vence: ${DateFormat('dd/MM/yyyy').format(deuda.fk_ciclos!.vencimiento)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (estaVencida) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Vencida hace ${_diasVencidos(deuda)} días',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
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

  void _mostrarDetalleDeuda(Deuda deuda) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
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
                'Detalle de la Deuda',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildDetalleRow('Concepto', deuda.fk_concepto.nombre),
              _buildDetalleRow('Monto Total', _formatoMoneda.format(deuda.monto)),
              _buildDetalleRow('Pagado', _formatoMoneda.format(deuda.pagado)),
              _buildDetalleRow('Saldo', _formatoMoneda.format(deuda.saldo)),
              if (deuda.fk_ciclos != null) ...[
                _buildDetalleRow(
                  'Período',
                  '${DateFormat('dd/MM/yyyy').format(deuda.fk_ciclos!.inicio)} - ${DateFormat('dd/MM/yyyy').format(deuda.fk_ciclos!.fin)}',
                ),
                _buildDetalleRow(
                  'Fecha de Vencimiento',
                  DateFormat('dd/MM/yyyy').format(deuda.fk_ciclos!.vencimiento),
                ),
              ],
              _buildDetalleRow('Estado', deuda.estado),
              if (deuda.descripcion.isNotEmpty)
                _buildDetalleRow('Descripción', deuda.descripcion),
              if (deuda.fk_consumos != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Información de Consumo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetalleRow(
                  'Lectura Anterior',
                  '${deuda.fk_consumos!.lectura_anterior} m³',
                ),
                _buildDetalleRow(
                  'Lectura Actual',
                  '${deuda.fk_consumos!.lectura_actual} m³',
                ),
                _buildDetalleRow(
                  'Consumo',
                  '${deuda.fk_consumos!.consumo_m3} m³',
                ),
              ],
              const SizedBox(height: 24),
              if (deuda.estado != 'PAGADO') ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _mostrarOpcionesPago(deuda);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0085FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Pagar Deuda',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
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

  void _mostrarOpcionesPago(Deuda deuda) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opciones de Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monto a pagar: ${_formatoMoneda.format(deuda.saldo)}'),
            const SizedBox(height: 16),
            const Text(
              'Métodos de pago disponibles:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('• Pago en oficina'),
            const Text('• Transferencia bancaria'),
            const Text('• Pago móvil'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Comuníquese con la oficina para realizar el pago',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
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
}