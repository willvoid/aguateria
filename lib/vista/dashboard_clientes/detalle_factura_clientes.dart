import 'package:flutter/material.dart';
import 'package:myapp/dao/facturaciondao/conceptocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/ciclocrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/detalle_factura.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/inmuebles.dart';

class DetalleFacturaDinamicoWidget extends StatefulWidget {
  final Function(DetalleFactura) onDetalleAgregado;
  final List<DetalleFactura> detallesActuales;
  final Inmuebles? inmuebleSeleccionado;

  const DetalleFacturaDinamicoWidget({
    Key? key,
    required this.onDetalleAgregado,
    required this.detallesActuales,
    this.inmuebleSeleccionado,
  }) : super(key: key);

  @override
  State<DetalleFacturaDinamicoWidget> createState() => _DetalleFacturaDinamicoWidgetState();
}

class _DetalleFacturaDinamicoWidgetState extends State<DetalleFacturaDinamicoWidget> {
  final ConceptoCrudImpl _conceptoCrud = ConceptoCrudImpl();
  final CicloCrudImpl _cicloCrud = CicloCrudImpl();
  final _formKey = GlobalKey<FormState>();

  List<Concepto> _conceptos = [];
  List<Ciclo> _ciclos = [];
  Concepto? _conceptoSeleccionado;
  Ciclo? _cicloSeleccionado;
  
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  
  bool _isLoading = false;
  int _ivaAplicado = 10;
  double _subtotal = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
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
    final monto = double.tryParse(_montoController.text) ?? 0;
    setState(() {
      _subtotal = monto;
    });
  }

  void _agregarDetalle() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_conceptoSeleccionado == null) {
      _mostrarError('Debe seleccionar un concepto');
      return;
    }

    // Validar ciclo solo si es concepto de Consumo (id = 1)
    if (_conceptoSeleccionado!.id == 1 && _cicloSeleccionado == null) {
      _mostrarError('Debe seleccionar un ciclo para el consumo');
      return;
    }

    final monto = double.parse(_montoController.text);

    // Crear detalle temporal
    final detalle = DetalleFactura(
      fk_concepto: _conceptoSeleccionado!,
      monto: monto,
      descripcion: _descripcionController.text.isEmpty 
          ? _conceptoSeleccionado!.nombre 
          : _descripcionController.text,
      iva_aplicado: _ivaAplicado,
      subtotal: _subtotal,
      estado: 'ACTIVO',
      cantidad: 1,
      fk_ciclo: _conceptoSeleccionado!.id == 1 ? _cicloSeleccionado : null,
    );

    widget.onDetalleAgregado(detalle);
    _limpiarFormulario();
  }

  void _limpiarFormulario() {
    _montoController.clear();
    _descripcionController.clear();
    setState(() {
      _conceptoSeleccionado = null;
      _cicloSeleccionado = null;
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

  // Widget para interfaz de Consumo (id = 1)
  Widget _buildConsumoInterface() {
    return Column(
      children: [
        // Selector de Ciclo
        DropdownButtonFormField<Ciclo>(
          value: _cicloSeleccionado,
          decoration: const InputDecoration(
            labelText: 'Ciclo de Consumo *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today),
            helperText: 'Seleccione el período de consumo',
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
            if (value == null) {
              return 'Seleccione un ciclo';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        
        // Monto
        TextFormField(
          controller: _montoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monto del Consumo *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.water_drop),
            suffixText: 'Gs.',
            helperText: 'Ingrese el monto del consumo de agua',
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Campo requerido';
            if (double.tryParse(value!) == null) return 'Número inválido';
            final monto = double.parse(value);
            if (monto <= 0) return 'El monto debe ser mayor a 0';
            return null;
          },
        ),
      ],
    );
  }

  // Widget para interfaz de Conexión (id = 2)
  Widget _buildConexionInterface() {
    return Column(
      children: [
        TextFormField(
          controller: _montoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monto de Conexión *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
            suffixText: 'Gs.',
            helperText: 'Ingrese el monto de la conexión',
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Campo requerido';
            if (double.tryParse(value!) == null) return 'Número inválido';
            final monto = double.parse(value);
            if (monto <= 0) return 'El monto debe ser mayor a 0';
            return null;
          },
        ),
      ],
    );
  }

  // Widget genérico para otros conceptos
  Widget _buildGenericoInterface() {
    return Column(
      children: [
        TextFormField(
          controller: _montoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monto *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
            suffixText: 'Gs.',
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Campo requerido';
            if (double.tryParse(value!) == null) return 'Número inválido';
            final monto = double.parse(value);
            if (monto <= 0) return 'El monto debe ser mayor a 0';
            return null;
          },
        ),
      ],
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

              // Selector de Concepto
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
                    child: Row(
                      children: [
                        Icon(
                          concepto.id == 1 
                              ? Icons.water_drop 
                              : concepto.id == 2 
                                  ? Icons.link 
                                  : Icons.receipt,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(concepto.nombre),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (concepto) {
                  setState(() {
                    _conceptoSeleccionado = concepto;
                    if (concepto != null) {
                      _montoController.text = concepto.arancel.toStringAsFixed(0);
                      _ivaAplicado = concepto.fk_iva.valor;
                      _descripcionController.text = concepto.nombre;
                      // Limpiar ciclo si no es consumo
                      if (concepto.id != 1) {
                        _cicloSeleccionado = null;
                      }
                    }
                  });
                },
                validator: (value) => value == null ? 'Seleccione un concepto' : null,
              ),
              const SizedBox(height: 16),

              // Interfaz dinámica según el concepto
              if (_conceptoSeleccionado != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _conceptoSeleccionado!.id == 1 
                        ? Colors.blue.shade50
                        : _conceptoSeleccionado!.id == 2
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _conceptoSeleccionado!.id == 1 
                            ? Icons.info_outline
                            : _conceptoSeleccionado!.id == 2
                                ? Icons.info_outline
                                : Icons.info_outline,
                        size: 20,
                        color: _conceptoSeleccionado!.id == 1 
                            ? Colors.blue.shade700
                            : _conceptoSeleccionado!.id == 2
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _conceptoSeleccionado!.id == 1 
                              ? 'Consumo de agua - Seleccione el ciclo y monto'
                              : _conceptoSeleccionado!.id == 2
                                  ? 'Conexión nueva - Ingrese solo el monto'
                                  : 'Concepto general - Ingrese el monto',
                          style: TextStyle(
                            fontSize: 12,
                            color: _conceptoSeleccionado!.id == 1 
                                ? Colors.blue.shade700
                                : _conceptoSeleccionado!.id == 2
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Mostrar interfaz según el tipo de concepto
                if (_conceptoSeleccionado!.id == 1)
                  _buildConsumoInterface()
                else if (_conceptoSeleccionado!.id == 2)
                  _buildConexionInterface()
                else
                  _buildGenericoInterface(),
                
                const SizedBox(height: 12),

                // IVA (solo lectura, se toma del concepto)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.percent, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'IVA Aplicado: $_ivaAplicado%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Descripción (opcional)
                TextFormField(
                  controller: _descripcionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción adicional (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Subtotal y botón agregar
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
                    onPressed: _conceptoSeleccionado != null ? _agregarDetalle : null,
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
                        backgroundColor: detalle.fk_concepto.id == 1
                            ? Colors.blue
                            : detalle.fk_concepto.id == 2
                                ? Colors.green
                                : Colors.orange,
                        child: Icon(
                          detalle.fk_concepto.id == 1
                              ? Icons.water_drop
                              : detalle.fk_concepto.id == 2
                                  ? Icons.link
                                  : Icons.receipt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(detalle.descripcion),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${detalle.monto.toStringAsFixed(0)} Gs. - IVA ${detalle.iva_aplicado}%'),
                          if (detalle.fk_ciclo != null)
                            Text(
                              'Ciclo: ${detalle.fk_ciclo!.ciclo}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
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
    _montoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}