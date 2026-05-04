import 'package:flutter/material.dart';
import 'package:myapp/dao/tarifacrudimpl.dart';
import 'package:myapp/dao/categoriaserviciocrudimpl.dart';
import 'package:myapp/modelo/tarifa.dart';
import 'package:myapp/modelo/categoria_servicio.dart';

class TarifaPage extends StatefulWidget {
  const TarifaPage({Key? key}) : super(key: key);

  @override
  State<TarifaPage> createState() => _TarifaPageState();
}

class _TarifaPageState extends State<TarifaPage> {
  final TarifaCrudImpl _tarifaCrud = TarifaCrudImpl();
  final CategoriaServicioCrudImpl _categoriaServicioCrud = CategoriaServicioCrudImpl();
  
  List<Tarifa> tarifas = [];
  List<Tarifa> tarifasFiltradas = [];
  List<CategoriaServicio> categorias = [];
  
  final TextEditingController _searchController = TextEditingController();
  CategoriaServicio? _categoriaSeleccionada;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarTarifas);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultadoCategorias = await _categoriaServicioCrud.leerCategoriasServicio();
      final resultadoTarifas = await _tarifaCrud.leerTarifas();

      setState(() {
        categorias = resultadoCategorias;
        tarifas = resultadoTarifas;
        tarifasFiltradas = tarifas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarTarifas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      tarifasFiltradas = tarifas.where((tarifa) {
        final cumpleBusqueda = query.isEmpty ||
            tarifa.categoriaServicio.nombre.toLowerCase().contains(query) ||
            tarifa.costo_m3.toString().contains(query);
        
        final cumpleCategoria = _categoriaSeleccionada == null ||
            tarifa.categoriaServicio.id == _categoriaSeleccionada!.id;
        
        return cumpleBusqueda && cumpleCategoria;
      }).toList();
    });
  }

  void _mostrarDialogoEdicion(Tarifa? tarifa) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarTarifa(
        tarifa: tarifa,
        categorias: categorias,
        onGuardar: (tarifaEditada) async {
          Navigator.of(dialogContext).pop();
          await _guardarTarifa(tarifaEditada);
        },
      ),
    );
  }

  Future<void> _guardarTarifa(Tarifa tarifa) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (tarifa.id_tarifa == null) {
        // Verificar solapamiento de rangos
        final rangoSolapado = await _tarifaCrud.verificarSolapamientoRangos(
          tarifa.rango_min,
          tarifa.rango_max,
          tarifa.categoriaServicio.id!,
        );
        
        if (rangoSolapado) {
          Navigator.pop(context);
          _mostrarError('El rango de consumo se solapa con otra tarifa en esta categoría');
          return;
        }

        final tarifaCreada = await _tarifaCrud.crearTarifa(tarifa);
        exito = tarifaCreada != null;
      } else {
        // Verificar solapamiento de rangos (excluyendo la tarifa actual)
        final rangoSolapado = await _tarifaCrud.verificarSolapamientoRangos(
          tarifa.rango_min,
          tarifa.rango_max,
          tarifa.categoriaServicio.id!,
          idTarifaExcluir: tarifa.id_tarifa,
        );
        
        if (rangoSolapado) {
          Navigator.pop(context);
          _mostrarError('El rango de consumo se solapa con otra tarifa en esta categoría');
          return;
        }

        exito = await _tarifaCrud.actualizarTarifa(tarifa);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tarifa.id_tarifa == null
                  ? 'Tarifa creada exitosamente'
                  : 'Tarifa actualizada exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar la tarifa');
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
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por categoría o costo...',
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
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<CategoriaServicio>(
                  value: _categoriaSeleccionada,
                  decoration: InputDecoration(
                    hintText: 'Filtrar por categoría',
                    prefixIcon: Icon(Icons.category, size: 20),
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
                  items: [
                    const DropdownMenuItem<CategoriaServicio>(
                      value: null,
                      child: Text('Todas las categorías'),
                    ),
                    ...categorias.map((categoria) {
                      return DropdownMenuItem<CategoriaServicio>(
                        value: categoria,
                        child: Text(categoria.nombre),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _categoriaSeleccionada = value;
                      _filtrarTarifas();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (categorias.isEmpty) {
                      _mostrarError('Debe crear al menos una categoría de servicio primero');
                      return;
                    }
                    _mostrarDialogoEdicion(null);
                  },
                  icon: Icon(Icons.add, size: 18),
                  label: Text('Agregar', overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
                  : tarifasFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.attach_money, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay tarifas para mostrar',
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
                                DataColumn(label: Text('Categoría')),
                                DataColumn(label: Text('Rango Mínimo (m³)')),
                                DataColumn(label: Text('Rango Máximo (m³)')),
                                DataColumn(label: Text('Costo por m³')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: tarifasFiltradas.map((tarifa) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${tarifa.id_tarifa}')),
                                    DataCell(Text(tarifa.categoriaServicio.nombre)),
                                    DataCell(Text(tarifa.rango_min.toStringAsFixed(2))),
                                    DataCell(Text(tarifa.rango_max.toStringAsFixed(2))),
                                    DataCell(Text('₲ ${tarifa.costo_m3.toStringAsFixed(0)}')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit, size: 18, color: Color(0xFF0085FF)),
                                            onPressed: () => _mostrarDialogoEdicion(tarifa),
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

class _DialogoEditarTarifa extends StatefulWidget {
  final Tarifa? tarifa;
  final List<CategoriaServicio> categorias;
  final Function(Tarifa) onGuardar;

  _DialogoEditarTarifa({
    this.tarifa,
    required this.categorias,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarTarifa> createState() => _DialogoEditarTarifaState();
}

class _DialogoEditarTarifaState extends State<_DialogoEditarTarifa> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rangoMinController;
  late TextEditingController _rangoMaxController;
  late TextEditingController _costoM3Controller;
  CategoriaServicio? _categoriaSeleccionada;

  @override
  void initState() {
    super.initState();
    
    _rangoMinController = TextEditingController(
      text: widget.tarifa?.rango_min.toString() ?? '',
    );
    _rangoMaxController = TextEditingController(
      text: widget.tarifa?.rango_max.toString() ?? '',
    );
    _costoM3Controller = TextEditingController(
      text: widget.tarifa?.costo_m3.toString() ?? '',
    );
    _categoriaSeleccionada = widget.tarifa?.categoriaServicio;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF0085FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: Theme.of(context).cardColor),
                  const SizedBox(width: 12),
                  Text(
                    widget.tarifa == null ? 'Agregar Tarifa' : 'Editar Tarifa',
                    style: TextStyle(
                      color: Theme.of(context).cardColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
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
                      _buildDropdown(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _rangoMinController,
                              label: 'Rango Mínimo (m³) *',
                              hint: 'Ingrese rango mínimo',
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
                              controller: _rangoMaxController,
                              label: 'Rango Máximo (m³) *',
                              hint: 'Ingrese rango máximo',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Campo requerido';
                                if (double.tryParse(value!) == null) {
                                  return 'Debe ser un número válido';
                                }
                                final rangoMin = double.tryParse(_rangoMinController.text);
                                final rangoMax = double.tryParse(value);
                                if (rangoMin != null && rangoMax != null && rangoMax <= rangoMin) {
                                  return 'Debe ser mayor que el rango mínimo';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _costoM3Controller,
                        label: 'Costo por m³ *',
                        hint: 'Ingrese costo por m³',
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
                    onPressed: _guardarTarifa,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
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

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categoría de Servicio *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<CategoriaServicio>(
          value: _categoriaSeleccionada,
          decoration: InputDecoration(
            hintText: 'Seleccione una categoría',
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          items: widget.categorias.map((categoria) {
            return DropdownMenuItem<CategoriaServicio>(
              value: categoria,
              child: Text(categoria.nombre),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _categoriaSeleccionada = value;
            });
          },
          validator: (value) => value == null ? 'Debe seleccionar una categoría' : null,
        ),
      ],
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
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _guardarTarifa() {
    if (_formKey.currentState!.validate()) {
      final tarifa = Tarifa(
        id_tarifa: widget.tarifa?.id_tarifa,
        rango_min: double.parse(_rangoMinController.text),
        rango_max: double.parse(_rangoMaxController.text),
        costo_m3: double.parse(_costoM3Controller.text),
        categoriaServicio: _categoriaSeleccionada!,
      );

      widget.onGuardar(tarifa);
    }
  }

  @override
  void dispose() {
    _rangoMinController.dispose();
    _rangoMaxController.dispose();
    _costoM3Controller.dispose();
    super.dispose();
  }
}