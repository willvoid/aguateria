import 'package:flutter/material.dart';
import 'package:myapp/dao/empresadao/timbradocrudimpl.dart';
import 'package:myapp/dao/empresadao/establecimientocrudimpl.dart';
import 'package:myapp/modelo/empresa/timbrado.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:intl/intl.dart';

class TimbradoPage extends StatefulWidget {
  const TimbradoPage({Key? key}) : super(key: key);

  @override
  State<TimbradoPage> createState() => _TimbradoPageState();
}

class _TimbradoPageState extends State<TimbradoPage> {
  final TimbradoCrudImpl _timbradoCrud = TimbradoCrudImpl();
  final EstablecimientoCrudImpl _establecimientoCrud = EstablecimientoCrudImpl();
  
  List<Timbrado> timbrados = [];
  List<Timbrado> timbradosFiltrados = [];
  List<Establecimiento> establecimientos = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _filtroEstado = 'TODOS';

  final List<String> _filtrosEstado = ['TODOS', 'ACTIVO', 'INACTIVO', 'VIGENTE', 'VENCIDO'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarTimbrados);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultados = await Future.wait([
        _timbradoCrud.leerTimbrados(),
        _establecimientoCrud.leerEstablecimientos(),
      ]);

      setState(() {
        timbrados = resultados[0] as List<Timbrado>;
        establecimientos = resultados[1] as List<Establecimiento>;
        timbradosFiltrados = timbrados;
        _isLoading = false;
      });
      
      _aplicarFiltros();
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarTimbrados() {
    _aplicarFiltros();
  }

  void _aplicarFiltros() {
    final query = _searchController.text.toLowerCase();
    final ahora = DateTime.now();
    
    setState(() {
      timbradosFiltrados = timbrados.where((tim) {
        // Filtro de búsqueda por texto
        final cumpleBusqueda = query.isEmpty ||
            tim.timbrado.toLowerCase().contains(query) ||
            tim.fk_establecimiento.denominacion.toLowerCase().contains(query) ||
            tim.fk_establecimiento.fk_empresa.razon_social.toLowerCase().contains(query);

        if (!cumpleBusqueda) return false;

        // Filtro por estado
        if (_filtroEstado == 'TODOS') return true;
        if (_filtroEstado == 'VIGENTE') {
          return tim.estado == 'ACTIVO' && 
                 tim.inicio.isBefore(ahora) && 
                 tim.vencimiento.isAfter(ahora);
        }
        if (_filtroEstado == 'VENCIDO') {
          return tim.vencimiento.isBefore(ahora);
        }
        return tim.estado == _filtroEstado;
      }).toList();
    });
  }

  String _obtenerEstadoVisual(Timbrado timbrado) {
    final ahora = DateTime.now();
    
    if (timbrado.vencimiento.isBefore(ahora)) {
      return 'VENCIDO';
    }
    
    if (timbrado.estado == 'ACTIVO' && 
        timbrado.inicio.isBefore(ahora) && 
        timbrado.vencimiento.isAfter(ahora)) {
      return 'VIGENTE';
    }
    
    return timbrado.estado;
  }

