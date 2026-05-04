import 'package:flutter/material.dart';
import 'package:myapp/dao/configuracion_sistema_crudimpl.dart';
import 'package:myapp/dao/empresadao/datos_transferenciacrudimpl.dart';
import 'package:myapp/dao/empresadao/establecimientocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/modo_pagocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/monedascrudimpl.dart';
import 'package:myapp/dao/facturaciondao/tipo_facturacrudimpl.dart';
import 'package:myapp/modelo/configuracion_sistema.dart';
import 'package:myapp/modelo/empresa/datos_transferencia.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';

class OpcionesPage extends StatefulWidget {
  const OpcionesPage({Key? key}) : super(key: key);

  @override
  State<OpcionesPage> createState() => _OpcionesPageState();
}

class _OpcionesPageState extends State<OpcionesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar Header
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0085FF),
            unselectedLabelColor: const Color(0xFF6B7280),
            indicatorColor: const Color(0xFF0085FF),
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.settings_outlined, size: 18),
                text: 'Configuración del Sistema',
              ),
              Tab(
                icon: Icon(Icons.account_balance_outlined, size: 18),
                text: 'Datos de Transferencia',
              ),
            ],
          ),
        ),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ConfiguracionSistemaTab(),
              _DatosTransferenciaTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB 1 — CONFIGURACIÓN DEL SISTEMA
// ══════════════════════════════════════════════════════════

class _ConfiguracionSistemaTab extends StatefulWidget {
  _ConfiguracionSistemaTab();

  @override
  State<_ConfiguracionSistemaTab> createState() =>
      _ConfiguracionSistemaTabState();
}

class _ConfiguracionSistemaTabState extends State<_ConfiguracionSistemaTab> {
  final ConfiguracionSistemaCrudImpl _crud = ConfiguracionSistemaCrudImpl();
  final EstablecimientoCrudImpl _estCrud = EstablecimientoCrudImpl();
  final MonedaCrudImpl _monedaCrud = MonedaCrudImpl();
  final ModoPagoCrudImpl _modoPagoCrud = ModoPagoCrudImpl();
  final TipoFacturaCrudImpl _tipoFacturaCrud = TipoFacturaCrudImpl();

  ConfiguracionSistema? _config;
  List<Establecimiento> _establecimientos = [];
  List<Moneda> _monedas = [];
  List<ModoPago> _modosPago = [];
  List<TipoFactura> _tiposFactura = [];

