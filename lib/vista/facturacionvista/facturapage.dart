import 'package:flutter/material.dart';
import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:myapp/dao/empresadao/establecimientocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/apertura_cierre_cajacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/detalle_facturacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/facturacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/modo_pagocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/monedascrudimpl.dart';
import 'package:myapp/dao/facturaciondao/tipo_facturacrudimpl.dart';
import 'package:myapp/dao/inmueblescrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/detalle_factura.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/facturacionmodelo/apertura_cierre_caja.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';
import 'package:myapp/modelo/usuario/authprovider.dart';
import 'package:myapp/service/factura_rpc_service.dart';
import 'package:myapp/vista/facturacionvista/detallefacturawidget.dart';
import 'package:myapp/widget/autocomplete_cliente.dart';
import 'package:myapp/widget/dialogo_exito_factura.dart';
import 'package:provider/provider.dart';

class CrearFacturaPage extends StatefulWidget {
  const CrearFacturaPage({Key? key}) : super(key: key);

  @override
  State<CrearFacturaPage> createState() => _CrearFacturaPageState();
}

class _CrearFacturaPageState extends State<CrearFacturaPage> {
  final FacturaRpcService _facturaRpcService = FacturaRpcService();
  final FacturaCrudImpl _facturaCrud = FacturaCrudImpl();
  final DetalleFacturaCrudImpl _detalleCrud = DetalleFacturaCrudImpl();
  final ClienteCrudImpl _clienteCrud = ClienteCrudImpl();
  final InmuebleCrudImpl _inmuebleCrud = InmuebleCrudImpl();
  final EstablecimientoCrudImpl _establecimientoCrud = EstablecimientoCrudImpl();
  final AperturaCierreCajaCrudImpl _aperturaCrud = AperturaCierreCajaCrudImpl();
  final ModoPagoCrudImpl _modoPagoCrud = ModoPagoCrudImpl();
  final MonedaCrudImpl _monedaCrud = MonedaCrudImpl();
  final TipoFacturaCrudImpl _tipoFacturaCrud = TipoFacturaCrudImpl();

  Key _detalleWidgetKey = UniqueKey();
  final _formKey = GlobalKey<FormState>();

  // Datos de catálogos
  List<Cliente> _clientes = [];
  List<Inmuebles> _inmuebles = [];
  List<Establecimiento> _establecimientos = [];
  List<ModoPago> _modosPago = [];
  List<Moneda> _monedas = [];
  List<TipoFactura> _tiposFactura = [];
  AperturaCierreCaja? _cajaAbierta;

  // Selecciones
  Cliente? _clienteSeleccionado;
  Inmuebles? _inmuebleSeleccionado;
  Establecimiento? _establecimientoSeleccionado;
  ModoPago? _modoPagoSeleccionado;
  Moneda? _monedaSeleccionada;
  TipoFactura? _tipoFacturaSeleccionado;
  int _condicionVenta = 1;

  // Detalles de la factura
  List<DetalleFactura> _detalles = [];

  // Campos de pago
  final TextEditingController _efectivoController = TextEditingController();
  final TextEditingController _observacionController = TextEditingController();

  bool _isLoading = false;
  bool _errorCarga = false;
  String _mensajeError = '';
  double _totalGeneral = 0;
  double _totalGravado10 = 0;
  double _totalGravado5 = 0;
  double _totalExenta = 0;
  double _totalIVA = 0;
  double _vuelto = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _efectivoController.addListener(_calcularVuelto);
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorCarga = false;
      _mensajeError = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final usuario = authProvider.usuarioActual;

      if (usuario == null) {
        setState(() {
          _isLoading = false;
          _errorCarga = true;
          _mensajeError = 'Usuario no autenticado';
        });
        return;
      }

      final cajaAbierta = await _aperturaCrud.verificarCajaAbiertaUsuario(usuario.id_usuario!);

