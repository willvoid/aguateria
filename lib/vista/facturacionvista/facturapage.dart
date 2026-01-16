import 'package:flutter/material.dart';
import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:myapp/dao/empresadao/establecimientocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/apertura_cierre_cajacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/detalle_facturacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/facturacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/modo_pagocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/monedascrudimpl.dart';
import 'package:myapp/dao/facturaciondao/tipo_facturacrudimpl.dart';
import 'package:myapp/modelo/facturacionmodelo/factura.dart';
import 'package:myapp/modelo/facturacionmodelo/detalle_factura.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/facturacionmodelo/apertura_cierre_caja.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';
import 'package:myapp/modelo/usuario/authprovider.dart';
import 'package:myapp/vista/facturacionvista/apertura_cierre_cajapage.dart';
import 'package:myapp/vista/facturacionvista/detallefacturawidget.dart';
import 'package:provider/provider.dart';

class CrearFacturaPage extends StatefulWidget {
  const CrearFacturaPage({Key? key}) : super(key: key);

  @override
  State<CrearFacturaPage> createState() => _CrearFacturaPageState();
}

class _CrearFacturaPageState extends State<CrearFacturaPage> {
  final FacturaCrudImpl _facturaCrud = FacturaCrudImpl();
  final DetalleFacturaCrudImpl _detalleCrud = DetalleFacturaCrudImpl();
  final ClienteCrudImpl _clienteCrud = ClienteCrudImpl();
  final EstablecimientoCrudImpl _establecimientoCrud = EstablecimientoCrudImpl();
  final AperturaCierreCajaCrudImpl _aperturaCrud = AperturaCierreCajaCrudImpl();
  final ModoPagoCrudImpl _modoPagoCrud = ModoPagoCrudImpl();
  final MonedaCrudImpl _monedaCrud = MonedaCrudImpl();
  final TipoFacturaCrudImpl _tipoFacturaCrud = TipoFacturaCrudImpl();

  final _formKey = GlobalKey<FormState>();

  // Datos de catálogos
  List<Cliente> _clientes = [];
  List<Establecimiento> _establecimientos = [];
  List<ModoPago> _modosPago = [];
  List<Moneda> _monedas = [];
  List<TipoFactura> _tiposFactura = [];
  AperturaCierreCaja? _cajaAbierta;

  // Selecciones
  Cliente? _clienteSeleccionado;
  Establecimiento? _establecimientoSeleccionado;
  ModoPago? _modoPagoSeleccionado;
  Moneda? _monedaSeleccionada;
  TipoFactura? _tipoFacturaSeleccionado;
  int _condicionVenta = 1; // 1 = Contado, 2 = Crédito

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

      // Verificar caja abierta
      final cajaAbierta = await _aperturaCrud.verificarCajaAbiertaUsuario(usuario.id_usuario!);
      
      if (!cajaAbierta) {
        setState(() {
          _isLoading = false;
          _errorCarga = true;
          _mensajeError = 'Debe abrir una caja antes de facturar';
        });
        return;
      }

      // Cargar catálogos en paralelo
      final resultados = await Future.wait([
        _clienteCrud.leerClientes(),
        _establecimientoCrud.leerEstablecimientos(),
        _modoPagoCrud.leerModosPago(),
        _monedaCrud.leerMonedas(),
        _tipoFacturaCrud.leerTiposFactura(),
        _aperturaCrud.leerAperturasPorUsuario(usuario.id_usuario!),
      ]);

      final clientes = resultados[0] as List<Cliente>;
      final establecimientos = resultados[1] as List<Establecimiento>;
      final modosPago = resultados[2] as List<ModoPago>;
      final monedas = resultados[3] as List<Moneda>;
      final tiposFactura = resultados[4] as List<TipoFactura>;
      final aperturas = resultados[5] as List<AperturaCierreCaja>;

      // Obtener caja abierta del usuario
      final cajaActiva = aperturas.firstWhere(
        (a) => a.cierre == null,
        orElse: () => throw Exception('No hay caja abierta'),
      );

