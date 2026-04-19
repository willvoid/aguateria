import 'package:flutter/material.dart';
import 'package:myapp/dao/empresadao/cajacrudimpl.dart';
import 'package:myapp/dao/empresadao/establecimientocrudimpl.dart';
import 'package:myapp/modelo/empresa/caja.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';

class CajaPage extends StatefulWidget {
  const CajaPage({Key? key}) : super(key: key);

  @override
  State<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends State<CajaPage> {
  final CajaCrudImpl _cajaCrud = CajaCrudImpl();
  final EstablecimientoCrudImpl _establecimientoCrud = EstablecimientoCrudImpl();
  
  List<Caja> cajas = [];
  List<Caja> cajasFiltradas = [];
  List<Establecimiento> establecimientos = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  Establecimiento? _filtroEstablecimiento;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarCajas);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultados = await Future.wait([
        _cajaCrud.leerCajas(),
        _establecimientoCrud.leerEstablecimientos(),
      ]);

      setState(() {
        cajas = resultados[0] as List<Caja>;
        establecimientos = resultados[1] as List<Establecimiento>;
        cajasFiltradas = cajas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarCajas() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      cajasFiltradas = cajas.where((caja) {
        // Filtro de búsqueda por texto
        final cumpleBusqueda = query.isEmpty ||
            caja.nro_caja.toString().contains(query) ||
            caja.descripcion_caja.toLowerCase().contains(query) ||
            caja.fk_establecimiento.denominacion.toLowerCase().contains(query) ||
            caja.fk_establecimiento.fk_empresa.razon_social.toLowerCase().contains(query);

        if (!cumpleBusqueda) return false;

        // Filtro por establecimiento
        if (_filtroEstablecimiento != null) {
          return caja.fk_establecimiento.id_establecimiento == _filtroEstablecimiento!.id_establecimiento;
        }

        return true;
      }).toList();
    });
  }

  void _mostrarDialogoEdicion(Caja? caja) {
    if (establecimientos.isEmpty) {
      _mostrarError('Cargando datos necesarios, por favor espere...');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarCaja(
        caja: caja,
        establecimientos: establecimientos,
        cajaCrud: _cajaCrud,
        onGuardar: (cajaEditada) async {
          Navigator.of(dialogContext).pop();
          await _guardarCaja(cajaEditada);
        },
      ),
    );
  }

  Future<void> _guardarCaja(Caja caja) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (caja.id_caja == null) {
        // Verificar si el número de caja ya existe para este establecimiento
        final cajaExiste = await _cajaCrud.verificarNumeroCajaExistente(
          caja.nro_caja,
          caja.fk_establecimiento.id_establecimiento!,
        );
        
        if (cajaExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe una caja con ese número en el establecimiento seleccionado');
          return;
        }

        final cajaCreada = await _cajaCrud.crearCaja(caja);
        exito = cajaCreada != null;
      } else {
        // Verificar si el número de caja ya existe (excluyendo la actual)
        final cajaExiste = await _cajaCrud.verificarNumeroCajaExistente(
          caja.nro_caja,
          caja.fk_establecimiento.id_establecimiento!,
          idCajaExcluir: caja.id_caja,
        );
        
        if (cajaExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otra caja con ese número en el establecimiento seleccionado');
          return;
        }

        exito = await _cajaCrud.actualizarCaja(caja);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              caja.id_caja == null
                  ? 'Caja creada exitosamente'
                  : 'Caja actualizada exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar la caja');
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
                    hintText: 'Buscar por número, descripción, establecimiento o empresa...',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<Establecimiento?>(
                  value: _filtroEstablecimiento,
                  hint: const Text('Todos los establecimientos'),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem<Establecimiento?>(
                      value: null,
                      child: Text('Todos los establecimientos'),
                    ),
                    ...establecimientos.map((est) {
                      return DropdownMenuItem<Establecimiento?>(
                        value: est,
                        child: Text('${est.codigo_establecimiento} - ${est.denominacion}'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filtroEstablecimiento = value;
                      _filtrarCajas();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _mostrarDialogoEdicion(null);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar Caja'),
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
                  : cajasFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.point_of_sale_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay cajas para mostrar',
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
                                DataColumn(label: Text('Nro. Caja')),
                                DataColumn(label: Text('Descripción')),
                                DataColumn(label: Text('Establecimiento')),
                                DataColumn(label: Text('Empresa')),
                                DataColumn(label: Text('Dirección')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: cajasFiltradas.map((caja) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${caja.id_caja}')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${caja.nro_caja}',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          caja.descripcion_caja,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          '${caja.fk_establecimiento.codigo_establecimiento} - ${caja.fk_establecimiento.denominacion}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          caja.fk_establecimiento.fk_empresa.razon_social,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          '${caja.fk_establecimiento.direccion}, ${caja.fk_establecimiento.numero_casa}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0085FF)),
                                            onPressed: () => _mostrarDialogoEdicion(caja),
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

class _DialogoEditarCaja extends StatefulWidget {
  final Caja? caja;
  final List<Establecimiento> establecimientos;
  final CajaCrudImpl cajaCrud;
  final Function(Caja) onGuardar;

  const _DialogoEditarCaja({
    this.caja,
    required this.establecimientos,
    required this.cajaCrud,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarCaja> createState() => _DialogoEditarCajaState();
}

class _DialogoEditarCajaState extends State<_DialogoEditarCaja> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _numeroCajaController;
  late TextEditingController _descripcionController;
  late Establecimiento _establecimientoSeleccionado;
  bool _autoGenerarNumero = false;
  int _proximoNumero = 0;

  @override
  void initState() {
    super.initState();
    
    _numeroCajaController = TextEditingController(
      text: widget.caja?.nro_caja.toString() ?? '',
    );
    _descripcionController = TextEditingController(
      text: widget.caja?.descripcion_caja ?? '',
    );
    
    _establecimientoSeleccionado = widget.caja != null
        ? widget.establecimientos.firstWhere(
            (e) => e.id_establecimiento == widget.caja!.fk_establecimiento.id_establecimiento,
            orElse: () => widget.establecimientos.first,
          )
        : widget.establecimientos.first;

    if (widget.caja == null) {
      _cargarProximoNumero();
    }
  }

  Future<void> _cargarProximoNumero() async {
    final numero = await widget.cajaCrud.obtenerProximoNumeroCaja(
      _establecimientoSeleccionado.id_establecimiento!,
    );
    setState(() {
      _proximoNumero = numero;
      if (_autoGenerarNumero) {
        _numeroCajaController.text = numero.toString();
      }
    });
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
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.point_of_sale, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.caja == null ? 'Agregar Caja' : 'Editar Caja',
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
                      _buildDropdown<Establecimiento>(
                        label: 'Establecimiento *',
                        value: _establecimientoSeleccionado,
                        items: widget.establecimientos,
                        onChanged: (value) {
                          setState(() {
                            _establecimientoSeleccionado = value!;
                            if (_autoGenerarNumero) {
                              _cargarProximoNumero();
                            }
                          });
                        },
                        itemLabel: (item) => '${item.codigo_establecimiento} - ${item.denominacion}',
                      ),
                      const SizedBox(height: 16),
                      if (widget.caja == null) ...[
                        Row(
                          children: [
                            Checkbox(
                              value: _autoGenerarNumero,
                              onChanged: (value) {
                                setState(() {
                                  _autoGenerarNumero = value ?? false;
                                  if (_autoGenerarNumero) {
                                    _numeroCajaController.text = _proximoNumero.toString();
                                  } else {
                                    _numeroCajaController.clear();
                                  }
                                });
                              },
                            ),
                            const Text('Auto-generar número de caja'),
                            const SizedBox(width: 8),
                            if (_proximoNumero > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Próximo: $_proximoNumero',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildTextField(
                        controller: _numeroCajaController,
                        label: 'Número de Caja *',
                        hint: 'Ej: 1',
                        keyboardType: TextInputType.number,
                        enabled: !_autoGenerarNumero,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (int.tryParse(value!) == null) return 'Debe ser un número';
                          if (int.parse(value) <= 0) return 'Debe ser mayor a 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descripcionController,
                        label: 'Descripción *',
                        hint: 'Ej: Caja Principal',
                        maxLines: 2,
                        validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'El número de caja debe ser único para cada establecimiento.',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    onPressed: _guardarCaja,
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
    int maxLines = 1,
    bool enabled = true,
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
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            disabledBorder: OutlineInputBorder(
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
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
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

  void _guardarCaja() {
    if (_formKey.currentState!.validate()) {
      final caja = Caja(
        id_caja: widget.caja?.id_caja,
        nro_caja: int.parse(_numeroCajaController.text),
        descripcion_caja: _descripcionController.text,
        fk_establecimiento: _establecimientoSeleccionado,
      );

      widget.onGuardar(caja);
    }
  }

  @override
  void dispose() {
    _numeroCajaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}