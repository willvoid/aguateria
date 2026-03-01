import 'package:flutter/material.dart';
import 'package:myapp/dao/facturaciondao/apertura_cierre_cajacrudimpl.dart';
import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/facturacionmodelo/apertura_cierre_caja.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/pago.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/service/pago_deuda_service.dart';
import 'package:myapp/widget/dialogo_exito_factura.dart';
import 'package:myapp/widget/selector_ciclos_widget.dart';
import 'package:myapp/widget/selector_metodo_pago.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PagarDeudaDialog extends StatefulWidget {
  final CuentaCobrar deuda;
  final Cliente cliente;
  final Inmuebles inmueble;
  final int idUsuario;

  const PagarDeudaDialog({
    Key? key,
    required this.deuda,
    required this.cliente,
    required this.inmueble,
    required this.idUsuario,
  }) : super(key: key);

  @override
  State<PagarDeudaDialog> createState() => _PagarDeudaDialogState();
}

class _PagarDeudaDialogState extends State<PagarDeudaDialog> {
  final PagoDeudaService _pagoService = PagoDeudaService();
  final TextEditingController _efectivoController = TextEditingController();

  List<Ciclo> _ciclosDisponibles = [];
  List<Ciclo> _ciclosSeleccionados = [];

  bool _isLoading = true;
  double _totalAPagar = 0.0;
  double _vuelto = 0.0;
  double _totalGravado = 0.0;
  double _totalIva = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _efectivoController.addListener(_calcularVuelto);
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      final esConsumo = widget.deuda.fk_concepto.id == 1;

