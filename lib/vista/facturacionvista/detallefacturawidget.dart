import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/dao/facturaciondao/conceptocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/ciclocrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/detalle_factura.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/widget/autocomplete_ciclos.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetalleFacturaWidget extends StatefulWidget {
  final Function(DetalleFactura) onDetalleAgregado;
  final List<DetalleFactura> detallesActuales;
  final Inmuebles? inmuebleSeleccionado;

  const DetalleFacturaWidget({
    Key? key,
    required this.onDetalleAgregado,
    required this.detallesActuales,
    this.inmuebleSeleccionado,
  }) : super(key: key);

  @override
  State<DetalleFacturaWidget> createState() => _DetalleFacturaWidgetState();
}

class _DetalleFacturaWidgetState extends State<DetalleFacturaWidget> {
  final ConceptoCrudImpl _conceptoCrud = ConceptoCrudImpl();
  final CicloCrudImpl _cicloCrud = CicloCrudImpl();
  final _formKey = GlobalKey<FormState>();

  List<Concepto> _conceptos = [];
  List<Ciclo> _ciclos = [];
  Concepto? _conceptoSeleccionado;
  Ciclo? _cicloSeleccionado;

  final TextEditingController _cantidadController =
      TextEditingController(text: '1');
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  bool _isLoading = false;
  int _ivaAplicado = 10;
  double _subtotal = 0;
  bool _esConsumo = false;
  bool _esConexion = false; // ← NUEVO: detecta concepto id=2

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cantidadController.addListener(_calcularSubtotal);
    _montoController.addListener(_calcularSubtotal);
  }

  @override
  void didUpdateWidget(DetalleFacturaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inmuebleSeleccionado?.id != widget.inmuebleSeleccionado?.id &&
        _esConsumo) {
      _cicloSeleccionado = null;
      _cargarCiclosFiltrados();
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final conceptos = await _conceptoCrud.leerConceptos();
      setState(() {
        _conceptos = conceptos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  Future<void> _cargarCiclosFiltrados() async {
    final idInmueble = widget.inmuebleSeleccionado?.id;

    if (idInmueble == null) {
      final ciclos = await _cicloCrud.leerCiclos();
      setState(() => _ciclos = ciclos);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final ciclosResponse = await supabase
          .from('ciclos')
          .select('*')
          .order('inicio', ascending: true);

      final List<Ciclo> ciclos =
          (ciclosResponse as List).map((c) => Ciclo.fromMap(c)).toList();

      final detallesResponse = await supabase
          .from('detalle_factura')
          .select('fk_ciclo, factura:fk_factura!inner(fk_inmueble)')
          .eq('factura.fk_inmueble', idInmueble)
          .eq('fk_concepto', 1)
          .not('fk_ciclo', 'is', null);

      if ((detallesResponse as List).isEmpty) {
        setState(() => _ciclos = ciclos);
        return;
      }

      final Set<int> ciclosPagados =
          detallesResponse.map((d) => d['fk_ciclo'] as int).toSet();

      setState(() {
        _ciclos = ciclos.where((c) => !ciclosPagados.contains(c.id)).toList();
      });
    } catch (e) {
      _mostrarError('Error al cargar ciclos: $e');
    }
  }

  // ── NUEVO: consulta el saldo pendiente de conexión del inmueble ──────────────
  Future<double?> _obtenerSaldoConexion() async {
    final idInmueble = widget.inmuebleSeleccionado?.id;
    if (idInmueble == null) return null;

    try {
      final supabase = Supabase.instance.client;

      // Busca la deuda de conexión (fk_concepto = 2) del inmueble con saldo > 0
      final response = await supabase
          .from('cuentas_cobrar')
          .select('saldo')
          .eq('fk_inmueble', idInmueble)
          .eq('fk_concepto', 2)
          .gt('saldo', 0)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return (response['saldo'] as num).toDouble();
    } catch (e) {
      return null;
    }
  }

  void _calcularSubtotal() {
    final cantidad = double.tryParse(_cantidadController.text) ?? 0;
    final monto = double.tryParse(_montoController.text) ?? 0;
    setState(() {
      _subtotal = cantidad * monto;
    });
  }

  // ── NUEVO: dialog cuando el monto supera el saldo de conexión ───────────────
  Future<void> _mostrarDialogoSaldoExcedido(
      double montoIngresado, double saldoPendiente) async {
    final formato = NumberFormat.currency(symbol: '₲', decimalDigits: 0);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade600, size: 48),
            ),
            const SizedBox(height: 12),
            const Text(
              'Monto Excedido',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'El monto ingresado para Conexión supera el saldo pendiente del inmueble.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildFilaDialog(
                    label: 'Monto ingresado',
                    valor: formato.format(montoIngresado),
                    color: Colors.red.shade700,
                  ),
                  const Divider(height: 20),
                  _buildFilaDialog(
                    label: 'Saldo pendiente',
                    valor: formato.format(saldoPendiente),
                    color: Colors.green.shade700,
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
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El monto máximo permitido es ${formato.format(saldoPendiente)}',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaDialog(
      {required String label, required String valor, required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(valor,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ── Ahora es async para poder await la verificación de conexión ─────────────
  Future<void> _agregarDetalle() async {
    if (!_formKey.currentState!.validate()) return;

    if (_conceptoSeleccionado == null) {
      _mostrarError('Debe seleccionar un concepto');
      return;
    }

    if (_esConsumo && _cicloSeleccionado == null) {
      _mostrarError('Debe seleccionar un ciclo para el consumo');
      return;
    }

    // Validación: ciclo duplicado
    if (_esConsumo && _cicloSeleccionado != null) {
      final cicloYaExiste = widget.detallesActuales.any(
        (d) => d.fk_ciclo?.id == _cicloSeleccionado!.id,
      );
      if (cicloYaExiste) {
        _mostrarError('El ciclo "${_cicloSeleccionado!.ciclo}" ya fue agregado');
        return;
      }
    }

    // ── NUEVO: validación de saldo para concepto Conexión (id=2) ────────────
    if (_esConexion) {
      final montoIngresado =
          (double.tryParse(_cantidadController.text) ?? 1) *
              (double.tryParse(_montoController.text) ?? 0);

      final saldoPendiente = await _obtenerSaldoConexion();

      if (saldoPendiente == null) {
        _mostrarError(
            'No se encontró una deuda de conexión pendiente para este inmueble');
        return;
      }

      if (montoIngresado > saldoPendiente) {
        await _mostrarDialogoSaldoExcedido(montoIngresado, saldoPendiente);
        return; // No agrega el detalle; el usuario corrige el monto
      }
    }

    final cantidad = double.parse(_cantidadController.text);
    final precioUnitario = double.parse(_montoController.text);

    final detalle = DetalleFactura(
      fk_concepto: _conceptoSeleccionado!,
      monto: precioUnitario,
      descripcion: _descripcionController.text.isEmpty
          ? _conceptoSeleccionado!.nombre
          : _descripcionController.text,
      iva_aplicado: _ivaAplicado,
      subtotal: cantidad * precioUnitario,
      estado: 'ACTIVO',
      cantidad: cantidad,
      fk_ciclo: _esConsumo ? _cicloSeleccionado : null,
    );

    widget.onDetalleAgregado(detalle);
    _limpiarFormulario();
  }

  void _limpiarFormulario() {
    _cantidadController.text = '1';
    _montoController.clear();
    _descripcionController.clear();
    setState(() {
      _conceptoSeleccionado = null;
      _cicloSeleccionado = null;
      _ivaAplicado = 10;
      _subtotal = 0;
      _esConsumo = false;
      _esConexion = false; // ← NUEVO
    });
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Agregar Item',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Concepto
              DropdownButtonFormField<Concepto>(
                value: _conceptoSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Concepto *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _conceptos.map((concepto) {
                  return DropdownMenuItem(
                    value: concepto,
                    child: Text(concepto.nombre),
                  );
                }).toList(),
                onChanged: (concepto) {
                  setState(() {
                    _conceptoSeleccionado = concepto;
                    if (concepto != null) {
                      _montoController.text =
                          concepto.arancel.toStringAsFixed(0);
                      _ivaAplicado = concepto.fk_iva.valor;
                      _descripcionController.text = concepto.nombre;
                      _esConsumo = concepto.id == 1;
                      _esConexion = concepto.id == 2; // ← NUEVO
                      if (!_esConsumo) {
                        _cicloSeleccionado = null;
                        _ciclos = [];
                      } else {
                        _cargarCiclosFiltrados();
                      }
                    }
                  });
                },
                validator: (value) =>
                    value == null ? 'Seleccione un concepto' : null,
              ),
              const SizedBox(height: 12),

              // Ciclo (solo visible si es consumo)
              if (_esConsumo) ...[
                CicloAutocomplete(
                  ciclos: _ciclos,
                  onSeleccionado: (ciclo) {
                    setState(() {
                      _cicloSeleccionado = ciclo;
                      _descripcionController.text = 'Consumo ${ciclo.descripcion}';
                    });
                  },
                  validator: (_) => _esConsumo && _cicloSeleccionado == null
                      ? 'Debe seleccionar un ciclo'
                      : null,
                ),
                const SizedBox(height: 12),
              ],

              // Cantidad y Monto
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cantidadController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Cantidad *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo requerido';
                        final cantidad = double.tryParse(value!);
                        if (cantidad == null) return 'Solo se permiten números';
                        if (cantidad <= 0)
                          return 'La cantidad debe ser mayor a 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _montoController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Monto Unit. *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        suffixText: 'Gs.',
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo requerido';
                        final monto = double.tryParse(value!);
                        if (monto == null) return 'Solo se permiten números';
                        if (monto <= 0) return 'El monto debe ser mayor a 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // IVA
              DropdownButtonFormField<int>(
                value: _ivaAplicado,
                decoration: InputDecoration(
                  labelText: 'IVA *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.percent),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Exenta (0%)')),
                  DropdownMenuItem(value: 5, child: Text('IVA 5%')),
                  DropdownMenuItem(value: 10, child: Text('IVA 10%')),
                ],
                onChanged: (value) {
                  setState(() => _ivaAplicado = value!);
                  _calcularSubtotal();
                },
              ),
              const SizedBox(height: 12),

              // Descripción
              TextFormField(
                controller: _descripcionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),

              // Subtotal y botón
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subtotal:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        '${_subtotal.toStringAsFixed(0)} Gs.',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0085FF),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _agregarDetalle, // async, Flutter lo maneja bien
                    icon: Icon(Icons.add),
                    label: Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Lista de detalles agregados
              if (widget.detallesActuales.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Items agregados',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...widget.detallesActuales.asMap().entries.map((entry) {
                  final index = entry.key;
                  final detalle = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(detalle.descripcion),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${detalle.cantidad} x ${detalle.monto.toStringAsFixed(0)} Gs. - IVA ${detalle.iva_aplicado}%',
                          ),
                          if (detalle.fk_ciclo != null)
                            Text(
                              'Ciclo: ${detalle.fk_ciclo!.ciclo}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      trailing: Text(
                        '${detalle.subtotal.toStringAsFixed(0)} Gs.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _montoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}