import 'package:flutter/material.dart';
import 'package:myapp/dao/categoriaserviciocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/conceptocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/ivacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/unidadmedidacrudimpl.dart';
import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/facturacionmodelo/iva.dart';
import 'package:myapp/modelo/facturacionmodelo/unidad_medida.dart';

class ConceptosPage extends StatefulWidget {
  const ConceptosPage({Key? key}) : super(key: key);

  @override
  State<ConceptosPage> createState() => _ConceptosPageState();
}

class _ConceptosPageState extends State<ConceptosPage> {
  final ConceptoCrudImpl _conceptoCrud = ConceptoCrudImpl();
  final IvaCrudImpl _ivaCrud = IvaCrudImpl();
  final UnidadMedidaCrudImpl _unidadMedidaCrud = UnidadMedidaCrudImpl();
  final CategoriaServicioCrudImpl _categoriaServicioCrud = CategoriaServicioCrudImpl();
  
  List<Concepto> conceptos = [];
  List<Concepto> conceptosFiltrados = [];
  List<Iva> ivas = [];
  List<UnidadMedida> unidadesMedida = [];
  List<CategoriaServicio> categoriasServicio = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarConceptos);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultados = await Future.wait([
        _conceptoCrud.leerConceptos(),
        _ivaCrud.leerIvas(),
        _unidadMedidaCrud.leerUnidadesMedida(),
        _categoriaServicioCrud.leerCategoriasServicio(),
      ]);

      setState(() {
        conceptos = resultados[0] as List<Concepto>;
        ivas = resultados[1] as List<Iva>;
        unidadesMedida = resultados[2] as List<UnidadMedida>;
        categoriasServicio = resultados[3] as List<CategoriaServicio>;
        conceptosFiltrados = conceptos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarConceptos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        conceptosFiltrados = conceptos;
      } else {
        conceptosFiltrados = conceptos.where((concepto) {
          return concepto.nombre.toLowerCase().contains(query) ||
              concepto.descripcion.toLowerCase().contains(query) ||
              concepto.fk_servicio.nombre.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarDialogoEdicion(Concepto? concepto) {
    if (ivas.isEmpty || unidadesMedida.isEmpty || categoriasServicio.isEmpty) {
      _mostrarError('Cargando datos necesarios, por favor espere...');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarConcepto(
        concepto: concepto,
        ivas: ivas,
        unidadesMedida: unidadesMedida,
        categoriasServicio: categoriasServicio,
        onGuardar: (conceptoEditado) async {
          Navigator.of(dialogContext).pop();
          await _guardarConcepto(conceptoEditado);
        },
      ),
    );
  }

  Future<void> _guardarConcepto(Concepto concepto) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (concepto.id == null) {
        final nombreExiste = await _conceptoCrud.verificarNombreConceptoExistente(concepto.nombre);
        
        if (nombreExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe un concepto con ese nombre');
          return;
        }

        exito = await _conceptoCrud.crearConcepto(concepto);
      } else {
        final nombreExiste = await _conceptoCrud.verificarNombreConceptoExistente(
          concepto.nombre,
          idExcluir: concepto.id,
        );
        
        if (nombreExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otro concepto con ese nombre');
          return;
        }

        exito = await _conceptoCrud.actualizarConcepto(concepto);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              concepto.id == null
                  ? 'Concepto creado exitosamente'
                  : 'Concepto actualizado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar el concepto');
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
                    hintText: 'Buscar por nombre, descripción o servicio...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
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
                icon: Icon(Icons.add, size: 18),
                label: Text('Agregar Concepto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _cargarDatos,
                icon: Icon(Icons.refresh),
                tooltip: 'Recargar',
              ),
            ],
          ),
          SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : conceptosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay conceptos para mostrar',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Nombre')),
                                DataColumn(label: Text('Descripción')),
                                DataColumn(label: Text('Arancel')),
                                DataColumn(label: Text('IVA')),
                                DataColumn(label: Text('Unidad')),
                                DataColumn(label: Text('Servicio')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: conceptosFiltrados.map((concepto) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${concepto.id}')),
                                    DataCell(Text(concepto.nombre)),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          concepto.descripcion,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('${concepto.arancel.toStringAsFixed(0)} Gs.')),
                                    DataCell(Text('${concepto.fk_iva.valor}%')),
                                    DataCell(Text(concepto.fk_unidad_medida.representacion)),
                                    DataCell(Text(concepto.fk_servicio.nombre)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: concepto.estado == 'ACTIVO'
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          concepto.estado,
                                          style: TextStyle(
                                            color: concepto.estado == 'ACTIVO'
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
                                            icon: Icon(Icons.edit, size: 18, color: Color(0xFF0085FF)),
                                            onPressed: () => _mostrarDialogoEdicion(concepto),
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

class _DialogoEditarConcepto extends StatefulWidget {
  final Concepto? concepto;
  final List<Iva> ivas;
  final List<UnidadMedida> unidadesMedida;
  final List<CategoriaServicio> categoriasServicio;
  final Function(Concepto) onGuardar;

  _DialogoEditarConcepto({
    this.concepto,
    required this.ivas,
    required this.unidadesMedida,
    required this.categoriasServicio,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarConcepto> createState() => _DialogoEditarConceptoState();
}

class _DialogoEditarConceptoState extends State<_DialogoEditarConcepto> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _arancelController;
  late TextEditingController _descripcionController;
  
  late String _estadoSeleccionado;
  late Iva _ivaSeleccionado;
  late UnidadMedida _unidadMedidaSeleccionada;
  late CategoriaServicio _categoriaServicioSeleccionada;

  final List<String> _estados = ['ACTIVO', 'INACTIVO'];

  @override
  void initState() {
    super.initState();
    
    _nombreController = TextEditingController(text: widget.concepto?.nombre ?? '');
    _arancelController = TextEditingController(text: widget.concepto?.arancel.toString() ?? '');
    _descripcionController = TextEditingController(text: widget.concepto?.descripcion ?? '');

    _estadoSeleccionado = widget.concepto?.estado ?? 'ACTIVO';
    
    _ivaSeleccionado = widget.concepto != null
        ? widget.ivas.firstWhere(
            (i) => i.id == widget.concepto!.fk_iva.id,
            orElse: () => widget.ivas.first,
          )
        : widget.ivas.first;
    
    _unidadMedidaSeleccionada = widget.concepto != null
        ? widget.unidadesMedida.firstWhere(
            (u) => u.id == widget.concepto!.fk_unidad_medida.id,
            orElse: () => widget.unidadesMedida.first,
          )
        : widget.unidadesMedida.first;
    
    _categoriaServicioSeleccionada = widget.concepto != null
        ? widget.categoriasServicio.firstWhere(
            (c) => c.id == widget.concepto!.fk_servicio.id,
            orElse: () => widget.categoriasServicio.first,
          )
        : widget.categoriasServicio.first;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        constraints: BoxConstraints(maxHeight: 650),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF0085FF),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: Theme.of(context).cardColor),
                  const SizedBox(width: 12),
                  Text(
                    widget.concepto == null ? 'Agregar Concepto' : 'Editar Concepto',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).cardColor),
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
                        controller: _nombreController,
                        label: 'Nombre *',
                        hint: 'Ingrese el nombre del concepto',
                        validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descripcionController,
                        label: 'Descripción *',
                        hint: 'Ingrese la descripción',
                        maxLines: 3,
                        validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _arancelController,
                              label: 'Arancel *',
                              hint: 'Ingrese el arancel',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Campo requerido';
                                if (double.tryParse(value!) == null) return 'Debe ser un número';
                                if (double.parse(value) < 0) return 'Debe ser mayor o igual a 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown<Iva>(
                              label: 'IVA *',
                              value: _ivaSeleccionado,
                              items: widget.ivas,
                              onChanged: (value) => setState(() => _ivaSeleccionado = value!),
                              itemLabel: (item) => '${item.descripcion} (${item.valor}%)',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown<UnidadMedida>(
                              label: 'Unidad de Medida *',
                              value: _unidadMedidaSeleccionada,
                              items: widget.unidadesMedida,
                              onChanged: (value) => setState(() => _unidadMedidaSeleccionada = value!),
                              itemLabel: (item) => '${item.representacion} - ${item.descripcion}',
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
                      _buildDropdown<CategoriaServicio>(
                        label: 'Categoría de Servicio *',
                        value: _categoriaServicioSeleccionada,
                        items: widget.categoriasServicio,
                        onChanged: (value) => setState(() => _categoriaServicioSeleccionada = value!),
                        itemLabel: (item) => item.nombre,
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
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
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
                    onPressed: _guardarConcepto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
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
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
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
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item)))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _guardarConcepto() {
    if (_formKey.currentState!.validate()) {
      final concepto = Concepto(
        id: widget.concepto?.id,
        nombre: _nombreController.text,
        arancel: double.parse(_arancelController.text),
        descripcion: _descripcionController.text,
        fk_iva: _ivaSeleccionado,
        fk_unidad_medida: _unidadMedidaSeleccionada,
        estado: _estadoSeleccionado,
        fk_servicio: _categoriaServicioSeleccionada,
      );

      widget.onGuardar(concepto);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _arancelController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}