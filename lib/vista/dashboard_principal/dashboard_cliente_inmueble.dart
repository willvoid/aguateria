import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DashboardClientesInmueblesPage extends StatefulWidget {
  const DashboardClientesInmueblesPage({Key? key}) : super(key: key);

  @override
  State<DashboardClientesInmueblesPage> createState() =>
      _DashboardClientesInmueblesPageState();
}

class _DashboardClientesInmueblesPageState
    extends State<DashboardClientesInmueblesPage> {
  bool _isLoading = true;

  // ── Métricas clientes ───────────────────────────────────────────────────────
  int _totalActivos = 0;
  int _totalInactivos = 0;
  int _nuevosEsteMes = 0;

  // ── Métricas inmuebles ──────────────────────────────────────────────────────
  int _totalInmuebles = 0;
  int _inmueblesConDeuda = 0;

  // ── Datos para gráfico de barras ────────────────────────────────────────────
  // { nombre: String, total: int }
  List<Map<String, dynamic>> _porCategoria = [];

  // ── Top deudores ─────────────────────────────────────────────────────────────
  // { razon_social, documento, inmuebles, saldo, estado }
  List<Map<String, dynamic>> _topDeudores = [];

  final DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _cargarMetricasClientes(),
        _cargarMetricasInmuebles(),
        _cargarPorCategoria(),
        _cargarTopDeudores(),
      ]);
    } catch (e) {
      print('❌ Error dashboard clientes/inmuebles: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarMetricasClientes() async {
    final inicioMes = DateTime(_ahora.year, _ahora.month, 1).toIso8601String();

    final results = await Future.wait([
      supabase.from('clientes').select('id_cliente').eq('estado_cliente', 'ACTIVO'),
      supabase.from('clientes').select('id_cliente').eq('estado_cliente', 'INACTIVO'),
      supabase.from('clientes').select('id_cliente').gte('created_at', inicioMes),
    ]);

    setState(() {
      _totalActivos = (results[0] as List).length;
      _totalInactivos = (results[1] as List).length;
      _nuevosEsteMes = (results[2] as List).length;
    });
  }

  Future<void> _cargarMetricasInmuebles() async {
    final results = await Future.wait([
      supabase.from('inmuebles').select('id'),
      // Inmuebles con al menos una deuda con saldo > 0
      supabase
          .from('cuentas_cobrar')
          .select('fk_inmueble')
          .gt('saldo', 0)
          .eq('estado', 'PENDIENTE'),
    ]);

    final inmuebles = (results[0] as List).length;
    // Contar inmuebles únicos con deuda
    final conDeuda = (results[1] as List)
        .map((r) => r['fk_inmueble'])
        .toSet()
        .length;

    setState(() {
      _totalInmuebles = inmuebles;
      _inmueblesConDeuda = conDeuda;
    });
  }

  Future<void> _cargarPorCategoria() async {
    // Traer inmuebles con su categoría — query liviana
    final data = await supabase
        .from('inmuebles')
        .select('fk_categoria_servicio, categoria_servicio!fk_categoria_servicio(nombre)');

    // Agrupar en Dart
    final Map<String, int> conteo = {};
    for (final row in data) {
      final cat = row['categoria_servicio'];
      final nombre = cat != null ? (cat['nombre'] as String? ?? 'Sin categoría') : 'Sin categoría';
      conteo[nombre] = (conteo[nombre] ?? 0) + 1;
    }

    final lista = conteo.entries
        .map((e) => {'nombre': e.key, 'total': e.value})
        .toList();
    lista.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

    setState(() => _porCategoria = lista);
  }

  Future<void> _cargarTopDeudores() async {
    // Obtener top deudas agrupadas por inmueble con saldo pendiente
    final data = await supabase
        .from('cuentas_cobrar')
        .select('''
          fk_inmueble,
          saldo,
          estado,
          inmuebles!fk_inmueble(
            fk_cliente,
            clientes!fk_cliente(razon_social, documento)
          )
        ''')
        .gt('saldo', 0)
        .order('saldo', ascending: false)
        .limit(30);

    // Agrupar por cliente sumando saldos
    final Map<int, Map<String, dynamic>> porCliente = {};
    for (final row in data) {
      final inmueble = row['inmuebles'];
      if (inmueble == null) continue;
      final cliente = inmueble['clientes'];
      if (cliente == null) continue;
      final fkCliente = inmueble['fk_cliente'] as int;
      final saldo = (row['saldo'] as num).toDouble();
      final estado = row['estado'] as String? ?? '';

      if (!porCliente.containsKey(fkCliente)) {
        porCliente[fkCliente] = {
          'razon_social': cliente['razon_social'] ?? '',
          'documento': cliente['documento'] ?? '',
          'inmuebles': 0,
          'saldo': 0.0,
          'estado': estado,
        };
      }
      porCliente[fkCliente]!['saldo'] =
          (porCliente[fkCliente]!['saldo'] as double) + saldo;
      porCliente[fkCliente]!['inmuebles'] =
          (porCliente[fkCliente]!['inmuebles'] as int) + 1;
      // Si alguna deuda está vencida, marcar como vencida
      if (estado == 'VENCIDA') {
        porCliente[fkCliente]!['estado'] = 'VENCIDA';
      }
    }

    final lista = porCliente.values.toList();
    lista.sort((a, b) =>
        (b['saldo'] as double).compareTo(a['saldo'] as double));

    setState(() => _topDeudores = lista.take(5).toList());
  }

  // ── Formato ─────────────────────────────────────────────────────────────────

  String _formatGuarani(double valor) {
    if (valor >= 1000000) return '₲ ${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return '₲ ${(valor / 1000).toStringAsFixed(0)}K';
    return '₲ ${valor.toStringAsFixed(0)}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
                  const SizedBox(height: 20),
                  _buildSeccionLabel('Clientes e inmuebles'),
                  const SizedBox(height: 12),
                  _buildMetricasRow(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildTopDeudores()),
                      const SizedBox(width: 16),
                      //Expanded(flex: 3, child: _buildGraficoCategorias()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clientes e inmuebles',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Resumen general del padrón',
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

  Widget _buildSeccionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.8,
      ),
    );
  }

  // ── Tarjetas métricas ─────────────────────────────────────────────────────────

  Widget _buildMetricasRow() {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Clientes activos',
            value: _totalActivos.toString(),
            sub: '+$_nuevosEsteMes este mes',
            subColor: Colors.green.shade600,
            icon: Icons.people_alt_outlined,
            iconColor: const Color(0xFF0085FF),
            iconBg: const Color(0xFFE6F0FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Inmuebles conectados',
            value: _totalInmuebles.toString(),
            sub: 'por $_totalActivos clientes',
            icon: Icons.home_outlined,
            iconColor: Colors.green.shade600,
            iconBg: Colors.green.shade50,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Con deuda activa',
            value: _inmueblesConDeuda.toString(),
            sub: _totalInmuebles > 0
                ? '${(_inmueblesConDeuda / _totalInmuebles * 100).toStringAsFixed(1)}% del total'
                : '0% del total',
            subColor: Colors.red.shade600,
            icon: Icons.warning_amber_outlined,
            iconColor: Colors.orange.shade600,
            iconBg: Colors.orange.shade50,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Clientes inactivos',
            value: _totalInactivos.toString(),
            sub: 'requieren revisión',
            icon: Icons.person_off_outlined,
            iconColor: Colors.grey.shade500,
            iconBg: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  // ── Top deudores ──────────────────────────────────────────────────────────────

  Widget _buildTopDeudores() {
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
                  'Top deudores — saldo pendiente',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade200, height: 1),
          _topDeudores.isEmpty
              ? _buildEmptyState(Icons.check_circle_outline, 'Sin deudas pendientes')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _topDeudores.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade100, height: 1),
                  itemBuilder: (context, index) {
                    final d = _topDeudores[index];
                    final estado = d['estado'] as String;
                    final esVencido = estado == 'VENCIDA';
                    final inmuebles = d['inmuebles'] as int;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d['razon_social'] as String,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'CI ${d['documento']} · $inmuebles ${inmuebles == 1 ? 'inmueble' : 'inmuebles'}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatGuarani(d['saldo'] as double),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildBadge(
                                esVencido ? 'vencido' : 'por vencer',
                                esVencido
                                    ? Colors.red.shade50
                                    : Colors.orange.shade50,
                                esVencido
                                    ? Colors.red.shade700
                                    : Colors.orange.shade700,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Gráfico barras horizontales por categoría ─────────────────────────────────

  Widget _buildGraficoCategorias() {
    final maxVal = _porCategoria.isEmpty
        ? 1
        : (_porCategoria.first['total'] as int);

    final colores = [
      const Color(0xFF5DCAA5),
      const Color(0xFF85B7EB),
      const Color(0xFFEF9F27),
      const Color(0xFFED93B1),
      const Color(0xFFAFA9EC),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inmuebles por categoría de servicio',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),
          _porCategoria.isEmpty
              ? _buildEmptyState(Icons.category_outlined, 'Sin datos')
              : Column(
                  children: List.generate(_porCategoria.length, (i) {
                    final item = _porCategoria[i];
                    final nombre = item['nombre'] as String;
                    final total = item['total'] as int;
                    final pct = maxVal > 0 ? total / maxVal : 0.0;
                    final color = colores[i % colores.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          // Label
                          SizedBox(
                            width: 110,
                            child: Text(
                              nombre,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Barra
                          Expanded(
                            child: Stack(
                              children: [
                                // Fondo
                                Container(
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                // Relleno animado
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOut,
                                  height: 28,
                                  width: double.infinity,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: pct.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Número
                          SizedBox(
                            width: 36,
                            child: Text(
                              '$total',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
          if (_porCategoria.isNotEmpty) ...[
            const SizedBox(height: 4),
            Divider(color: Colors.grey.shade100),
            const SizedBox(height: 8),
            // Eje X con referencia numérica
            Row(
              children: [
                const SizedBox(width: 122),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (i) {
                      final val = (maxVal * i / 4).round();
                      return Text(
                        '$val',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF9CA3AF)),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 46),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────────

  Widget _buildBadge(String texto, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        texto,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String mensaje) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(mensaje,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta métrica ───────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _MetricCard({
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: TextStyle(
                fontSize: 12,
                color: subColor ?? const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ],
      ),
    );
  }
}