      if (esConsumo) {
        final ciclos = await _pagoService.cargarCiclosDisponiblesConsumo(
          widget.inmueble.id!,
        );
        setState(() {
          _ciclosDisponibles = ciclos;
          _isLoading = false;
        });
      } else {
        setState(() {
          _totalAPagar = widget.deuda.saldo;
          _calcularTotales();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _toggleCiclo(Ciclo ciclo) {
    setState(() {
      if (_ciclosSeleccionados.contains(ciclo)) {
        _ciclosSeleccionados.remove(ciclo);
      } else {
        _ciclosSeleccionados.add(ciclo);
      }
      _calcularTotales();
    });
  }

  void _calcularTotales() {
    final esConsumo = widget.deuda.fk_concepto.id == 1;

    if (esConsumo) {
      final montoPorCiclo = widget.deuda.fk_concepto.arancel;
      _totalAPagar = montoPorCiclo * _ciclosSeleccionados.length;
    } else {
      _totalAPagar = widget.deuda.saldo;
    }

    final totales = _pagoService.calcularTotales(
      _totalAPagar,
      widget.deuda.fk_concepto.fk_iva.valor,
    );

    setState(() {
      _totalGravado =
          totales['totalGravado10']! +
          totales['totalGravado5']! +
          totales['totalExenta']!;
      _totalIva = totales['totalIva']!;
      _calcularVuelto();
    });
  }

  void _calcularVuelto() {
    final efectivo = double.tryParse(_efectivoController.text) ?? 0;
    setState(() {
      _vuelto = efectivo - _totalAPagar;
    });
  }

  Future<void> _procesarPago() async {
    // Validar datos básicos
    final error = _pagoService.validarPago(
      deuda: widget.deuda,
      ciclosSeleccionados: _ciclosSeleccionados,
      efectivo: double.tryParse(_efectivoController.text) ?? 0,
    );

    if (error != null) {
      _mostrarError(error);
      return;
    }

    // ── PASO 0: Obtener turno activo ─────────────────────────────────────
    final turnoActivo = await _obtenerTurnoActivo();

    if (turnoActivo == null) {
      _mostrarError(
        'No hay un turno de caja activo.\n\nDebe abrir caja antes de procesar pagos.',
      );
      return;
    }

    // ── PASO 1: Seleccionar método de pago ───────────────────────────────
    ModoPago? modoPagoSeleccionado;
    Pago? pagoConComprobante;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SelectorMetodoPagoDialog(
        totalAPagar: _totalAPagar,
        idUsuario: widget.idUsuario,
        cliente: widget.cliente,
        payloadFactura: (ModoPago modoPago) => _construirPayloadCompleto(
          turnoActivo: turnoActivo,
          modoPago: modoPago,
        ),
        onMetodoSeleccionado: (modoPago, pagoCreado) {
          modoPagoSeleccionado = modoPago;
          pagoConComprobante = pagoCreado;
        },
      ),
    );

    // ── Si el usuario cerró el selector sin elegir, no hacer nada ────────
    if (modoPagoSeleccionado == null || !mounted) return;

    // ── PASO 2: Según el método, procesar de forma diferente ─────────────
    final esTransferenciaOGiro =
        modoPagoSeleccionado!.id_modo_pago == 5 ||
        modoPagoSeleccionado!.id_modo_pago == 6;

    if (esTransferenciaOGiro && pagoConComprobante != null) {
      // Transferencia/Giro: mostrar diálogo informativo y cerrar con true
      await _mostrarDialogoPagoPendiente(
        modoPagoSeleccionado!,
        pagoConComprobante!,
      );
      // ✅ Cerrar PagarDeudaDialog retornando true → dispara _cargarDeudas()
      if (mounted) Navigator.pop(context, true);
    } else if (!esTransferenciaOGiro) {
      // Efectivo, Tarjeta, etc.: procesar factura directamente
      await _procesarFactura(modoPagoSeleccionado!);
      // _procesarFactura ya hace Navigator.pop(context, true) al final
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  Future<AperturaCierreCaja?> _obtenerTurnoActivo() async {
    try {
      final crudTurno = AperturaCierreCajaCrudImpl();
      final aperturas = await crudTurno.leerAperturasPorUsuario(widget.idUsuario);

      if (aperturas.isEmpty) return null;

      final turnoAbierto = aperturas.firstWhere(
        (apertura) => apertura.cierre == null,
        orElse: () => throw Exception('No hay turno abierto'),
      );

      return turnoAbierto;
    } catch (e) {
      print('❌ Error al obtener turno activo: $e');
      return null;
    }
  }

  Map<String, dynamic> _construirPayloadCompleto({
    required AperturaCierreCaja turnoActivo,
    required ModoPago modoPago,
  }) {
    final ivaValor = widget.deuda.fk_concepto.fk_iva.valor;
    double totalGravado10 = 0;
    double totalGravado5 = 0;
    double totalExenta = 0;

    if (ivaValor == 10) {
      totalGravado10 = _totalGravado;
    } else if (ivaValor == 5) {
      totalGravado5 = _totalGravado;
    } else {
      totalExenta = _totalAPagar;
    }

    final detalles = _construirDetallesFactura();

    return {
      'fechaEmision': DateTime.now().toUtc().toIso8601String(),
      'fk_cliente': widget.cliente.idCliente,
      'fk_inmueble': widget.inmueble.id,
      'condicion_venta': 1,
      'total_gravado_10': double.parse(totalGravado10.toStringAsFixed(2)),
      'total_gravado_5': double.parse(totalGravado5.toStringAsFixed(2)),
      'total_exenta': double.parse(totalExenta.toStringAsFixed(2)),
      'total_iva': double.parse(_totalIva.toStringAsFixed(2)),
      'total_general': double.parse(_totalAPagar.toStringAsFixed(2)),
      'observacion': _construirObservacion(),
      'fk_monedas': 1,
      'fk_establecimientos': 1,
      'fk_modo_pago': modoPago.id_modo_pago,
      'fk_tipo_factura': 1,
      'nro_secuencial': 0,
      'fk_turno': turnoActivo.id_turno,
      'tipo_emision': 1,
      'fk_motivo': null,
      'fk_factura_asociada': null,
      'efectivo': 0,
      'vuelto': 0,
      'descuento_global': 0,
      'detalles': detalles,
    };
  }

  Future<void> _procesarFactura(ModoPago modoPago) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Procesando pago...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final facturaCreada = await _pagoService.procesarPagoDeuda(
        deuda: widget.deuda,
        cliente: widget.cliente,
        inmueble: widget.inmueble,
        ciclosSeleccionados: _ciclosSeleccionados,
        efectivo: double.parse(_efectivoController.text),
        idUsuario: widget.idUsuario,
        idModoPago: modoPago.id_modo_pago,
      );

      if (mounted) Navigator.pop(context); // cerrar loading

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => FacturaSuccessDialog(
            facturaCreada: facturaCreada,
            clienteNombre: widget.cliente.razonSocial,
            onImprimir: () {
              print('📄 Imprimir factura de pago de deuda');
            },
          ),
        );

        // ✅ Cerrar retornando true → dispara _cargarDeudas() en DeudasClientesPage
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // cerrar loading
      _mostrarError('Error al procesar pago: $e');
    }
  }

  Future<void> _mostrarDialogoPagoPendiente(
    ModoPago modoPago,
    Pago pago,
  ) async {
    final color = modoPago.id_modo_pago == 5 ? Colors.teal : Colors.indigo;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pending_actions,
                color: Colors.orange.shade600,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Pago Pendiente de Aprobación',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Su comprobante de ${modoPago.descripcion.toLowerCase()} ha sido registrado exitosamente.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('ID de Pago', '#${pago.idPago}', Icons.tag, color),
                    const Divider(height: 16),
                    _buildInfoRow('Método', modoPago.descripcion, Icons.payment, color),
                    const Divider(height: 16),
                    _buildInfoRow(
                      'Monto',
                      '${pago.monto.toStringAsFixed(0)} Gs.',
                      Icons.attach_money,
                      color,
                    ),
                    const Divider(height: 16),
                    _buildInfoRow(
                      'Estado',
                      pago.estado,
                      Icons.info_outline,
                      Colors.orange,
                    ),
                    const Divider(height: 16),
                    _buildInfoRow(
                      'Fecha',
                      _formatearFecha(pago.fechaPago!),
                      Icons.calendar_today,
                      color,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El pago será procesado una vez que un administrador verifique y apruebe el comprobante.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Para consultas, comuníquese con administración presentando el ID de pago #${pago.idPago}.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            // ✅ Botón "Entendido" cierra solo este AlertDialog
            // El Navigator.pop(context, true) del PagarDeudaDialog
            // se ejecuta justo después en _procesarPago()
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    // ← cuando este await termina, _procesarPago() ejecuta Navigator.pop(context, true)
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatearFecha(DateTime fecha) {
    final meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year} - '
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
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

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final esConsumo = widget.deuda.fk_concepto.id == 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildResumenDeuda(),
                          const SizedBox(height: 24),
                          if (esConsumo)
                            _buildResumenCiclosSeleccionados()
                          else
                            _buildMontoFijo(),
                          const SizedBox(height: 24),
                          _buildResumenTotales(),
                          const SizedBox(height: 24),
                          _buildInputEfectivo(),
                          const SizedBox(height: 24),
                          _buildBotones(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final IconData icono;
    final Color color;

    switch (widget.deuda.fk_concepto.id) {
      case 1:
        icono = Icons.water_drop;
        color = Colors.blue;
        break;
      case 2:
        icono = Icons.electrical_services;
        color = Colors.orange;
        break;
      default:
        icono = Icons.receipt_long;
        color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pagar Deuda',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  widget.deuda.fk_concepto.nombre,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildResumenDeuda() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Información del Inmueble',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          _buildInfoRowSimple('Código', widget.inmueble.cod_inmueble),
          const SizedBox(height: 8),
          _buildInfoRowSimple('Dirección', widget.inmueble.direccion ?? 'Sin dirección'),
          const SizedBox(height: 8),
          _buildInfoRowSimple('Cliente', widget.cliente.razonSocial),
        ],
      ),
    );
  }

  Widget _buildInfoRowSimple(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.black87 : Colors.grey.shade800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildResumenCiclosSeleccionados() {
    final montoPorCiclo = widget.deuda.fk_concepto.arancel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ciclos a Pagar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _abrirSelectorCiclos,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Agregar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0085FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_ciclosSeleccionados.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.touch_app, color: Colors.blue.shade300, size: 48),
                const SizedBox(height: 12),
                Text(
                  'No hay ciclos seleccionados',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toca el botón "Agregar" para seleccionar ciclos',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.check_circle,
                          color: Colors.green.shade600, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_ciclosSeleccionados.length} ciclo(s) seleccionado(s)',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Precio por ciclo: ${montoPorCiclo.toStringAsFixed(0)} Gs.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _abrirSelectorCiclos,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Editar'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0085FF)),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ..._ciclosSeleccionados.map((ciclo) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.water_drop,
                            size: 16, color: Colors.blue.shade400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ciclo.descripcion,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w500)),
                              Text(
                                'Ciclo ${ciclo.ciclo} - Año ${ciclo.anio}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${montoPorCiclo.toStringAsFixed(0)} Gs.',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _abrirSelectorCiclos() async {
    await showDialog(
      context: context,
      builder: (context) => SelectorCiclosDialog(
        ciclosDisponibles: _ciclosDisponibles,
        ciclosSeleccionados: _ciclosSeleccionados,
        montoPorCiclo: widget.deuda.fk_concepto.arancel,
        onCiclosSeleccionados: (ciclosSeleccionados) {
          setState(() {
            _ciclosSeleccionados = ciclosSeleccionados;
            _calcularTotales();
          });
        },
      ),
    );
  }

  Widget _buildMontoFijo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money, color: Colors.blue.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monto a Pagar',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  '${widget.deuda.saldo.toStringAsFixed(0)} Gs.',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0085FF),
                  ),
                ),
                Text(
                  widget.deuda.descripcion,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.deuda.pagado > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Pagado: ${widget.deuda.pagado.toStringAsFixed(0)} Gs.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTotales() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text('Resumen del Pago',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 16),
          _buildTotalRow('Subtotal', _totalGravado),
          const SizedBox(height: 8),
          _buildTotalRow(
              'IVA (${widget.deuda.fk_concepto.fk_iva.valor}%)', _totalIva),
          const Divider(height: 16),
          _buildTotalRow('TOTAL', _totalAPagar, isTotal: true),
          if (widget.deuda.fk_concepto.id == 1 &&
              _ciclosSeleccionados.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_ciclosSeleccionados.length} ciclo(s) seleccionado(s)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputEfectivo() {
    final esValido = _vuelto >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _efectivoController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Efectivo Recibido *',
            prefixIcon: const Icon(Icons.payments),
            suffixText: 'Gs.',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: esValido ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: esValido ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                esValido ? Icons.check_circle : Icons.warning,
                color:
                    esValido ? Colors.green.shade700 : Colors.red.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vuelto',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                    Text(
                      '${_vuelto.toStringAsFixed(0)} Gs.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: esValido
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    if (!esValido)
                      Text('Insuficiente',
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _construirDetallesFactura() {
    final esConsumo = widget.deuda.fk_concepto.id == 1;
    final ivaValor = widget.deuda.fk_concepto.fk_iva.valor;

    if (esConsumo && _ciclosSeleccionados.isNotEmpty) {
      return _ciclosSeleccionados.map((ciclo) {
        final montoPorCiclo = widget.deuda.fk_concepto.arancel;
        return {
          'fk_concepto': widget.deuda.fk_concepto.id,
          'monto': double.parse(montoPorCiclo.toStringAsFixed(2)),
          'descripcion':
              '${widget.deuda.fk_concepto.nombre} - ${ciclo.descripcion}',
          'iva_aplicado': ivaValor,
          'subtotal': double.parse(montoPorCiclo.toStringAsFixed(2)),
          'estado': 'PENDIENTE',
          'cantidad': 1.0,
          'fk_consumos': null,
          'fk_deudas': widget.deuda.id_deuda,
          'fk_ciclo': ciclo.id,
        };
      }).toList();
    } else {
      return [
        {
          'fk_concepto': widget.deuda.fk_concepto.id,
          'monto': double.parse(_totalAPagar.toStringAsFixed(2)),
          'descripcion':
              widget.deuda.descripcion ?? widget.deuda.fk_concepto.nombre,
          'iva_aplicado': ivaValor,
          'subtotal': double.parse(_totalAPagar.toStringAsFixed(2)),
          'estado': 'PENDIENTE',
          'cantidad': 1.0,
          'fk_consumos': null,
          'fk_deudas': widget.deuda.id_deuda,
          'fk_ciclo': null,
        },
      ];
    }
  }

  String _construirObservacion() {
    final esConsumo = widget.deuda.fk_concepto.id == 1;

    if (esConsumo && _ciclosSeleccionados.isNotEmpty) {
      final ciclosTexto =
          _ciclosSeleccionados.map((c) => 'Ciclo ${c.ciclo}/${c.anio}').join(', ');
      return 'Pago de ${widget.deuda.fk_concepto.nombre} - $ciclosTexto - Aprobación de Transferencia';
    } else {
      return 'Pago de ${widget.deuda.fk_concepto.nombre} - Aprobación de Transferencia';
    }
  }

  Widget _buildBotones() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed:
                _totalAPagar > 0 && _vuelto >= 0 ? _procesarPago : null,
            icon: const Icon(Icons.payment),
            label: const Text('Procesar Pago'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0085FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, double valor, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${valor.toStringAsFixed(0)} Gs.',
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color:
                isTotal ? const Color(0xFF0085FF) : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _efectivoController.dispose();
    super.dispose();
  }
}