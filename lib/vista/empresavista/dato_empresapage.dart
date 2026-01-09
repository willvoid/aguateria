import 'package:flutter/material.dart';
import 'package:myapp/dao/empresadao/dato_empresacrudimpl.dart';
import 'package:myapp/dao/empresadao/tipo_contribuyentecrudimpl.dart';
import 'package:myapp/dao/empresadao/tipo_regimencrudimpl.dart';
import 'package:myapp/dao/empresadao/actividad_empresacrudimpl.dart';
import 'package:myapp/dao/empresadao/actividad_economicacrudimpl.dart' hide ActividadEmpresaCrudImpl;
import 'package:myapp/modelo/empresa/dato_empresa.dart';
import 'package:myapp/modelo/empresa/tipo_contribuyente.dart';
import 'package:myapp/modelo/empresa/tipo_regimen.dart';
import 'package:myapp/modelo/empresa/actividad_economica.dart';
import 'package:myapp/modelo/empresa/actividad_empresa.dart';

class DatoEmpresaPage extends StatefulWidget {
  const DatoEmpresaPage({Key? key}) : super(key: key);

  @override
  State<DatoEmpresaPage> createState() => _DatoEmpresaPageState();
}

class _DatoEmpresaPageState extends State<DatoEmpresaPage> {
  final DatoEmpresaCrudImpl _empresaCrud = DatoEmpresaCrudImpl();
  final TipoContribuyenteCrudImpl _tipoContribuyenteCrud = TipoContribuyenteCrudImpl();
  final TipoRegimenCrudImpl _tipoRegimenCrud = TipoRegimenCrudImpl();
  final ActividadEmpresaCrudImpl _actividadEmpresaCrud = ActividadEmpresaCrudImpl();
  final ActividadEconomicaCrudImpl _actividadEconomicaCrud = ActividadEconomicaCrudImpl();
  