  Color _obtenerColorEstado(String estado) {
  switch (estado) {
    case 'VIGENTE':
      return Colors.green;
    case 'VENCIDO':
      return Colors.red;
    case 'ACTIVO':
      return Colors.blue;
    case 'INACTIVO':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

  void _mostrarDialogoEdicion(Timbrado? timbrado) {
    if (establecimientos.isEmpty) {
      _mostrarError('Cargando datos necesarios, por favor espere...');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarTimbrado(
        timbrado: timbrado,
        establecimientos: establecimientos,
        onGuardar: (timbradoEditado) async {
          Navigator.of(dialogContext).pop();
          await _guardarTimbrado(timbradoEditado);
        },
      ),
    );
  }

  Future<void> _guardarTimbrado(Timbrado timbrado) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (timbrado.id_timbrado == null) {
        // Verificar si el número de timbrado ya existe
        final timbradoExiste = await _timbradoCrud.verificarTimbradoExistente(
          timbrado.timbrado,
        );
        
        if (timbradoExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe un timbrado con ese número');
          return;
        }

        // Verificar superposición de fechas para el establecimiento
        final haySuperposicion = await _timbradoCrud.verificarSuperposicionFechas(
          timbrado.fk_establecimiento.id_establecimiento!,
          timbrado.inicio,
          timbrado.vencimiento,
        );

        if (haySuperposicion) {
          Navigator.pop(context);
          _mostrarError('Ya existe un timbrado activo para este establecimiento en el rango de fechas seleccionado');
          return;
        }

        final timbradoCreado = await _timbradoCrud.crearTimbrado(timbrado);
        exito = timbradoCreado != null;
      } else {
        // Verificar si el número de timbrado ya existe (excluyendo el actual)
        final timbradoExiste = await _timbradoCrud.verificarTimbradoExistente(
          timbrado.timbrado,
          idTimbradoExcluir: timbrado.id_timbrado,
        );
        
        if (timbradoExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otro timbrado con ese número');
          return;
        }

        // Verificar superposición de fechas (excluyendo el actual)
        final haySuperposicion = await _timbradoCrud.verificarSuperposicionFechas(
          timbrado.fk_establecimiento.id_establecimiento!,
          timbrado.inicio,
          timbrado.vencimiento,
          idTimbradoExcluir: timbrado.id_timbrado,
        );

        if (haySuperposicion) {
          Navigator.pop(context);
          _mostrarError('Ya existe un timbrado activo para este establecimiento en el rango de fechas seleccionado');
          return;
        }

        exito = await _timbradoCrud.actualizarTimbrado(timbrado);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              timbrado.id_timbrado == null
                  ? 'Timbrado creado exitosamente'
                  : 'Timbrado actualizado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar el timbrado');
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
                    hintText: 'Buscar por número de timbrado, establecimiento o empresa...',
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
                child: DropdownButton<String>(
                  value: _filtroEstado,
                  underline: const SizedBox(),
                  items: _filtrosEstado.map((estado) {
                    return DropdownMenuItem(
                      value: estado,
                      child: Text(estado),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _filtroEstado = value!;
                      _aplicarFiltros();
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
                label: const Text('Agregar Timbrado'),
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
                  : timbradosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay timbrados para mostrar',
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
                                DataColumn(label: Text('Número Timbrado')),
                                DataColumn(label: Text('Establecimiento')),
                                DataColumn(label: Text('Empresa')),
                                DataColumn(label: Text('Fecha Inicio')),
                                DataColumn(label: Text('Fecha Vencimiento')),
                                DataColumn(label: Text('Días Restantes')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: timbradosFiltrados.map((tim) {
                                final estadoVisual = _obtenerEstadoVisual(tim);
                                final diasRestantes = tim.vencimiento.difference(DateTime.now()).inDays;
                                
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${tim.id_timbrado}')),
                                    DataCell(Text(tim.timbrado)),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          tim.fk_establecimiento.denominacion,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          tim.fk_establecimiento.fk_empresa.razon_social,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(DateFormat('dd/MM/yyyy').format(tim.inicio))),
                                    DataCell(Text(DateFormat('dd/MM/yyyy').format(tim.vencimiento))),
                                    DataCell(
                                      Text(
                                        diasRestantes < 0 
                                            ? 'Vencido' 
                                            : '$diasRestantes días',
                                        style: TextStyle(
                                          color: diasRestantes < 30 
                                              ? Colors.red 
                                              : diasRestantes < 90 
                                                  ? Colors.orange 
                                                  : Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _obtenerColorEstado(estadoVisual).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              estadoVisual,
                                              style: TextStyle(
                                                color: _obtenerColorEstado(estadoVisual),
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
                                            onPressed: () => _mostrarDialogoEdicion(tim),
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

class _DialogoEditarTimbrado extends StatefulWidget {
  final Timbrado? timbrado;
  final List<Establecimiento> establecimientos;
  final Function(Timbrado) onGuardar;

  const _DialogoEditarTimbrado({
    this.timbrado,
    required this.establecimientos,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarTimbrado> createState() => _DialogoEditarTimbradoState();
}

class _DialogoEditarTimbradoState extends State<_DialogoEditarTimbrado> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _numeroTimbradoController;
  late DateTime _fechaInicio;
  late DateTime _fechaVencimiento;
  late String _estadoSeleccionado;
  late Establecimiento _establecimientoSeleccionado;

  final List<String> _estados = ['ACTIVO', 'INACTIVO'];

  @override
  void initState() {
    super.initState();
    
    _numeroTimbradoController = TextEditingController(text: widget.timbrado?.timbrado ?? '');
    _fechaInicio = widget.timbrado?.inicio ?? DateTime.now();
    _fechaVencimiento = widget.timbrado?.vencimiento ?? DateTime.now().add(const Duration(days: 365));
    _estadoSeleccionado = widget.timbrado?.estado ?? 'ACTIVO';
    
    _establecimientoSeleccionado = widget.timbrado != null
        ? widget.establecimientos.firstWhere(
            (e) => e.id_establecimiento == widget.timbrado!.fk_establecimiento.id_establecimiento,
            orElse: () => widget.establecimientos.first,
          )
        : widget.establecimientos.first;
  }

  Future<void> _seleccionarFecha(BuildContext context, bool esInicio) async {
  final fecha = await showDatePicker(
    context: context,
    initialDate: esInicio ? _fechaInicio : _fechaVencimiento,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    // Remover esta línea: locale: const Locale('es', 'ES'),
  );

  if (fecha != null) {
    setState(() {
      if (esInicio) {
        _fechaInicio = fecha;
        if (_fechaInicio.isAfter(_fechaVencimiento)) {
          _fechaVencimiento = _fechaInicio.add(const Duration(days: 365));
        }
      } else {
        _fechaVencimiento = fecha;
        if (_fechaVencimiento.isBefore(_fechaInicio)) {
          _fechaInicio = _fechaVencimiento.subtract(const Duration(days: 365));
        }
      }
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 600),
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
                  const Icon(Icons.receipt_long, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.timbrado == null ? 'Agregar Timbrado' : 'Editar Timbrado',
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
                        controller: _numeroTimbradoController,
                        label: 'Número de Timbrado *',
                        hint: 'Ej: 12345678',
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (value!.length < 8) return 'Debe tener al menos 8 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown<Establecimiento>(
                        label: 'Establecimiento *',
                        value: _establecimientoSeleccionado,
                        items: widget.establecimientos,
                        onChanged: (value) => setState(() => _establecimientoSeleccionado = value!),
                        itemLabel: (item) => '${item.codigo_establecimiento} - ${item.denominacion}',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              label: 'Fecha de Inicio *',
                              fecha: _fechaInicio,
                              onTap: () => _seleccionarFecha(context, true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateField(
                              label: 'Fecha de Vencimiento *',
                              fecha: _fechaVencimiento,
                              onTap: () => _seleccionarFecha(context, false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Vigencia: ${_fechaVencimiento.difference(_fechaInicio).inDays} días',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    onPressed: _guardarTimbrado,
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

  Widget _buildDateField({
    required String label,
    required DateTime fecha,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd/MM/yyyy').format(fecha),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
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

  void _guardarTimbrado() {
    if (_formKey.currentState!.validate()) {
      final timbrado = Timbrado(
        id_timbrado: widget.timbrado?.id_timbrado,
        timbrado: _numeroTimbradoController.text,
        inicio: _fechaInicio,
        vencimiento: _fechaVencimiento,
        estado: _estadoSeleccionado,
        fk_establecimiento: _establecimientoSeleccionado,
      );

      widget.onGuardar(timbrado);
    }
  }

  @override
  void dispose() {
    _numeroTimbradoController.dispose();
    super.dispose();
  }
}