import 'dart:math';
import 'package:flutter/material.dart';
import 'package:myapp/dao/contabilidad/asientos_crud.dart';
import 'package:myapp/modelo/contabilidad/asiento.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DashboardResumenPage extends StatefulWidget {
  const DashboardResumenPage({Key? key}) : super(key: key);

  @override
  State<DashboardResumenPage> createState() =>
      _DashboardResumenPageState();
}

class _DashboardResumenPageState extends State<DashboardResumenPage> {
  final AsientosCrudImpl _asientosCrud = AsientosCrudImpl();

  List<Asientos> _asientosDelMes = [];
  List<Map<String, dynamic>> _resumenCuentas = [];
  double _totalDebe = 0;
  double _totalHaber = 0;

  List<Map<String, dynamic>> _datosMensuales = [];

  bool _isLoading = true;
  final DateTime _ahora = DateTime.now();

  // ── Período ──────────────────────────────────────────────────────────────
  int _periodoSeleccionado = 0; // 0=este mes, 1=mes anterior, 2=personalizado
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  DateTime get _rangoInicio {
    if (_periodoSeleccionado == 2 && _fechaInicio != null) {
      return DateTime.utc(
          _fechaInicio!.year, _fechaInicio!.month, _fechaInicio!.day);
    }
    if (_periodoSeleccionado == 1) {
      final mes = _ahora.month == 1 ? 12 : _ahora.month - 1;
      final anio =
          _ahora.month == 1 ? _ahora.year - 1 : _ahora.year;
      return DateTime.utc(anio, mes, 1);
    }
    return DateTime.utc(_ahora.year, _ahora.month, 1);
  }

  DateTime get _rangoFin {
    if (_periodoSeleccionado == 2 && _fechaFin != null) {
      return DateTime.utc(
          _fechaFin!.year, _fechaFin!.month, _fechaFin!.day + 1);
    }
    if (_periodoSeleccionado == 1) {
      return DateTime.utc(_ahora.year, _ahora.month, 1);
    }
    return DateTime.utc(_ahora.year, _ahora.month + 1, 1);
  }

  String get _labelPeriodo {
    if (_periodoSeleccionado == 2 &&
        _fechaInicio != null &&
        _fechaFin != null) {
      final d = (DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      return '${d(_fechaInicio!)} — ${d(_fechaFin!)}';
    }
    if (_periodoSeleccionado == 1) {
      final mes = _ahora.month == 1 ? 12 : _ahora.month - 1;
      final anio =
          _ahora.month == 1 ? _ahora.year - 1 : _ahora.year;
      return _formatMesAnio(DateTime(anio, mes));
    }
    return _formatMesAnio(_ahora);
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final inicio = _rangoInicio;
      final fin = _rangoFin;

      final asientos =
          await _asientosCrud.leerPorRangoFechas(inicio, fin);

      double debe = 0;
      double haber = 0;
      final Map<String, Map<String, dynamic>> porCuenta = {};

      if (asientos.isNotEmpty) {
        final ids = asientos
            .where((a) => a.id != null)
            .map((a) => a.id!)
            .toList();

        final detalles = await supabase
            .from('detalle_asientos')
            .select('debe, haber, cuentas_contables(nombre, codigo)')
            .inFilter('fk_asientos', ids);

        for (final d in detalles) {
          final debeVal = (d['debe'] as num?)?.toDouble() ?? 0;
          final haberVal = (d['haber'] as num?)?.toDouble() ?? 0;
          debe += debeVal;
          haber += haberVal;

          final cuenta = d['cuentas_contables'];
          if (cuenta != null) {
            final nombre =
                cuenta['nombre'] as String? ?? 'Sin nombre';
            final codigo = cuenta['codigo'] as String? ?? '';
            if (!porCuenta.containsKey(nombre)) {
              porCuenta[nombre] = {
                'nombre': nombre,
                'codigo': codigo,
                'debe': 0.0,
                'haber': 0.0,
              };
            }
            porCuenta[nombre]!['debe'] =
                (porCuenta[nombre]!['debe'] as double) + debeVal;
            porCuenta[nombre]!['haber'] =
                (porCuenta[nombre]!['haber'] as double) + haberVal;
          }
        }
      }

      final resumen = porCuenta.values.map((c) {
        final saldo =
            (c['haber'] as double) - (c['debe'] as double);
        return {...c, 'saldo': saldo};
      }).toList();
      resumen.sort((a, b) => (b['saldo'] as double)
          .abs()
          .compareTo((a['saldo'] as double).abs()));

      final datosMensuales = await _cargarUltimosSeisMeses();

      setState(() {
        _asientosDelMes = asientos;
        _totalDebe = debe;
        _totalHaber = haber;
        _resumenCuentas = resumen;
        _datosMensuales = datosMensuales;
        _isLoading = false;
      });
    } catch (e, stack) {
      print('❌ ERROR en _cargarDatos: $e');
      print('❌ STACK: $stack');
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos contables: $e');
    }
  }

