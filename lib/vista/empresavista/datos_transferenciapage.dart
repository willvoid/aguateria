import 'package:flutter/material.dart';
import 'package:myapp/dao/empresadao/datos_transferenciacrudimpl.dart';
import 'package:myapp/dao/empresadao/establecimientocrudimpl.dart';
import 'package:myapp/modelo/empresa/datos_transferencia.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/widget/crud_dialog.dart';
import 'package:myapp/widget/crud_list_view.dart';
import 'package:myapp/widget/responsive_form_row.dart';

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
      child: CrudListView<DatosTransferencia>(
        items: registrosFiltrados,
        isLoading: _isLoading,
        emptyIcon: Icons.account_balance_outlined,
        emptyText: 'No hay cuentas para mostrar',
        onEdit: _mostrarDialogo,
        onDelete: _eliminar,
        toolbar: Row(
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
        columns: [
          CrudColumn<DatosTransferencia>(
            label: 'ID',
            cellBuilder: (item) => Text('${item.id}'),
          ),
          CrudColumn<DatosTransferencia>(
            label: 'Alias',
            isTitle: true,
            cellBuilder: (item) => Text(item.alias ?? '-'),
          ),
          CrudColumn<DatosTransferencia>(
            label: 'Titular',
            isSubtitle: true,
            cellBuilder: (item) => Text(item.titular_cuenta),
          ),
          CrudColumn<DatosTransferencia>(
            label: 'Banco',
            cellBuilder: (item) => Text(item.banco),
          ),
          CrudColumn<DatosTransferencia>(
            label: 'CI',
            cellBuilder: (item) => Text(item.ci),
          ),
          CrudColumn<DatosTransferencia>(
            label: 'Nro. Cuenta',
            cellBuilder: (item) => Text(item.num_cuenta),
          ),
          CrudColumn<DatosTransferencia>(
            label: 'Nro. Giro',
            cellBuilder: (item) => Text(item.nro_giro ?? '-'),
          ),
          CrudColumn<DatosTransferencia>(
            label: 'CI Giro',
            cellBuilder: (item) => Text(item.ci_giro ?? '-'),
          ),
          CrudColumn<DatosTransferencia>(
            label: 'Sucursal',
            cellBuilder: (item) => Text(item.fk_sucursal.denominacion),
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
    return CrudDialog(
      icon: Icons.account_balance,
      title: widget.item == null
          ? 'Agregar Cuenta de Transferencia'
          : 'Editar Cuenta de Transferencia',
      preferredWidth: 700,
      preferredMaxHeight: 680,
      onGuardar: _guardar,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveFormRow(
                children: [
                  _buildTextField(
                    controller: _titularController,
                    label: 'Titular de la Cuenta *',
                    hint: 'Ingrese el titular',
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Campo requerido' : null,
                  ),
                  _buildTextField(
                    controller: _aliasController,
                    label: 'Alias',
                    hint: 'Ingrese alias (opcional)',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ResponsiveFormRow(
                children: [
                  _buildTextField(
                    controller: _bancoController,
                    label: 'Banco *',
                    hint: 'Nombre del banco',
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Campo requerido' : null,
                  ),
                  _buildTextField(
                    controller: _ciController,
                    label: 'CI *',
                    hint: 'Cédula de identidad',
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Campo requerido' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ResponsiveFormRow(
                children: [
                  _buildTextField(
                    controller: _numCuentaController,
                    label: 'Nro. de Cuenta *',
                    hint: 'Ingrese número de cuenta',
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Campo requerido' : null,
                  ),
                  _buildTextField(
                    controller: _nroGiroController,
                    label: 'Nro. de Giro',
                    hint: 'Ingrese nro. de giro (opcional)',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ResponsiveFormRow(
                children: [
                  _buildTextField(
                    controller: _ciGiroController,
                    label: 'CI Giro',
                    hint: 'CI del giro (opcional)',
                  ),
                  _buildDropdown<Establecimiento>(
                    label: 'Sucursal *',
                    value: _sucursalSeleccionada,
                    items: widget.establecimientos,
                    onChanged: (v) =>
                        setState(() => _sucursalSeleccionada = v!),
                    itemLabel: (e) => e.denominacion,
                  ),
                ],
              ),
            ],
          ),
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