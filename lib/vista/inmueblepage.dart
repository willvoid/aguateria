import 'package:flutter/material.dart';
import 'package:myapp/dao/categoriaserviciocrudimpl.dart';
import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:myapp/dao/inmueblescrudimpl.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/vista/deuda_page.dart';
import 'package:myapp/widget/autocomplete_cliente.dart';

class InmueblesPage extends StatefulWidget {
  const InmueblesPage({Key? key}) : super(key: key);

  @override
  State<InmueblesPage> createState() => _InmueblesPageState();
}

class _InmueblesPageState extends State<InmueblesPage> {
  final InmuebleCrudImpl _inmuebleCrud = InmuebleCrudImpl();
  final ClienteCrudImpl _clienteCrud = ClienteCrudImpl();
  final CategoriaServicioCrudImpl _categoriaServicioCrud = CategoriaServicioCrudImpl();
  
  List<Inmuebles> inmuebles = [];
  List<Inmuebles> inmueblesFiltrados = [];
  List<Cliente> clientes = [];
  List<CategoriaServicio> categoriasServicio = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarInmuebles);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultados = await Future.wait([
        _inmuebleCrud.leerInmuebles(),
        _clienteCrud.leerClientes(),
        _categoriaServicioCrud.leerCategoriasServicio(),
      ]);

      setState(() {
        inmuebles = resultados[0] as List<Inmuebles>;
        clientes = resultados[1] as List<Cliente>;
        categoriasServicio = resultados[2] as List<CategoriaServicio>;
        inmueblesFiltrados = inmuebles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarInmuebles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        inmueblesFiltrados = inmuebles;
      } else {
        inmueblesFiltrados = inmuebles.where((inmueble) {
          return inmueble.cod_inmueble.toLowerCase().contains(query) ||
              inmueble.direccion.toLowerCase().contains(query) ||
              inmueble.cliente.razonSocial.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarDialogoEdicion(Inmuebles? inmueble) {
    if (clientes.isEmpty || categoriasServicio.isEmpty) {
      _mostrarError('Cargando datos necesarios, por favor espere...');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarInmueble(
        inmueble: inmueble,
        clientes: clientes,
        categoriasServicio: categoriasServicio,
        onGuardar: (inmuebleEditado) async {
          Navigator.of(dialogContext).pop();
          await _guardarInmueble(inmuebleEditado);
        },
      ),
    );
  }

  Future<void> _guardarInmueble(Inmuebles inmueble) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito = false;
      String? errorMsg;
      
      if (inmueble.id == null) {
        final codigoExiste = await _inmuebleCrud.verificarCodigoExistente(inmueble.cod_inmueble);
        
        if (codigoExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe un inmueble con ese código');
          return;
        }

        try {
          final inmuebleCreado = await _inmuebleCrud.crearInmueble(inmueble);
          exito = inmuebleCreado != null;
        } catch (e) {
          print('Error detallado al crear: $e');
          errorMsg = e.toString();
          exito = false;
        }
      } else {
        final codigoExiste = await _inmuebleCrud.verificarCodigoExistente(
          inmueble.cod_inmueble,
          idInmuebleExcluir: inmueble.id,
        );
        
        if (codigoExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otro inmueble con ese código');
          return;
        }

        try {
          exito = await _inmuebleCrud.actualizarInmueble(inmueble);
        } catch (e) {
          print('Error detallado al actualizar: $e');
          errorMsg = e.toString();
          exito = false;
        }
      }

      Navigator.pop(context);

      // Recargar datos siempre para verificar si se guardó en BD
      await _cargarDatos();

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              inmueble.id == null
                  ? 'Inmueble creado exitosamente'
                  : 'Inmueble actualizado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Verificar si realmente se guardó en la BD
        final codigo = inmueble.cod_inmueble;
        final existe = inmueblesFiltrados.any((i) => i.cod_inmueble == codigo);
        
        if (existe) {
          // Se guardó en BD pero hubo error al parsear la respuesta
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                inmueble.id == null
                    ? 'Inmueble creado exitosamente'
                    : 'Inmueble actualizado exitosamente',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _mostrarError(errorMsg != null 
            ? 'Error al guardar: ${errorMsg.substring(0, errorMsg.length > 100 ? 100 : errorMsg.length)}...' 
            : 'Error al guardar el inmueble');
        }
      }
    } catch (e) {
      Navigator.pop(context);
      print('Error general: $e');
      _mostrarError('Error: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}');
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
                    hintText: 'Buscar por código, dirección o cliente...',
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
                label: const Text('Agregar Inmueble'),
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
                  : inmueblesFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay inmuebles para mostrar',
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
                                DataColumn(label: Text('Código')),
                                DataColumn(label: Text('Dirección')),
                                DataColumn(label: Text('Cliente')),
                                DataColumn(label: Text('Categoría')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: inmueblesFiltrados.map((inmueble) {
    return DataRow(
      cells: [
        DataCell(Text('${inmueble.id}')),
        DataCell(Text(inmueble.cod_inmueble)),
        DataCell(Text(inmueble.direccion)),
        DataCell(Text(inmueble.cliente.razonSocial)),
        DataCell(Text(inmueble.categoriaServicio.descripcion)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: inmueble.estado == 'CONECTADO'
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              inmueble.estado,
              style: TextStyle(
                color: inmueble.estado == 'CONECTADO'
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
                icon: const Icon(Icons.receipt_long, size: 18, color: Colors.purple),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeudasPage(inmueble: inmueble),
                    ),
                  );
                },
                tooltip: 'Ver Deudas',
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0085FF)),
                onPressed: () => _mostrarDialogoEdicion(inmueble),
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
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _DialogoEditarInmueble extends StatefulWidget {
  final Inmuebles? inmueble;
  final List<Cliente> clientes;
  final List<CategoriaServicio> categoriasServicio;
  final Function(Inmuebles) onGuardar;

  const _DialogoEditarInmueble({
    this.inmueble,
    required this.clientes,
    required this.categoriasServicio,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarInmueble> createState() => _DialogoEditarInmuebleState();
}

class _DialogoEditarInmuebleState extends State<_DialogoEditarInmueble> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codigoController;
  late TextEditingController _direccionController;
  
  late String _estadoSeleccionado;
  late Cliente _clienteSeleccionado;
  late CategoriaServicio _categoriaSeleccionada;

  final List<String> _estados = ['CONECTADO', 'DESCONECTADO'];

  @override
  void initState() {
    super.initState();
    
    _codigoController = TextEditingController(text: widget.inmueble?.cod_inmueble ?? '');
    _direccionController = TextEditingController(text: widget.inmueble?.direccion ?? '');
    _estadoSeleccionado = widget.inmueble?.estado ?? 'CONECTADO';
    
    _clienteSeleccionado = widget.inmueble != null
        ? widget.clientes.firstWhere(
            (c) => c.idCliente == widget.inmueble!.cliente.idCliente,
            orElse: () => widget.clientes.first,
          )
        : widget.clientes.first;
    
    _categoriaSeleccionada = widget.inmueble != null
        ? widget.categoriasServicio.firstWhere(
            (c) => c.id == widget.inmueble!.categoriaServicio.id,
            orElse: () => widget.categoriasServicio.first,
          )
        : widget.categoriasServicio.first;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 550),
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
                  const Icon(Icons.home, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.inmueble == null ? 'Agregar Inmueble' : 'Editar Inmueble',
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
                      _buildTextField(
                        controller: _codigoController,
                        label: 'Código de Inmueble *',
                        hint: 'Ingrese código único',
                        validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _direccionController,
                        label: 'Dirección *',
                        hint: 'Ingrese dirección del inmueble',
                        validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      /*_buildDropdown<Cliente>(
                        label: 'Cliente *',
                        value: _clienteSeleccionado,
                        items: widget.clientes,
                        onChanged: (value) => setState(() => _clienteSeleccionado = value!),
                        itemLabel: (item) => '${item.razonSocial} - ${item.documento}',
                      ),*/
                      ClienteAutocomplete(
                        clientes: widget.clientes,
                        clienteInicial: widget.inmueble != null ? _clienteSeleccionado : null,
                        onSeleccionado: (c) => setState(() => _clienteSeleccionado = c),
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown<CategoriaServicio>(
                        label: 'Categoría de Servicio *',
                        value: _categoriaSeleccionada,
                        items: widget.categoriasServicio,
                        onChanged: (value) => setState(() => _categoriaSeleccionada = value!),
                        itemLabel: (item) => item.descripcion,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown<String>(
                        label: 'Estado *',
                        value: _estadoSeleccionado,
                        items: _estados,
                        onChanged: (value) => setState(() => _estadoSeleccionado = value!),
                        itemLabel: (item) => item,
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
                    onPressed: _guardarInmueble,
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

  Widget _buildAutocompleteCliente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cliente *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<Cliente>(
          initialValue: TextEditingValue(
            text: '${_clienteSeleccionado.razonSocial} - ${_clienteSeleccionado.documento}',
          ),
          displayStringForOption: (Cliente cliente) =>
              '${cliente.razonSocial} - ${cliente.documento}',
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return widget.clientes;
            }
            return widget.clientes.where((Cliente cliente) {
              final searchTerm = textEditingValue.text.toLowerCase();
              return cliente.razonSocial.toLowerCase().contains(searchTerm) ||
                  cliente.documento.toLowerCase().contains(searchTerm) ||
                  cliente.nombreFantasia?.toLowerCase().contains(searchTerm) == true;
            });
          },
          onSelected: (Cliente cliente) {
            setState(() {
              _clienteSeleccionado = cliente;
            });
          },
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Solo actualizamos el texto la primera vez
            if (controller.text.isEmpty && widget.inmueble != null) {
              controller.text = '${_clienteSeleccionado.razonSocial} - ${_clienteSeleccionado.documento}';
            }
            
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Buscar cliente por nombre o documento...',
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
                suffixIcon: const Icon(Icons.search, size: 20),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Debe seleccionar un cliente';
                }
                return null;
              },
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<Cliente> onSelected,
            Iterable<Cliente> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 550,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: options.length,
                    shrinkWrap: true,
                    itemBuilder: (BuildContext context, int index) {
                      final Cliente option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.razonSocial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Doc: ${option.documento} • Tel: ${option.celular}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
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

  void _guardarInmueble() {
    if (_formKey.currentState!.validate()) {
      final inmueble = Inmuebles(
        id: widget.inmueble?.id,
        cod_inmueble: _codigoController.text,
        estado: _estadoSeleccionado,
        direccion: _direccionController.text,
        cliente: _clienteSeleccionado,
        categoriaServicio: _categoriaSeleccionada,
      );

      widget.onGuardar(inmueble);
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }
}