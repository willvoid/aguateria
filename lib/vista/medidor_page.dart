import 'package:flutter/material.dart';
import 'package:myapp/dao/medidorcrudimpl.dart';
import 'package:myapp/dao/inmueblescrudimpl.dart';
import 'package:myapp/modelo/medidor.dart';
import 'package:myapp/modelo/inmuebles.dart';

class MedidoresPage extends StatefulWidget {
  const MedidoresPage({Key? key}) : super(key: key);

  @override
  State<MedidoresPage> createState() => _MedidoresPageState();
}

class _MedidoresPageState extends State<MedidoresPage> {
  final MedidorCrudImpl _medidorCrud = MedidorCrudImpl();
  final InmuebleCrudImpl _inmueblesCrud = InmuebleCrudImpl();
  
  List<Medidor> medidores = [];
  List<Medidor> medidoresFiltrados = [];
  List<Inmuebles> inmuebles = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarMedidores);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultados = await Future.wait([
        _medidorCrud.leerMedidores(),
        _inmueblesCrud.leerInmuebles(),
      ]);

      setState(() {
        medidores = resultados[0] as List<Medidor>;
        inmuebles = resultados[1] as List<Inmuebles>;
        medidoresFiltrados = medidores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarMedidores() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        medidoresFiltrados = medidores;
      } else {
        medidoresFiltrados = medidores.where((medidor) {
          return medidor.nro.toString().contains(query) ||
              medidor.estado.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarDialogoEdicion(Medidor? medidor) {
    if (inmuebles.isEmpty) {
      _mostrarError('Cargando datos necesarios, por favor espere...');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarMedidor(
        medidor: medidor,
        inmuebles: inmuebles,
        onGuardar: (medidorEditado) async {
          Navigator.of(dialogContext).pop();
          await _guardarMedidor(medidorEditado);
        },
      ),
    );
  }

  Future<void> _guardarMedidor(Medidor medidor) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (medidor.idMedidor == null) {
        final numeroExiste = await _medidorCrud.verificarNumeroMedidorExistente(medidor.nro);
        
        if (numeroExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe un medidor con ese número');
          return;
        }

        final medidorCreado = await _medidorCrud.crearMedidor(medidor);
        exito = medidorCreado != null;
      } else {
        final numeroExiste = await _medidorCrud.verificarNumeroMedidorExistente(
          medidor.nro,
          idMedidorExcluir: medidor.idMedidor,
        );
        
        if (numeroExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otro medidor con ese número');
          return;
        }

        exito = await _medidorCrud.actualizarMedidor(medidor);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              medidor.idMedidor == null
                  ? 'Medidor creado exitosamente'
                  : 'Medidor actualizado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar el medidor');
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError('Error: $e');
    }
  }

  void _eliminarMedidor(Medidor medidor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar el medidor #${medidor.nro}?'),
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

              final exito = await _medidorCrud.eliminarMedidor(medidor.idMedidor!);
              Navigator.pop(context);

              if (exito) {
                await _cargarDatos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Medidor eliminado exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                _mostrarError('Error al eliminar el medidor');
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

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
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
                    hintText: 'Buscar por número o estado...',
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
                label: const Text('Agregar Medidor'),
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
                  : medidoresFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.speed, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay medidores para mostrar',
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
                                DataColumn(label: Text('Número')),
                                DataColumn(label: Text('Fecha Instalación')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Inmueble')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: medidoresFiltrados.map((medidor) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${medidor.idMedidor}')),
                                    DataCell(Text('${medidor.nro}')),
                                    DataCell(Text(_formatearFecha(medidor.fechaInstalacion))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: medidor.estado == 'ACTIVO'
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          medidor.estado,
                                          style: TextStyle(
                                            color: medidor.estado == 'ACTIVO'
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('ID: ${medidor.inmueble.id}')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0085FF)),
                                            onPressed: () => _mostrarDialogoEdicion(medidor),
                                            tooltip: 'Editar',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () => _eliminarMedidor(medidor),
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

class _DialogoEditarMedidor extends StatefulWidget {
  final Medidor? medidor;
  final List<Inmuebles> inmuebles;
  final Function(Medidor) onGuardar;

  const _DialogoEditarMedidor({
    this.medidor,
    required this.inmuebles,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarMedidor> createState() => _DialogoEditarMedidorState();
}

class _DialogoEditarMedidorState extends State<_DialogoEditarMedidor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nroController;
  late DateTime _fechaInstalacion;
  late String _estadoSeleccionado;
  late Inmuebles _inmuebleSeleccionado;

  final List<String> _estados = ['ACTIVO', 'INACTIVO'];

  @override
  void initState() {
    super.initState();
    
    _nroController = TextEditingController(text: widget.medidor?.nro.toString() ?? '');
    _fechaInstalacion = widget.medidor?.fechaInstalacion ?? DateTime.now();
    _estadoSeleccionado = widget.medidor?.estado ?? 'ACTIVO';
    
    _inmuebleSeleccionado = widget.medidor != null
        ? widget.inmuebles.firstWhere(
            (i) => i.id == widget.medidor!.inmueble.id,
            orElse: () => widget.inmuebles.first,
          )
        : widget.inmuebles.first;
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaInstalacion,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'ES'),
    );
    
    if (picked != null) {
      setState(() {
        _fechaInstalacion = picked;
      });
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 500),
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
                  const Icon(Icons.speed, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.medidor == null ? 'Agregar Medidor' : 'Editar Medidor',
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
                        controller: _nroController,
                        label: 'Número de Medidor *',
                        hint: 'Ingrese número de medidor',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (int.tryParse(value!) == null) return 'Debe ser un número';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDateField(
                        label: 'Fecha de Instalación *',
                        fecha: _fechaInstalacion,
                        onTap: () => _seleccionarFecha(context),
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown<String>(
                        label: 'Estado *',
                        value: _estadoSeleccionado,
                        items: _estados,
                        onChanged: (value) => setState(() => _estadoSeleccionado = value!),
                        itemLabel: (item) => item,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown<Inmuebles>(
                        label: 'Inmueble *',
                        value: _inmuebleSeleccionado,
                        items: widget.inmuebles,
                        onChanged: (value) => setState(() => _inmuebleSeleccionado = value!),
                        itemLabel: (item) => 'ID: ${item.id}',
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
                    onPressed: _guardarMedidor,
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
                Text(_formatearFecha(fecha)),
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

  void _guardarMedidor() {
    if (_formKey.currentState!.validate()) {
      final medidor = Medidor(
        idMedidor: widget.medidor?.idMedidor,
        nro: int.parse(_nroController.text),
        fechaInstalacion: _fechaInstalacion,
        estado: _estadoSeleccionado,
        inmueble: _inmuebleSeleccionado,
      );

      widget.onGuardar(medidor);
    }
  }

  @override
  void dispose() {
    _nroController.dispose();
    super.dispose();
  }
}