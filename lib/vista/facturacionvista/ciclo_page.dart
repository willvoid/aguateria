import 'package:flutter/material.dart';
import 'package:myapp/dao/facturaciondao/ciclocrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';

class CiclosPage extends StatefulWidget {
  const CiclosPage({Key? key}) : super(key: key);

  @override
  State<CiclosPage> createState() => _CiclosPageState();
}

class _CiclosPageState extends State<CiclosPage> {
  final CicloCrudImpl _cicloCrud = CicloCrudImpl();
  
  List<Ciclo> ciclos = [];
  List<Ciclo> ciclosFiltrados = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarCiclos);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultado = await _cicloCrud.leerCiclos();

      setState(() {
        ciclos = resultado;
        ciclosFiltrados = ciclos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarCiclos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        ciclosFiltrados = ciclos;
      } else {
        ciclosFiltrados = ciclos.where((ciclo) {
          return ciclo.ciclo.toLowerCase().contains(query) ||
              ciclo.descripcion.toLowerCase().contains(query) ||
              ciclo.anio.toString().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarDialogoEdicion(Ciclo? ciclo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarCiclo(
        ciclo: ciclo,
        onGuardar: (cicloEditado) async {
          Navigator.of(dialogContext).pop();
          await _guardarCiclo(cicloEditado);
        },
      ),
    );
  }

  Future<void> _guardarCiclo(Ciclo ciclo) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (ciclo.id == null) {
        // Verificar si el código de ciclo ya existe
        final cicloExiste = await _cicloCrud.verificarCicloExistente(ciclo.ciclo);
        
        if (cicloExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe un ciclo con ese código');
          return;
        }

        // Verificar solapamiento de fechas
        final solapamiento = await _cicloCrud.verificarSolapamientoFechas(
          ciclo.inicio,
          ciclo.fin,
        );
        
        if (solapamiento) {
          Navigator.pop(context);
          _mostrarError('Las fechas se solapan con otro ciclo existente');
          return;
        }

        exito = await _cicloCrud.crearCiclo(ciclo);
      } else {
        // Verificar si el código de ciclo ya existe (excluyendo el actual)
        final cicloExiste = await _cicloCrud.verificarCicloExistente(
          ciclo.ciclo,
          idExcluir: ciclo.id,
        );
        
        if (cicloExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otro ciclo con ese código');
          return;
        }

        // Verificar solapamiento de fechas (excluyendo el actual)
        final solapamiento = await _cicloCrud.verificarSolapamientoFechas(
          ciclo.inicio,
          ciclo.fin,
          idExcluir: ciclo.id,
        );
        
        if (solapamiento) {
          Navigator.pop(context);
          _mostrarError('Las fechas se solapan con otro ciclo existente');
          return;
        }

        exito = await _cicloCrud.actualizarCiclo(ciclo);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ciclo.id == null
                  ? 'Ciclo creado exitosamente'
                  : 'Ciclo actualizado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar el ciclo');
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
                    hintText: 'Buscar por ciclo, descripción o año...',
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
                label: const Text('Agregar Ciclo'),
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
                  : ciclosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay ciclos para mostrar',
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
                                DataColumn(label: Text('Ciclo')),
                                DataColumn(label: Text('Descripción')),
                                DataColumn(label: Text('Año')),
                                DataColumn(label: Text('Fecha Inicio')),
                                DataColumn(label: Text('Fecha Fin')),
                                DataColumn(label: Text('Vencimiento')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: ciclosFiltrados.map((ciclo) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${ciclo.id}')),
                                    DataCell(Text(ciclo.ciclo)),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          ciclo.descripcion,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('${ciclo.anio}')),
                                    DataCell(Text(_formatearFecha(ciclo.inicio))),
                                    DataCell(Text(_formatearFecha(ciclo.fin))),
                                    DataCell(Text(_formatearFecha(ciclo.vencimiento))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: ciclo.estado == 'ACTIVO'
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          ciclo.estado,
                                          style: TextStyle(
                                            color: ciclo.estado == 'ACTIVO'
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
                                            onPressed: () => _mostrarDialogoEdicion(ciclo),
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

class _DialogoEditarCiclo extends StatefulWidget {
  final Ciclo? ciclo;
  final Function(Ciclo) onGuardar;

  const _DialogoEditarCiclo({
    this.ciclo,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarCiclo> createState() => _DialogoEditarCicloState();
}

class _DialogoEditarCicloState extends State<_DialogoEditarCiclo> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _cicloController;
  late TextEditingController _descripcionController;
  late TextEditingController _anioController;
  
  late DateTime _fechaInicio;
  late DateTime _fechaFin;
  late DateTime _fechaVencimiento;
  late String _estadoSeleccionado;

  final List<String> _estados = ['ACTIVO', 'INACTIVO'];

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  @override
  void initState() {
    super.initState();
    
    _cicloController = TextEditingController(text: widget.ciclo?.ciclo ?? '');
    _descripcionController = TextEditingController(text: widget.ciclo?.descripcion ?? '');
    _anioController = TextEditingController(text: widget.ciclo?.anio.toString() ?? DateTime.now().year.toString());
    
    _fechaInicio = widget.ciclo?.inicio ?? DateTime.now();
    _fechaFin = widget.ciclo?.fin ?? DateTime.now().add(const Duration(days: 30));
    _fechaVencimiento = widget.ciclo?.vencimiento ?? DateTime.now().add(const Duration(days: 40));
    _estadoSeleccionado = widget.ciclo?.estado ?? 'ACTIVO';
  }

  Future<void> _seleccionarFecha(BuildContext context, String tipo) async {
    DateTime? fechaSeleccionada;
    DateTime fechaActual;
    
    switch (tipo) {
      case 'inicio':
        fechaActual = _fechaInicio;
        break;
      case 'fin':
        fechaActual = _fechaFin;
        break;
      case 'vencimiento':
        fechaActual = _fechaVencimiento;
        break;
      default:
        fechaActual = DateTime.now();
    }

    fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: fechaActual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (fechaSeleccionada != null) {
      setState(() {
        switch (tipo) {
          case 'inicio':
            _fechaInicio = fechaSeleccionada!;
            break;
          case 'fin':
            _fechaFin = fechaSeleccionada!;
            break;
          case 'vencimiento':
            _fechaVencimiento = fechaSeleccionada!;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 750),
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
                  const Icon(Icons.calendar_month, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.ciclo == null ? 'Agregar Ciclo' : 'Editar Ciclo',
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
                              controller: _cicloController,
                              label: 'Código de Ciclo *',
                              hint: 'Ej: 2024-01',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _anioController,
                              label: 'Año *',
                              hint: 'Ingrese el año',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Campo requerido';
                                if (int.tryParse(value!) == null) return 'Debe ser un número';
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
                        hint: 'Ej: Ciclo de Enero 2024',
                        maxLines: 2,
                        validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown<String>(
                        label: 'Estado *',
                        value: _estadoSeleccionado,
                        items: _estados,
                        onChanged: (value) => setState(() => _estadoSeleccionado = value!),
                        itemLabel: (item) => item,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Fechas del Ciclo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 16),
                      _buildDateField(
                        label: 'Fecha de Inicio *',
                        fecha: _fechaInicio,
                        onTap: () => _seleccionarFecha(context, 'inicio'),
                      ),
                      const SizedBox(height: 16),
                      _buildDateField(
                        label: 'Fecha de Fin *',
                        fecha: _fechaFin,
                        onTap: () => _seleccionarFecha(context, 'fin'),
                      ),
                      const SizedBox(height: 16),
                      _buildDateField(
                        label: 'Fecha de Vencimiento *',
                        fecha: _fechaVencimiento,
                        onTap: () => _seleccionarFecha(context, 'vencimiento'),
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
                                'La fecha de vencimiento debe ser posterior a la fecha de fin del ciclo.',
                                style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
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
                    onPressed: _guardarCiclo,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                  _formatearFecha(fecha),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _guardarCiclo() {
    if (_formKey.currentState!.validate()) {
      // Validar que la fecha de fin sea posterior a la fecha de inicio
      if (_fechaFin.isBefore(_fechaInicio)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La fecha de fin debe ser posterior a la fecha de inicio'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validar que la fecha de vencimiento sea posterior a la fecha de fin
      if (_fechaVencimiento.isBefore(_fechaFin)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La fecha de vencimiento debe ser posterior a la fecha de fin'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final ciclo = Ciclo(
        id: widget.ciclo?.id,
        ciclo: _cicloController.text,
        descripcion: _descripcionController.text,
        anio: int.parse(_anioController.text),
        inicio: _fechaInicio,
        fin: _fechaFin,
        vencimiento: _fechaVencimiento,
        estado: _estadoSeleccionado,
      );

      widget.onGuardar(ciclo);
    }
  }

  @override
  void dispose() {
    _cicloController.dispose();
    _descripcionController.dispose();
    _anioController.dispose();
    super.dispose();
  }
}