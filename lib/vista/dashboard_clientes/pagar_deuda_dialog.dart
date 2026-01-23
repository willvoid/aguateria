import 'package:flutter/material.dart';
import 'package:myapp/modelo/deuda.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/service/pago_deuda_service.dart';
import 'package:myapp/widget/dialogo_exito_factura.dart';


class PagarDeudaDialog extends StatefulWidget {
  final Deuda deuda;
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

  // Para deudas de consumo: lista de ciclos disponibles
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
        // Cargar ciclos disponibles para consumo
        final ciclos = await _pagoService.cargarCiclosDisponiblesConsumo(
          widget.inmueble.id!,
        );
        
        setState(() {
          _ciclosDisponibles = ciclos;
          _isLoading = false;
        });
      } else {
        // Si no es consumo, usar directamente el saldo de la deuda
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
      // El monto viene del arancel del concepto, multiplicado por cantidad de ciclos
      final montoPorCiclo = widget.deuda.fk_concepto.arancel;
      _totalAPagar = montoPorCiclo * _ciclosSeleccionados.length;
    } else {
      _totalAPagar = widget.deuda.saldo;
    }

    // Calcular IVA y base gravada
    final totales = _pagoService.calcularTotales(
      _totalAPagar,
      widget.deuda.fk_concepto.fk_iva.valor,
    );

    setState(() {
      _totalGravado = totales['totalGravado10']! + totales['totalGravado5']! + totales['totalExenta']!;
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
    // Validar
    final error = _pagoService.validarPago(
      deuda: widget.deuda,
      ciclosSeleccionados: _ciclosSeleccionados,
      efectivo: double.tryParse(_efectivoController.text) ?? 0,
    );

    if (error != null) {
      _mostrarError(error);
      return;
    }

    // Mostrar loading
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
      );

      // Cerrar loading
      if (mounted) Navigator.pop(context);

      // Mostrar éxito
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

        // Cerrar el dialog de pago
        Navigator.pop(context, true); // true indica que se pagó exitosamente
      }
    } catch (e) {
      // Cerrar loading
      if (mounted) Navigator.pop(context);
      _mostrarError('Error al procesar pago: $e');
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

  @override
  Widget build(BuildContext context) {
    final esConsumo = widget.deuda.fk_concepto.id == 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),
            
            // Contenido scrolleable
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Resumen de la deuda
                          _buildResumenDeuda(),
                          const SizedBox(height: 24),

                          // Selector de ciclos o monto fijo
                          if (esConsumo) ...[
                            _buildSelectorCiclos(),
                          ] else ...[
                            _buildMontoFijo(),
                          ],
                          const SizedBox(height: 24),

                          // Resumen de totales
                          _buildResumenTotales(),
                          const SizedBox(height: 24),

                          // Input de efectivo
                          _buildInputEfectivo(),
                          const SizedBox(height: 24),

                          // Botones
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
      case 1: // Consumo
        icono = Icons.water_drop;
        color = Colors.blue;
        break;
      case 2: // Conexión
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
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
          _buildInfoRow('Código', widget.inmueble.cod_inmueble),
          const SizedBox(height: 8),
          _buildInfoRow('Dirección', widget.inmueble.direccion ?? "Sin dirección"),
          const SizedBox(height: 8),
          _buildInfoRow('Cliente', widget.cliente.razonSocial),
        ],
      ),
    );
  }

  Widget _buildSelectorCiclos() {
    final montoPorCiclo = widget.deuda.fk_concepto.arancel;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Seleccione los ciclos a pagar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Precio por ciclo: ${montoPorCiclo.toStringAsFixed(0)} Gs.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        if (_ciclosDisponibles.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('No hay ciclos pendientes de pago'),
                ),
              ],
            ),
          )
        else
          ..._ciclosDisponibles.map((ciclo) {
            final isSelected = _ciclosSeleccionados.contains(ciclo);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isSelected ? Colors.blue.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _toggleCiclo(ciclo),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleCiclo(ciclo),
                          activeColor: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ciclo.descripcion,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ciclo: ${ciclo.ciclo}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (ciclo.vencimiento != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Vence: ${ciclo.vencimiento.toString().split(' ')[0]}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ciclo.vencimiento!.isBefore(DateTime.now())
                                        ? Colors.red.shade700
                                        : Colors.grey.shade600,
                                    fontWeight: ciclo.vencimiento!.isBefore(DateTime.now())
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '${montoPorCiclo.toStringAsFixed(0)} Gs.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.blue : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
      ],
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
                const Text(
                  'Monto a Pagar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.deuda.pagado > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              const Text(
                'Resumen del Pago',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          _buildTotalRow('Subtotal', _totalGravado),
          const SizedBox(height: 8),
          _buildTotalRow('IVA (${widget.deuda.fk_concepto.fk_iva.valor}%)', _totalIva),
          const Divider(height: 16),
          _buildTotalRow('TOTAL', _totalAPagar, isTotal: true),
          if (widget.deuda.fk_concepto.id == 1 && _ciclosSeleccionados.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_ciclosSeleccionados.length} ciclo(s) seleccionado(s)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
                color: esValido ? Colors.green.shade700 : Colors.red.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vuelto',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${_vuelto.toStringAsFixed(0)} Gs.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: esValido ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                    if (!esValido)
                      Text(
                        'Insuficiente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
            onPressed: _totalAPagar > 0 && _vuelto >= 0 ? _procesarPago : null,
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

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
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
            color: isTotal ? const Color(0xFF0085FF) : Colors.grey.shade800,
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