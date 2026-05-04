import 'package:flutter/material.dart';
import 'package:myapp/dao/barriocrudimpl.dart';
import 'package:myapp/dao/empresadao/dato_empresacrudimpl.dart';
import 'package:myapp/dao/empresadao/establecimientocrudimpl.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/empresa/dato_empresa.dart';

class EstablecimientosPage extends StatefulWidget {
  const EstablecimientosPage({Key? key}) : super(key: key);

  @override
  State<EstablecimientosPage> createState() => _EstablecimientosPageState();
}

class _EstablecimientosPageState extends State<EstablecimientosPage> {
  final EstablecimientoCrudImpl _establecimientoCrud = EstablecimientoCrudImpl();
  final BarrioCrudImpl _barrioCrud = BarrioCrudImpl();
  final DatoEmpresaCrudImpl _empresaCrud = DatoEmpresaCrudImpl();
  
  List<Establecimiento> establecimientos = [];
  List<Establecimiento> establecimientosFiltrados = [];
  List<Barrio> barrios = [];
  List<DatoEmpresa> empresas = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarEstablecimientos);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultados = await Future.wait([
        _establecimientoCrud.leerEstablecimientos(),
        _barrioCrud.leerBarrios(),
        _empresaCrud.leerDatosEmpresas(),
      ]);

      setState(() {
        establecimientos = resultados[0] as List<Establecimiento>;
        barrios = resultados[1] as List<Barrio>;
        empresas = resultados[2] as List<DatoEmpresa>;
        establecimientosFiltrados = establecimientos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarEstablecimientos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        establecimientosFiltrados = establecimientos;
      } else {
        establecimientosFiltrados = establecimientos.where((est) {
          return est.codigo_establecimiento.toLowerCase().contains(query) ||
              est.denominacion.toLowerCase().contains(query) ||
              est.direccion.toLowerCase().contains(query) ||
              est.fk_empresa.razon_social.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarDialogoEdicion(Establecimiento? establecimiento) {
    if (barrios.isEmpty || empresas.isEmpty) {
      _mostrarError('Cargando datos necesarios, por favor espere...');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _DialogoEditarEstablecimiento(
        establecimiento: establecimiento,
        barrios: barrios,
        empresas: empresas,
        onGuardar: (establecimientoEditado) async {
          Navigator.of(dialogContext).pop();
          await _guardarEstablecimiento(establecimientoEditado);
        },
      ),
    );
  }

  Future<void> _guardarEstablecimiento(Establecimiento establecimiento) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      if (establecimiento.id_establecimiento == null) {
        final codigoExiste = await _establecimientoCrud.verificarCodigoExistente(
          establecimiento.codigo_establecimiento,
        );
        
        if (codigoExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe un establecimiento con ese código');
          return;
        }

        final establecimientoCreado = await _establecimientoCrud.crearEstablecimiento(establecimiento);
        exito = establecimientoCreado != null;
      } else {
        final codigoExiste = await _establecimientoCrud.verificarCodigoExistente(
          establecimiento.codigo_establecimiento,
          idEstablecimientoExcluir: establecimiento.id_establecimiento,
        );
        
        if (codigoExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otro establecimiento con ese código');
          return;
        }

        exito = await _establecimientoCrud.actualizarEstablecimiento(establecimiento);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              establecimiento.id_establecimiento == null
                  ? 'Establecimiento creado exitosamente'
                  : 'Establecimiento actualizado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar el establecimiento');
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
                    hintText: 'Buscar por código, denominación, dirección o empresa...',
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
                label: Text('Agregar Establecimiento'),
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
                  : establecimientosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay establecimientos para mostrar',
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
                                DataColumn(label: Text('Código')),
                                DataColumn(label: Text('Denominación')),
                                DataColumn(label: Text('Empresa')),
                                DataColumn(label: Text('Dirección')),
                                DataColumn(label: Text('Nro. Casa')),
                                DataColumn(label: Text('Barrio')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: establecimientosFiltrados.map((est) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${est.id_establecimiento}')),
                                    DataCell(Text(est.codigo_establecimiento)),
                                    DataCell(Text(est.denominacion)),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          est.fk_empresa.razon_social,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 120,
                                        child: Text(
                                          est.direccion,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(est.numero_casa)),
                                    DataCell(Text(est.fk_barrio.nombre_barrio)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: est.estado_establecimiento == 'ACTIVO'
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          est.estado_establecimiento,
                                          style: TextStyle(
                                            color: est.estado_establecimiento == 'ACTIVO'
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
                                            onPressed: () => _mostrarDialogoEdicion(est),
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

class _DialogoEditarEstablecimiento extends StatefulWidget {
  final Establecimiento? establecimiento;
  final List<Barrio> barrios;
  final List<DatoEmpresa> empresas;
  final Function(Establecimiento) onGuardar;

  _DialogoEditarEstablecimiento({
    this.establecimiento,
    required this.barrios,
    required this.empresas,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarEstablecimiento> createState() => _DialogoEditarEstablecimientoState();
}

class _DialogoEditarEstablecimientoState extends State<_DialogoEditarEstablecimiento> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codigoController;
  late TextEditingController _direccionController;
  late TextEditingController _numeroCasaController;
  late TextEditingController _complemento1Controller;
  late TextEditingController _complemento2Controller;
  late TextEditingController _telefonoController;
  late TextEditingController _emailController;
  late TextEditingController _denominacionController;
  
  late String _estadoSeleccionado;
  late Barrio _barrioSeleccionado;
  late DatoEmpresa _empresaSeleccionada;

  final List<String> _estados = ['ACTIVO', 'INACTIVO'];

  @override
  void initState() {
    super.initState();
    
    _codigoController = TextEditingController(text: widget.establecimiento?.codigo_establecimiento ?? '');
    _direccionController = TextEditingController(text: widget.establecimiento?.direccion ?? '');
    _numeroCasaController = TextEditingController(text: widget.establecimiento?.numero_casa ?? '');
    _complemento1Controller = TextEditingController(text: widget.establecimiento?.complemento_direccion_1 ?? '');
    _complemento2Controller = TextEditingController(text: widget.establecimiento?.complemento_direccion_2 ?? '');
    _telefonoController = TextEditingController(text: widget.establecimiento?.telefono ?? '');
    _emailController = TextEditingController(text: widget.establecimiento?.email ?? '');
    _denominacionController = TextEditingController(text: widget.establecimiento?.denominacion ?? '');

    _estadoSeleccionado = widget.establecimiento?.estado_establecimiento ?? 'ACTIVO';
    
    _barrioSeleccionado = widget.establecimiento != null
        ? widget.barrios.firstWhere(
            (b) => b.cod_barrio == widget.establecimiento!.fk_barrio.cod_barrio,
            orElse: () => widget.barrios.first,
          )
        : widget.barrios.first;
    
    _empresaSeleccionada = widget.establecimiento != null
        ? widget.empresas.firstWhere(
            (e) => e.id_empresa == widget.establecimiento!.fk_empresa.id_empresa,
            orElse: () => widget.empresas.first,
          )
        : widget.empresas.first;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 900,
        constraints: BoxConstraints(maxHeight: 700),
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
                  Icon(Icons.store, color: Theme.of(context).cardColor),
                  const SizedBox(width: 12),
                  Text(
                    widget.establecimiento == null ? 'Agregar Establecimiento' : 'Editar Establecimiento',
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _codigoController,
                              label: 'Código de Establecimiento *',
                              hint: 'Ej: 001',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _denominacionController,
                              label: 'Denominación *',
                              hint: 'Ingrese denominación',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown<DatoEmpresa>(
                        label: 'Empresa *',
                        value: _empresaSeleccionada,
                        items: widget.empresas,
                        onChanged: (value) => setState(() => _empresaSeleccionada = value!),
                        itemLabel: (item) => '${item.ruc} - ${item.razon_social}',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _direccionController,
                              label: 'Dirección *',
                              hint: 'Ingrese dirección',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _numeroCasaController,
                              label: 'Nro. Casa *',
                              hint: 'Ej: 123',
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
                              controller: _complemento1Controller,
                              label: 'Complemento Dirección 1 *',
                              hint: 'Ej: Entre calles X e Y',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _complemento2Controller,
                              label: 'Complemento Dirección 2',
                              hint: 'Información adicional (opcional)',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown<Barrio>(
                        label: 'Barrio *',
                        value: _barrioSeleccionado,
                        items: widget.barrios,
                        onChanged: (value) => setState(() => _barrioSeleccionado = value!),
                        itemLabel: (item) => item.nombre_barrio,
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
                          ),
                        ],
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
                    onPressed: _guardarEstablecimiento,
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

  void _guardarEstablecimiento() {
    if (_formKey.currentState!.validate()) {
      final establecimiento = Establecimiento(
        id_establecimiento: widget.establecimiento?.id_establecimiento,
        codigo_establecimiento: _codigoController.text,
        direccion: _direccionController.text,
        numero_casa: _numeroCasaController.text,
        complemento_direccion_1: _complemento1Controller.text,
        complemento_direccion_2: _complemento2Controller.text.isEmpty ? null : _complemento2Controller.text,
        telefono: _telefonoController.text.isEmpty ? null : _telefonoController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        denominacion: _denominacionController.text,
        estado_establecimiento: _estadoSeleccionado,
        fk_barrio: _barrioSeleccionado,
        fk_empresa: _empresaSeleccionada,
      );

      widget.onGuardar(establecimiento);
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _direccionController.dispose();
    _numeroCasaController.dispose();
    _complemento1Controller.dispose();
    _complemento2Controller.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _denominacionController.dispose();
    super.dispose();
  }
}