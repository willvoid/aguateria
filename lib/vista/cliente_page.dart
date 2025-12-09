import 'package:flutter/material.dart';
import 'package:myapp/dao/barriocrudimpl.dart';
import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:myapp/dao/tipo_operacioncrudimpl.dart';
import 'package:myapp/dao/tipodoc_crudimpl.dart';
import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/tipo_operacion.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({Key? key}) : super(key: key);

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final ClienteCrudImpl _clienteCrud = ClienteCrudImpl();
  final TipoDocCrudimpl _tipoDocCrud = TipoDocCrudimpl();
  final TipoOperacionCrudimpl _tipoOperacionCrud = TipoOperacionCrudimpl();
  final BarrioCrudImpl _barrioCrud = BarrioCrudImpl();
  
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  List<TipoDocumento> tiposDocumento = [];
  List<TipoOperacion> tiposOperacion = [];
  List<Barrio> barrios = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarClientes);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultados = await Future.wait([
        _clienteCrud.leerClientes(),
        _tipoDocCrud.leerTipoDoc(),
        _tipoOperacionCrud.leerTipoOperacion(),
        _barrioCrud.leerBarrios(),
      ]);

      setState(() {
        clientes = resultados[0] as List<Cliente>;
        tiposDocumento = resultados[1] as List<TipoDocumento>;
        tiposOperacion = resultados[2] as List<TipoOperacion>;
        barrios = resultados[3] as List<Barrio>;
        clientesFiltrados = clientes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarClientes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        clientesFiltrados = clientes;
      } else {
        clientesFiltrados = clientes.where((cliente) {
          return cliente.razonSocial.toLowerCase().contains(query) ||
              cliente.documento.toLowerCase().contains(query) ||
              cliente.celular.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarDialogoEdicion(Cliente? cliente) {
    if (tiposDocumento.isEmpty || tiposOperacion.isEmpty || barrios.isEmpty) {
      _mostrarError('Cargando datos necesarios, por favor espere...');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarCliente(
        cliente: cliente,
        tiposDocumento: tiposDocumento,
        tiposOperacion: tiposOperacion,
        barrios: barrios,
        onGuardar: (clienteEditado) async {
          Navigator.of(dialogContext).pop();
          await _guardarCliente(clienteEditado);
        },
      ),
    );
  }

  Future<void> _guardarCliente(Cliente cliente) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (cliente.idCliente == null) {
        final documentoExiste = await _clienteCrud.verificarDocumentoExistente(cliente.documento);
        
        if (documentoExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe un cliente con ese documento');
          return;
        }

        final clienteCreado = await _clienteCrud.crearCliente(cliente);
        exito = clienteCreado != null;
      } else {
        final documentoExiste = await _clienteCrud.verificarDocumentoExistente(
          cliente.documento,
          idClienteExcluir: cliente.idCliente,
        );
        
        if (documentoExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otro cliente con ese documento');
          return;
        }

        exito = await _clienteCrud.actualizarCliente(cliente);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cliente.idCliente == null
                  ? 'Cliente creado exitosamente'
                  : 'Cliente actualizado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar el cliente');
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError('Error: $e');
    }
  }

  void _eliminarCliente(Cliente cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar al cliente ${cliente.razonSocial}?'),
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
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              final exito = await _clienteCrud.eliminarCliente(cliente.idCliente!);
              Navigator.pop(context);

              if (exito) {
                await _cargarDatos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cliente eliminado exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                _mostrarError('Error al eliminar el cliente');
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, documento o celular...',
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _mostrarDialogoEdicion(null);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar Cliente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0085FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  : clientesFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay clientes para mostrar',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Razón Social')),
                                DataColumn(label: Text('Documento')),
                                DataColumn(label: Text('Celular')),
                                DataColumn(label: Text('Dirección')),
                                DataColumn(label: Text('Nro. Casa')),
                                DataColumn(label: Text('Barrio')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: clientesFiltrados.map((cliente) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${cliente.idCliente}')),
                                    DataCell(Text(cliente.razonSocial)),
                                    DataCell(Text(cliente.documento)),
                                    DataCell(Text(cliente.celular)),
                                    DataCell(Text(cliente.direccion ?? '-')),
                                    DataCell(Text('${cliente.nroCasa}')),
                                    DataCell(Text(cliente.barrio.nombre_barrio)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cliente.estado == 'ACTIVO'
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          cliente.estado,
                                          style: TextStyle(
                                            color: cliente.estado == 'ACTIVO'
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
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
                                            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0085FF)),
                                            onPressed: () => _mostrarDialogoEdicion(cliente),
                                            tooltip: 'Editar',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () => _eliminarCliente(cliente),
                                            tooltip: 'Eliminar',
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
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _DialogoEditarCliente extends StatefulWidget {
  final Cliente? cliente;
  final List<TipoDocumento> tiposDocumento;
  final List<TipoOperacion> tiposOperacion;
  final List<Barrio> barrios;
  final Function(Cliente) onGuardar;

  const _DialogoEditarCliente({
    this.cliente,
    required this.tiposDocumento,
    required this.tiposOperacion,
    required this.barrios,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarCliente> createState() => _DialogoEditarClienteState();
}

class _DialogoEditarClienteState extends State<_DialogoEditarCliente> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _razonSocialController;
  late TextEditingController _nombreFantasiaController;
  late TextEditingController _documentoController;
  late TextEditingController _telefonoController;
  late TextEditingController _celularController;
  late TextEditingController _direccionController;
  late TextEditingController _emailController;
  late TextEditingController _nroCasaController;
  
  late bool _esProveedorEstado;
  late String _estadoSeleccionado;
  late TipoDocumento _tipoDocumentoSeleccionado;
  late TipoOperacion _tipoOperacionSeleccionado;
  late Barrio _barrioSeleccionado;

  final List<String> _estados = ['ACTIVO', 'INACTIVO'];

  @override
  void initState() {
    super.initState();
    
    _razonSocialController = TextEditingController(text: widget.cliente?.razonSocial ?? '');
    _nombreFantasiaController = TextEditingController(text: widget.cliente?.nombreFantasia ?? '');
    _documentoController = TextEditingController(text: widget.cliente?.documento ?? '');
    _telefonoController = TextEditingController(text: widget.cliente?.telefono ?? '');
    _celularController = TextEditingController(text: widget.cliente?.celular ?? '');
    _direccionController = TextEditingController(text: widget.cliente?.direccion ?? '');
    _emailController = TextEditingController(text: widget.cliente?.email ?? '');
    _nroCasaController = TextEditingController(text: widget.cliente?.nroCasa.toString() ?? '');

    _esProveedorEstado = widget.cliente?.es_proveedor_del_estado ?? false;
    _estadoSeleccionado = widget.cliente?.estado ?? 'ACTIVO';
    
    _tipoDocumentoSeleccionado = widget.cliente != null
        ? widget.tiposDocumento.firstWhere(
            (t) => t.cod_tipo_documento == widget.cliente!.tipoDocumento.cod_tipo_documento,
            orElse: () => widget.tiposDocumento.first,
          )
        : widget.tiposDocumento.first;
    
    _tipoOperacionSeleccionado = widget.cliente != null
        ? widget.tiposOperacion.firstWhere(
            (t) => t.id_tipo_operacion == widget.cliente!.tipoOperacion.id_tipo_operacion,
            orElse: () => widget.tiposOperacion.first,
          )
        : widget.tiposOperacion.first;
    
    _barrioSeleccionado = widget.cliente != null
        ? widget.barrios.firstWhere(
            (b) => b.cod_barrio == widget.cliente!.barrio.cod_barrio,
            orElse: () => widget.barrios.first,
          )
        : widget.barrios.first;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0085FF),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.cliente == null ? 'Agregar Cliente' : 'Editar Cliente',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _razonSocialController,
                              label: 'Razón Social *',
                              hint: 'Ingrese razón social',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _nombreFantasiaController,
                              label: 'Nombre Fantasía',
                              hint: 'Ingrese nombre fantasía',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown<TipoDocumento>(
                              label: 'Tipo Documento *',
                              value: _tipoDocumentoSeleccionado,
                              items: widget.tiposDocumento,
                              onChanged: (value) => setState(() => _tipoDocumentoSeleccionado = value!),
                              itemLabel: (item) => item.descripcion_tipodoc,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _documentoController,
                              label: 'Documento *',
                              hint: 'Ingrese documento',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _telefonoController,
                              label: 'Teléfono',
                              hint: 'Ingrese teléfono',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _celularController,
                              label: 'Celular *',
                              hint: 'Ingrese celular',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _direccionController,
                        label: 'Dirección',
                        hint: 'Ingrese dirección',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Ingrese email',
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!value.contains('@') || !value.contains('.')) return 'Email inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _nroCasaController,
                              label: 'Nro. Casa *',
                              hint: 'Ingrese número de casa',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Campo requerido';
                                if (int.tryParse(value!) == null) return 'Debe ser un número';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown<Barrio>(
                              label: 'Barrio *',
                              value: _barrioSeleccionado,
                              items: widget.barrios,
                              onChanged: (value) => setState(() => _barrioSeleccionado = value!),
                              itemLabel: (item) => item.nombre_barrio,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown<TipoOperacion>(
                              label: 'Tipo Operación *',
                              value: _tipoOperacionSeleccionado,
                              items: widget.tiposOperacion,
                              onChanged: (value) => setState(() => _tipoOperacionSeleccionado = value!),
                              itemLabel: (item) => item.codigo_tipo_operacion,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown<String>(
                              label: 'Estado *',
                              value: _estadoSeleccionado,
                              items: _estados,
                              onChanged: (value) => setState(() => _estadoSeleccionado = value!),
                              itemLabel: (item) => item,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('¿Es proveedor del estado?'),
                        value: _esProveedorEstado,
                        onChanged: (value) => setState(() => _esProveedorEstado = value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
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
                    onPressed: _guardarCliente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0085FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item)))).toList(),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _guardarCliente() {
    if (_formKey.currentState!.validate()) {
      final cliente = Cliente(
        idCliente: widget.cliente?.idCliente,
        razonSocial: _razonSocialController.text,
        nombreFantasia: _nombreFantasiaController.text.isEmpty ? null : _nombreFantasiaController.text,
        documento: _documentoController.text,
        telefono: _telefonoController.text.isEmpty ? null : _telefonoController.text,
        celular: _celularController.text,
        direccion: _direccionController.text.isEmpty ? null : _direccionController.text,
        es_proveedor_del_estado: _esProveedorEstado,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        nroCasa: int.parse(_nroCasaController.text),
        tipoOperacion: _tipoOperacionSeleccionado,
        estado: _estadoSeleccionado,
        tipoDocumento: _tipoDocumentoSeleccionado,
        barrio: _barrioSeleccionado,
      );

      widget.onGuardar(cliente);
    }
  }

  @override
  void dispose() {
    _razonSocialController.dispose();
    _nombreFantasiaController.dispose();
    _documentoController.dispose();
    _telefonoController.dispose();
    _celularController.dispose();
    _direccionController.dispose();
    _emailController.dispose();
    _nroCasaController.dispose();
    super.dispose();
  }
}