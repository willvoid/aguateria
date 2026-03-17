import 'package:flutter/material.dart';
import 'package:myapp/dao/contabilidad/asientos_crud.dart';
import 'package:myapp/dao/contabilidad/saldos_mensuales_crud.dart' hide supabase;
import 'package:myapp/modelo/contabilidad/asiento.dart';
import 'package:myapp/modelo/contabilidad/saldo_mensual.dart';

class DashboardResumenPage extends StatefulWidget {
  const DashboardResumenPage({Key? key}) : super(key: key);

  @override
  State<DashboardResumenPage> createState() =>
      _DashboardResumenPageState();
}

class _DashboardResumenPageState
    extends State<DashboardResumenPage> {
  final AsientosCrudImpl _asientosCrud = AsientosCrudImpl();
  final SaldosMensualesCrudImpl _saldosCrud = SaldosMensualesCrudImpl();

  List<Asientos> _asientosDelMes = [];
  List<SaldosMensuales> _saldosDelMes = [];
  bool _isLoading = true;

  final DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
  setState(() => _isLoading = true);
  try {
    final inicio = DateTime.utc(_ahora.year, _ahora.month, 1);
    final fin = DateTime.utc(_ahora.year, _ahora.month + 1, 1);

    print('🔵 llamando DAO asientos...');
    final asientos = await _asientosCrud.leerPorRangoFechas(inicio, fin);
    print('🟢 asientos del DAO: ${asientos.length}');

    final saldos = await _saldosCrud.leerPorMesAnio(_ahora.month, _ahora.year);
    print('🟢 saldos del DAO: ${saldos.length}');

    setState(() {
      _asientosDelMes = asientos;
      _saldosDelMes = saldos;
      _isLoading = false;
    });
  } catch (e, stack) {
    print('❌ ERROR en _cargarDatos: $e');
    print('❌ STACK: $stack');
    setState(() => _isLoading = false);
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

  // ── Cálculos derivados ──────────────────────────────────────────────────────

  double get _totalDebe =>
      _saldosDelMes.fold(0, (sum, s) => sum + s.saldoDebeAcumulado);

  double get _totalHaber =>
      _saldosDelMes.fold(0, (sum, s) => sum + s.saldoHaberAcumulado);

  double get _resultadoPeriodo => _totalHaber - _totalDebe;

  int get _asientosActivos =>
      _asientosDelMes.where((a) => a.estado == 'ACTIVO').length;

  int get _asientosPendientes =>
      _asientosDelMes.where((a) => a.estado == 'PENDIENTE').length;

  // ── Helpers de formato ──────────────────────────────────────────────────────

  String _formatGuarani(double valor) {
    final abs = valor.abs();
    if (abs >= 1000000) {
      return '₲ ${(abs / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 1000) {
      return '₲ ${(abs / 1000).toStringAsFixed(0)}K';
    }
    return '₲ ${abs.toStringAsFixed(0)}';
  }

  String _formatMesAnio(DateTime fecha) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }

  String _formatFechaCorta(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildMetricCards(),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildTablaAsientos()),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildResumenSaldos()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen contable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Período: ${_formatMesAnio(_ahora)}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: _cargarDatos,
          icon: const Icon(Icons.refresh, color: Color(0xFF6B7280)),
          tooltip: 'Recargar',
        ),
      ],
    );
  }

  // ── Tarjetas de métricas ────────────────────────────────────────────────────

  Widget _buildMetricCards() {
    final resultado = _resultadoPeriodo;
    final esSuperavit = resultado >= 0;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Total ingresos (haber)',
            value: _formatGuarani(_totalHaber),
            icon: Icons.arrow_downward_rounded,
            iconColor: Colors.green.shade600,
            iconBg: Colors.green.shade50,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Total egresos (debe)',
            value: _formatGuarani(_totalDebe),
            icon: Icons.arrow_upward_rounded,
            iconColor: Colors.red.shade600,
            iconBg: Colors.red.shade50,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Resultado del período',
            value: '${esSuperavit ? '+' : '-'}${_formatGuarani(resultado)}',
            icon: esSuperavit
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            iconColor:
                esSuperavit ? Colors.green.shade600 : Colors.red.shade600,
            iconBg: esSuperavit ? Colors.green.shade50 : Colors.red.shade50,
            valueColor:
                esSuperavit ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Asientos del mes',
            value: '${_asientosDelMes.length}',
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF0085FF),
            iconBg: const Color(0xFFE6F0FF),
            subtitle:
                '$_asientosActivos activos · $_asientosPendientes pendientes',
          ),
        ),
      ],
    );
  }

  // ── Tabla de asientos ───────────────────────────────────────────────────────

  Widget _buildTablaAsientos() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Text(
                  'Asientos del mes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_asientosDelMes.length} registros',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _asientosDelMes.isEmpty
              ? _buildEmptyState(
                  Icons.receipt_long_outlined, 'Sin asientos este mes')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 44,
                    headingRowHeight: 42,
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('Nro.')),
                      DataColumn(label: Text('Fecha')),
                      DataColumn(label: Text('Descripción')),
                      DataColumn(label: Text('Sucursal')),
                      DataColumn(label: Text('Estado')),
                    ],
                    rows: _asientosDelMes.take(10).map((asiento) {
                      return DataRow(cells: [
                        DataCell(Text(
                          '#${asiento.nroAsiento}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0085FF)),
                        )),
                        DataCell(Text(_formatFechaCorta(asiento.fecha))),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Text(
                              asiento.descripcion,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(
                          asiento.sucursal.denominacion,
                          overflow: TextOverflow.ellipsis,
                        )),
                        DataCell(_buildEstadoBadge(asiento.estado)),
                      ]);
                    }).toList(),
                  ),
                ),
          if (_asientosDelMes.length > 10)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Mostrando 10 de ${_asientosDelMes.length} asientos',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Resumen de saldos ───────────────────────────────────────────────────────

  Widget _buildResumenSaldos() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Saldos por cuenta',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_saldosDelMes.length} cuentas',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade200, height: 1),
          _saldosDelMes.isEmpty
              ? _buildEmptyState(
                  Icons.account_balance_outlined, 'Sin saldos este mes')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _saldosDelMes.take(8).length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade100, height: 1),
                  itemBuilder: (context, index) {
                    final saldo = _saldosDelMes[index];
                    final esSuperavit = saldo.saldoFinal >= 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  saldo.cuenta.nombre,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (saldo.cuenta.codigo != null)
                                  Text(
                                    saldo.cuenta.codigo!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${esSuperavit ? '+' : ''}${_formatGuarani(saldo.saldoFinal)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: esSuperavit
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          if (_saldosDelMes.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Mostrando 8 de ${_saldosDelMes.length} cuentas',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Helpers de UI ───────────────────────────────────────────────────────────

  Widget _buildEstadoBadge(String estado) {
    Color bg;
    Color fg;
    switch (estado.toUpperCase()) {
      case 'ACTIVO':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'PENDIENTE':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        break;
      case 'ANULADO':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        estado,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String mensaje) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              mensaje,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget reutilizable: tarjeta de métrica ─────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color? valueColor;
  final String? subtitle;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.valueColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF111827),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}