  Establecimiento? _estSeleccionado;
  Moneda? _monedaSeleccionada;
  ModoPago? _modoPagoSeleccionado;
  TipoFactura? _tipoFacturaSeleccionado;
  int _condicionVenta = 1;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _crud.leerConfiguracionActual(),
        _estCrud.leerEstablecimientos(),
        _monedaCrud.leerMonedas(),
        _modoPagoCrud.leerModosPago(),
        _tipoFacturaCrud.leerTiposFactura(),
      ]);

      final config = results[0] as ConfiguracionSistema?;
      final establecimientos = results[1] as List<Establecimiento>;
      final monedas = results[2] as List<Moneda>;
      final modosPago = results[3] as List<ModoPago>;
      final tiposFactura = results[4] as List<TipoFactura>;

      setState(() {
        _config = config;
        _establecimientos = establecimientos;
        _monedas = monedas;
        _modosPago = modosPago;
        _tiposFactura = tiposFactura;

        if (config != null) {
          _estSeleccionado = establecimientos.firstWhere(
            (e) =>
                e.id_establecimiento ==
                config.establecimiento_default.id_establecimiento,
            orElse: () => establecimientos.isNotEmpty
                ? establecimientos.first
                : config.establecimiento_default,
          );
          _monedaSeleccionada = monedas.firstWhere(
            (m) => m.id_monedas == config.moneda_default.id_monedas,
            orElse: () =>
                monedas.isNotEmpty ? monedas.first : config.moneda_default,
          );
          _modoPagoSeleccionado = modosPago.firstWhere(
            (mp) => mp.id_modo_pago == config.modo_pago_default.id_modo_pago,
            orElse: () => modosPago.isNotEmpty
                ? modosPago.first
                : config.modo_pago_default,
          );
          _tipoFacturaSeleccionado = tiposFactura.firstWhere(
            (tf) =>
                tf.id_tipo_factura ==
                config.tipo_factura_default.id_tipo_factura,
            orElse: () => tiposFactura.isNotEmpty
                ? tiposFactura.first
                : config.tipo_factura_default,
          );
          _condicionVenta = config.condicion_venta_default;
        } else {
          // Sin config previa: usar primeros de cada lista como default
          if (establecimientos.isNotEmpty) {
            _estSeleccionado = establecimientos.first;
          }
          if (monedas.isNotEmpty) _monedaSeleccionada = monedas.first;
          if (modosPago.isNotEmpty) _modoPagoSeleccionado = modosPago.first;
          if (tiposFactura.isNotEmpty) {
            _tipoFacturaSeleccionado = tiposFactura.first;
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarSnack('Error al cargar configuración: $e', Colors.red);
    }
  }

  Future<void> _guardar() async {
    if (_estSeleccionado == null ||
        _monedaSeleccionada == null ||
        _modoPagoSeleccionado == null ||
        _tipoFacturaSeleccionado == null) {
      _mostrarSnack('Complete todos los campos requeridos', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    final configNueva = ConfiguracionSistema(
      id_config: _config?.id_config,
      establecimiento_default: _estSeleccionado!,
      moneda_default: _monedaSeleccionada!,
      modo_pago_default: _modoPagoSeleccionado!,
      tipo_factura_default: _tipoFacturaSeleccionado!,
      condicion_venta_default: _condicionVenta,
    );

    try {
      bool exito;
      if (_config == null) {
        final creado = await _crud.crearConfiguracion(configNueva);
        exito = creado != null;
        if (exito) setState(() => _config = creado);
      } else {
        exito = await _crud.actualizarConfiguracion(configNueva);
      }

      setState(() => _isSaving = false);

      _mostrarSnack(
        exito
            ? 'Configuración guardada correctamente'
            : 'Error al guardar configuración',
        exito ? Colors.green : Colors.red,
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _mostrarSnack('Error: $e', Colors.red);
    }
  }

  void _mostrarSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              _HeaderCard(
                icon: Icons.settings_outlined,
                titulo: 'Configuración del Sistema',
                subtitulo: _config == null
                    ? 'Sin configuración — se creará una nueva al guardar'
                    : 'ID Configuración: ${_config!.id_config}',
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // Sección: Defaults de Facturación
              _SectionCard(
                titulo: 'Valores por Defecto de Facturación',
                icon: Icons.receipt_outlined,
                children: [
                  _buildDropdown<Establecimiento>(
                    label: 'Establecimiento por Defecto *',
                    value: _estSeleccionado,
                    items: _establecimientos,
                    onChanged: (v) => setState(() => _estSeleccionado = v),
                    itemLabel: (e) =>
                        '${e.codigo_establecimiento} — ${e.denominacion}',
                    icon: Icons.store_outlined,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown<Moneda>(
                          label: 'Moneda *',
                          value: _monedaSeleccionada,
                          items: _monedas,
                          onChanged: (v) =>
                              setState(() => _monedaSeleccionada = v),
                          itemLabel: (m) => m.divisa,
                          icon: Icons.attach_money_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown<ModoPago>(
                          label: 'Modo de Pago *',
                          value: _modoPagoSeleccionado,
                          items: _modosPago,
                          onChanged: (v) =>
                              setState(() => _modoPagoSeleccionado = v),
                          itemLabel: (mp) => mp.descripcion,
                          icon: Icons.payment_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown<TipoFactura>(
                          label: 'Tipo de Factura *',
                          value: _tipoFacturaSeleccionado,
                          items: _tiposFactura,
                          onChanged: (v) =>
                              setState(() => _tipoFacturaSeleccionado = v),
                          itemLabel: (tf) => tf.descripcion,
                          icon: Icons.description_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown<int>(
                          label: 'Condición de Venta *',
                          value: _condicionVenta,
                          items: const [1, 2],
                          onChanged: (v) =>
                              setState(() => _condicionVenta = v ?? 1),
                          itemLabel: (c) =>
                              c == 1 ? 'Contado' : 'Crédito',
                          icon: Icons.handshake_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Botón Guardar
              _BotonGuardar(
                isSaving: _isSaving,
                isNew: _config == null,
                onPressed: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String Function(T) itemLabel,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            )),
        SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: _inputDecoration(icon),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      itemLabel(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TAB 2 — DATOS DE TRANSFERENCIA
// ══════════════════════════════════════════════════════════

class _DatosTransferenciaTab extends StatefulWidget {
  _DatosTransferenciaTab();

  @override
  State<_DatosTransferenciaTab> createState() => _DatosTransferenciaTabState();
}

class _DatosTransferenciaTabState extends State<_DatosTransferenciaTab> {
  final DatosTransferenciaCrudImpl _crud = DatosTransferenciaCrudImpl();
  final EstablecimientoCrudImpl _estCrud = EstablecimientoCrudImpl();
  final _formKey = GlobalKey<FormState>();

  DatosTransferencia? _datos;
  List<Establecimiento> _establecimientos = [];
  Establecimiento? _sucursalSeleccionada;

  final _aliasCtrl = TextEditingController();
  final _titularCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  final _ciCtrl = TextEditingController();
  final _numCuentaCtrl = TextEditingController();
  final _nroGiroCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _aliasCtrl.dispose();
    _titularCtrl.dispose();
    _bancoCtrl.dispose();
    _ciCtrl.dispose();
    _numCuentaCtrl.dispose();
    _nroGiroCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _crud.leerDatosTransferencia(),
        _estCrud.leerEstablecimientos(),
      ]);

      final lista = results[0] as List<DatosTransferencia>;
      final establecimientos = results[1] as List<Establecimiento>;

      setState(() {
        _establecimientos = establecimientos;

        if (lista.isNotEmpty) {
          _datos = lista.first;
          _poblarFormulario(_datos!);
        } else {
          if (establecimientos.isNotEmpty) {
            _sucursalSeleccionada = establecimientos.first;
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarSnack('Error al cargar datos: $e', Colors.red);
    }
  }

  void _poblarFormulario(DatosTransferencia d) {
    _aliasCtrl.text = d.alias ?? '';
    _titularCtrl.text = d.titular_cuenta;
    _bancoCtrl.text = d.banco;
    _ciCtrl.text = d.ci;
    _numCuentaCtrl.text = d.num_cuenta;
    _nroGiroCtrl.text = d.nro_giro ?? '';
    _sucursalSeleccionada = _establecimientos.firstWhere(
      (e) => e.id_establecimiento == d.fk_sucursal.id_establecimiento,
      orElse: () => d.fk_sucursal,
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sucursalSeleccionada == null) {
      _mostrarSnack('Seleccione una sucursal', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      bool exito;

      if (_datos == null) {
        // Crear nuevo — id temporal 0, la BD lo asigna
        final nuevo = DatosTransferencia(
          id: 0,
          alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
          titular_cuenta: _titularCtrl.text.trim(),
          banco: _bancoCtrl.text.trim(),
          ci: _ciCtrl.text.trim(),
          num_cuenta: _numCuentaCtrl.text.trim(),
          fk_sucursal: _sucursalSeleccionada!,
          nro_giro: _nroGiroCtrl.text.trim().isEmpty
              ? null
              : _nroGiroCtrl.text.trim(),
        );
        final creado = await _crud.crearDatosTransferencia(nuevo);
        exito = creado != null;
        if (exito) await _cargarDatos(); // recargar para obtener id real
      } else {
        final actualizado = DatosTransferencia(
          id: _datos!.id,
          alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
          titular_cuenta: _titularCtrl.text.trim(),
          banco: _bancoCtrl.text.trim(),
          ci: _ciCtrl.text.trim(),
          num_cuenta: _numCuentaCtrl.text.trim(),
          fk_sucursal: _sucursalSeleccionada!,
          nro_giro: _nroGiroCtrl.text.trim().isEmpty
              ? null
              : _nroGiroCtrl.text.trim(),
        );
        exito = await _crud.actualizarDatosTransferencia(actualizado);
      }

      setState(() => _isSaving = false);
      _mostrarSnack(
        exito ? 'Datos guardados correctamente' : 'Error al guardar',
        exito ? Colors.green : Colors.red,
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _mostrarSnack('Error: $e', Colors.red);
    }
  }

  void _mostrarSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 700),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                _HeaderCard(
                  icon: Icons.account_balance_outlined,
                  titulo: 'Datos de Transferencia',
                  subtitulo: _datos == null
                      ? 'Sin datos registrados — se creará uno nuevo al guardar'
                      : 'ID: ${_datos!.id}',
                  color: Color(0xFF059669),
                ),
                SizedBox(height: 24),

                // Sección: Identificación
                _SectionCard(
                  titulo: 'Identificación de la Cuenta',
                  icon: Icons.badge_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _aliasCtrl,
                            label: 'Alias (opcional)',
                            hint: 'Ej: Cuenta Principal',
                            icon: Icons.label_outline,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _titularCtrl,
                            label: 'Titular de la Cuenta *',
                            hint: 'Nombre del titular',
                            icon: Icons.person_outline,
                            required: true,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _bancoCtrl,
                            label: 'Banco *',
                            hint: 'Nombre del banco',
                            icon: Icons.account_balance_outlined,
                            required: true,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _ciCtrl,
                            label: 'CI *',
                            hint: 'Cédula de identidad',
                            icon: Icons.credit_card_outlined,
                            required: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Sección: Datos Bancarios
                _SectionCard(
                  titulo: 'Datos Bancarios',
                  icon: Icons.payments_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _numCuentaCtrl,
                            label: 'Número de Cuenta *',
                            hint: 'Ej: 0000-000000-0',
                            icon: Icons.numbers_outlined,
                            required: true,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _nroGiroCtrl,
                            label: 'Nro. Giro (opcional)',
                            hint: 'Número de giro',
                            icon: Icons.loop_outlined,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildDropdown<Establecimiento>(
                      label: 'Sucursal Asociada *',
                      value: _sucursalSeleccionada,
                      items: _establecimientos,
                      onChanged: (v) =>
                          setState(() => _sucursalSeleccionada = v),
                      itemLabel: (e) =>
                          '${e.codigo_establecimiento} — ${e.denominacion}',
                      icon: Icons.store_outlined,
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Botón Guardar
                _BotonGuardar(
                  isSaving: _isSaving,
                  isNew: _datos == null,
                  onPressed: _guardar,
                  color: Color(0xFF059669),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            )),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
              : null,
          decoration: _inputDecoration(icon).copyWith(hintText: hint),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String Function(T) itemLabel,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            )),
        SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: _inputDecoration(icon),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      itemLabel(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS COMPARTIDOS
// ══════════════════════════════════════════════════════════

class _HeaderCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final Color color;

  _HeaderCard({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  )),
              SizedBox(height: 2),
              Text(subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String titulo;
  final IconData icon;
  final List<Widget> children;

  _SectionCard({
    required this.titulo,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(titulo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    )),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonGuardar extends StatelessWidget {
  final bool isSaving;
  final bool isNew;
  final VoidCallback onPressed;
  final Color color;

  _BotonGuardar({
    required this.isSaving,
    required this.isNew,
    required this.onPressed,
    this.color = const Color(0xFF0085FF),
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isSaving ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
      ),
      icon: isSaving
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(isNew ? Icons.add_circle_outline : Icons.save_outlined,
              size: 18),
      label: Text(
        isSaving
            ? 'Guardando...'
            : isNew
                ? 'Crear Registro'
                : 'Guardar Cambios',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HELPER GLOBAL
// ══════════════════════════════════════════════════════════

InputDecoration _inputDecoration(IconData icon) {
  return InputDecoration(
    prefixIcon: Icon(icon, size: 18, color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: Color(0xFFF9FAFB),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Color(0xFFD1D5DB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Color(0xFFD1D5DB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Color(0xFF0085FF), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.red),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}