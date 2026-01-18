import 'package:flutter/material.dart';
import 'package:myapp/dao/facturaciondao/conceptocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/ciclocrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/detalle_factura.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/inmuebles.dart';

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
  
  final TextEditingController _cantidadController = TextEditingController(text: '1');
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  
  bool _isLoading = false;
  int _ivaAplicado = 10;
  double _subtotal = 0;
  bool _esConsumo = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cantidadController.addListener(_calcularSubtotal);
    _montoController.addListener(_calcularSubtotal);
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final resultados = await Future.wait([
        _conceptoCrud.leerConceptos(),
        _cicloCrud.leerCiclos(),
      ]);

      final conceptos = resultados[0] as List<Concepto>;
      final ciclos = resultados[1] as List<Ciclo>;

      setState(() {
        _conceptos = conceptos;
        _ciclos = ciclos.where((c) => c.estado == 'ACTIVO').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _calcularSubtotal() {
  final cantidad = double.tryParse(_cantidadController.text) ?? 0;
  final monto = double.tryParse(_montoController.text) ?? 0;
  
  // El monto ingresado YA incluye IVA
  final subtotalConIva = cantidad * monto;
  
  setState(() {
    _subtotal = subtotalConIva;
  });
}

// Método _agregarDetalle modificado - SIN asignar factura aún

void _agregarDetalle() {
  if (!_formKey.currentState!.validate()) return;
  
  if (_conceptoSeleccionado == null) {
    _mostrarError('Debe seleccionar un concepto');
    return;
  }

  if (_esConsumo && _cicloSeleccionado == null) {
    _mostrarError('Debe seleccionar un ciclo para el consumo');
    return;
  }

  final cantidad = double.parse(_cantidadController.text);
  final precioUnitario = double.parse(_montoController.text);
  
  // El precio unitario YA incluye IVA
  final subtotalConIva = cantidad * precioUnitario;

  // Crear detalle temporal (sin factura asignada aún)
  final detalle = DetalleFactura(
    // NO asignar fk_factura aquí - dejarlo como el valor por defecto del constructor
    fk_concepto: _conceptoSeleccionado!,
    monto: precioUnitario, // Precio unitario CON IVA incluido
    descripcion: _descripcionController.text.isEmpty 
        ? _conceptoSeleccionado!.nombre 
        : _descripcionController.text,
    iva_aplicado: _ivaAplicado,
    subtotal: subtotalConIva,
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
                      // Verificar si es consumo (id = 1)
                      _esConsumo = concepto.id == 1;
                      if (!_esConsumo) {
                        _cicloSeleccionado = null;
                      }
                    }
                  });
                },
                validator: (value) => value == null ? 'Seleccione un concepto' : null,
              ),
              const SizedBox(height: 12),

              // Ciclo (solo visible si es consumo)
              if (_esConsumo) ...[
                DropdownButtonFormField<Ciclo>(
                  value: _cicloSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Ciclo *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: _ciclos.map((ciclo) {
                    return DropdownMenuItem(
                      value: ciclo,
                      child: Text('${ciclo.ciclo} - ${ciclo.descripcion}'),
                    );
                  }).toList(),
                  onChanged: (ciclo) {
                    setState(() => _cicloSeleccionado = ciclo);
                  },
                  validator: (value) {
                    if (_esConsumo && value == null) {
                      return 'Seleccione un ciclo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

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