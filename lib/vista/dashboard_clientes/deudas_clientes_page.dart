import 'package:flutter/material.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/dao/cuenta_cobrarcrudimpl.dart';
import 'package:intl/intl.dart';
import 'package:myapp/vista/dashboard_clientes/pagar_deuda_dialog.dart';

enum ModoDeudasClientes { deuda, consumo }

class DeudasClientesPage extends StatefulWidget {
  final Cliente cliente;
  final Inmuebles inmueble;
  final ModoDeudasClientes modo;

  const DeudasClientesPage({
    Key? key,
    required this.cliente,
    required this.inmueble,
    this.modo = ModoDeudasClientes.deuda,
  }) : super(key: key);

  @override
  State<DeudasClientesPage> createState() => _DeudasClientesPageState();
}

class _DeudasClientesPageState extends State<DeudasClientesPage> {
  final CuentaCobrarCrudImpl _deudaCrud = CuentaCobrarCrudImpl();
  bool _isLoading = true;
  List<CuentaCobrar> _deudas = [];
  String _filtroEstado = 'TODAS';
  int? _anioSeleccionado;
  List<int> _aniosDisponibles = [];

  final NumberFormat _formatoMoneda = NumberFormat.currency(
    symbol: 'Gs. ',
    decimalDigits: 0,
  );

  bool get _modoConsumo => widget.modo == ModoDeudasClientes.consumo;

  @override
  void initState() {
    super.initState();
    _cargarDeudas();
  }

  Future<void> _cargarDeudas() async {
    setState(() => _isLoading = true);

    try {
      final todasLasDeudas = await _deudaCrud.leerDeudasPorInmueble(
        widget.inmueble.id!,
      );

      final deudasDelModo = _modoConsumo
          ? todasLasDeudas.where((d) => d.estado == 'PAGADO').toList()
          : todasLasDeudas.where((d) => d.estado != 'PAGADO').toList();

      final anios =
          deudasDelModo
              .where((d) => d.fk_ciclos != null)
              .map((d) => _extraerAnio(d))
              .whereType<int>()
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));

      setState(() {
        _deudas = deudasDelModo;
        _aniosDisponibles = anios;
        if (_modoConsumo && anios.isNotEmpty && _anioSeleccionado == null) {
          _anioSeleccionado = anios.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar deudas: $e')));
      }
    }
  }

  int? _extraerAnio(CuentaCobrar deuda) {
    if (deuda.fk_ciclos == null) return null;
    try {
      return int.parse(deuda.fk_ciclos!.ciclo.substring(0, 4));
    } catch (_) {
      return deuda.fk_ciclos!.inicio.year;
    }
  }

  List<CuentaCobrar> get _deudasFiltradas {
    List<CuentaCobrar> resultado = _deudas;

    if (_modoConsumo && _anioSeleccionado != null) {
      resultado = resultado
          .where((d) => _extraerAnio(d) == _anioSeleccionado)
          .toList();
    }

    if (!_modoConsumo && _filtroEstado != 'TODAS') {
      resultado = resultado.where((d) => d.estado == _filtroEstado).toList();
    }

    return resultado;
  }

  double get _totalDeuda {
    return _deudas
        .where((d) => d.estado == 'PENDIENTE')
        .fold(0.0, (sum, deuda) => sum + deuda.saldo);
  }

  int get _cantidadPendientes =>
      _deudas.where((d) => d.estado == 'PENDIENTE').length;

  int get _cantidadPagadas => _deudas.where((d) => d.estado == 'PAGADO').length;

  bool _estaVencida(CuentaCobrar deuda) {
    if (deuda.fk_ciclos == null) return false;
    return deuda.estado == 'PENDIENTE' &&
        deuda.fk_ciclos!.vencimiento.isBefore(DateTime.now());
  }

  int _diasVencidos(CuentaCobrar deuda) {
    if (!_estaVencida(deuda)) return 0;
    return DateTime.now().difference(deuda.fk_ciclos!.vencimiento).inDays;
  }

  // ── Abre el diálogo de pago pre-seleccionando el ciclo de la deuda ───────
  Future<void> _abrirPagarDeuda(
    CuentaCobrar deuda,
    Cliente cliente,
    Inmuebles inmueble,
    int idUsuario,
  ) async {
    // Si la deuda tiene ciclo asociado, lo pasamos como pre-selección
    final ciclosIniciales = deuda.fk_ciclos != null
        ? [deuda.fk_ciclos!]
        : <dynamic>[];

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PagarDeudaDialog(
        deuda: deuda,
        cliente: cliente,
        inmueble: inmueble,
        idUsuario: idUsuario,
        ciclosIniciales: deuda.fk_ciclos != null
            ? [deuda.fk_ciclos!] // ← ciclo de esta deuda pre-seleccionado
            : const [],
      ),
    );

