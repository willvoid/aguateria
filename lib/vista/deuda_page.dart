import 'package:flutter/material.dart';
import 'package:myapp/dao/consumocrudimpl.dart';
import 'package:myapp/dao/cuenta_cobrarcrudimpl.dart';
import 'package:myapp/dao/facturaciondao/ciclocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/conceptocrudimpl.dart';
import 'package:myapp/modelo/consumo.dart';
import 'package:myapp/modelo/cuenta_cobrar.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/widget/autocomplete_ciclos.dart';

class DeudasPage extends StatefulWidget {
  final Inmuebles inmueble;

  const DeudasPage({Key? key, required this.inmueble}) : super(key: key);

  @override
  State<DeudasPage> createState() => _DeudasPageState();
}

class _DeudasPageState extends State<DeudasPage> {
  final CuentaCobrarCrudImpl _deudaCrud = CuentaCobrarCrudImpl();
  final ConceptoCrudImpl _conceptoCrud = ConceptoCrudImpl();
  final CicloCrudImpl _cicloCrud = CicloCrudImpl();
  final ConsumoCrudImpl _consumoCrud = ConsumoCrudImpl();

  List<CuentaCobrar> deudas = [];
  List<CuentaCobrar> deudasFiltradas = [];
  List<Concepto> conceptos = [];
  List<Ciclo> ciclos = [];
  List<Consumo> consumos = [];

  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  double _totalDeuda = 0.0;

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _formatearMonto(double monto) {
    return '${monto.toStringAsFixed(0)} Gs.';
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarDeudas);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      final resultados = await Future.wait([
        _deudaCrud.leerDeudasPorInmueble(widget.inmueble.id!),
        _conceptoCrud.leerConceptos(),
        _cicloCrud.leerCiclos(),
        _consumoCrud.leerConsumosPorMedidor(
          widget.inmueble.id!,
        ), // Asumiendo que hay medidor
        _deudaCrud.calcularTotalDeudasPorInmueble(widget.inmueble.id!),
      ]);

