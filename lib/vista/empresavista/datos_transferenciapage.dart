import 'package:flutter/material.dart';
import 'package:myapp/dao/empresadao/datos_transferenciacrudimpl.dart';
import 'package:myapp/dao/empresadao/establecimientocrudimpl.dart';
import 'package:myapp/modelo/empresa/datos_transferencia.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';

class DatosTransferenciaPage extends StatefulWidget {
  const DatosTransferenciaPage({Key? key}) : super(key: key);

  @override
  State<DatosTransferenciaPage> createState() => _DatosTransferenciaPageState();
}

class _DatosTransferenciaPageState extends State<DatosTransferenciaPage> {
  final DatosTransferenciaCrudImpl _crud = DatosTransferenciaCrudImpl();
  final EstablecimientoCrudImpl _establecimientoCrud = EstablecimientoCrudImpl();

  List<DatosTransferencia> registros = [];
  List<DatosTransferencia> registrosFiltrados = [];
  List<Establecimiento> establecimientos = [];

  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrar);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final resultados = await Future.wait([
        _crud.leerDatosTransferencia(),
        _establecimientoCrud.leerEstablecimientos(),
      ]);

      setState(() {
        registros = resultados[0] as List<DatosTransferencia>;
        establecimientos = resultados[1] as List<Establecimiento>;
        registrosFiltrados = registros;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrar() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        registrosFiltrados = registros;
      } else {
        registrosFiltrados = registros.where((r) {
          return (r.alias?.toLowerCase().contains(query) ?? false) ||
              r.titular_cuenta.toLowerCase().contains(query) ||
              r.banco.toLowerCase().contains(query) ||
              r.num_cuenta.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarDialogo(DatosTransferencia? item) {
    if (establecimientos.isEmpty) {
      _mostrarError('Cargando datos necesarios, por favor espere...');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DialogoEditarTransferencia(
        item: item,
        establecimientos: establecimientos,
        onGuardar: (editado) async {
          Navigator.of(dialogContext).pop();
          await _guardar(editado);
        },
      ),
    );
  }

  Future<void> _guardar(DatosTransferencia item) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;

      if (item.id == 0) {
        final cuentaExiste = await _crud.verificarCuentaExistente(item.num_cuenta);
        if (cuentaExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe un registro con ese número de cuenta');
          return;
        }
        final creado = await _crud.crearDatosTransferencia(item);
        exito = creado != null;
      } else {
        final cuentaExiste = await _crud.verificarCuentaExistente(
          item.num_cuenta,
          idExcluir: item.id,
        );
        if (cuentaExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otro registro con ese número de cuenta');
          return;
        }
        exito = await _crud.actualizarDatosTransferencia(item);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item.id == 0
                  ? 'Registro creado exitosamente'
                  : 'Registro actualizado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar el registro');
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError('Error: $e');
    }
  }

  void _eliminar(DatosTransferencia item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Está seguro de eliminar la cuenta ${item.alias ?? item.num_cuenta}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              final exito = await _crud.eliminarDatosTransferencia(item.id);
              Navigator.pop(context);

              if (exito) {
                await _cargarDatos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Registro eliminado exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                _mostrarError('Error al eliminar el registro');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barra superior ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por alias, titular, banco o cuenta...',
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
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _mostrarDialogo(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar Cuenta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0085FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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

          // ── Tabla ───────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : registrosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay cuentas para mostrar',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF9FAFB)),
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Alias')),
                                DataColumn(label: Text('Titular')),
                                DataColumn(label: Text('Banco')),
                                DataColumn(label: Text('CI')),
                                DataColumn(label: Text('Nro. Cuenta')),
                                DataColumn(label: Text('Nro. Giro')),
                                DataColumn(label: Text('CI Giro')), // ← nuevo
                                DataColumn(label: Text('Sucursal')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: registrosFiltrados.map((item) {
  return DataRow(cells: [
    DataCell(Text('${item.id}')),
    DataCell(Text(item.alias ?? '-')),
    DataCell(Text(item.titular_cuenta)),
    DataCell(Text(item.banco)),
    DataCell(Text(item.ci)),
    DataCell(Text(item.num_cuenta)),
    DataCell(Text(item.nro_giro ?? '-')),
    DataCell(Text(item.ci_giro ?? '-')),
    DataCell(Text(item.fk_sucursal.denominacion)),
    DataCell(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0085FF)),
            onPressed: () => _mostrarDialogo(item),
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: () => _eliminar(item),
            tooltip: 'Eliminar',
          ),
        ],
      ),
    ),
  ]);
}).toList(),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════
//  DIÁLOGO DE EDICIÓN
// ════════════════════════════════════════════════════════════════

class _DialogoEditarTransferencia extends StatefulWidget {
  final DatosTransferencia? item;
  final List<Establecimiento> establecimientos;
  final Function(DatosTransferencia) onGuardar;

  const _DialogoEditarTransferencia({
    this.item,
    required this.establecimientos,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarTransferencia> createState() =>
      _DialogoEditarTransferenciaState();
}

class _DialogoEditarTransferenciaState
    extends State<_DialogoEditarTransferencia> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _aliasController;
  late TextEditingController _titularController;
  late TextEditingController _bancoController;
  late TextEditingController _ciController;
  late TextEditingController _numCuentaController;
  late TextEditingController _nroGiroController;
  late TextEditingController _ciGiroController; // ← nuevo

  late Establecimiento _sucursalSeleccionada;

  @override
  void initState() {
    super.initState();

    _aliasController =
        TextEditingController(text: widget.item?.alias ?? '');
    _titularController =
        TextEditingController(text: widget.item?.titular_cuenta ?? '');
    _bancoController =
        TextEditingController(text: widget.item?.banco ?? '');
    _ciController =
        TextEditingController(text: widget.item?.ci ?? '');
    _numCuentaController =
        TextEditingController(text: widget.item?.num_cuenta ?? '');
    _nroGiroController =
        TextEditingController(text: widget.item?.nro_giro ?? '');
    _ciGiroController =                                          // ← nuevo
        TextEditingController(text: widget.item?.ci_giro ?? '');

    _sucursalSeleccionada = widget.item != null
        ? widget.establecimientos.firstWhere(
            (e) =>
                e.id_establecimiento ==
                widget.item!.fk_sucursal.id_establecimiento,
            orElse: () => widget.establecimientos.first,
          )
        : widget.establecimientos.first;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 680), // ← ajustado
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
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
                  const Icon(Icons.account_balance, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.item == null
                        ? 'Agregar Cuenta de Transferencia'
                        : 'Editar Cuenta de Transferencia',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Formulario ──────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _titularController,
                              label: 'Titular de la Cuenta *',
                              hint: 'Ingrese el titular',
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _aliasController,
                              label: 'Alias',
                              hint: 'Ingrese alias (opcional)',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _bancoController,
                              label: 'Banco *',
                              hint: 'Nombre del banco',
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _ciController,
                              label: 'CI *',
                              hint: 'Cédula de identidad',
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _numCuentaController,
                              label: 'Nro. de Cuenta *',
                              hint: 'Ingrese número de cuenta',
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _nroGiroController,
                              label: 'Nro. de Giro',
                              hint: 'Ingrese nro. de giro (opcional)',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Fila nueva: CI Giro + Sucursal ──────────
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _ciGiroController,
                              label: 'CI Giro',
                              hint: 'CI del giro (opcional)',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown<Establecimiento>(
                              label: 'Sucursal *',
                              value: _sucursalSeleccionada,
                              items: widget.establecimientos,
                              onChanged: (v) =>
                                  setState(() => _sucursalSeleccionada = v!),
                              itemLabel: (e) => e.denominacion,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────
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
                    onPressed: _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0085FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items
              .map((item) => DropdownMenuItem<T>(
                  value: item, child: Text(itemLabel(item))))
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _guardar() {
    if (_formKey.currentState!.validate()) {
      final item = DatosTransferencia(
        id: widget.item?.id ?? 0,
        alias: _aliasController.text.isEmpty ? null : _aliasController.text,
        titular_cuenta: _titularController.text,
        banco: _bancoController.text,
        ci: _ciController.text,
        num_cuenta: _numCuentaController.text,
        fk_sucursal: _sucursalSeleccionada,
        nro_giro:
            _nroGiroController.text.isEmpty ? null : _nroGiroController.text,
        ci_giro:                                                  // ← nuevo
            _ciGiroController.text.isEmpty ? null : _ciGiroController.text,
      );

      widget.onGuardar(item);
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _titularController.dispose();
    _bancoController.dispose();
    _ciController.dispose();
    _numCuentaController.dispose();
    _nroGiroController.dispose();
    _ciGiroController.dispose(); // ← nuevo
    super.dispose();
  }
}