    if (resultado == true && mounted) {
      await _cargarDeudas();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Pago procesado exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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
        title: Text(_modoConsumo ? 'Mis Consumos' : 'Mis Deudas'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                      if (!_modoConsumo) ...[
                        const Text(
                          'Total Adeudado',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
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
                      ] else ...[
                        _buildEstadistica(
                          'Consumos pagados',
                          _deudas.length.toString(),
                          Icons.check_circle,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: _modoConsumo
                      ? _buildFiltrosAnio()
                      : _buildFiltrosEstado(),
                ),
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
                                _modoConsumo
                                    ? 'No hay consumos para mostrar'
                                    : 'No hay deudas',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _modoConsumo
                                    ? 'No se encontraron consumos para este período'
                                    : _filtroEstado == 'TODAS'
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
                              return _buildDeudaCard(
                                deuda,
                                widget.cliente,
                                widget.inmueble,
                                1,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFiltrosEstado() {
    return Row(
      children: [
        const Icon(Icons.filter_list, size: 20, color: Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFiltroChip('TODAS'),
                const SizedBox(width: 8),
                _buildFiltroChip('PENDIENTE'),
                const SizedBox(width: 8),
                _buildFiltroChip('EN REVISION'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltrosAnio() {
    if (_aniosDisponibles.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 20, color: Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _aniosDisponibles.map((anio) {
                final seleccionado = anio == _anioSeleccionado;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$anio'),
                    selected: seleccionado,
                    selectedColor: const Color(0xFF0085FF),
                    labelStyle: TextStyle(
                      color: seleccionado ? Colors.white : Colors.black87,
                      fontWeight: seleccionado
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      setState(() => _anioSeleccionado = anio);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
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
    return FilterChip(
      label: Text(
        filtro == 'TODAS'
            ? 'Todas'
            : filtro == 'PENDIENTE'
            ? 'Pendiente'
            : 'En Verificación',
      ),
      selected: isSelected,
      onSelected: (selected) => setState(() => _filtroEstado = filtro),
      backgroundColor: Colors.grey[100],
      selectedColor: const Color(0xFF0085FF).withOpacity(0.2),
      checkmarkColor: const Color(0xFF0085FF),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0085FF) : const Color(0xFF6B7280),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildDeudaCard(
    CuentaCobrar deuda,
    Cliente cliente,
    Inmuebles inmueble,
    int idUsuario,
  ) {
    Color estadoColor;
    IconData estadoIcon;
    String estadoTexto;
    final estaVencida = _estaVencida(deuda);
    final bool enRevision = deuda.estado == 'EN REVISION';
    final bool pagoParcial = deuda.estado == 'PAGO_PARCIAL';

    if (deuda.estado == 'PAGADO') {
      estadoColor = Colors.green;
      estadoIcon = Icons.check_circle;
      estadoTexto = 'PAGADA';
    } else if (enRevision) {
      estadoColor = Colors.blue;
      estadoIcon = Icons.hourglass_top;
      estadoTexto = 'EN VERIFICACIÓN';
    } else if (estaVencida) {
      estadoColor = Colors.red;
      estadoIcon = Icons.warning;
      estadoTexto = 'VENCIDA';
    } else if (pagoParcial) {
      estadoColor = Colors.orange;
      estadoIcon = Icons.pending;
      estadoTexto = 'PAGO PARCIAL';
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
          color: estaVencida ? Colors.red.withOpacity(0.3) : Colors.grey[200]!,
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
          onTap: () =>
              _mostrarDetalleDeuda(deuda, cliente, inmueble, idUsuario),
          onLongPress: () => _mostrarOpcionesPago(deuda),
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
                      child: Icon(estadoIcon, color: estadoColor, size: 20),
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
                            deuda.estado == 'PAGADO'
                                ? deuda.monto
                                : deuda.saldo,
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (deuda.estado == 'PENDIENTE' &&
                            deuda.pagado > 0) ...[
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
                if (!_modoConsumo) ...[
                  const SizedBox(height: 12),
                  if (deuda.estado == 'PENDIENTE' ||
                      deuda.estado == 'PAGO_PARCIAL')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _abrirPagarDeuda(
                          deuda,
                          cliente,
                          inmueble,
                          idUsuario,
                        ),
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Pagar Ahora'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0085FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    )
                  else if (enRevision)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_top,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Comprobante enviado — pendiente de aprobación',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
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

  void _mostrarDetalleDeuda(
    CuentaCobrar deuda,
    Cliente cliente,
    Inmuebles inmueble,
    int idUsuario,
  ) {
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
              _buildDetalleRow(
                'Monto Total',
                _formatoMoneda.format(deuda.monto),
              ),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              if (!_modoConsumo) ...[
                if (deuda.estado == 'PENDIENTE')
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _abrirPagarDeuda(
                        deuda,
                        cliente,
                        inmueble,
                        idUsuario,
                      );
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
                  )
                else if (deuda.estado == 'EN REVISION')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Su comprobante está pendiente de aprobación.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
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

  void _mostrarOpcionesPago(CuentaCobrar deuda) {
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