  Future<List<Map<String, dynamic>>>
      _cargarUltimosSeisMeses() async {
    const mesesLabel = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];

    final List<Map<String, dynamic>> resultado = [];

    for (int i = 5; i >= 0; i--) {
      int mes = _ahora.month - i;
      int anio = _ahora.year;
      while (mes <= 0) {
        mes += 12;
        anio -= 1;
      }

      final inicioMes = DateTime.utc(anio, mes, 1);
      final finMes = DateTime.utc(anio, mes + 1, 1);

      try {
        final asientosMes =
            await _asientosCrud.leerPorRangoFechas(inicioMes, finMes);

        double debeTotal = 0;
        double haberTotal = 0;

        if (asientosMes.isNotEmpty) {
          final ids = asientosMes
              .where((a) => a.id != null)
              .map((a) => a.id!)
              .toList();

          final detalles = await supabase
              .from('detalle_asientos')
              .select('debe, haber')
              .inFilter('fk_asientos', ids);

          for (final d in detalles) {
            debeTotal += (d['debe'] as num?)?.toDouble() ?? 0;
            haberTotal += (d['haber'] as num?)?.toDouble() ?? 0;
          }
        }

        resultado.add({
          'label': mesesLabel[mes - 1],
          'debe': debeTotal,
          'haber': haberTotal,
        });
      } catch (_) {
        resultado.add({
          'label': mesesLabel[mes - 1],
          'debe': 0.0,
          'haber': 0.0,
        });
      }
    }