      if (!cajaAbierta) {
        setState(() {
          _isLoading = false;
          _errorCarga = true;
          _mensajeError = 'Debe abrir una caja antes de facturar';
        });
        return;
      }

      final resultados = await Future.wait([
        _clienteCrud.leerClientes(),
        _inmuebleCrud.leerInmuebles(),
        _establecimientoCrud.leerEstablecimientos(),
        _modoPagoCrud.leerModosPago(),
        _monedaCrud.leerMonedas(),
        _tipoFacturaCrud.leerTiposFactura(),
        _aperturaCrud.leerAperturasPorUsuario(usuario.id_usuario!),
      ]);

      final clientes = resultados[0] as List<Cliente>;
      final inmuebles = resultados[1] as List<Inmuebles>;
      final establecimientos = resultados[2] as List<Establecimiento>;
      final modosPago = resultados[3] as List<ModoPago>;
      final monedas = resultados[4] as List<Moneda>;
      final tiposFactura = resultados[5] as List<TipoFactura>;
      final aperturas = resultados[6] as List<AperturaCierreCaja>;

      final cajaActiva = aperturas.firstWhere(
        (a) => a.cierre == null,
        orElse: () => throw Exception('No hay caja abierta'),
      );

      setState(() {
        _clientes = clientes;
        _inmuebles = inmuebles;
        _establecimientos = establecimientos;
        _modosPago = modosPago;
        _monedas = monedas;
        _tiposFactura = tiposFactura;
        _cajaAbierta = cajaActiva;
        _isLoading = false;

        if (_monedas.isNotEmpty) _monedaSeleccionada = _monedas.first;
        if (_modosPago.isNotEmpty) _modoPagoSeleccionado = _modosPago.first;
        if (_tiposFactura.isNotEmpty) _tipoFacturaSeleccionado = _tiposFactura.first;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorCarga = true;
        _mensajeError = 'Error al cargar datos: $e';
      });
    }
  }

  void _cargarInmueblesPorCliente(Cliente cliente) async {
    try {
      final inmuebles = await _inmuebleCrud.leerInmueblesPorCliente(cliente.idCliente!);
      setState(() {
        _inmuebles = inmuebles;
        _inmuebleSeleccionado = null;
        if (_inmuebles.isNotEmpty) {
          _inmuebleSeleccionado = _inmuebles.first;
        }
      });
    } catch (e) {
      _mostrarError('Error al cargar inmuebles: $e');
    }
  }

  void _agregarDetalle(DetalleFactura detalle) {
    setState(() {
      _detalles.add(detalle);
      _calcularTotales();
    });
  }

  void _calcularTotales() {
    double totalGravado10 = 0;
    double totalGravado5 = 0;
    double totalExenta = 0;
    double totalIVA = 0;

    for (var detalle in _detalles) {
      final montoTotalConIva = detalle.monto * detalle.cantidad;
      final tasaIva = detalle.iva_aplicado;

      if (tasaIva == 10) {
        final iva = montoTotalConIva * (tasaIva / 100) / (1 + tasaIva / 100);
        totalGravado10 += montoTotalConIva - iva;
        totalIVA += iva;
      } else if (tasaIva == 5) {
        final iva = montoTotalConIva * (tasaIva / 100) / (1 + tasaIva / 100);
        totalGravado5 += montoTotalConIva - iva;
        totalIVA += iva;
      } else {
        totalExenta += montoTotalConIva;
      }
    }

    setState(() {
      _totalGravado10 = totalGravado10;
      _totalGravado5 = totalGravado5;
      _totalExenta = totalExenta;
      _totalIVA = totalIVA;
      _totalGeneral = totalGravado10 + totalGravado5 + totalExenta + totalIVA;
    });
  }

  void _calcularVuelto() {
    final efectivo = double.tryParse(_efectivoController.text) ?? 0;
    setState(() {
      _vuelto = efectivo - _totalGeneral;
    });
  }

  void _limpiarFormulario() {
    _efectivoController.clear();
    _observacionController.clear();
    setState(() {
      _clienteSeleccionado = null;
      _inmuebleSeleccionado = null;
      _establecimientoSeleccionado = null;
      _detalles = [];
      _totalGeneral = 0;
      _totalGravado10 = 0;
      _totalGravado5 = 0;
      _totalExenta = 0;
      _totalIVA = 0;
      _vuelto = 0;
      _condicionVenta = 1;
      _detalleWidgetKey = UniqueKey(); // fuerza rebuild del DetalleFacturaWidget
      if (_monedas.isNotEmpty) _monedaSeleccionada = _monedas.first;
      if (_modosPago.isNotEmpty) _modoPagoSeleccionado = _modosPago.first;
      if (_tiposFactura.isNotEmpty) _tipoFacturaSeleccionado = _tiposFactura.first;
    });
  }

  Future<void> _guardarFactura() async {
    if (!_formKey.currentState!.validate()) return;

    if (_clienteSeleccionado == null) {
      _mostrarError('Debe seleccionar un cliente');
      return;
    }

    if (_inmuebleSeleccionado == null) {
      _mostrarError('Debe seleccionar un inmueble');
      return;
    }

    if (_detalles.isEmpty) {
      _mostrarError('Debe agregar al menos un item');
      return;
    }

    if (_establecimientoSeleccionado == null) {
      _mostrarError('Debe seleccionar un establecimiento');
      return;
    }

    final efectivo = double.tryParse(_efectivoController.text) ?? 0;
    if (efectivo < _totalGeneral) {
      _mostrarError('El efectivo debe ser mayor o igual al total');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Guardando factura...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final nroSecuencial = await _facturaCrud.obtenerProximoSecuencial(
        _establecimientoSeleccionado!.id_establecimiento!,
        _tipoFacturaSeleccionado!.id_tipo_factura!,
      );

      final payload = _facturaRpcService.construirPayload(
        cliente: _clienteSeleccionado!,
        inmueble: _inmuebleSeleccionado!,
        establecimiento: _establecimientoSeleccionado!,
        modoPago: _modoPagoSeleccionado!,
        moneda: _monedaSeleccionada!,
        tipoFactura: _tipoFacturaSeleccionado!,
        cajaAbierta: _cajaAbierta!,
        condicionVenta: _condicionVenta,
        totalGravado10: _totalGravado10,
        totalGravado5: _totalGravado5,
        totalExenta: _totalExenta,
        totalIva: _totalIVA,
        totalGeneral: _totalGeneral,
        observacion: _observacionController.text,
        nroSecuencial: nroSecuencial,
        efectivo: efectivo,
        vuelto: _vuelto,
        descuentoGlobal: 0,
        detalles: _detalles,
      );

      print('📦 Payload JSON a enviar:');
      print(payload.toJson());

      final facturaCreada = await _facturaRpcService.guardarFacturaRpc(payload);
      final idFactura = _facturaRpcService.extraerIdFactura(facturaCreada);

      if (mounted) Navigator.pop(context);

      if (idFactura != null) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => FacturaSuccessDialog(
              facturaCreada: facturaCreada,
              clienteNombre: _clienteSeleccionado!.razonSocial,
            ),
          ).then((_) {
            if (mounted) _limpiarFormulario();
          });
        }
      } else {
        throw Exception('No se pudo extraer el ID de la factura');
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, color: Colors.red.shade600, size: 64),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Error al Guardar',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.toString().replaceAll('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Por favor, verifique los datos e intente nuevamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva Factura'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorCarga
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _mensajeError,
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back),
                        label: Text('Volver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Datos de la Factura',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),

                                  ClienteAutocomplete(
                                    clientes: _clientes,
                                    onSeleccionado: (c) {
                                      setState(() => _clienteSeleccionado = c);
                                      _cargarInmueblesPorCliente(c);
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  DropdownButtonFormField<Inmuebles>(
                                    value: _inmuebleSeleccionado,
                                    decoration: InputDecoration(
                                      labelText: 'Inmueble *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.home),
                                    ),
                                    items: _inmuebles.map((inmueble) {
                                      return DropdownMenuItem(
                                        value: inmueble,
                                        child: Text(
                                          '${inmueble.cod_inmueble} - ${inmueble.direccion ?? "Sin dirección"}',
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _inmuebleSeleccionado = value);
                                    },
                                    validator: (value) =>
                                        value == null ? 'Seleccione un inmueble' : null,
                                  ),
                                  const SizedBox(height: 12),

                                  DropdownButtonFormField<Establecimiento>(
                                    value: _establecimientoSeleccionado,
                                    decoration: InputDecoration(
                                      labelText: 'Establecimiento *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.store),
                                    ),
                                    items: _establecimientos.map((est) {
                                      return DropdownMenuItem(
                                        value: est,
                                        child: Text(est.denominacion),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _establecimientoSeleccionado = value);
                                    },
                                    validator: (value) =>
                                        value == null ? 'Seleccione un establecimiento' : null,
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<TipoFactura>(
                                          value: _tipoFacturaSeleccionado,
                                          decoration: InputDecoration(
                                            labelText: 'Tipo *',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: _tiposFactura.map((tipo) {
                                            return DropdownMenuItem(
                                              value: tipo,
                                              child: Text(tipo.descripcion ?? ''),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() => _tipoFacturaSeleccionado = value);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          value: _condicionVenta,
                                          decoration: InputDecoration(
                                            labelText: 'Condición *',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 1, child: Text('Contado')),
                                            DropdownMenuItem(value: 2, child: Text('Crédito')),
                                          ],
                                          onChanged: (value) {
                                            setState(() => _condicionVenta = value!);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<ModoPago>(
                                          value: _modoPagoSeleccionado,
                                          decoration: InputDecoration(
                                            labelText: 'Modo Pago *',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: _modosPago.map((modo) {
                                            return DropdownMenuItem(
                                              value: modo,
                                              child: Text(modo.descripcion),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() => _modoPagoSeleccionado = value);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<Moneda>(
                                          value: _monedaSeleccionada,
                                          decoration: InputDecoration(
                                            labelText: 'Moneda *',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: _monedas.map((moneda) {
                                            return DropdownMenuItem(
                                              value: moneda,
                                              child: Text(moneda.divisa),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() => _monedaSeleccionada = value);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  TextFormField(
                                    controller: _observacionController,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      labelText: 'Observación',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.note),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          DetalleFacturaWidget(
                            key: _detalleWidgetKey,
                            onDetalleAgregado: _agregarDetalle,
                            detallesActuales: _detalles,
                            inmuebleSeleccionado: _inmuebleSeleccionado, // ← FIX
                          ),
                          const SizedBox(height: 24),

                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Resumen',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildResumenItem('Gravado 10%', _totalGravado10),
                                  _buildResumenItem('Gravado 5%', _totalGravado5),
                                  _buildResumenItem('Exenta', _totalExenta),
                                  _buildResumenItem('IVA', _totalIVA),
                                  const Divider(thickness: 2),
                                  _buildResumenItem('TOTAL', _totalGeneral, isTotal: true),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _efectivoController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Efectivo *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.payments),
                                      suffixText: 'Gs.',
                                    ),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) return 'Campo requerido';
                                      final monto = double.tryParse(value!);
                                      if (monto == null) return 'Monto inválido';
                                      if (monto < _totalGeneral) return 'Insuficiente';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildResumenItem('Vuelto', _vuelto, color: Colors.green),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _guardarFactura,
                              icon: Icon(Icons.save),
                              label: Text(
                                'Guardar Factura',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildResumenItem(String label, double valor,
      {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${valor.toStringAsFixed(0)} Gs.',
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isTotal ? const Color(0xFF0085FF) : null),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _efectivoController.dispose();
    _observacionController.dispose();
    super.dispose();
  }
}