      setState(() {
        _clientes = clientes;
        _establecimientos = establecimientos;
        _modosPago = modosPago;
        _monedas = monedas;
        _tiposFactura = tiposFactura;
        _cajaAbierta = cajaActiva;
        _isLoading = false;

        // Seleccionar valores por defecto
        if (_monedas.isNotEmpty) {
          _monedaSeleccionada = _monedas.first;
        }
        if (_modosPago.isNotEmpty) {
          _modoPagoSeleccionado = _modosPago.first;
        }
        if (_tiposFactura.isNotEmpty) {
          _tipoFacturaSeleccionado = _tiposFactura.first;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorCarga = true;
        _mensajeError = 'Error al cargar datos: $e';
      });
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
      final montoBase = detalle.monto * detalle.cantidad;
      
      if (detalle.iva_aplicado == 10) {
        totalGravado10 += montoBase;
        totalIVA += montoBase * 0.1;
      } else if (detalle.iva_aplicado == 5) {
        totalGravado5 += montoBase;
        totalIVA += montoBase * 0.05;
      } else {
        totalExenta += montoBase;
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

  Future<void> _guardarFactura() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_clienteSeleccionado == null) {
      _mostrarError('Debe seleccionar un cliente');
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

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Obtener próximo número secuencial
      final nroSecuencial = await _facturaCrud.obtenerProximoSecuencial(
        _establecimientoSeleccionado!.id_establecimiento!,
        _tipoFacturaSeleccionado!.id_tipo_factura!,
      );

      // Crear factura
      final factura = Factura(
        fecha_emision: DateTime.now(),
        fk_cliente: _clienteSeleccionado!,
        codicion_venta: _condicionVenta,
        total_gravado_10: _totalGravado10,
        total_gravado_5: _totalGravado5,
        total_exenta: _totalExenta,
        total_iva: _totalIVA,
        total_general: _totalGeneral,
        observacion: _observacionController.text,
        fk_monedas: _monedaSeleccionada!,
        fk_establecimientos: _establecimientoSeleccionado!,
        fk_modo_pago: _modoPagoSeleccionado!,
        fk_tipo_factura: _tipoFacturaSeleccionado!,
        nro_secuencial: nroSecuencial,
        fk_turno: _cajaAbierta!,
        tipo_emision: 1,
        efectivo: efectivo,
        vuelto: _vuelto,
        descuento_global: 0,
      );

      // Guardar factura
      final facturaCreada = await _facturaCrud.crearFactura(factura);

      if (facturaCreada == null) {
        throw Exception('Error al crear la factura');
      }

      // Asignar factura a los detalles y guardarlos
      for (var detalle in _detalles) {
        detalle.fk_factura = facturaCreada;
      }

      final detallesGuardados = await _detalleCrud.crearDetallesFactura(_detalles);

      // Cerrar diálogo de carga
      Navigator.pop(context);

      if (detallesGuardados) {
        _mostrarExito('Factura creada exitosamente');
        Navigator.pop(context, facturaCreada);
      } else {
        _mostrarError('Error al guardar detalles de la factura');
      }
    } catch (e) {
      // Cerrar diálogo de carga
      Navigator.pop(context);
      _mostrarError('Error al guardar factura: $e');
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

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Factura'),
        backgroundColor: const Color(0xFF0085FF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorCarga
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _mensajeError,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => AperturaCierreCajaPage(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Abri Caja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0085FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
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
                          // Datos principales
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Datos de la Factura',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Cliente
                                  DropdownButtonFormField<Cliente>(
                                    value: _clienteSeleccionado,
                                    decoration: const InputDecoration(
                                      labelText: 'Cliente *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                    items: _clientes.map((cliente) {
                                      return DropdownMenuItem(
                                        value: cliente,
                                        child: Text(cliente.razonSocial),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _clienteSeleccionado = value);
                                    },
                                    validator: (value) =>
                                        value == null ? 'Seleccione un cliente' : null,
                                  ),
                                  const SizedBox(height: 12),

                                  // Establecimiento
                                  DropdownButtonFormField<Establecimiento>(
                                    value: _establecimientoSeleccionado,
                                    decoration: const InputDecoration(
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
                                      // Tipo Factura
                                      Expanded(
                                        child: DropdownButtonFormField<TipoFactura>(
                                          value: _tipoFacturaSeleccionado,
                                          decoration: const InputDecoration(
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
                                      // Condición de venta
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          value: _condicionVenta,
                                          decoration: const InputDecoration(
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
                                      // Modo Pago
                                      Expanded(
                                        child: DropdownButtonFormField<ModoPago>(
                                          value: _modoPagoSeleccionado,
                                          decoration: const InputDecoration(
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
                                      // Moneda
                                      Expanded(
                                        child: DropdownButtonFormField<Moneda>(
                                          value: _monedaSeleccionada,
                                          decoration: const InputDecoration(
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

                                  // Observación
                                  TextFormField(
                                    controller: _observacionController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
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

                          // Widget de detalles
                          DetalleFacturaWidget(
                            onDetalleAgregado: _agregarDetalle,
                            detallesActuales: _detalles,
                          ),
                          const SizedBox(height: 24),

                          // Resumen y pago
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Resumen',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                    decoration: const InputDecoration(
                                      labelText: 'Efectivo *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.payments),
                                      suffixText: 'Gs.',
                                    ),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) return 'Campo requerido';
                                      final monto = double.tryParse(value!);
                                      if (monto == null) return 'Monto inválido';
                                      if (monto < _totalGeneral) {
                                        return 'Insuficiente';
                                      }
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

                          // Botón guardar
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _guardarFactura,
                              icon: const Icon(Icons.save),
                              label: const Text(
                                'Guardar Factura',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0085FF),
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

  Widget _buildResumenItem(String label, double valor, {bool isTotal = false, Color? color}) {
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