    return resultado;
  }

  Future<void> _seleccionarRangoPersonalizado() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _fechaInicio != null && _fechaFin != null
          ? DateTimeRange(start: _fechaInicio!, end: _fechaFin!)
          : DateTimeRange(
              start: DateTime(_ahora.year, _ahora.month, 1),
              end: _ahora,
            ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0085FF),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
        _periodoSeleccionado = 2;
      });
      _cargarDatos();
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

  int get _asientosAsentados =>
      _asientosDelMes.where((a) => a.estado == 'ASENTADO').length;

  int get _asientosPendientes =>
      _asientosDelMes.where((a) => a.estado == 'PENDIENTE').length;

  String _formatGuarani(double valor) {
    final abs = valor.abs();
    if (abs >= 1000000)
      return '₲ ${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000)
      return '₲ ${(abs / 1000).toStringAsFixed(0)}K';
    return '₲ ${abs.toStringAsFixed(0)}';
  }

  String _formatMesAnio(DateTime fecha) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre',
      'diciembre'
    ];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }

  String _formatFechaCorta(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
  }

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
                  _buildTopRow(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 3, child: _buildTablaAsientos()),
                      const SizedBox(width: 16),
                      Expanded(
                          flex: 2, child: _buildResumenCuentas()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

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
              'Período: $_labelPeriodo',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PeriodoTab(
                label: 'Este mes',
                activo: _periodoSeleccionado == 0,
                onTap: () {
                  if (_periodoSeleccionado != 0) {
                    setState(() => _periodoSeleccionado = 0);
                    _cargarDatos();
                  }
                },
              ),
              _PeriodoTab(
                label: 'Mes anterior',
                activo: _periodoSeleccionado == 1,
                onTap: () {
                  if (_periodoSeleccionado != 1) {
                    setState(() => _periodoSeleccionado = 1);
                    _cargarDatos();
                  }
                },
              ),
              _PeriodoTab(
                label: _periodoSeleccionado == 2
                    ? 'Personalizado ✓'
                    : 'Personalizado',
                activo: _periodoSeleccionado == 2,
                onTap: _seleccionarRangoPersonalizado,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _cargarDatos,
          icon: const Icon(Icons.refresh, color: Color(0xFF6B7280)),
          tooltip: 'Recargar',
        ),
      ],
    );
  }

  Widget _buildTopRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: Column(
            children: [
              _MetricCard(
                label: 'Total haber',
                value: _formatGuarani(_totalHaber),
                icon: Icons.arrow_downward_rounded,
                iconColor: Colors.green.shade600,
                iconBg: Colors.green.shade50,
              ),
              const SizedBox(height: 10),
              _MetricCard(
                label: 'Total debe',
                value: _formatGuarani(_totalDebe),
                icon: Icons.arrow_upward_rounded,
                iconColor: Colors.red.shade600,
                iconBg: Colors.red.shade50,
              ),
              const SizedBox(height: 10),
              _MetricCard(
                label: 'Asientos del período',
                value: '${_asientosDelMes.length}',
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF0085FF),
                iconBg: const Color(0xFFE6F0FF),
                subtitle:
                    '$_asientosAsentados asentados · $_asientosPendientes pendientes',
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _buildGraficoEvolucion()),
      ],
    );
  }

  Widget _buildGraficoEvolucion() {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Evolución últimos 6 meses',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              _LeyendaPunto(
                  color: const Color(0xFF10B981), label: 'Haber'),
              const SizedBox(width: 16),
              _LeyendaPunto(
                  color: const Color(0xFFEF4444), label: 'Debe'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _datosMensuales.isEmpty
                ? const Center(
                    child: Text('Sin datos',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 13)),
                  )
                : CustomPaint(
                    painter:
                        _LineChartPainter(datos: _datosMensuales),
                    size: Size.infinite,
                  ),
          ),
        ],
      ),
    );
  }

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
                  'Asientos del período',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
              ? _buildEmptyState(Icons.receipt_long_outlined,
                  'Sin asientos en este período')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF9FAFB)),
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
                        DataCell(Text(
                            _formatFechaCorta(asiento.fecha))),
                        DataCell(SizedBox(
                          width: 180,
                          child: Text(
                            asiento.descripcion,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Text(
                          asiento.sucursal.denominacion,
                          overflow: TextOverflow.ellipsis,
                        )),
                        DataCell(
                            _buildEstadoBadge(asiento.estado)),
                      ]);
                    }).toList(),
                  ),
                ),
          if (_asientosDelMes.length > 10)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Mostrando 10 de ${_asientosDelMes.length} asientos',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildResumenCuentas() {
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
                  'Movimiento por cuenta',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_resumenCuentas.length} cuentas',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade200, height: 1),
          _resumenCuentas.isEmpty
              ? _buildEmptyState(Icons.account_balance_outlined,
                  'Sin movimientos en este período')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _resumenCuentas.take(8).length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade100, height: 1),
                  itemBuilder: (context, index) {
                    final c = _resumenCuentas[index];
                    final saldo = c['saldo'] as double;
                    final esSuperavit = saldo >= 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['nombre'] as String,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((c['codigo'] as String)
                                    .isNotEmpty)
                                  Text(
                                    c['codigo'] as String,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${esSuperavit ? '+' : ''}${_formatGuarani(saldo)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: esSuperavit
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                              Text(
                                'D: ${_formatGuarani(c['debe'] as double)}  H: ${_formatGuarani(c['haber'] as double)}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          if (_resumenCuentas.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Mostrando 8 de ${_resumenCuentas.length} cuentas',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color bg;
    Color fg;
    switch (estado.toUpperCase()) {
      case 'ASENTADO':
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
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        estado,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: fg),
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
            Text(mensaje,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

// ── Selector de período ─────────────────────────────────────────────────────

class _PeriodoTab extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _PeriodoTab({
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                activo ? FontWeight.w600 : FontWeight.w400,
            color: activo
                ? const Color(0xFF111827)
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ── CustomPainter del gráfico de línea ──────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> datos;

  _LineChartPainter({required this.datos});

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;

    final haberVals =
        datos.map((d) => (d['haber'] as double)).toList();
    final debeVals =
        datos.map((d) => (d['debe'] as double)).toList();
    final labels =
        datos.map((d) => d['label'] as String).toList();

    final maxVal = [...haberVals, ...debeVals]
        .fold(0.0, (prev, v) => v > prev ? v : prev);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal * 1.15;

    const paddingLeft = 48.0;
    const paddingBottom = 28.0;
    const paddingTop = 8.0;
    final chartW = size.width - paddingLeft;
    final chartH = size.height - paddingBottom - paddingTop;

    final gridPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 1;

    const labelStyle = TextStyle(
      fontSize: 10,
      color: Color(0xFF9CA3AF),
    );

    for (int i = 0; i <= 4; i++) {
      final y = paddingTop + chartH - (chartH * i / 4);
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width, y),
        gridPaint,
      );
      final val = effectiveMax * i / 4;
      final label = val >= 1000000
          ? '${(val / 1000000).toStringAsFixed(1)}M'
          : val >= 1000
              ? '${(val / 1000).toStringAsFixed(0)}K'
              : val.toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(paddingLeft - tp.width - 6, y - tp.height / 2));
    }

    double xOf(int i) =>
        paddingLeft + (i / (datos.length - 1)) * chartW;
    double yOf(double val) =>
        paddingTop + chartH - (val / effectiveMax) * chartH;

    // Área haber
    final haberFillPath = Path()
      ..moveTo(xOf(0), paddingTop + chartH);
    for (int i = 0; i < datos.length; i++) {
      haberFillPath.lineTo(xOf(i), yOf(haberVals[i]));
    }
    haberFillPath
      ..lineTo(xOf(datos.length - 1), paddingTop + chartH)
      ..close();
    canvas.drawPath(
      haberFillPath,
      Paint()
        ..color = const Color(0xFF10B981).withOpacity(0.08)
        ..style = PaintingStyle.fill,
    );

    // Área debe
    final debeFillPath = Path()
      ..moveTo(xOf(0), paddingTop + chartH);
    for (int i = 0; i < datos.length; i++) {
      debeFillPath.lineTo(xOf(i), yOf(debeVals[i]));
    }
    debeFillPath
      ..lineTo(xOf(datos.length - 1), paddingTop + chartH)
      ..close();
    canvas.drawPath(
      debeFillPath,
      Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.06)
        ..style = PaintingStyle.fill,
    );

    // Línea haber
    final haberPath = Path();
    for (int i = 0; i < datos.length; i++) {
      i == 0
          ? haberPath.moveTo(xOf(i), yOf(haberVals[i]))
          : haberPath.lineTo(xOf(i), yOf(haberVals[i]));
    }
    canvas.drawPath(
      haberPath,
      Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Línea debe
    final debePath = Path();
    for (int i = 0; i < datos.length; i++) {
      i == 0
          ? debePath.moveTo(xOf(i), yOf(debeVals[i]))
          : debePath.lineTo(xOf(i), yOf(debeVals[i]));
    }
    canvas.drawPath(
      debePath,
      Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Puntos haber
    for (int i = 0; i < datos.length; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(haberVals[i])), 3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(xOf(i), yOf(haberVals[i])), 3.5,
          Paint()
            ..color = const Color(0xFF10B981)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Puntos debe
    for (int i = 0; i < datos.length; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(debeVals[i])), 3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(xOf(i), yOf(debeVals[i])), 3.5,
          Paint()
            ..color = const Color(0xFFEF4444)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Etiquetas eje X
    for (int i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(xOf(i) - tp.width / 2, paddingTop + chartH + 8),
      );
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.datos != datos;
}

// ── Widget leyenda ──────────────────────────────────────────────────────────

class _LeyendaPunto extends StatelessWidget {
  final Color color;
  final String label;

  const _LeyendaPunto({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF6B7280))),
      ],
    );
  }
}

// ── Tarjeta de métrica ──────────────────────────────────────────────────────

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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ??
                        const Color(0xFF111827),
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}