  List<DatoEmpresa> empresas = [];
  List<DatoEmpresa> empresasFiltradas = [];
  List<TipoContribuyente> tiposContribuyente = [];
  List<TipoRegimen> tiposRegimen = [];
  List<ActividadEconomica> actividadesEconomicas = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarEmpresas);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final resultados = await Future.wait([
        _empresaCrud.leerDatosEmpresas(),
        _tipoContribuyenteCrud.leerTiposContribuyente(),
        _tipoRegimenCrud.leerTiposRegimen(),
        _actividadEconomicaCrud.leerActividadesEconomicas(),
      ]);

      setState(() {
        empresas = resultados[0] as List<DatoEmpresa>;
        tiposContribuyente = resultados[1] as List<TipoContribuyente>;
        tiposRegimen = resultados[2] as List<TipoRegimen>;
        actividadesEconomicas = resultados[3] as List<ActividadEconomica>;
        empresasFiltradas = empresas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  void _filtrarEmpresas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        empresasFiltradas = empresas;
      } else {
        empresasFiltradas = empresas.where((empresa) {
          return empresa.ruc.toLowerCase().contains(query) ||
              empresa.razon_social.toLowerCase().contains(query) ||
              empresa.nombre_fantasia.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _mostrarDialogoEdicion(DatoEmpresa? empresa) async {
  if (tiposContribuyente.isEmpty || tiposRegimen.isEmpty || actividadesEconomicas.isEmpty) {
    _mostrarError('Cargando datos necesarios, por favor espere...');
    return;
  }

  // Cargar actividades existentes si es edición
  List<ActividadEconomica> actividadesSeleccionadas = [];
  if (empresa != null) {
    // Obtener solo los IDs
    final idsActividades = await _actividadEmpresaCrud.leerIdsActividadesPorEmpresa(empresa.id_empresa!);
    
    print('IDs obtenidos: $idsActividades');
    
    // Buscar las actividades completas en la lista que ya tenemos
    actividadesSeleccionadas = actividadesEconomicas.where((actividad) {
      return idsActividades.contains(actividad.id_actividad_economica);
    }).toList();
    
    print('Actividades encontradas: ${actividadesSeleccionadas.length}');
    for (var act in actividadesSeleccionadas) {
      print('  - ${act.codigo_actividad}: ${act.descripcion_actividad}');
    }
  }

  if (!mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => _DialogoEditarEmpresa(
      empresa: empresa,
      tiposContribuyente: tiposContribuyente,
      tiposRegimen: tiposRegimen,
      actividadesEconomicas: actividadesEconomicas,
      actividadesSeleccionadas: actividadesSeleccionadas,
      onGuardar: (empresaEditada, actividadesSeleccionadas) async {
        Navigator.of(dialogContext).pop();
        await _guardarEmpresa(empresaEditada, actividadesSeleccionadas);
      },
    ),
  );
}

  Future<void> _guardarEmpresa(DatoEmpresa empresa, List<ActividadEconomica> actividadesSeleccionadas) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool exito;
      DatoEmpresa? empresaGuardada;
      
      if (empresa.id_empresa == null) {
        // Crear nueva empresa
        final rucExiste = await _empresaCrud.verificarRucExistente(empresa.ruc);
        
        if (rucExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe una empresa con ese RUC');
          return;
        }

        empresaGuardada = await _empresaCrud.crearDatoEmpresa(empresa);
        exito = empresaGuardada != null;
      } else {
        // Actualizar empresa existente
        final rucExiste = await _empresaCrud.verificarRucExistente(
          empresa.ruc,
          idEmpresaExcluir: empresa.id_empresa,
        );
        
        if (rucExiste) {
          Navigator.pop(context);
          _mostrarError('Ya existe otra empresa con ese RUC');
          return;
        }

        exito = await _empresaCrud.actualizarDatoEmpresa(empresa);
        empresaGuardada = empresa;
      }

      // Guardar actividades económicas
      if (exito && empresaGuardada != null && empresaGuardada.id_empresa != null) {
        await _guardarActividadesEmpresa(empresaGuardada.id_empresa!, actividadesSeleccionadas);
      }

      Navigator.pop(context);

      if (exito) {
        await _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              empresa.id_empresa == null
                  ? 'Empresa creada exitosamente'
                  : 'Empresa actualizada exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _mostrarError('Error al guardar la empresa');
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError('Error: $e');
    }
  }

  Future<void> _guardarActividadesEmpresa(int idEmpresa, List<ActividadEconomica> actividadesSeleccionadas) async {
    try {
      // Eliminar todas las actividades existentes de la empresa
      await _actividadEmpresaCrud.eliminarActividadEmpresa(idEmpresa);

      // Crear las nuevas relaciones
      for (var actividad in actividadesSeleccionadas) {
        final actividadEmpresa = ActividadEmpresa(
          fk_empresa: DatoEmpresa(
            id_empresa: idEmpresa,
            ruc: '',
            razon_social: '',
            nombre_fantasia: '',
            fk_contribuyente: tiposContribuyente.first,
            fk_regimen: tiposRegimen.first,
            estado: 'ACTIVO',
          ),
          fk_actividad: actividad,
        );
        
        await _actividadEmpresaCrud.crearActividadEmpresa(actividadEmpresa);
      }
    } catch (e) {
      print('Error al guardar actividades de la empresa: $e');
    }
  }

  void _eliminarEmpresa(DatoEmpresa empresa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar la empresa ${empresa.razon_social}?'),
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

              // Eliminar primero las actividades asociadas
              await _actividadEmpresaCrud.eliminarActividadEmpresa(empresa.id_empresa!);
              
              final exito = await _empresaCrud.eliminarDatoEmpresa(empresa.id_empresa!);
              Navigator.pop(context);

              if (exito) {
                await _cargarDatos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Empresa eliminada exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                _mostrarError('Error al eliminar la empresa');
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
                    hintText: 'Buscar por RUC, razón social o nombre fantasía...',
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
                label: const Text('Agregar Empresa'),
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
                  : empresasFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay empresas para mostrar',
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
                                DataColumn(label: Text('RUC')),
                                DataColumn(label: Text('Razón Social')),
                                DataColumn(label: Text('Nombre Fantasía')),
                                DataColumn(label: Text('Tipo Contribuyente')),
                                DataColumn(label: Text('Tipo Régimen')),
                                DataColumn(label: Text('Estado')),
                                DataColumn(label: Text('Acciones')),
                              ],
                              rows: empresasFiltradas.map((empresa) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text('${empresa.id_empresa}')),
                                    DataCell(Text(empresa.ruc)),
                                    DataCell(Text(empresa.razon_social)),
                                    DataCell(Text(empresa.nombre_fantasia)),
                                    DataCell(Text(empresa.fk_contribuyente.descripcion)),
                                    DataCell(Text(empresa.fk_regimen.descripcion)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: empresa.estado == 'ACTIVO'
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          empresa.estado,
                                          style: TextStyle(
                                            color: empresa.estado == 'ACTIVO'
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
                                            onPressed: () => _mostrarDialogoEdicion(empresa),
                                            tooltip: 'Editar',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () => _eliminarEmpresa(empresa),
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

class _DialogoEditarEmpresa extends StatefulWidget {
  final DatoEmpresa? empresa;
  final List<TipoContribuyente> tiposContribuyente;
  final List<TipoRegimen> tiposRegimen;
  final List<ActividadEconomica> actividadesEconomicas;
  final List<ActividadEconomica> actividadesSeleccionadas;
  final Function(DatoEmpresa, List<ActividadEconomica>) onGuardar;

  const _DialogoEditarEmpresa({
    this.empresa,
    required this.tiposContribuyente,
    required this.tiposRegimen,
    required this.actividadesEconomicas,
    required this.actividadesSeleccionadas,
    required this.onGuardar,
  });

  @override
  State<_DialogoEditarEmpresa> createState() => _DialogoEditarEmpresaState();
}

class _DialogoEditarEmpresaState extends State<_DialogoEditarEmpresa> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rucController;
  late TextEditingController _razonSocialController;
  late TextEditingController _nombreFantasiaController;
  late TextEditingController _searchActividadController;
  
  late String _estadoSeleccionado;
  late TipoContribuyente _tipoContribuyenteSeleccionado;
  late TipoRegimen _tipoRegimenSeleccionado;
  late List<ActividadEconomica> _actividadesSeleccionadas;
  List<ActividadEconomica> _actividadesFiltradas = [];

  final List<String> _estados = ['ACTIVO', 'INACTIVO'];

  @override
@override
void initState() {
  super.initState();
  
  _rucController = TextEditingController(text: widget.empresa?.ruc ?? '');
  _razonSocialController = TextEditingController(text: widget.empresa?.razon_social ?? '');
  _nombreFantasiaController = TextEditingController(text: widget.empresa?.nombre_fantasia ?? '');
  _searchActividadController = TextEditingController();
  _searchActividadController.addListener(_filtrarActividades);

  _estadoSeleccionado = widget.empresa?.estado ?? 'ACTIVO';
  
  _tipoContribuyenteSeleccionado = widget.empresa != null
      ? widget.tiposContribuyente.firstWhere(
          (t) => t.id_tipo_contribuyente == widget.empresa!.fk_contribuyente.id_tipo_contribuyente,
          orElse: () => widget.tiposContribuyente.first,
        )
      : widget.tiposContribuyente.first;
  
  _tipoRegimenSeleccionado = widget.empresa != null
      ? widget.tiposRegimen.firstWhere(
          (t) => t.id_regimen == widget.empresa!.fk_regimen.id_regimen,
          orElse: () => widget.tiposRegimen.first,
        )
      : widget.tiposRegimen.first;
  
  // ← CORRECCIÓN AQUÍ: Inicializar correctamente la lista
  _actividadesSeleccionadas = List.from(widget.actividadesSeleccionadas);
  _actividadesFiltradas = widget.actividadesEconomicas;
  
  // Debug: Imprimir para verificar
  print('Actividades seleccionadas inicialmente: ${_actividadesSeleccionadas.length}');
  for (var act in _actividadesSeleccionadas) {
    print('  - ID: ${act.id_actividad_economica}, Código: ${act.codigo_actividad}');
  }
}


  void _filtrarActividades() {
    final query = _searchActividadController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _actividadesFiltradas = widget.actividadesEconomicas;
      } else {
        _actividadesFiltradas = widget.actividadesEconomicas.where((actividad) {
          return actividad.codigo_actividad.toString().toLowerCase().contains(query) ||
              actividad.descripcion_actividad.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // Seleccionar actividad y mantener selecionado si se desea editar
void _toggleActividad(ActividadEconomica actividad) {
  setState(() {
    final index = _actividadesSeleccionadas.indexWhere(
      (a) => a.id_actividad_economica == actividad.id_actividad_economica
    );
    
    if (index != -1) {
      _actividadesSeleccionadas.removeAt(index);
      print('Actividad ${actividad.codigo_actividad} desmarcada');
    } else {
      _actividadesSeleccionadas.add(actividad);
      print('Actividad ${actividad.codigo_actividad} marcada');
    }
    print('Total seleccionadas: ${_actividadesSeleccionadas.length}');
  });
}

bool _isActividadSeleccionada(ActividadEconomica actividad) {
  final seleccionada = _actividadesSeleccionadas.any(
    (a) => a.id_actividad_economica == actividad.id_actividad_economica
  );
  return seleccionada;
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 900,
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
                  const Icon(Icons.business, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.empresa == null ? 'Agregar Empresa' : 'Editar Empresa',
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna izquierda - Datos básicos
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Datos de la Empresa',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _rucController,
                              label: 'RUC *',
                              hint: 'Ingrese RUC',
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Campo requerido';
                                if (value!.length < 6) return 'RUC debe tener al menos 6 dígitos';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _razonSocialController,
                              label: 'Razón Social *',
                              hint: 'Ingrese razón social',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _nombreFantasiaController,
                              label: 'Nombre Fantasía *',
                              hint: 'Ingrese nombre fantasía',
                              validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDropdown<TipoContribuyente>(
                                    label: 'Tipo Contribuyente *',
                                    value: _tipoContribuyenteSeleccionado,
                                    items: widget.tiposContribuyente,
                                    onChanged: (value) => setState(() => _tipoContribuyenteSeleccionado = value!),
                                    itemLabel: (item) => item.descripcion,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDropdown<TipoRegimen>(
                                    label: 'Tipo Régimen *',
                                    value: _tipoRegimenSeleccionado,
                                    items: widget.tiposRegimen,
                                    onChanged: (value) => setState(() => _tipoRegimenSeleccionado = value!),
                                    itemLabel: (item) => item.descripcion,
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
                      const SizedBox(width: 24),
                      // Columna derecha - Actividades económicas
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Actividades Económicas',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_actividadesSeleccionadas.length} seleccionada(s)',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchActividadController,
                              decoration: InputDecoration(
                                hintText: 'Buscar actividad...',
                                prefixIcon: const Icon(Icons.search, size: 18),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 350,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: ListView.builder(
                                itemCount: _actividadesFiltradas.length,
                                itemBuilder: (context, index) {
                                  final actividad = _actividadesFiltradas[index];
                                  final isSeleccionada = _isActividadSeleccionada(actividad);
                                  
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey.shade200),
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      value: isSeleccionada,
                                      onChanged: (value) => _toggleActividad(actividad),
                                      title: Text(
                                        actividad.codigo_actividad.toString(),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        actividad.descripcion_actividad,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      activeColor: const Color(0xFF0085FF),
                                    ),
                                  );
                                },
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
                    onPressed: _guardarEmpresa,
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

  void _guardarEmpresa() {
    if (_formKey.currentState!.validate()) {
      final empresa = DatoEmpresa(
        id_empresa: widget.empresa?.id_empresa,
        ruc: _rucController.text,
        razon_social: _razonSocialController.text,
        nombre_fantasia: _nombreFantasiaController.text,
        fk_contribuyente: _tipoContribuyenteSeleccionado,
        fk_regimen: _tipoRegimenSeleccionado,
        estado: _estadoSeleccionado,
      );

      widget.onGuardar(empresa, _actividadesSeleccionadas);
    }
  }

  @override
  void dispose() {
    _rucController.dispose();
    _razonSocialController.dispose();
    _nombreFantasiaController.dispose();
    _searchActividadController.dispose();
    super.dispose();
  }
}