      setState(() {
        deudas = resultados[0] as List<CuentaCobrar>;
        conceptos = resultados[1] as List<Concepto>;
        ciclos = resultados[2] as List<Ciclo>;
        consumos = resultados[3] as List<Consumo>;
        _totalDeuda = resultados[4] as double;
        deudasFiltradas = deudas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarDeudas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        deudasFiltradas = deudas;
      } else {
        deudasFiltradas = deudas.where((deuda) {
          return deuda.descripcion.toLowerCase().contains(query) ||
              deuda.fk_concepto.nombre.toLowerCase().contains(query) ||
              deuda.estado.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarDialogoEdicion(CuentaCobrar? deuda) {
    if (conceptos.isEmpty) {
      _mostrarError('Cargando datos necesarios, por favor espere...');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarDeuda(
        deuda: deuda,
        inmueble: widget.inmueble,
        conceptos: conceptos,
        ciclos: ciclos,
        consumos: consumos,
        onGuardar: (deudaEditada) async {
          Navigator.of(dialogContext).pop();
          await _guardarDeuda(deudaEditada);
        },
      ),
    );
  }

  Future<void> _guardarDeuda(CuentaCobrar deuda) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (deuda.id_deuda == null) {
        exito = await _deudaCrud.crearDeuda(deuda);
      } else {
        exito = await _deudaCrud.actualizarDeuda(deuda);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deuda.id_deuda == null
                  ? 'Deuda creada exitosamente'
                  : 'Deuda actualizada exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar la deuda');
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError('Error: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deudas - ${widget.inmueble.cod_inmueble}'),
            Text(
              widget.inmueble.cliente?.razonSocial ?? 'Sin cliente',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0085FF),
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de resumen
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dirección',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            widget.inmueble.direccion,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Deuda Pendiente',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            _formatearMonto(_totalDeuda),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _totalDeuda > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por descripción, concepto o estado...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _mostrarDialogoEdicion(null);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar Deuda'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0085FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _cargarDatos,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Recargar',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : deudasFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay deudas para mostrar',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF9FAFB),
                            ),
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('Concepto')),
                              DataColumn(label: Text('Descripción')),
                              DataColumn(label: Text('Ciclo')),
                              DataColumn(label: Text('Monto')),
                              DataColumn(label: Text('Pagado')),
                              DataColumn(label: Text('Saldo')),
                              DataColumn(label: Text('Estado')),
                              DataColumn(label: Text('Acciones')),
                            ],
                            rows: deudasFiltradas.map((deuda) {
                              return DataRow(
                                cells: [
                                  DataCell(Text('${deuda.id_deuda}')),
                                  DataCell(Text(deuda.fk_concepto.nombre)),
                                  DataCell(
                                    SizedBox(
                                      width: 200,
                                      child: Text(
                                        deuda.descripcion,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(deuda.fk_ciclos?.ciclo ?? 'N/A'),
                                  ),
                                  DataCell(Text(_formatearMonto(deuda.monto))),
                                  DataCell(Text(_formatearMonto(deuda.pagado))),
                                  DataCell(
                                    Text(
                                      _formatearMonto(deuda.saldo),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: deuda.saldo > 0
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: deuda.estado == 'PAGADO'
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        deuda.estado,
                                        style: TextStyle(
                                          color: deuda.estado == 'PAGADO'
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Color(0xFF0085FF),
                                          ),
                                          onPressed: () =>
                                              _mostrarDialogoEdicion(deuda),
                                          tooltip: 'Editar',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _DialogoEditarDeuda extends StatefulWidget {
  final CuentaCobrar? deuda;
  final Inmuebles inmueble;
  final List<Concepto> conceptos;
  final List<Ciclo> ciclos;
  final List<Consumo> consumos;
  final Function(CuentaCobrar) onGuardar;

  const _DialogoEditarDeuda({
    this.deuda,
    required this.inmueble,
    required this.conceptos,
    required this.ciclos,
    required this.consumos,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarDeuda> createState() => _DialogoEditarDeudaState();
}

class _DialogoEditarDeudaState extends State<_DialogoEditarDeuda> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descripcionController;
  late TextEditingController _montoController;

  late String _estadoSeleccionado;
  late Concepto _conceptoSeleccionado;
  Ciclo? _cicloSeleccionado;
  Consumo? _consumoSeleccionado;

  final List<String> _estados = [
    'PENDIENTE',
    'PAGADO',
    'VENCIDO',
    'EN REVISION',
  ];

  @override
  void initState() {
    super.initState();

    _descripcionController = TextEditingController(
      text: widget.deuda?.descripcion ?? '',
    );
    _montoController = TextEditingController(
      text: widget.deuda?.monto.toString() ?? '',
    );
    _estadoSeleccionado = widget.deuda?.estado ?? 'PENDIENTE';

    _conceptoSeleccionado = widget.deuda != null && widget.conceptos.isNotEmpty
        ? widget.conceptos.firstWhere(
            (c) => c.id == widget.deuda!.fk_concepto.id,
            orElse: () => widget.conceptos.first,
          )
        : widget.conceptos.isNotEmpty
        ? widget.conceptos.first
        : widget.conceptos.first;

    _cicloSeleccionado = widget.deuda?.fk_ciclos == null
        ? null
        : widget.ciclos.firstWhere(
            (c) => c.id == widget.deuda!.fk_ciclos!.id,
            orElse: () => widget.ciclos.first,
          );

    _consumoSeleccionado = widget.deuda?.fk_consumos == null
        ? null
        : widget.consumos.firstWhere(
            (c) => c.id_consumos == widget.deuda!.fk_consumos!.id_consumos,
            orElse: () => widget.consumos.first,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0085FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.deuda == null ? 'Agregar Deuda' : 'Editar Deuda',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDropdown<Concepto>(
                        label: 'Concepto *',
                        value: _conceptoSeleccionado,
                        items: widget.conceptos,
                        onChanged: (value) =>
                            setState(() => _conceptoSeleccionado = value!),
                        itemLabel: (item) => item.nombre,
                      ),
                      const SizedBox(height: 16),
                      if (_conceptoSeleccionado.id != 2)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CicloAutocomplete(
                              key: ValueKey(_cicloSeleccionado?.id),
                              ciclos: widget.ciclos,
                              cicloInicial: _cicloSeleccionado,
                              label: 'Ciclo *',
                              hint: 'Buscar por ciclo o descripción...',
                              onSeleccionado: (ciclo) {
                                setState(() {
                                  _cicloSeleccionado = ciclo;
                                  _descripcionController.text =
                                      'Consumo ${ciclo.descripcion}';
                                });
                              },
                              validator: (_) {
                                if (_conceptoSeleccionado.id == 1 &&
                                    _cicloSeleccionado == null) {
                                  return 'Debe seleccionar un ciclo';
                                }
                                return null;
                              },
                            ),
                            if (_cicloSeleccionado != null)
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _cicloSeleccionado = null),
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Limpiar ciclo'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade600,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      _buildTextField(
                        controller: _descripcionController,
                        label: 'Descripción *',
                        hint: 'Ingrese la descripción',
                        maxLines: 2,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _montoController,
                              label: 'Monto *',
                              hint: 'Ingrese el monto',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty ?? true)
                                  return 'Campo requerido';
                                if (double.tryParse(value!) == null)
                                  return 'Debe ser un número';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown<String>(
                              label: 'Estado *',
                              value: _estadoSeleccionado,
                              items: _estados,
                              onChanged: (value) =>
                                  setState(() => _estadoSeleccionado = value!),
                              itemLabel: (item) => item,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _guardarDeuda,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0085FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required Function(T?) onChanged,
    required String Function(T) itemLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _guardarDeuda() {
    if (_formKey.currentState!.validate()) {
      final monto = double.parse(_montoController.text);
      final saldo = widget.deuda?.saldo ?? monto;
      final pagado = widget.deuda?.pagado ?? 0.0;

      final deuda = CuentaCobrar(
        id_deuda: widget.deuda?.id_deuda,
        fk_concepto: _conceptoSeleccionado,
        descripcion: _descripcionController.text,
        monto: monto,
        estado: _estadoSeleccionado,
        fk_ciclos: _cicloSeleccionado,
        fk_inmueble: widget.inmueble,
        saldo: saldo,
        pagado: pagado,
        fk_consumos: _consumoSeleccionado,
      );

      widget.onGuardar(deuda);
    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }
}
