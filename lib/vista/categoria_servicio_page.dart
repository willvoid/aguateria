import 'package:flutter/material.dart';
import 'package:myapp/dao/categoriaserviciocrudimpl.dart';

import 'package:myapp/modelo/categoria_servicio.dart';

class CategoriaServicioPage extends StatefulWidget {
  const CategoriaServicioPage({Key? key}) : super(key: key);

  @override
  State<CategoriaServicioPage> createState() => _CategoriaServicioPageState();
}

class _CategoriaServicioPageState extends State<CategoriaServicioPage> {
  final CategoriaServicioCrudImpl _categoriaServicioCrud = CategoriaServicioCrudImpl();
  
  List<CategoriaServicio> categorias = [];
  List<CategoriaServicio> categoriasFiltradas = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarCategorias);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultado = await _categoriaServicioCrud.leerCategoriasServicio();

      setState(() {
        categorias = resultado;
        categoriasFiltradas = categorias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarCategorias() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        categoriasFiltradas = categorias;
      } else {
        categoriasFiltradas = categorias.where((categoria) {
          return categoria.nombre.toLowerCase().contains(query) ||
              categoria.descripcion.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarDialogoEdicion(CategoriaServicio? categoria) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarCategoriaServicio(
        categoria: categoria,
        onGuardar: (categoriaEditada) async {
          Navigator.of(dialogContext).pop();
          await _guardarCategoria(categoriaEditada);
        },
      ),
    );
  }

  Future<void> _guardarCategoria(CategoriaServicio categoria) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (categoria.id == null) {
        // Verificar nombre duplicado
        final nombreExiste = await _categoriaServicioCrud.verificarNombreExistente(categoria.nombre);
        
        if (nombreExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe una categoría con ese nombre');
          return;
        }

        // Verificar solapamiento de rangos
        final rangoSolapado = await _categoriaServicioCrud.verificarSolapamientoRangos(
          categoria.m2_min,
          categoria.m2_max,
        );
        
        if (rangoSolapado) {
          Navigator.pop(context);
          _mostrarError('El rango de m² se solapa con otra categoría existente');
          return;
        }

        final categoriaCreada = await _categoriaServicioCrud.crearCategoriaServicio(categoria);
        exito = categoriaCreada != null;
      } else {
        // Verificar nombre duplicado (excluyendo la categoría actual)
        final nombreExiste = await _categoriaServicioCrud.verificarNombreExistente(
          categoria.nombre,
          idCategoriaExcluir: categoria.id,
        );
        
        if (nombreExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otra categoría con ese nombre');
          return;
        }

        // Verificar solapamiento de rangos (excluyendo la categoría actual)
        final rangoSolapado = await _categoriaServicioCrud.verificarSolapamientoRangos(
          categoria.m2_min,
          categoria.m2_max,
          idCategoriaExcluir: categoria.id,
        );
        
        if (rangoSolapado) {
          Navigator.pop(context);
          _mostrarError('El rango de m² se solapa con otra categoría existente');
          return;
        }

        exito = await _categoriaServicioCrud.actualizarCategoriaServicio(categoria);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              categoria.id == null
                  ? 'Categoría creada exitosamente'
                  : 'Categoría actualizada exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar la categoría');
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError('Error: $e');
    }
  }

  void _eliminarCategoria(CategoriaServicio categoria) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar la categoría ${categoria.nombre}?'),
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

              final exito = await _categoriaServicioCrud.eliminarCategoriaServicio(categoria.id!);
              Navigator.pop(context);

              if (exito) {
                await _cargarDatos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Categoría eliminada exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                _mostrarError('Error al eliminar la categoría');
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
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o descripción...',
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
              const SizedBox(width: 8),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _mostrarDialogoEdicion(null);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar', overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0085FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  : categoriasFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay categorías para mostrar',
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
                                DataColumn(label: Text('Nombre')),
                                DataColumn(label: Text('Tarifa Fija')),
                                DataColumn(label: Text('M² Mínimo')),
                                DataColumn(label: Text('M² Máximo')),
                                DataColumn(label: Text('Descripción')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: categoriasFiltradas.map((categoria) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${categoria.id}')),
                                    DataCell(Text(categoria.nombre)),
                                    DataCell(Text('₲ ${categoria.tarifa_fija.toStringAsFixed(0)}')),
                                    DataCell(Text('${categoria.m2_min.toStringAsFixed(2)} m²')),
                                    DataCell(Text('${categoria.m2_max.toStringAsFixed(2)} m²')),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          categoria.descripcion,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0085FF)),
                                            onPressed: () => _mostrarDialogoEdicion(categoria),
                                            tooltip: 'Editar',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () => _eliminarCategoria(categoria),
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

class _DialogoEditarCategoriaServicio extends StatefulWidget {
  final CategoriaServicio? categoria;
  final Function(CategoriaServicio) onGuardar;

  const _DialogoEditarCategoriaServicio({
    this.categoria,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarCategoriaServicio> createState() => _DialogoEditarCategoriaServicioState();
}

class _DialogoEditarCategoriaServicioState extends State<_DialogoEditarCategoriaServicio> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _tarifaFijaController;
  late TextEditingController _m2MinController;
  late TextEditingController _m2MaxController;
  late TextEditingController _descripcionController;

  @override
  void initState() {
    super.initState();
    
    _nombreController = TextEditingController(text: widget.categoria?.nombre ?? '');
    _tarifaFijaController = TextEditingController(
      text: widget.categoria?.tarifa_fija.toString() ?? '',
    );
    _m2MinController = TextEditingController(
      text: widget.categoria?.m2_min.toString() ?? '',
    );
    _m2MaxController = TextEditingController(
      text: widget.categoria?.m2_max.toString() ?? '',
    );
    _descripcionController = TextEditingController(
      text: widget.categoria?.descripcion ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 600),
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
                  const Icon(Icons.category, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.categoria == null
                        ? 'Agregar Categoría de Servicio'
                        : 'Editar Categoría de Servicio',
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
                      _buildTextField(
                        controller: _nombreController,
                        label: 'Nombre *',
                        hint: 'Ingrese nombre de la categoría',
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _tarifaFijaController,
                        label: 'Tarifa Fija *',
                        hint: 'Ingrese tarifa fija',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (double.tryParse(value!) == null) {
                            return 'Debe ser un número válido';
                          }
                          if (double.parse(value) < 0) {
                            return 'Debe ser mayor o igual a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _m2MinController,
                              label: 'M² Mínimo *',
                              hint: 'Ingrese m² mínimo',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Campo requerido';
                                if (double.tryParse(value!) == null) {
                                  return 'Debe ser un número válido';
                                }
                                if (double.parse(value) < 0) {
                                  return 'Debe ser mayor o igual a 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _m2MaxController,
                              label: 'M² Máximo *',
                              hint: 'Ingrese m² máximo',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Campo requerido';
                                if (double.tryParse(value!) == null) {
                                  return 'Debe ser un número válido';
                                }
                                final m2Min = double.tryParse(_m2MinController.text);
                                final m2Max = double.tryParse(value);
                                if (m2Min != null && m2Max != null && m2Max <= m2Min) {
                                  return 'Debe ser mayor que el m² mínimo';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descripcionController,
                        label: 'Descripción *',
                        hint: 'Ingrese descripción',
                        maxLines: 3,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Campo requerido' : null,
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
                    onPressed: _guardarCategoria,
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

  void _guardarCategoria() {
    if (_formKey.currentState!.validate()) {
      final categoria = CategoriaServicio(
        id: widget.categoria?.id,
        nombre: _nombreController.text,
        tarifa_fija: double.parse(_tarifaFijaController.text),
        m2_min: double.parse(_m2MinController.text),
        m2_max: double.parse(_m2MaxController.text),
        descripcion: _descripcionController.text,
      );

      widget.onGuardar(categoria);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _tarifaFijaController.dispose();
    _m2MinController.dispose();
    _m2MaxController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}