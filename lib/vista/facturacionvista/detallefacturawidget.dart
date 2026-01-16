import 'package:flutter/material.dart';
import 'package:myapp/dao/facturaciondao/conceptocrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/detalle_factura.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';

class DetalleFacturaWidget extends StatefulWidget {
  final Function(DetalleFactura) onDetalleAgregado;
  final List<DetalleFactura> detallesActuales;

  const DetalleFacturaWidget({
    Key? key,
    required this.onDetalleAgregado,
    required this.detallesActuales,
  }) : super(key: key);

  @override
  State<DetalleFacturaWidget> createState() => _DetalleFacturaWidgetState();
}

class _DetalleFacturaWidgetState extends State<DetalleFacturaWidget> {
  final ConceptoCrudImpl _conceptoCrud = ConceptoCrudImpl();
  final _formKey = GlobalKey<FormState>();

  List<Concepto> _conceptos = [];
  Concepto? _conceptoSeleccionado;
  
  final TextEditingController _cantidadController = TextEditingController(text: '1');
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  
  bool _isLoading = false;
  int _ivaAplicado = 10;
  double _subtotal = 0;

  @override
  void initState() {
    super.initState();
    _cargarConceptos();
    _cantidadController.addListener(_calcularSubtotal);
    _montoController.addListener(_calcularSubtotal);
  }

  Future<void> _cargarConceptos() async {
    setState(() => _isLoading = true);
    try {
      final conceptos = await _conceptoCrud.leerConceptos();
      setState(() {
        _conceptos = conceptos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar conceptos: $e');
    }
  }

  void _calcularSubtotal() {
    final cantidad = double.tryParse(_cantidadController.text) ?? 0;
    final monto = double.tryParse(_montoController.text) ?? 0;
    
    final subtotalBase = cantidad * monto;
    final ivaMultiplicador = 1 + (_ivaAplicado / 100);
    
    setState(() {
      _subtotal = subtotalBase * ivaMultiplicador;
    });
  }

  void _agregarDetalle() {
    if (!_formKey.currentState!.validate()) return;
    if (_conceptoSeleccionado == null) {
      _mostrarError('Debe seleccionar un concepto');
      return;
    }

    final cantidad = double.parse(_cantidadController.text);
    final monto = double.parse(_montoController.text);

    // Crear detalle temporal (sin factura asignada aún)
    final detalle = DetalleFactura(
      fk_factura: null as dynamic, // Se asignará después de crear la factura
      fk_concepto: _conceptoSeleccionado!,
      monto: monto,
      descripcion: _descripcionController.text.isEmpty 
          ? _conceptoSeleccionado!.nombre 
          : _descripcionController.text,
      iva_aplicado: _ivaAplicado,
      subtotal: _subtotal,
      estado: 'ACTIVO',
      cantidad: cantidad,
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
      _ivaAplicado = 10;
      _subtotal = 0;
    });
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Concepto
              DropdownButtonFormField<Concepto>(
                value: _conceptoSeleccionado,
                decoration: const InputDecoration(
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
                      _montoController.text = concepto.arancel.toStringAsFixed(0);
                      _ivaAplicado = concepto.fk_iva.valor;
                      _descripcionController.text = concepto.nombre;
                    }
                  });
                },
                validator: (value) => value == null ? 'Seleccione un concepto' : null,
              ),
              const SizedBox(height: 12),

              // Cantidad y Monto
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cantidadController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo requerido';
                        if (double.tryParse(value!) == null) return 'Número inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _montoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monto Unit. *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        suffixText: 'Gs.',
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo requerido';
                        if (double.tryParse(value!) == null) return 'Número inválido';
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
                decoration: const InputDecoration(
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
                decoration: const InputDecoration(
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
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${_subtotal.toStringAsFixed(0)} Gs.',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0085FF),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _agregarDetalle,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0085FF),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...widget.detallesActuales.asMap().entries.map((entry) {
                  final index = entry.key;
                  final detalle = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF0085FF),
                        child: Text('${index + 1}'),
                      ),
                      title: Text(detalle.descripcion),
                      subtitle: Text(
                        '${detalle.cantidad} x ${detalle.monto.toStringAsFixed(0)} Gs. - IVA ${detalle.iva_aplicado}%',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${detalle.subtotal.toStringAsFixed(0)} Gs.',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
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